// Copyright 2023 Sony Group Corporation. All rights reserved.
// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/base/os.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/run.dart';

import '../elinux_cache.dart';
import '../elinux_plugins.dart';

class ELinuxRunCommand extends RunCommand
    with ELinuxExtension, ELinuxRequiredArtifacts {
  ELinuxRunCommand({super.verboseHelp});

  @override
  Future<Set<DevelopmentArtifact>> get requiredArtifacts async =>
      <DevelopmentArtifact>{
        // Use gen_snapshot of the arm64 linux-desktop when self-building
        // on arm64 hosts. This is because elinux's artifacts for arm64
        // doesn't support self-build as of now.
        if (_getCurrentHostPlatformArchName() == 'arm64')
          DevelopmentArtifact.linux,
        ELinuxDevelopmentArtifact.elinux,
      };

  String _getCurrentHostPlatformArchName() {
    final HostPlatform hostPlatform = getCurrentHostPlatform();
    return hostPlatform.platformName;
  }
}
