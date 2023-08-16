// Copyright 2021 Sony Group Corporation. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

/// See: [_listsEqual] in `custom_device_config.dart` (exact copy)
bool _listsEqual(List<dynamic>? a, List<dynamic>? b) {
  if (a == b) {
    return true;
  }
  if (a == null || b == null) {
    return false;
  }
  if (a.length != b.length) {
    return false;
  }

  return a
      .asMap()
      .entries
      .every((MapEntry<int, dynamic> e) => e.value == b[e.key]);
}

/// See: [_regexesEqual] in `custom_device_config.dart` (exact copy)
bool _regexesEqual(RegExp? a, RegExp? b) {
  if (a == b) {
    return true;
  }
  if (a == null || b == null) {
    return false;
  }

  return a.pattern == b.pattern &&
      a.isMultiLine == b.isMultiLine &&
      a.isCaseSensitive == b.isCaseSensitive &&
      a.isUnicode == b.isUnicode &&
      a.isDotAll == b.isDotAll;
}

/// See: [CustomDeviceRevivalException] in `custom_device_config.dart`
@immutable
class ELinuxRemoteDeviceRevivalException implements Exception {
  const ELinuxRemoteDeviceRevivalException(this.message);

  const ELinuxRemoteDeviceRevivalException.fromDescriptions(
      String fieldDescription, String expectedValueDescription)
      : message = 'Expected $fieldDescription to be $expectedValueDescription.';

  final String message;

  @override
  String toString() {
    return message;
  }

  @override
  bool operator ==(Object other) {
    return (other is ELinuxRemoteDeviceRevivalException) &&
        (other.message == message);
  }

  @override
  int get hashCode => message.hashCode;
}

/// See: [CustomDeviceConfig] in `custom_device_config.dart`
@immutable
class ELinuxRemoteDeviceConfig {
  const ELinuxRemoteDeviceConfig(
      {required this.id,
      required this.label,
      required this.sdkNameAndVersion,
      this.platform = 'arm64',
      this.backend = 'wayland',
      required this.enabled,
      required this.pingCommand,
      this.pingSuccessRegex,
      required this.postBuildCommand,
      required this.installCommand,
      required this.uninstallCommand,
      required this.runDebugCommand,
      this.stopAppCommand = const <String>[],
      this.forwardPortCommand,
      this.forwardPortSuccessRegex,
      this.screenshotCommand})
      : assert(forwardPortCommand == null || forwardPortSuccessRegex != null);

  factory ELinuxRemoteDeviceConfig.fromJson(dynamic json) {
    final Map<String, dynamic> typedMap =
        _castJsonObject(json, 'device configuration', 'a JSON object');

    final List<String>? forwardPortCommand = _castStringListOrNull(
        typedMap[_kForwardPortCommand],
        _kForwardPortCommand,
        'null or array of strings with at least one element',
        minLength: 1);

    final RegExp? forwardPortSuccessRegex = _convertToRegexOrNull(
        typedMap[_kForwardPortSuccessRegex],
        _kForwardPortSuccessRegex,
        'null or string-ified regex');

    if (forwardPortCommand != null && forwardPortSuccessRegex == null) {
      throw const ELinuxRemoteDeviceRevivalException(
          'When forwardPort is given, forwardPortSuccessRegex must be specified too.');
    }

    return ELinuxRemoteDeviceConfig(
        id: _castString(typedMap[_kId], _kId, 'a string'),
        label: _castString(typedMap[_kLabel], _kLabel, 'a string'),
        sdkNameAndVersion: _castString(
            typedMap[_kSdkNameAndVersion], _kSdkNameAndVersion, 'a string'),
        enabled: _castBool(typedMap[_kEnabled], _kEnabled, 'a boolean'),
        platform: _castString(typedMap[_kPlatform], _kPlatform, 'arm64'),
        backend: _castString(typedMap[_kBackend], _kBackend, 'wayland'),
        pingCommand: _castStringList(typedMap[_kPingCommand], _kPingCommand,
            'array of strings with at least one element', minLength: 1),
        pingSuccessRegex: _convertToRegexOrNull(typedMap[_kPingSuccessRegex],
            _kPingSuccessRegex, 'null or string-ified regex'),
        postBuildCommand: _castStringListOrNull(
          typedMap[_kPostBuildCommand],
          _kPostBuildCommand,
          'null or array of strings with at least one element',
          minLength: 1,
        ),
        installCommand: _castStringList(
            typedMap[_kInstallCommand], _kInstallCommand, 'array of strings with at least one element',
            minLength: 1),
        uninstallCommand: _castStringList(typedMap[_kUninstallCommand],
            _kUninstallCommand, 'array of strings with at least one element',
            minLength: 1),
        runDebugCommand: _castStringList(
            typedMap[_kRunDebugCommand], _kRunDebugCommand, 'array of strings with at least one element',
            minLength: 1),
        stopAppCommand: _castStringList(typedMap[_kStopAppCommand], _kStopAppCommand, 'array of strings with at least one element', minLength: 1),
        forwardPortCommand: forwardPortCommand,
        forwardPortSuccessRegex: forwardPortSuccessRegex,
        screenshotCommand: _castStringListOrNull(typedMap[_kScreenshotCommand], _kScreenshotCommand, 'array of strings with at least one element', minLength: 1));
  }

  static const String _kId = 'id';
  static const String _kLabel = 'label';
  static const String _kSdkNameAndVersion = 'sdkNameAndVersion';
  static const String _kPlatform = 'platform';
  static const String _kEnabled = 'enabled';
  static const String _kBackend = 'backend';
  static const String _kPingCommand = 'ping';
  static const String _kPingSuccessRegex = 'pingSuccessRegex';
  static const String _kPostBuildCommand = 'postBuild';
  static const String _kInstallCommand = 'install';
  static const String _kUninstallCommand = 'uninstall';
  static const String _kRunDebugCommand = 'runDebug';
  static const String _kStopAppCommand = 'stopApp';
  static const String _kForwardPortCommand = 'forwardPort';
  static const String _kForwardPortSuccessRegex = 'forwardPortSuccessRegex';
  static const String _kScreenshotCommand = 'screenshot';

  final String id;
  final String label;
  final String sdkNameAndVersion;
  final String? platform;
  final String? backend;
  final bool enabled;
  final List<String> pingCommand;
  final RegExp? pingSuccessRegex;
  final List<String>? postBuildCommand;
  final List<String> installCommand;
  final List<String> uninstallCommand;
  final List<String> runDebugCommand;
  final List<String> stopAppCommand;
  final List<String>? forwardPortCommand;
  final RegExp? forwardPortSuccessRegex;
  final List<String>? screenshotCommand;

  bool get usesPortForwarding => forwardPortCommand != null;

  bool get supportsScreenshotting => screenshotCommand != null;

  static T _maybeRethrowAsRevivalException<T>(T Function() closure,
      String fieldDescription, String expectedValueDescription) {
    try {
      return closure();
    } on Object {
      throw ELinuxRemoteDeviceRevivalException.fromDescriptions(
          fieldDescription, expectedValueDescription);
    }
  }

  static Map<String, dynamic> _castJsonObject(
      dynamic value, String fieldDescription, String expectedValueDescription) {
    if (value == null) {
      throw ELinuxRemoteDeviceRevivalException.fromDescriptions(
          fieldDescription, expectedValueDescription);
    }

    return _maybeRethrowAsRevivalException(
      () => Map<String, dynamic>.from(value as Map<dynamic, dynamic>),
      fieldDescription,
      expectedValueDescription,
    );
  }

  static bool _castBool(
      dynamic value, String fieldDescription, String expectedValueDescription) {
    if (value == null) {
      throw ELinuxRemoteDeviceRevivalException.fromDescriptions(
          fieldDescription, expectedValueDescription);
    }

    return _maybeRethrowAsRevivalException(
      () => value as bool,
      fieldDescription,
      expectedValueDescription,
    );
  }

  static String _castString(
      dynamic value, String fieldDescription, String expectedValueDescription) {
    if (value == null) {
      throw ELinuxRemoteDeviceRevivalException.fromDescriptions(
          fieldDescription, expectedValueDescription);
    }

    return _maybeRethrowAsRevivalException(
      () => value as String,
      fieldDescription,
      expectedValueDescription,
    );
  }

  static List<String> _castStringList(
    dynamic value,
    String fieldDescription,
    String expectedValueDescription, {
    int minLength = 0,
  }) {
    if (value == null) {
      throw ELinuxRemoteDeviceRevivalException.fromDescriptions(
          fieldDescription, expectedValueDescription);
    }

    final List<String> list = _maybeRethrowAsRevivalException(
      () => List<String>.from(value as Iterable<dynamic>),
      fieldDescription,
      expectedValueDescription,
    );

    if (list.length < minLength) {
      throw ELinuxRemoteDeviceRevivalException.fromDescriptions(
          fieldDescription, expectedValueDescription);
    }

    return list;
  }

  static List<String>? _castStringListOrNull(
    dynamic value,
    String fieldDescription,
    String expectedValueDescription, {
    int minLength = 0,
  }) {
    if (value == null) {
      return null;
    }

    return _castStringList(value, fieldDescription, expectedValueDescription,
        minLength: minLength);
  }

  static RegExp? _convertToRegexOrNull(
      dynamic value, String fieldDescription, String expectedValueDescription) {
    if (value == null) {
      return null;
    }

    return _maybeRethrowAsRevivalException(
      () => RegExp(value as String),
      fieldDescription,
      expectedValueDescription,
    );
  }

  Object toJson() {
    return <String, Object?>{
      _kId: id,
      _kLabel: label,
      _kSdkNameAndVersion: sdkNameAndVersion,
      _kPlatform: platform,
      _kEnabled: enabled,
      _kBackend: backend,
      _kPingCommand: pingCommand,
      _kPingSuccessRegex: pingSuccessRegex?.pattern,
      _kPostBuildCommand: postBuildCommand,
      _kInstallCommand: installCommand,
      _kUninstallCommand: uninstallCommand,
      _kRunDebugCommand: runDebugCommand,
      _kStopAppCommand: stopAppCommand,
      _kForwardPortCommand: forwardPortCommand,
      _kForwardPortSuccessRegex: forwardPortSuccessRegex?.pattern,
      _kScreenshotCommand: screenshotCommand,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is ELinuxRemoteDeviceConfig &&
        other.id == id &&
        other.label == label &&
        other.sdkNameAndVersion == sdkNameAndVersion &&
        other.platform == platform &&
        other.enabled == enabled &&
        other.backend == backend &&
        _listsEqual(other.pingCommand, pingCommand) &&
        _regexesEqual(other.pingSuccessRegex, pingSuccessRegex) &&
        _listsEqual(other.postBuildCommand, postBuildCommand) &&
        _listsEqual(other.installCommand, installCommand) &&
        _listsEqual(other.uninstallCommand, uninstallCommand) &&
        _listsEqual(other.runDebugCommand, runDebugCommand) &&
        _listsEqual(other.stopAppCommand, stopAppCommand) &&
        _listsEqual(other.forwardPortCommand, forwardPortCommand) &&
        _regexesEqual(other.forwardPortSuccessRegex, forwardPortSuccessRegex) &&
        _listsEqual(other.screenshotCommand, screenshotCommand);
  }

  @override
  int get hashCode {
    return id.hashCode ^
        label.hashCode ^
        sdkNameAndVersion.hashCode ^
        platform.hashCode ^
        enabled.hashCode ^
        backend.hashCode ^
        pingCommand.hashCode ^
        (pingSuccessRegex?.pattern).hashCode ^
        postBuildCommand.hashCode ^
        installCommand.hashCode ^
        uninstallCommand.hashCode ^
        runDebugCommand.hashCode ^
        stopAppCommand.hashCode ^
        forwardPortCommand.hashCode ^
        (forwardPortSuccessRegex?.pattern).hashCode ^
        screenshotCommand.hashCode;
  }

  @override
  String toString() {
    return 'ELinuxDeviceConfig('
        'id: $id, '
        'label: $label, '
        'sdkNameAndVersion: $sdkNameAndVersion, '
        'platform: $platform, '
        'enabled: $enabled, '
        'backend: $backend, '
        'pingCommand: $pingCommand, '
        'pingSuccessRegex: $pingSuccessRegex, '
        'postBuildCommand: $postBuildCommand, '
        'installCommand: $installCommand, '
        'uninstallCommand: $uninstallCommand, '
        'runDebugCommand: $runDebugCommand, '
        'stopAppCommand: $stopAppCommand, '
        'forwardPortCommand: $forwardPortCommand, '
        'forwardPortSuccessRegex: $forwardPortSuccessRegex, '
        'screenshotCommand: $screenshotCommand)';
  }
}
