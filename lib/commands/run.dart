// Copyright 2021 Sony Group Corporation. All rights reserved.
// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/run.dart';

import '../elinux_cache.dart';
import '../elinux_plugins.dart';

class ELinuxRunCommand extends RunCommand with ELinuxExtension {
  ELinuxRunCommand({bool verboseHelp = false})
      : super(verboseHelp: verboseHelp);

  @override
  Future<Set<DevelopmentArtifact>> get requiredArtifacts async =>
      <DevelopmentArtifact>{
        DevelopmentArtifact.androidGenSnapshot,
        ELinuxDevelopmentArtifact.elinux,
      };
}
