// Copyright 2023 Sony Group Corporation. All rights reserved.
// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/commands/drive.dart';
import 'package:flutter_tools/src/globals.dart' as globals;

import '../elinux_cache.dart';
import '../elinux_plugins.dart';

class ELinuxDriveCommand extends DriveCommand with ELinuxExtension, ELinuxRequiredArtifacts {
  ELinuxDriveCommand({super.verboseHelp})
      : super(
          fileSystem: globals.fs,
          logger: globals.logger,
          platform: globals.platform,
          terminal: globals.terminal,
          outputPreferences: globals.outputPreferences,
          signals: globals.signals,
        );
}
