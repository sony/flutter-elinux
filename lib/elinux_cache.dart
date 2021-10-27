// Copyright 2021 Sony Group Corporation. All rights reserved.
// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/os.dart' show OperatingSystemUtils;
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/features.dart';
import 'package:flutter_tools/src/flutter_cache.dart';
import 'package:flutter_tools/src/globals_null_migrated.dart' as globals;

/// See: [DevelopmentArtifact] in `cache.dart`
class ELinuxDevelopmentArtifact implements DevelopmentArtifact {
  const ELinuxDevelopmentArtifact._(this.name, {this.feature});

  @override
  final String name;

  @override
  final Feature? feature;

  static const DevelopmentArtifact elinux =
      ELinuxDevelopmentArtifact._('elinux');
}

/// Extends [FlutterCache] to register [ELinuxEngineArtifacts].
///
/// See: [FlutterCache] in `flutter_cache.dart`
class ELinuxFlutterCache extends FlutterCache {
  ELinuxFlutterCache({
    required Logger logger,
    required FileSystem fileSystem,
    required Platform platform,
    required OperatingSystemUtils osUtils,
  }) : super(
            logger: logger,
            fileSystem: fileSystem,
            platform: platform,
            osUtils: osUtils) {
    registerArtifact(ELinuxEngineArtifacts(this, platform: platform));
  }
}

class ELinuxEngineArtifacts extends EngineCachedArtifact {
  ELinuxEngineArtifacts(
    Cache cache, {
    required Platform platform,
  })  : _platform = platform,
        super(
          'elinux-sdk',
          cache,
          ELinuxDevelopmentArtifact.elinux,
        );

  final Platform _platform;

  @override
  String? get version {
    final File versionFile = globals.fs
        .directory(Cache.flutterRoot)
        .parent
        .childDirectory('bin')
        .childDirectory('internal')
        .childFile('engine.version');
    return versionFile.existsSync()
        ? versionFile.readAsStringSync().trim()
        : null;
  }

  String get shortVersion {
    if (version == null) {
      throwToolExit(
          'Failed to get the short revision of the eLinux engine artifact.');
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
    final String downloadUrl = '$engineBaseUrl/download/$shortVersion';
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
}
