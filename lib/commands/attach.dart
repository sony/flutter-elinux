// Copyright 2021 Sony Group Corporation. All rights reserved.
// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:flutter_tools/src/commands/attach.dart';

import '../elinux_plugins.dart';

class ELinuxAttachCommand extends AttachCommand with ELinuxExtension {
  ELinuxAttachCommand({bool verboseHelp = false})
      : super(verboseHelp: verboseHelp);
}
