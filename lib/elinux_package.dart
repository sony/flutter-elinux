// Copyright 2021 Sony Group Corporation. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:file/file.dart';
import 'package:flutter_tools/src/application_package.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/cmake.dart';
import 'package:flutter_tools/src/flutter_application_package.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/globals_null_migrated.dart' as globals;
import 'package:flutter_tools/src/project.dart';
import 'package:meta/meta.dart';

import 'elinux_cmake_project.dart';

class ELinuxApplicationPackageFactory extends FlutterApplicationPackageFactory {
  ELinuxApplicationPackageFactory()
      : super(
          androidSdk: globals.androidSdk,
          processManager: globals.processManager,
          logger: globals.logger,
          userMessages: globals.userMessages,
          fileSystem: globals.fs,
        );

  @override
  Future<ApplicationPackage> getPackageForPlatform(
    TargetPlatform platform, {
    BuildInfo buildInfo,
    File applicationBinary,
  }) async {
    if (platform == TargetPlatform.tester) {
      return applicationBinary == null
          ? ELinuxApp.fromELinuxProject(FlutterProject.current())
          : ELinuxApp.fromPrebuiltApp(applicationBinary);
    }
    return super.getPackageForPlatform(platform,
        buildInfo: buildInfo, applicationBinary: applicationBinary);
  }
}

abstract class ELinuxApp extends ApplicationPackage {
  ELinuxApp({@required String projectBundleId}) : super(id: projectBundleId);

  factory ELinuxApp.fromELinuxProject(FlutterProject project) {
    return BuildableELinuxApp(
      project: ELinuxProject.fromFlutter(project),
    );
  }

  factory ELinuxApp.fromPrebuiltApp(FileSystemEntity applicationBinary) {
    return PrebuiltELinuxApp(
      executable: applicationBinary.path,
      outputDirectory: applicationBinary.path,
    );
  }

  @override
  String get displayName => id;

  String executable(BuildMode buildMode, String targetArch);

  String outputDirectory(BuildMode buildMode, String targetArch);
}

class PrebuiltELinuxApp extends ELinuxApp {
  PrebuiltELinuxApp({
    @required String executable,
    @required String outputDirectory,
  })  : _executable = executable,
        _outputDirectory = outputDirectory,
        super(projectBundleId: executable);

  final String _executable;
  final String _outputDirectory;

  @override
  String executable(BuildMode buildMode, String targetArch) => _executable;

  @override
  String outputDirectory(BuildMode buildMode, String targetArch) =>
      _outputDirectory;

  @override
  String get name => _executable;
}

class BuildableELinuxApp extends ELinuxApp {
  BuildableELinuxApp({@required this.project})
      : super(projectBundleId: project.parent.manifest.appName);

  final ELinuxProject project;

  @override
  String executable(BuildMode buildMode, String targetArch) {
    final String binaryName = getCmakeExecutableName(project);
    return globals.fs.path.join(
      'build/elinux/',
      targetArch,
      getNameForBuildMode(buildMode),
      'bundle',
      binaryName,
    );
  }

  @override
  String outputDirectory(BuildMode buildMode, String targetArch) {
    return globals.fs.path.join(
      'build/elinux/',
      targetArch,
      getNameForBuildMode(buildMode),
      'bundle',
    );
  }

  @override
  String get name => project.parent.manifest.appName;
}
