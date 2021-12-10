// Copyright 2021 Sony Group Corporation. All rights reserved.
// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:io';

import 'package:flutter_tools/executable.dart' as flutter;
import 'package:flutter_tools/runner.dart' as runner;
import 'package:flutter_tools/src/application_package.dart';
import 'package:flutter_tools/src/base/context.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/template.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/config.dart';
import 'package:flutter_tools/src/commands/devices.dart';
import 'package:flutter_tools/src/commands/doctor.dart';
import 'package:flutter_tools/src/commands/emulators.dart';
import 'package:flutter_tools/src/commands/format.dart';
import 'package:flutter_tools/src/commands/generate_localizations.dart';
import 'package:flutter_tools/src/commands/install.dart';
import 'package:flutter_tools/src/commands/logs.dart';
import 'package:flutter_tools/src/commands/screenshot.dart';
import 'package:flutter_tools/src/commands/symbolize.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/doctor.dart';
import 'package:flutter_tools/src/features.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/isolated/mustache_template.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';
import 'package:path/path.dart';

import 'commands/analyze.dart';
import 'commands/attach.dart';
import 'commands/build.dart';
import 'commands/clean.dart';
import 'commands/create.dart';
import 'commands/drive.dart';
import 'commands/packages.dart';
import 'commands/precache.dart';
import 'commands/run.dart';
import 'commands/test.dart';
import 'commands/upgrade.dart';
import 'elinux_cache.dart';
import 'elinux_device_discovery.dart';
import 'elinux_doctor.dart';
import 'elinux_package.dart';

/// Main entry point for commands.
///
/// Source: [flutter.main] in `executable.dart` (some commands and options were omitted)
Future<void> main(List<String> args) async {
  final bool veryVerbose = args.contains('-vv');
  final bool verbose =
      args.contains('-v') || args.contains('--verbose') || veryVerbose;

  final bool doctor = (args.isNotEmpty && args.first == 'doctor') ||
      (args.length == 2 && verbose && args.last == 'doctor');
  final bool help = args.contains('-h') ||
      args.contains('--help') ||
      (args.isNotEmpty && args.first == 'help') ||
      (args.length == 1 && verbose);
  final bool muteCommandLogging = (help || doctor) && !veryVerbose;
  final bool verboseHelp = help && verbose;

  final bool hasSpecifiedDeviceId =
      args.contains('-d') || args.contains('--device-id');

  args = <String>[
    '--suppress-analytics', // Suppress flutter analytics by default.
    '--no-version-check',
    if (!hasSpecifiedDeviceId) ...<String>['--device-id', 'elinux'],
    ...args,
  ];

  Cache.flutterRoot = join(rootPath, 'flutter');

  await runner.run(
    args,
    () => <FlutterCommand>[
      // Commands directly from flutter_tools.
      ConfigCommand(verboseHelp: verboseHelp),
      DevicesCommand(verboseHelp: verboseHelp),
      DoctorCommand(verbose: verbose),
      EmulatorsCommand(),
      FormatCommand(verboseHelp: verbose),
      GenerateLocalizationsCommand(
        fileSystem: globals.fs,
        logger: globals.logger,
      ),
      InstallCommand(),
      LogsCommand(),
      ScreenshotCommand(),
      SymbolizeCommand(stdio: globals.stdio, fileSystem: globals.fs),
      ELinuxUpgradeCommand(verboseHelp: verboseHelp),
      // Commands extended for ELinux.
      ELinuxAnalyzeCommand(verboseHelp: verboseHelp),
      ELinuxAttachCommand(verboseHelp: verboseHelp),
      ELinuxBuildCommand(verboseHelp: verboseHelp),
      ELinuxCleanCommand(verbose: verbose),
      ELinuxCreateCommand(verboseHelp: verboseHelp),
      ELinuxDriveCommand(verboseHelp: verboseHelp),
      ELinuxPackagesCommand(),
      ELinuxPrecacheCommand(
        verboseHelp: verboseHelp,
        cache: globals.cache,
        logger: globals.logger,
        platform: globals.platform,
        featureFlags: featureFlags,
      ),
      ELinuxRunCommand(verboseHelp: verboseHelp),
      ELinuxTestCommand(verboseHelp: verboseHelp),
    ],
    verbose: verbose,
    verboseHelp: verboseHelp,
    muteCommandLogging: muteCommandLogging,
    reportCrashes: false,
    overrides: <Type, Generator>{
      Cache: () => ELinuxFlutterCache(
            fileSystem: globals.fs,
            logger: globals.logger,
            platform: globals.platform,
            osUtils: globals.os,
          ),
      TemplateRenderer: () => const MustacheTemplateRenderer(),
      ApplicationPackageFactory: () => ELinuxApplicationPackageFactory(),
      DeviceManager: () => ELinuxDeviceManager(),
      DoctorValidatorsProvider: () => ELinuxDoctorValidatorsProvider(),
      ELinuxWorkflow: () => ELinuxWorkflow(
            operatingSystemUtils: globals.os,
          ),
      ELinuxValidator: () => ELinuxValidator(
            processManager: globals.processManager,
            userMessages: globals.userMessages,
          ),
      if (verbose && !muteCommandLogging)
        Logger: () => VerboseLogger(StdoutLogger(
              stdio: globals.stdio,
              terminal: globals.terminal,
              outputPreferences: globals.outputPreferences,
            )),
    },
  );
}

/// See: [Cache.defaultFlutterRoot] in `cache.dart`
String get rootPath {
  final String scriptPath = Platform.script.toFilePath();
  return normalize(join(
    scriptPath,
    scriptPath.endsWith('.snapshot') ? '../../..' : '../..',
  ));
}
