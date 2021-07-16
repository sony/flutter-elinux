// Copyright 2021 Sony Group Corporation. All rights reserved.
// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:file/file.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/terminal.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/create.dart';
import 'package:flutter_tools/src/flutter_project_metadata.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/project.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';
import 'package:flutter_tools/src/template.dart';

import '../elinux_plugins.dart';

class ELinuxCreateCommand extends CreateCommand {
  ELinuxCreateCommand({bool verboseHelp = false})
      : super(verboseHelp: verboseHelp);

  @override
  void printUsage() {
    super.printUsage();
    // TODO(swift-kim): I couldn't find a proper way to override the --platforms
    // option without copying the entire class. This message is a workaround.
    print(
      'You don\'t have to specify "elinux" as a target platform with '
      '"--platforms" option. It is automatically added by default.',
    );
  }

  /// See:
  /// - [CreateCommand.runCommand] in `create.dart`
  /// - [CreateCommand._getProjectType] in `create.dart` (generatePlugin)
  Future<FlutterCommandResult> runInternal() async {
    final FlutterCommandResult result = await super.runCommand();
    if (result != FlutterCommandResult.success() || argResults.rest.isEmpty) {
      return result;
    }

    final bool generatePlugin = argResults['template'] != null
        ? stringArg('template') ==
            flutterProjectTypeToString(FlutterProjectType.plugin)
        : determineTemplateType() == FlutterProjectType.plugin;
    if (generatePlugin) {
      // Assume that pubspec.yaml uses the multi-platforms plugin format if the
      // file already exists.
      // TODO(swift-kim): Skip this message if elinux already exists in pubspec.
      globals.printStatus(
        'The `pubspec.yaml` under the project directory must be updated to support ELinux.\n'
        'Add below lines to under the `platforms:` key.',
        emphasis: true,
        color: TerminalColor.yellow,
      );
      final Map<String, dynamic> templateContext = createTemplateContext(
        organization: '',
        projectName: projectName,
        flutterRoot: '',
      );
      globals.printStatus(
        '\nelinux:\n'
        '  pluginClass: ${templateContext['pluginClass'] as String}\n'
        '  fileName: ${projectName}_plugin.h',
        emphasis: true,
        color: TerminalColor.blue,
      );
      globals.printStatus('');
    }

    if (boolArg('pub')) {
      final FlutterProject project = FlutterProject.fromDirectory(projectDir);
      await ensureReadyForELinuxTooling(project);
      if (project.hasExampleApp) {
        await ensureReadyForELinuxTooling(project.example);
      }
    }
    return result;
  }

  /// See: [Template.render] in `template.dart`
  @override
  Future<FlutterCommandResult> runCommand() async {
    // The template directory that the flutter tools search for available
    // templates cannot be overriden because the implementation is private.
    // So we have to copy eLinux templates into the directory manually.
    final Directory eLinuxTemplates = globals.fs
        .directory(Cache.flutterRoot)
        .parent
        .childDirectory('templates');
    if (!eLinuxTemplates.existsSync()) {
      throwToolExit('Could not locate eLinux templates.');
    }
    final File eLinuxTemplateManifest =
        eLinuxTemplates.childFile('template_manifest.json');

    final Directory templates = globals.fs
        .directory(Cache.flutterRoot)
        .childDirectory('packages')
        .childDirectory('flutter_tools')
        .childDirectory('templates');
    final File templateManifest = templates.childFile('template_manifest.json');

    // This is required due to: https://github.com/flutter/flutter/pull/59706
    // TODO(swift-kim): Find any better workaround. One option is to override
    // renderTemplate() but it may result in additional complexity.
    eLinuxTemplateManifest.copySync(templateManifest.path);

    final List<Directory> created = <Directory>[];
    try {
      for (final Directory projectType
          in eLinuxTemplates.listSync().whereType<Directory>()) {
        final Directory dest = templates
            .childDirectory(projectType.basename)
            .childDirectory('elinux.tmpl');
        if (dest.existsSync()) {
          dest.deleteSync(recursive: true);
        }

        copyDirectory(projectType, dest);
        if (projectType.basename == 'app') {
          final Directory sourceRunnerCommon =
              projectType.childDirectory('runner');
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
        created.add(dest);
      }
      return await runInternal();
    } finally {
      for (final Directory template in created) {
        template.deleteSync(recursive: true);
      }
    }
  }
}
