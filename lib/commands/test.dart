// Copyright 2023 Sony Group Corporation. All rights reserved.
// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/commands/test.dart';

import '../elinux_plugins.dart';

class ELinuxTestCommand extends TestCommand with ELinuxExtension {
  ELinuxTestCommand({super.verboseHelp});
}
