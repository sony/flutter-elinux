// Copyright 2021 Sony Group Corporation. All rights reserved.
// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:io';

import 'package:flutter_tools/src/android/android_workflow.dart';
import 'package:flutter_tools/src/base/context.dart';
import 'package:flutter_tools/src/base/os.dart';
import 'package:flutter_tools/src/doctor.dart';
import 'package:flutter_tools/src/doctor_validator.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/version.dart';
import 'package:meta/meta.dart';

import 'executable.dart';

ELinuxWorkflow get eLinuxWorkflow => context.get<ELinuxWorkflow>();
ELinuxValidator get eLinuxValidator => context.get<ELinuxValidator>();

/// See: [_DefaultDoctorValidatorsProvider] in `doctor.dart`
class ELinuxDoctorValidatorsProvider extends DoctorValidatorsProvider {
  @override
  List<DoctorValidator> get validators {
    final List<DoctorValidator> validators =
        DoctorValidatorsProvider.defaultInstance.validators;
    return <DoctorValidator>[
      validators.first,
      eLinuxValidator,
      ...validators.sublist(1)
    ];
  }

  @override
  List<Workflow> get workflows => <Workflow>[
        ...DoctorValidatorsProvider.defaultInstance.workflows,
        eLinuxWorkflow,
      ];
}

/// A validator that checks for eLinux SDK installation.
class ELinuxValidator extends DoctorValidator {
  ELinuxValidator() : super('eLinux toolchain - develop for eLinux devices');

  bool _validatePackages(List<ValidationMessage> messages) {
    return true;
  }

  /// See: [AndroidValidator.validate] in `android_workflow.dart`
  @override
  Future<ValidationResult> validate() async {
    final List<ValidationMessage> messages = <ValidationMessage>[];

    final FlutterVersion version = _FlutterELinuxVersion();
    messages.add(ValidationMessage(globals.userMessages.flutterRevision(
      version.frameworkRevisionShort,
      version.frameworkAge,
      version.frameworkCommitDate,
    )));
    messages.add(ValidationMessage(
        globals.userMessages.engineRevision(version.engineRevisionShort)));

    if (!_validatePackages(messages)) {
      return ValidationResult(ValidationType.partial, messages);
    }
    return ValidationResult(ValidationType.installed, messages);
  }
}

/// The eLinux-specific implementation of a [Workflow].
///
/// See: [AndroidWorkflow] in `android_workflow.dart`
class ELinuxWorkflow extends Workflow {
  ELinuxWorkflow({
    @required OperatingSystemUtils operatingSystemUtils,
  }) : _operatingSystemUtils = operatingSystemUtils;

  final OperatingSystemUtils _operatingSystemUtils;

  @override
  bool get appliesToHostPlatform =>
      _operatingSystemUtils.hostPlatform != HostPlatform.linux_arm64;

  @override
  bool get canLaunchDevices => true;

  @override
  bool get canListDevices => true;

  @override
  bool get canListEmulators => false;
}

class _FlutterELinuxVersion extends FlutterVersion {
  _FlutterELinuxVersion() : super(workingDirectory: rootPath);

  /// See: [Cache.getVersionFor] in `cache.dart`
  String _getVersionFor(String artifactName) {
    final File versionFile = globals.fs
        .directory(rootPath)
        .childDirectory('bin')
        .childDirectory('internal')
        .childFile('$artifactName.version');
    return versionFile.existsSync()
        ? versionFile.readAsStringSync().trim()
        : null;
  }

  @override
  String get engineRevision => _getVersionFor('engine');

  /// See: [_runGit] in `version.dart`
  String _runGit(String command) => globals.processUtils
      .runSync(command.split(' '), workingDirectory: rootPath)
      .stdout
      .trim();

  /// This should be overriden because [FlutterVersion._latestGitCommitDate]
  /// runs the git log command in the `Cache.flutterRoot` directory.
  @override
  String get frameworkCommitDate => _runGit(
      'git -c log.showSignature=false log -n 1 --pretty=format:%ad --date=iso');
}
