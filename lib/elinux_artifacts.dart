// Copyright 2023 Sony Group Corporation. All rights reserved.
// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/base/os.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/cache.dart';

class ELinuxArtifacts extends CachedArtifacts {
  ELinuxArtifacts({
    required super.fileSystem,
    required super.platform,
    required super.cache,
    required super.operatingSystemUtils,
  }) : _cache = cache;

  final Cache _cache;

  /// See: [CachedArtifacts._getEngineArtifactsPath]
  Directory _getEngineArtifactsDirectory(String arch, BuildMode mode) {
    return _cache
        .getArtifactDirectory('engine')
        .childDirectory('elinux-$arch-${mode.name}');
  }

  /// See: [CachedArtifacts._getAndroidArtifactPath] in `artifacts.dart`
  @override
  String getArtifactPath(
    Artifact artifact, {
    TargetPlatform? platform,
    BuildMode? mode,
    EnvironmentType? environmentType,
  }) {
    if (artifact == Artifact.genSnapshot &&
        platform != null &&
        getNameForTargetPlatform(platform).startsWith('android')) {
      assert(mode != null, 'Need to specify a build mode.');
      assert(mode != BuildMode.debug,
          'Artifact $artifact only available in non-debug mode.');
      final String arch = _getArchForTargetPlatform(platform);
      final HostPlatform hostPlatform = getCurrentHostPlatform();
      assert(hostPlatform != HostPlatform.linux_arm64,
          'Artifact $artifact not available on Linux arm64.');
      return _getEngineArtifactsDirectory(arch, mode!)
          .childDirectory(getNameForHostPlatform(hostPlatform))
          .childFile('gen_snapshot')
          .path;
    }
    return super.getArtifactPath(artifact, platform: platform, mode: mode);
  }

  String _getArchForTargetPlatform(TargetPlatform platform) {
    if (platform == TargetPlatform.android_arm64) {
      return 'arm64';
    } else {
      return 'x64';
    }
  }
}
