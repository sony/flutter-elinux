// Copyright 2021 Sony Group Corporation. All rights reserved.
// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:io';

import 'package:file/file.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/build_system/depfile.dart';
import 'package:flutter_tools/src/build_system/exceptions.dart';
import 'package:flutter_tools/src/build_system/source.dart';
import 'package:flutter_tools/src/build_system/targets/android.dart';
import 'package:flutter_tools/src/build_system/targets/assets.dart';
import 'package:flutter_tools/src/build_system/targets/common.dart';
import 'package:flutter_tools/src/build_system/targets/icon_tree_shaker.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/cmake.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/project.dart';

import 'elinux_builder.dart';
import 'elinux_cmake_project.dart';
import 'elinux_plugins.dart';

/// Prepares the pre-built flutter bundle.
///
/// Source: [AndroidAssetBundle] in `android.dart`
abstract class ELinuxAssetBundle extends Target {
  const ELinuxAssetBundle();

  @override
  String get name => 'elinux_asset_bundle';

  @override
  List<Source> get inputs => const <Source>[
        Source.pattern('{BUILD_DIR}/app.dill'),
        ...IconTreeShaker.inputs,
      ];

  @override
  List<Source> get outputs => const <Source>[];

  @override
  List<String> get depfiles => <String>[
        'flutter_assets.d',
      ];

  @override
  List<Target> get dependencies => const <Target>[
        KernelSnapshot(),
      ];

  @override
  Future<void> build(Environment environment) async {
    if (environment.defines[kBuildMode] == null) {
      throw MissingDefineException(kBuildMode, name);
    }
    final BuildMode buildMode =
        getBuildModeForName(environment.defines[kBuildMode]);
    final Directory outputDirectory = environment.outputDir
        .childDirectory('flutter_assets')
          ..createSync(recursive: true);

    // Only copy the prebuilt runtimes and kernel blob in debug mode.
    if (buildMode == BuildMode.debug) {
      final String vmSnapshotData = environment.artifacts
          .getArtifactPath(Artifact.vmSnapshotData, mode: BuildMode.debug);
      final String isolateSnapshotData = environment.artifacts
          .getArtifactPath(Artifact.isolateSnapshotData, mode: BuildMode.debug);
      environment.buildDir
          .childFile('app.dill')
          .copySync(outputDirectory.childFile('kernel_blob.bin').path);
      environment.fileSystem
          .file(vmSnapshotData)
          .copySync(outputDirectory.childFile('vm_snapshot_data').path);
      environment.fileSystem
          .file(isolateSnapshotData)
          .copySync(outputDirectory.childFile('isolate_snapshot_data').path);
    }
    final Depfile assetDepfile = await copyAssets(
      environment,
      outputDirectory,
      targetPlatform: null, // corresponds to flutter-tester
    );
    final DepfileService depfileService = DepfileService(
      fileSystem: environment.fileSystem,
      logger: environment.logger,
    );
    depfileService.writeToFile(
      assetDepfile,
      environment.buildDir.childFile('flutter_assets.d'),
    );
  }
}

/// Source: [DebugAndroidApplication] in `android.dart`
class DebugELinuxApplication extends ELinuxAssetBundle {
  DebugELinuxApplication(this.buildInfo);

  final ELinuxBuildInfo buildInfo;

  @override
  String get name => 'debug_elinux_application';

  @override
  List<Source> get inputs => <Source>[
        ...super.inputs,
        const Source.artifact(Artifact.vmSnapshotData, mode: BuildMode.debug),
        const Source.artifact(Artifact.isolateSnapshotData,
            mode: BuildMode.debug),
      ];

  @override
  List<Source> get outputs => <Source>[
        ...super.outputs,
        const Source.pattern('{OUTPUT_DIR}/flutter_assets/vm_snapshot_data'),
        const Source.pattern(
            '{OUTPUT_DIR}/flutter_assets/isolate_snapshot_data'),
        const Source.pattern('{OUTPUT_DIR}/flutter_assets/kernel_blob.bin'),
      ];

  @override
  List<Target> get dependencies => <Target>[
        ...super.dependencies,
        ELinuxPlugins(buildInfo),
      ];
}

/// See: [ReleaseAndroidApplication] in `android.dart`
class ReleaseELinuxApplication extends ELinuxAssetBundle {
  ReleaseELinuxApplication(this.buildInfo);

  final ELinuxBuildInfo buildInfo;

  @override
  String get name => 'release_elinux_application';

  @override
  List<Target> get dependencies => <Target>[
        ...super.dependencies,
        ELinuxAotElf(),
        ELinuxPlugins(buildInfo),
      ];
}

/// Compiles eLinux native plugins into a single shared object.
class ELinuxPlugins extends Target {
  ELinuxPlugins(this.buildInfo);

  final ELinuxBuildInfo buildInfo;

  @override
  String get name => 'elinux_plugins';

  @override
  List<Source> get inputs => const <Source>[
        Source.pattern('{FLUTTER_ROOT}/../lib/elinux_build_target.dart'),
        Source.pattern('{PROJECT_DIR}/.packages'),
      ];

  @override
  List<Source> get outputs => const <Source>[];

  @override
  List<String> get depfiles => <String>[
        'elinux_plugins.d',
      ];

  @override
  List<Target> get dependencies => const <Target>[];

  @override
  Future<void> build(Environment environment) async {
    // todo: add plugin build support.
  }
}

/// Generates an AOT snapshot (app.so) of the Dart code.
///
/// Source: [AotElfRelease] in `common.dart`
class ELinuxAotElf extends AotElfBase {
  ELinuxAotElf();

  @override
  String get name => 'elinux_aot_elf';

  @override
  List<Source> get inputs => <Source>[
        const Source.pattern('{BUILD_DIR}/app.dill'),
        const Source.hostArtifact(HostArtifact.engineDartBinary),
        const Source.artifact(Artifact.skyEnginePath),
        // Any type of gen_snapshot is applicable here because engine artifacts
        // are assumed to be updated at once, not one by one for each platform
        // or build mode.
        const Source.artifact(Artifact.genSnapshot, mode: BuildMode.release),
      ];

  @override
  List<Source> get outputs => const <Source>[
        Source.pattern('{BUILD_DIR}/app.so'),
      ];

  @override
  List<Target> get dependencies => const <Target>[
        KernelSnapshot(),
      ];
}

class NativeBundle {
  NativeBundle(this.buildInfo, this.targetFile);

  final ELinuxBuildInfo buildInfo;
  final String targetFile;

  final ProcessUtils _processUtils = ProcessUtils(
      logger: globals.logger, processManager: globals.processManager);

  Future<void> build(Environment environment) async {
    final FlutterProject project =
        FlutterProject.fromDirectory(environment.projectDir);
    final ELinuxProject eLinuxProject = ELinuxProject.fromFlutter(project);

    // Clean up the intermediate and output directories.
    final Directory eLinuxDir = eLinuxProject.editableDirectory;

    final BuildMode buildMode = buildInfo.buildInfo.mode;
    final String buildConfig = buildMode.isPrecompiled ? 'release' : 'debug';
    final Directory outputDir = environment.outputDir
        .childDirectory(buildInfo.targetArch)
        .childDirectory(buildConfig);
    if (outputDir.existsSync()) {
      outputDir.deleteSync(recursive: true);
    }
    outputDir.createSync(recursive: true);

    final Directory outputBundleDir = outputDir.childDirectory('bundle');
    if (outputBundleDir.existsSync()) {
      outputBundleDir.deleteSync(recursive: true);
    }
    outputBundleDir.createSync(recursive: true);

    final Directory outputBundleLibDir = outputBundleDir.childDirectory('lib');
    if (outputBundleLibDir.existsSync()) {
      outputBundleLibDir.deleteSync(recursive: true);
    }
    outputBundleLibDir.createSync(recursive: true);

    final Directory outputBundleDataDir =
        outputBundleDir.childDirectory('data');
    if (outputBundleDataDir.existsSync()) {
      outputBundleDataDir.deleteSync(recursive: true);
    }
    outputBundleDataDir.createSync(recursive: true);

    // Copy necessary files
    final Directory engineDir =
        _getEngineArtifactsDirectory(buildInfo.targetArch, buildMode);
    final Directory commonDir =
        engineDir.parent.childDirectory('elinux-common');
    final File engineBinary = engineDir.childFile('libflutter_engine.so');
    final File embedder =
        engineDir.childFile(buildInfo.targetBackendType == 'gbm'
            ? 'libflutter_elinux_gbm.so'
            : buildInfo.targetBackendType == 'eglstream'
                ? 'libflutter_elinux_eglstream.so'
                : buildInfo.targetBackendType == 'x11'
                    ? 'libflutter_elinux_x11.so'
                    : 'libflutter_elinux_wayland.so');
    final Directory clientWrapperDir =
        commonDir.childDirectory('cpp_client_wrapper');

    final Directory pluginsDir =
        environment.buildDir.childDirectory('elinux_plugins');
    final File pluginsLib = pluginsDir.childFile('libflutter_plugins.so');
    if (pluginsLib.existsSync()) {
      pluginsLib
          .copySync(outputBundleLibDir.childFile(pluginsLib.basename).path);
    }
    final Directory pluginsUserLibDir = pluginsDir.childDirectory('lib');
    if (pluginsUserLibDir.existsSync()) {
      pluginsUserLibDir.listSync().whereType<File>().forEach((File lib) =>
          lib.copySync(outputBundleLibDir.childFile(lib.basename).path));
    }

    final Directory flutterDir = eLinuxDir.childDirectory('flutter');
    final Directory flutterEphemeralDir =
        flutterDir.childDirectory('ephemeral');

    // Copy necessary files.
    {
      if (flutterEphemeralDir.existsSync()) {
        flutterEphemeralDir.deleteSync(recursive: true);
      }
      flutterEphemeralDir.createSync(recursive: true);
      flutterEphemeralDir
          .childDirectory('cpp_client_wrapper')
          .createSync(recursive: true);

      copyDirectory(
        clientWrapperDir,
        flutterEphemeralDir.childDirectory('cpp_client_wrapper'),
      );

      commonDir.listSync().whereType<File>().forEach((File lib) =>
          lib.copySync(flutterEphemeralDir.childFile(lib.basename).path));

      engineBinary
          .copySync(flutterEphemeralDir.childFile(engineBinary.basename).path);
      embedder.copySync(flutterEphemeralDir.childFile(embedder.basename).path);

      final File icuData =
          commonDir.childDirectory('icu').childFile('icudtl.dat');
      icuData.copySync(flutterEphemeralDir.childFile(icuData.basename).path);

      if (buildMode.isPrecompiled) {
        final File aotSharedLib = environment.buildDir.childFile('app.so');
        aotSharedLib.copySync(flutterEphemeralDir.childFile('libapp.so').path);
      }
    }

    // Build the environment that needs to be set for the re-entrant flutter build
    // step.
    {
      final Map<String, String> environment = <String, String>{
        if (targetFile != null) 'FLUTTER_TARGET': targetFile,
        ...buildInfo.buildInfo.toEnvironmentConfig(),
      };
      if (globals.artifacts is LocalEngineArtifacts) {
        final LocalEngineArtifacts localEngineArtifacts =
            globals.artifacts as LocalEngineArtifacts;
        final String engineOutPath = localEngineArtifacts.engineOutPath;
        environment['FLUTTER_ENGINE'] =
            globals.fs.path.dirname(globals.fs.path.dirname(engineOutPath));
        environment['LOCAL_ENGINE'] = globals.fs.path.basename(engineOutPath);
      }
      writeGeneratedCmakeConfig(Cache.flutterRoot, eLinuxProject, environment);
      await refreshELinuxPluginsList(eLinuxProject.parent);
    }

    // Run the native build.
    final String cmakeBuildType = buildMode.isPrecompiled ? 'Release' : 'Debug';
    int result;
    try {
      result = await _processUtils.stream(
        <String>[
          'cmake',
          '-DCMAKE_BUILD_TYPE=$cmakeBuildType',
          '-DFLUTTER_TARGET_BACKEND_TYPE=${buildInfo.targetBackendType}',
          eLinuxDir.path,
        ],
        workingDirectory: outputDir.path,
        environment: <String, String>{
          'CC': 'clang',
          'CXX': 'clang++',
          if (globals.logger.isVerbose) 'VERBOSE_SCRIPT_LOGGING': 'true',
          if (!globals.logger.isVerbose) 'PREFIXED_ERROR_LOGGING': 'true',
        },
      );
    } on ArgumentError {
      throwToolExit("Run 'flutter doctor' for more information.");
    }
    if (result != 0) {
      throwToolExit('Failed to cmake:\n$result');
    }

    result = await _processUtils.stream(
      <String>['cmake', '--build', '.'],
      workingDirectory: outputDir.path,
      environment: <String, String>{
        if (globals.logger.isVerbose) 'VERBOSE_SCRIPT_LOGGING': 'true',
        if (!globals.logger.isVerbose) 'PREFIXED_ERROR_LOGGING': 'true',
      },
    );
    if (result != 0) {
      throwToolExit('Failed to cmake build:\n$result');
    }

    // Create flutter app's bunle.
    result = await _processUtils.stream(
      <String>['cmake', '--install', '.'],
      workingDirectory: outputDir.path,
      environment: <String, String>{
        if (globals.logger.isVerbose) 'VERBOSE_SCRIPT_LOGGING': 'true',
        if (!globals.logger.isVerbose) 'PREFIXED_ERROR_LOGGING': 'true',
      },
    );
    if (result != 0) {
      throwToolExit('Failed to cmake install:\n$result');
    }
    {
      final Directory flutterAssetsDir =
          outputBundleDataDir.childDirectory('flutter_assets');
      copyDirectory(
        environment.outputDir.childDirectory('flutter_assets'),
        flutterAssetsDir,
      );
    }
  }
}

/// Converts [targetArch] to an arch name that corresponds to the `BUILD_ARCH`
/// value used by the eLinux native builder.
String getELinuxBuildArch(String targetArch) {
  switch (targetArch) {
    case 'arm':
      return 'armel';
    case 'arm64':
      return 'aarch64';
    case 'x86':
      return 'i586';
    default:
      return targetArch;
  }
}

/// On non-Windows, returns [path] unchanged.
///
/// On Windows, converts Windows-style [path] (e.g. 'C:\x\y') into Unix path
/// ('/c/x/y') and returns.
String getUnixPath(String path) {
  if (Platform.isWindows) {
    path = path.replaceAll(r'\', '/');
    if (path.startsWith(':', 1)) {
      path = '/${path[0].toLowerCase()}${path.substring(2)}';
    }
  }
  return path;
}

/// On non-Windows, returns the PATH environment variable.
///
/// On Windows, appends the msys2 executables directory to PATH and returns.
String getDefaultPathVariable() {
  final Map<String, String> variables = globals.platform.environment;
  return variables.containsKey('PATH') ? variables['PATH'] : '';
}

/// See: [CachedArtifacts._getEngineArtifactsPath]
Directory _getEngineArtifactsDirectory(String arch, BuildMode mode) {
  assert(mode != null, 'Need to specify a build mode.');
  return globals.cache
      .getArtifactDirectory('engine')
      .childDirectory('elinux-$arch-${mode.name}');
}
