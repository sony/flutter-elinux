// Copyright 2021 Sony Group Corporation. All rights reserved.
// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:io';

import 'package:flutter_tools/src/base/context.dart';
import 'package:flutter_tools/src/base/os.dart';
import 'package:flutter_tools/src/base/user_messages.dart';
import 'package:flutter_tools/src/base/version.dart';
import 'package:flutter_tools/src/doctor.dart';
import 'package:flutter_tools/src/doctor_validator.dart';
import 'package:meta/meta.dart';

import 'package:process/process.dart';

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

/// See: [_VersionInfo] in `linux_doctor.dart`
class _VersionInfo {
  _VersionInfo(this.description) {
    final String versionString = RegExp(r'[0-9]+\.[0-9]+(?:\.[0-9]+)?')
        .firstMatch(description)
        ?.group(0);
    number = Version.parse(versionString);
  }

  String description;
  Version number;
}

/// See: [LinuxDoctorValidator] in `linux_doctor.dart`
class ELinuxValidator extends DoctorValidator {
  ELinuxValidator({
    @required ProcessManager processManager,
    @required UserMessages userMessages,
  })  : _processManager = processManager,
        _userMessages = userMessages,
        super('eLinux toolchain - develop for embedded Linux devices');

  final ProcessManager _processManager;
  final UserMessages _userMessages;

  static const String kClangBinary = 'clang++';
  static const String kCmakeBinary = 'cmake';
  static const String kPkgConfigBinary = 'pkg-config';

  final Map<String, Version> _requiredBinaryVersions = <String, Version>{
    kClangBinary: Version(3, 4, 0),
    kCmakeBinary: Version(3, 10, 0),
    kPkgConfigBinary: Version(0, 29, 0),
  };

  final List<String> _requiredCommonLibraries = <String>[
    'glesv2',
    'egl',
  ];
  static const String kRequredCommonLibrariesErrorMessage =
      'OpenGL ES/EGL libraries are required for Embedded Linux development. '
      'They are likely available from your distribution (e.g.: apt install libegl1-mesa libgles2-mesa)';

  @override
  Future<ValidationResult> validate() async {
    ValidationType validationType = ValidationType.installed;
    final List<ValidationMessage> messages = <ValidationMessage>[];

    final Map<String, _VersionInfo> installedVersions = <String, _VersionInfo>{
      // Sort the check to make the call order predictable for unit tests.
      for (String binary in _requiredBinaryVersions.keys.toList()..sort())
        binary: await _getBinaryVersion(binary)
    };

    // Determine overall validation level.
    if (installedVersions.values
        .any((_VersionInfo versionInfo) => versionInfo?.number == null)) {
      validationType = ValidationType.missing;
    } else if (installedVersions.keys.any((String binary) =>
        installedVersions[binary].number < _requiredBinaryVersions[binary])) {
      validationType = ValidationType.partial;
    }

    // Message for Clang.
    {
      final _VersionInfo version = installedVersions[kClangBinary];
      if (version == null || version.number == null) {
        messages.add(ValidationMessage.error(_userMessages.clangMissing));
      } else {
        assert(_requiredBinaryVersions.containsKey(kClangBinary));
        messages.add(ValidationMessage(version.description));
        final Version requiredVersion = _requiredBinaryVersions[kClangBinary];
        if (version.number < requiredVersion) {
          messages.add(ValidationMessage.error(
              _userMessages.clangTooOld(requiredVersion.toString())));
        }
      }
    }

    // Message for CMake.
    {
      final _VersionInfo version = installedVersions[kCmakeBinary];
      if (version == null || version.number == null) {
        messages.add(ValidationMessage.error(_userMessages.cmakeMissing));
      } else {
        assert(_requiredBinaryVersions.containsKey(kCmakeBinary));
        messages.add(ValidationMessage(version.description));
        final Version requiredVersion = _requiredBinaryVersions[kCmakeBinary];
        if (version.number < requiredVersion) {
          messages.add(ValidationMessage.error(
              _userMessages.cmakeTooOld(requiredVersion.toString())));
        }
      }
    }

    // Message for pkg-config.
    {
      final _VersionInfo version = installedVersions[kPkgConfigBinary];
      if (version == null || version.number == null) {
        messages.add(ValidationMessage.error(_userMessages.pkgConfigMissing));
      } else {
        assert(_requiredBinaryVersions.containsKey(kPkgConfigBinary));
        // The full version description is just the number, so add context.
        messages.add(ValidationMessage(
            _userMessages.pkgConfigVersion(version.description)));
        final Version requiredVersion =
            _requiredBinaryVersions[kPkgConfigBinary];
        if (version.number < requiredVersion) {
          messages.add(ValidationMessage.error(
              _userMessages.pkgConfigTooOld(requiredVersion.toString())));
        }
      }
    }

    // Messages for libraries.
    {
      bool libraryMissing = false;
      for (final String library in _requiredCommonLibraries) {
        if (!await _libraryIsPresent(library)) {
          libraryMissing = true;
          break;
        }
      }
      if (libraryMissing) {
        validationType = ValidationType.missing;
        messages.add(
            const ValidationMessage.error(kRequredCommonLibrariesErrorMessage));
      }
    }

    return ValidationResult(validationType, messages);
  }

  /// See: [_getBinaryVersion] in `linux_doctor.dart`
  Future<_VersionInfo> _getBinaryVersion(String binary) async {
    ProcessResult result;
    try {
      result = await _processManager.run(<String>[
        binary,
        '--version',
      ]);
    } on ArgumentError {
      // ignore error.
    }
    if (result == null || result.exitCode != 0) {
      return null;
    }
    final String firstLine = (result.stdout as String).split('\n').first.trim();
    return _VersionInfo(firstLine);
  }

  /// See: [_libraryIsPresent] in `linux_doctor.dart`
  Future<bool> _libraryIsPresent(String library) async {
    ProcessResult result;
    try {
      result = await _processManager.run(<String>[
        'pkg-config',
        '--exists',
        library,
      ]);
    } on ArgumentError {
      // ignore error.
    }
    return (result?.exitCode ?? 1) == 0;
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
      (_operatingSystemUtils.hostPlatform == HostPlatform.linux_x64) ||
      (_operatingSystemUtils.hostPlatform == HostPlatform.linux_arm64);

  @override
  bool get canLaunchDevices => true;

  @override
  bool get canListDevices => true;

  @override
  bool get canListEmulators => false;
}
