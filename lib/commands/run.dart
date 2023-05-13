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
        // Use gensnapshot for Arm64 Linux when the host is arm64 because
        // the artifacts for arm64 host don't support self-building now.
        if (_getCurrentHostPlatformArchName() == 'arm64')
          DevelopmentArtifact.linux,
        if (_getCurrentHostPlatformArchName() == 'x64')
          DevelopmentArtifact.androidGenSnapshot,
        ELinuxDevelopmentArtifact.elinux,
      };

  String _getCurrentHostPlatformArchName() {
    final HostPlatform hostPlatform = getCurrentHostPlatform();
    return getNameForHostPlatformArch(hostPlatform);
  }
}
