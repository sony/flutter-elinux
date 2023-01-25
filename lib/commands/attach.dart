// Copyright 2023 Sony Group Corporation. All rights reserved.
// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/commands/attach.dart';

import '../elinux_plugins.dart';

class ELinuxAttachCommand extends AttachCommand with ELinuxExtension {
  ELinuxAttachCommand({
    super.verboseHelp,
    super.hotRunnerFactory,
    required super.artifacts,
    required super.stdio,
    required super.logger,
    required super.terminal,
    required super.signals,
    required super.platform,
    required super.processInfo,
    required super.fileSystem,
  });
}
