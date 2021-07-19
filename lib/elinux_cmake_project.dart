// Copyright 2021 Sony Group Corporation. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/project.dart';

import 'elinux_plugins.dart';

/// The eLinux sub project.
class ELinuxProject extends FlutterProjectPlatform
    implements CmakeBasedProject {
  ELinuxProject.fromFlutter(this.parent);

  @override
  final FlutterProject parent;

  @override
  String get pluginConfigKey => ELinuxPlugin.kConfigKey;

  String get _childDirectory => 'elinux';

  @override
  bool existsSync() => editableDirectory.existsSync() && cmakeFile.existsSync();

  @override
  File get cmakeFile => editableDirectory.childFile('CMakeLists.txt');

  @override
  File get managedCmakeFile => managedDirectory.childFile('CMakeLists.txt');

  @override
  File get generatedCmakeConfigFile =>
      ephemeralDirectory.childFile('generated_config.cmake');

  @override
  File get generatedPluginCmakeFile =>
      managedDirectory.childFile('generated_plugins.cmake');

  @override
  Directory get pluginSymlinkDirectory =>
      ephemeralDirectory.childDirectory('.plugin_symlinks');

  Directory get editableDirectory =>
      parent.directory.childDirectory(_childDirectory);

  Directory get managedDirectory => editableDirectory.childDirectory('flutter');

  Directory get ephemeralDirectory =>
      managedDirectory.childDirectory('ephemeral');

  Future<void> ensureReadyForPlatformSpecificTooling() async {
    await refreshELinuxPluginsList(parent);
  }
}
