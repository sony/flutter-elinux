// Copyright 2021 Sony Group Corporation. All rights reserved.
// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:flutter_tools/src/commands/analyze.dart';
import 'package:flutter_tools/src/globals.dart' as globals;

import '../elinux_plugins.dart';

class ELinuxAnalyzeCommand extends AnalyzeCommand with ELinuxExtension {
  ELinuxAnalyzeCommand({bool verboseHelp = false})
      : super(
          verboseHelp: verboseHelp,
          fileSystem: globals.fs,
          platform: globals.platform,
          processManager: globals.processManager,
          logger: globals.logger,
          terminal: globals.terminal,
          artifacts: globals.artifacts,
        );
}
