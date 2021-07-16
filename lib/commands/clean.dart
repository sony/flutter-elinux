// Copyright 2021 Sony Group Corporation. All rights reserved.
// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:file/file.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/commands/clean.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/project.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';
import 'package:path/path.dart';

import '../elinux_cmake_project.dart';

class ELinuxCleanCommand extends CleanCommand {
  ELinuxCleanCommand({bool verbose = false}) : super(verbose: verbose);

  /// See: [CleanCommand.runCommand] in `clean.dart`
  @override
  Future<FlutterCommandResult> runCommand() async {
    final FlutterProject flutterProject = FlutterProject.current();
    _cleanELinuxProject(ELinuxProject.fromFlutter(flutterProject));

    return super.runCommand();
  }

  void _cleanELinuxProject(ELinuxProject project) {
    if (!project.existsSync()) {
      return;
    }
    _deleteFile(project.ephemeralDirectory);
  }

  /// Source: [CleanCommand.deleteFile] in `clean.dart` (simplified)
  void _deleteFile(FileSystemEntity file) {
    if (!file.existsSync()) {
      return;
    }
    final String path = relative(file.path);
    final Status status = globals.logger.startProgress(
      'Deleting $path...',
    );
    try {
      file.deleteSync(recursive: true);
    } on FileSystemException catch (error) {
      globals.printError('Failed to remove $path: $error');
    } finally {
      status?.stop();
    }
  }
}
