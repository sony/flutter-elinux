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
    return _cache.getArtifactDirectory('engine').childDirectory('elinux-$arch-${mode.name}');
  }

  /// See: [CachedArtifacts._getAndroidArtifactPath] in `artifacts.dart`
  @override
  String getArtifactPath(
    Artifact artifact, {
    TargetPlatform? platform,
    BuildMode? mode,
    EnvironmentType? environmentType,
  }) {
    final HostPlatform hostPlatform = getCurrentHostPlatform();

    // Use elinux-*-*/linux-x64/gen_snapshot only when the host pc is x64 arch.
    // The other causes use linux-desktop's one.
    if (artifact == Artifact.genSnapshot &&
        hostPlatform == HostPlatform.linux_x64 &&
        platform != null &&
        getNameForTargetPlatform(platform).startsWith('linux')) {
      assert(mode != null, 'Need to specify a build mode.');
      assert(mode != BuildMode.debug, 'Artifact $artifact only available in non-debug mode.');

      final String arch = _getArchForTargetPlatform(platform);
      return _getEngineArtifactsDirectory(arch, mode!)
          .childDirectory(getNameForHostPlatform(hostPlatform))
          .childFile('gen_snapshot')
          .path;
    }
    return super.getArtifactPath(artifact, platform: platform, mode: mode);
  }

  String _getArchForTargetPlatform(TargetPlatform platform) {
    if (platform == TargetPlatform.linux_x64) {
      return 'x64';
    } else {
      return 'arm64';
    }
  }
}
