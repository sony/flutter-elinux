// Copyright 2021 Sony Group Corporation. All rights reserved.
// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:file/file.dart';
import 'package:flutter_tools/src/android/android_builder.dart';
import 'package:flutter_tools/src/android/gradle.dart';
import 'package:flutter_tools/src/base/analyze_size.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/os.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/assemble.dart';
import 'package:flutter_tools/src/commands/build_ios_framework.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/linux/build_linux.dart';
import 'package:flutter_tools/src/project.dart';
import 'package:meta/meta.dart';

import 'elinux_build_target.dart';
import 'elinux_cmake_project.dart';

/// The define to control what eLinux device is built for.
const String kTargetBackendType = 'TargetBackendType';

/// See: [AndroidBuildInfo] in `build_info.dart`
class ELinuxBuildInfo {
  const ELinuxBuildInfo(
    this.buildInfo, {
    @required this.targetArch,
    @required this.targetBackendType,
    @required this.targetSysroot,
    @required this.systemIncludeDirectories,
  })  : assert(targetArch != null),
        assert(targetBackendType != null);

  final BuildInfo buildInfo;
  final String targetArch;
  final String targetBackendType;
  final String targetSysroot;
  final String systemIncludeDirectories;
}

/// See:
/// - [AndroidBuilder] in `android_builder.dart`
/// - [AndroidGradleBuilder.buildGradleApp] in `gradle.dart`
/// - [BuildIOSFrameworkCommand._produceAppFramework] in `build_ios_framework.dart` (build target)
/// - [AssembleCommand.runCommand] in `assemble.dart` (performance measurement)
/// - [buildLinux] in `build_linux.dart` (code size)
class ELinuxBuilder {
  static Future<void> buildBundle({
    @required FlutterProject project,
    @required ELinuxBuildInfo eLinuxBuildInfo,
    @required String targetFile,
    SizeAnalyzer sizeAnalyzer,
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
    final String buildModeName = getNameForBuildMode(buildInfo.mode);
    // Used by AotElfBase to generate an AOT snapshot.
    final String targetPlatform = getNameForTargetPlatform(
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
        kTargetPlatform: targetPlatform,
        kDartObfuscation: buildInfo.dartObfuscation.toString(),
        kSplitDebugInfo: buildInfo.splitDebugInfoPath,
        kIconTreeShakerFlag: buildInfo.treeShakeIcons.toString(),
        kTrackWidgetCreation: buildInfo.trackWidgetCreation.toString(),
        kCodeSizeDirectory: buildInfo.codeSizeDirectory,
        if (buildInfo.dartDefines?.isNotEmpty ?? false)
          kDartDefines: encodeDartDefines(buildInfo.dartDefines),
        if (buildInfo.extraGenSnapshotOptions?.isNotEmpty ?? false)
          kExtraGenSnapshotOptions: buildInfo.extraGenSnapshotOptions.join(','),
        if (buildInfo.extraFrontEndOptions?.isNotEmpty ?? false)
          kExtraFrontEndOptions: buildInfo.extraFrontEndOptions.join(','),
        kTargetBackendType: eLinuxBuildInfo.targetBackendType,
      },
      inputs: <String, String>{
        kBundleSkSLPath: buildInfo.bundleSkSLPath,
      },
      artifacts: globals.artifacts,
      fileSystem: globals.fs,
      logger: globals.logger,
      processManager: globals.processManager,
      platform: globals.platform,
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
  }
}

/// See: [getTargetPlatformForName] in `build_info.dart`
TargetPlatform _getTargetPlatformForArch(String arch) {
  final String hostArch = _getCurrentHostPlatformArchName();
  switch (arch) {
    case 'arm64':
      // Use gensnapshot for Arm64 Linux when the host is arm64 because
      // the artifacts for arm64 host don't support self-building now.
      if (hostArch == 'arm64') {
        return TargetPlatform.linux_arm64;
      }
      return TargetPlatform.android_arm64;
    default:
      // Use gensnapshot for Arm64 Linux when the host is arm64 because
      // the artifacts for arm64 host don't support self-building now.
      if (hostArch == 'arm64') {
        return TargetPlatform.linux_x64;
      }
      return TargetPlatform.android_x64;
  }
}

String _getCurrentHostPlatformArchName() {
  final HostPlatform hostPlatform = getCurrentHostPlatform();
  return getNameForHostPlatformArch(hostPlatform);
}
