// Copyright 2023 Sony Group Corporation. All rights reserved.
// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/commands/analyze.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/project_validator.dart';

import '../elinux_plugins.dart';

class ELinuxAnalyzeCommand extends AnalyzeCommand with ELinuxExtension {
  ELinuxAnalyzeCommand({super.verboseHelp})
      : super(
          fileSystem: globals.fs,
          platform: globals.platform,
          processManager: globals.processManager,
          logger: globals.logger,
          terminal: globals.terminal,
          artifacts: globals.artifacts!,
          // new ProjectValidators should be added here for the --suggestions to run
          allProjectValidators: <ProjectValidator>[
            GeneralInfoProjectValidator(),
            VariableDumpMachineProjectValidator(
              logger: globals.logger,
              fileSystem: globals.fs,
              platform: globals.platform,
            ),
          ],
          suppressAnalytics: globals.flutterUsage.suppressAnalytics,
        );
}
