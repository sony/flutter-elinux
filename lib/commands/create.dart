// Copyright 2023 Sony Group Corporation. All rights reserved.
// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/terminal.dart';
import 'package:flutter_tools/src/base/utils.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/create.dart';
import 'package:flutter_tools/src/flutter_project_metadata.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/runner/flutter_command.dart';
import 'package:flutter_tools/src/template.dart';

const List<String> _kAvailablePlatforms = <String>[
  'elinux',
  'ios',
  'android',
  'windows',
  'linux',
  'macos',
  'web',
];

class ELinuxCreateCommand extends CreateCommand {
  ELinuxCreateCommand({super.verboseHelp});

  @override
  void addPlatformsOptions({String? customHelp}) {
    argParser.addMultiOption(
      'platforms',
      help: customHelp,
      defaultsTo: _kAvailablePlatforms,
      allowed: _kAvailablePlatforms,
    );
  }

  @override
  Future<int> renderTemplate(
    String templateName,
    Directory directory,
    Map<String, Object?> context, {
    bool overwrite = false,
    bool printStatusWhenWriting = true,
  }) async {
    // Disables https://github.com/flutter/flutter/pull/59706 by setting
    // templateManifest to null.
    final Template template = await Template.fromName(
      templateName,
      fileSystem: globals.fs,
      logger: globals.logger,
      templateRenderer: globals.templateRenderer,
      templateManifest: null,
    );
    return template.render(directory, context, overwriteExisting: overwrite);
  }

  @override
  Future<int> renderMerged(
    List<String> names,
    Directory directory,
    Map<String, Object?> context, {
    bool overwrite = false,
    bool printStatusWhenWriting = true,
  }) async {
    // Disables https://github.com/flutter/flutter/pull/59706 by setting
    // templateManifest to null.
    final Template template = await Template.merged(
      names,
      directory,
      fileSystem: globals.fs,
      logger: globals.logger,
      templateRenderer: globals.templateRenderer,
      templateManifest: <Uri>{},
    );
    return template.render(directory, context, overwriteExisting: overwrite);
  }

  /// See: [CreateCommand._getProjectType] in `create.dart`
  bool get _shouldGeneratePlugin {
    if (argResults!['template'] != null) {
      return stringArg('template') == 'plugin';
    } else if (projectDir.existsSync() && projectDir.listSync().isNotEmpty) {
      return determineTemplateType() == FlutterTemplateType.plugin;
    }
    return false;
  }

  /// See: [CreateCommand.runCommand] in `create.dart`
  Future<FlutterCommandResult> _runCommand() async {
    final FlutterCommandResult result = await super.runCommand();
    if (result != FlutterCommandResult.success()) {
      return result;
    }

    if (_shouldGeneratePlugin) {
      final String relativePluginPath =
          globals.fs.path.normalize(globals.fs.path.relative(projectDirPath));
      globals.printStatus(
        'Make sure your $relativePluginPath/pubspec.yaml contains the following lines.',
        color: TerminalColor.yellow,
      );

      final String dartSdk = globals.cache.dartSdkBuild;

      // The dart project_name is in snake_case, this variable is the Title Case of the Project Name.
      final String titleCaseProjectName = snakeCaseToTitleCase(projectName);

      final Map<String, Object?> templateContext = createTemplateContext(
        organization: '',
        projectName: projectName,
        flutterRoot: '',
        titleCaseProjectName: titleCaseProjectName,
        dartSdkVersionBounds: "'>=$dartSdk <3.0.0'",
      );
      globals.printStatus(
        '\nflutter:\n'
        '  plugin:\n'
        '    platforms:\n'
        '      elinux:\n'
        '        pluginClass: ${templateContext['pluginClass'] as String}\n',
        color: TerminalColor.blue,
      );
      globals.printStatus('');
    }

    return result;
  }

  /// See:
  /// - [CreateCommand._generatePlugin] in `create.dart`
  /// - [Template.render] in `template.dart`
  @override
  Future<FlutterCommandResult> runCommand() async {
    if (argResults!.rest.isEmpty) {
      return super.runCommand();
    }
    final List<String> platforms = stringsArg('platforms');
    bool shouldRenderELinuxTemplate = platforms.contains('elinux');
    if (_shouldGeneratePlugin && !argResults!.wasParsed('platforms')) {
      shouldRenderELinuxTemplate = false;
    }
    if (!shouldRenderELinuxTemplate) {
      return super.runCommand();
    }

    // The template directory that the flutter tools search for available
    // templates cannot be overriden because the implementation is private.
    // So we have to copy eLinux templates into the directory manually.
    final Directory eLinuxTemplates =
        globals.fs.directory(Cache.flutterRoot).parent.childDirectory('templates');
    if (!eLinuxTemplates.existsSync()) {
      throwToolExit('Could not locate eLinux templates.');
    }
    final Directory templates = globals.fs
        .directory(Cache.flutterRoot)
        .childDirectory('packages')
        .childDirectory('flutter_tools')
        .childDirectory('templates');
    _runGitClean(templates);

    try {
      for (final Directory projectType in eLinuxTemplates.listSync().whereType<Directory>()) {
        final Directory dest =
            templates.childDirectory(projectType.basename).childDirectory('elinux.tmpl');
        if (dest.existsSync()) {
          dest.deleteSync(recursive: true);
        }

        copyDirectory(projectType, dest);
        if (projectType.basename == 'app') {
          final Directory sourceRunnerCommon = projectType.childDirectory('runner');
          if (!sourceRunnerCommon.existsSync()) {
            continue;
          }
          final Directory sourceFlutter = projectType.childDirectory('flutter');
          if (!sourceFlutter.existsSync()) {
            continue;
          }
          copyDirectory(sourceFlutter, dest.childDirectory('flutter'));
          copyDirectory(sourceRunnerCommon, dest.childDirectory('runner'));
        }
      }
      return await _runCommand();
    } finally {
      _runGitClean(templates);
    }
  }

  void _runGitClean(Directory directory) {
    ProcessResult result = globals.processManager.runSync(
      <String>['git', 'restore', '.'],
      workingDirectory: directory.path,
    );
    if (result.exitCode != 0) {
      throwToolExit('Failed to run git restore: ${result.stderr}');
    }
    result = globals.processManager.runSync(
      <String>['git', 'clean', '-df', '.'],
      workingDirectory: directory.path,
    );
    if (result.exitCode != 0) {
      throwToolExit('Failed to run git clean: ${result.stderr}');
    }
  }
}
