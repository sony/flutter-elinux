// Copyright 2023 Sony Group Corporation. All rights reserved.
// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/os.dart' show OperatingSystemUtils;
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/features.dart';
import 'package:flutter_tools/src/flutter_cache.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/runner/flutter_command.dart';
import 'package:process/process.dart';

mixin ELinuxRequiredArtifacts on FlutterCommand {
  @override
  Future<Set<DevelopmentArtifact>> get requiredArtifacts async => <DevelopmentArtifact>{
        ...await super.requiredArtifacts,
        ELinuxDevelopmentArtifact.elinux,
      };
}

/// See: [DevelopmentArtifact] in `cache.dart`
class ELinuxDevelopmentArtifact implements DevelopmentArtifact {
  // ignore: unused_element
  const ELinuxDevelopmentArtifact._(this.name);

  @override
  final String name;

  @override
  final Feature? feature = null;

  static const DevelopmentArtifact elinux = ELinuxDevelopmentArtifact._('elinux');
}

/// Extends [FlutterCache] to register [ELinuxEngineArtifacts].
///
/// See: [FlutterCache] in `flutter_cache.dart`
class ELinuxFlutterCache extends FlutterCache {
  ELinuxFlutterCache({
    required Logger logger,
    required super.fileSystem,
    required Platform platform,
    required super.osUtils,
    required ProcessManager processManager,
    required super.projectFactory,
  }) : super(logger: logger, platform: platform) {
    registerArtifact(ELinuxEngineArtifacts(this,
        logger: logger, platform: platform, processManager: processManager));
  }
}

class ELinuxEngineArtifacts extends EngineCachedArtifact {
  ELinuxEngineArtifacts(
    Cache cache, {
    required Logger logger,
    required Platform platform,
    required ProcessManager processManager,
  })  : _logger = logger,
        _platform = platform,
        _processUtils = ProcessUtils(processManager: processManager, logger: logger),
        super(
          'elinux-sdk',
          cache,
          ELinuxDevelopmentArtifact.elinux,
        );

  final Logger _logger;
  final Platform _platform;
  final ProcessUtils _processUtils;

  @override
  String? get version {
    final File versionFile = globals.fs
        .directory(Cache.flutterRoot)
        .parent
        .childDirectory('bin')
        .childDirectory('internal')
        .childFile('engine.version');
    return versionFile.existsSync() ? versionFile.readAsStringSync().trim() : null;
  }

  String get shortVersion {
    if (version == null) {
      throwToolExit('Failed to get the short revision of the eLinux engine artifact.');
    }

    if (version!.length >= 10) {
      return version!.substring(0, 10);
    }
    return version!;
  }

  /// See: [Cache.storageBaseUrl] in `cache.dart`
  String get engineBaseUrl {
    final String? overrideUrl = _platform.environment['ELINUX_ENGINE_BASE_URL'];
    if (overrideUrl == null) {
      return 'https://github.com/sony/flutter-embedded-linux/releases';
    }
    try {
      Uri.parse(overrideUrl);
    } on FormatException catch (err) {
      throwToolExit('"ELINUX_ENGINE_BASE_URL" contains an invalid URI:\n$err');
    }
    return overrideUrl;
  }

  @override
  List<List<String>> getBinaryDirs() => <List<String>>[
        <String>['elinux-common', 'elinux-common.zip'],
        <String>['elinux-arm64-debug', 'elinux-arm64-debug.zip'],
        <String>['elinux-arm64-profile', 'elinux-arm64-profile.zip'],
        <String>['elinux-arm64-release', 'elinux-arm64-release.zip'],
        <String>['elinux-x64-debug', 'elinux-x64-debug.zip'],
        <String>['elinux-x64-profile', 'elinux-x64-profile.zip'],
        <String>['elinux-x64-release', 'elinux-x64-release.zip'],
      ];

  @override
  List<String> getLicenseDirs() => const <String>[];

  @override
  List<String> getPackageDirs() => const <String>[];

  @override
  Future<void> updateInner(
    ArtifactUpdater artifactUpdater,
    FileSystem fileSystem,
    OperatingSystemUtils operatingSystemUtils,
  ) async {
    String? downloadUrl;

    final String? overrideLocal = _platform.environment['ELINUX_ENGINE_BASE_LOCAL_DIRECTORY'];
    if (overrideLocal != null) {
      await _downloadArtifactsFromLocal(operatingSystemUtils, overrideLocal);
      return;
    }

    downloadUrl ??= '$engineBaseUrl/download/$shortVersion';
    for (final List<String> toolsDir in getBinaryDirs()) {
      final String cacheDir = toolsDir[0];
      final String urlPath = toolsDir[1];
      await artifactUpdater.downloadZipArchive(
        'Downloading $cacheDir tools...',
        Uri.parse('$downloadUrl/$urlPath'),
        location.childDirectory(cacheDir),
      );
    }
  }

  Future<void> _downloadArtifactsFromLocal(
    OperatingSystemUtils operatingSystemUtils,
    String overrideLocalDirectory,
  ) async {
    _logger.printStatus('Copying elinux artifacts from local directory...');
    for (final List<String> toolsDir in getBinaryDirs()) {
      final String cacheDir = toolsDir[0];
      final String filePath = '$overrideLocalDirectory/${toolsDir[1]}';
      final Directory artifactDir = location.childDirectory(cacheDir);
      final Status status = _logger.startProgress('Copying $cacheDir tools...');
      try {
        if (artifactDir.existsSync()) {
          artifactDir.deleteSync(recursive: true);
        }
        artifactDir.createSync(recursive: true);
        final RunResult result = await _processUtils.run(<String>[
          'unzip',
          filePath,
          '-d',
          artifactDir.path,
        ]);
        if (result.exitCode != 0) {
          throwToolExit(
            'Failed to copy elinux artifact from local.\n\n'
            '$result',
          );
        }
      } finally {
        status.stop();
      }
      _makeFilesExecutable(artifactDir, operatingSystemUtils);
    }
  }

  /// Source: [EngineCachedArtifact._makeFilesExecutable] in `cache.dart`
  void _makeFilesExecutable(
    Directory dir,
    OperatingSystemUtils operatingSystemUtils,
  ) {
    operatingSystemUtils.chmod(dir, 'a+r,a+x');
    for (final File file in dir.listSync(recursive: true).whereType<File>()) {
      if (file.basename == 'gen_snapshot') {
        operatingSystemUtils.chmod(file, 'a+r,a+x');
      }
    }
  }
}
