// Copyright 2023 Sony Group Corporation. All rights reserved.
// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:file/file.dart';
import 'package:flutter_tools/src/android/android_builder.dart';
import 'package:flutter_tools/src/android/gradle.dart';
import 'package:flutter_tools/src/base/analyze_size.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/assemble.dart';
import 'package:flutter_tools/src/commands/build_ios_framework.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/linux/build_linux.dart';
import 'package:flutter_tools/src/project.dart';

import 'elinux_build_target.dart';
import 'elinux_cmake_project.dart';

/// The define to control what eLinux device is built for.
const String kTargetBackendType = 'TargetBackendType';

/// See: [AndroidBuildInfo] in `build_info.dart`
class ELinuxBuildInfo {
  const ELinuxBuildInfo(
    this.buildInfo, {
    required this.targetArch,
    required this.targetBackendType,
    required this.targetCompilerTriple,
    required this.targetSysroot,
    required this.targetCompilerFlags,
    required this.targetToolchain,
    required this.systemIncludeDirectories,
  });

  final BuildInfo buildInfo;
  final String targetArch;
  final String targetBackendType;
  final String? targetCompilerTriple;
  final String targetSysroot;
  final String? targetCompilerFlags;
  final String? targetToolchain;
  final String? systemIncludeDirectories;
}

// ignore: avoid_classes_with_only_static_members
/// See:
/// - [AndroidBuilder] in `android_builder.dart`
/// - [AndroidGradleBuilder.buildGradleApp] in `gradle.dart`
/// - [BuildIOSFrameworkCommand._produceAppFramework] in `build_ios_framework.dart` (build target)
/// - [AssembleCommand.runCommand] in `assemble.dart` (performance measurement)
/// - [buildLinux] in `build_linux.dart` (code size)
class ELinuxBuilder {
  static Future<void> buildBundle({
    required FlutterProject project,
    required ELinuxBuildInfo eLinuxBuildInfo,
    required String targetFile,
    SizeAnalyzer? sizeAnalyzer,
  }) async {
    final ELinuxProject elinuxProject = ELinuxProject.fromFlutter(project);
    if (!elinuxProject.existsSync()) {
      throwToolExit(
        'This project is not configured for eLinux.\n'
        'To fix this problem, create a new project by running `flutter-elinux create <app-dir>`.',
      );
    }

    final Directory outputDir =
        project.directory.childDirectory('build').childDirectory('elinux');
    final BuildInfo buildInfo = eLinuxBuildInfo.buildInfo;
    final String buildModeName = buildInfo.mode.cliName;
    // Used by AotElfBase to generate an AOT snapshot.
    final String targetPlatformName = getNameForTargetPlatform(
        _getTargetPlatformForArch(eLinuxBuildInfo.targetArch));

    final Environment environment = Environment(
      projectDir: project.directory,
      outputDir: outputDir,
      buildDir: project.dartTool.childDirectory('flutter_build'),
      cacheDir: globals.cache.getRoot(),
      flutterRootDir: globals.fs.directory(Cache.flutterRoot),
      engineVersion: globals.flutterVersion.engineRevision,
      generateDartPluginRegistry: true,
      defines: <String, String>{
        kTargetFile: targetFile,
        kBuildMode: buildModeName,
        kTargetPlatform: targetPlatformName,
        ...buildInfo.toBuildSystemEnvironment(),
        kTargetBackendType: eLinuxBuildInfo.targetBackendType,
      },
      artifacts: globals.artifacts!,
      fileSystem: globals.fs,
      logger: globals.logger,
      processManager: globals.processManager,
      platform: globals.platform,
      usage: globals.flutterUsage,
      analytics: globals.analytics,
    );

    final Target target = buildInfo.isDebug
        ? DebugELinuxApplication(eLinuxBuildInfo)
        : ReleaseELinuxApplication(eLinuxBuildInfo);

    final Status status = globals.logger.startProgress(
        'Building an eLinux application with ${eLinuxBuildInfo.targetBackendType} backend in $buildModeName mode for ${eLinuxBuildInfo.targetArch} target...');
    try {
      final BuildResult result =
          await globals.buildSystem.build(target, environment);
      if (!result.success) {
        for (final ExceptionMeasurement measurement
            in result.exceptions.values) {
          globals.printError(measurement.exception.toString());
        }
        throwToolExit('The build failed.');
      }

      // These pseudo targets cannot be skipped and should be invoked whenever
      // the build is run.
      await NativeBundle(eLinuxBuildInfo, targetFile).build(environment);

      if (buildInfo.performanceMeasurementFile != null) {
        final File outFile =
            globals.fs.file(buildInfo.performanceMeasurementFile);
        // ignore: invalid_use_of_visible_for_testing_member
        writePerformanceData(result.performance.values, outFile);
      }
    } finally {
      status.stop();
    }

    if (buildInfo.codeSizeDirectory != null && sizeAnalyzer != null) {
      final String arch = eLinuxBuildInfo.targetArch;
      final String genSnapshotPlatform = _getTargetPlatformPlatformName(
          _getTargetPlatformForArch(eLinuxBuildInfo.targetArch));
      final File codeSizeFile = globals.fs
          .directory(buildInfo.codeSizeDirectory)
          .childFile('snapshot.$genSnapshotPlatform.json');
      final File precompilerTrace = globals.fs
          .directory(buildInfo.codeSizeDirectory)
          .childFile('trace.$genSnapshotPlatform.json');
      final Map<String, Object?> output = await sizeAnalyzer.analyzeAotSnapshot(
        aotSnapshot: codeSizeFile,
        // This analysis is only supported for release builds.
        outputDirectory: globals.fs.directory(
          globals.fs.path.join(outputDir.path, arch, 'release', 'bundle'),
        ),
        precompilerTrace: precompilerTrace,
        type: 'linux',
      );
      final File outputFile = globals.fsUtils.getUniqueFile(
        globals.fs
            .directory(globals.fsUtils.homeDirPath)
            .childDirectory('.flutter-devtools'),
        'elinux-code-size-analysis',
        'json',
      )..writeAsStringSync(jsonEncode(output));
      // This message is used as a sentinel in analyze_apk_size_test.dart
      globals.printStatus(
        'A summary of your Linux bundle analysis can be found at: ${outputFile.path}',
      );

      // DevTools expects a file path relative to the .flutter-devtools/ dir.
      final String relativeAppSizePath =
          outputFile.path.split('.flutter-devtools/').last.trim();
      globals.printStatus(
          '\nTo analyze your app size in Dart DevTools, run the following command:\n'
          'flutter pub global activate devtools; flutter pub global run devtools '
          '--appSizeBase=$relativeAppSizePath');
    }
  }
}

/// See: [getTargetPlatformForName] in `build_info.dart`
TargetPlatform _getTargetPlatformForArch(String arch) {
  switch (arch) {
    case 'arm64':
      return TargetPlatform.linux_arm64;
    default:
      return TargetPlatform.linux_x64;
  }
}

String _getTargetPlatformPlatformName(TargetPlatform targetPlatform) {
  switch (targetPlatform) {
    case TargetPlatform.linux_arm64:
      return 'linux-arm64';
    case TargetPlatform.linux_x64:
      return 'linux-x64';
    case TargetPlatform.android_arm64:
      return 'android-arm64';
    // ignore: no_default_cases
    default:
      return 'android-x64';
  }
}
