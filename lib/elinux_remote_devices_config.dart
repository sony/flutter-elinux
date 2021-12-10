// Copyright 2021 Sony Group Corporation. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/base/config.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/cache.dart';

import 'elinux_remote_device_config.dart';

/// See: [CustomDevicesConfig] in `custom_devices_config.dart`
class ELinuxRemoteDevicesConfig {
  ELinuxRemoteDevicesConfig({
    required Platform platform,
    required FileSystem fileSystem,
    required Logger logger,
  })  : _fileSystem = fileSystem,
        _logger = logger,
        _config = Config(_kCustomDevicesConfigName,
            fileSystem: fileSystem, logger: logger, platform: platform) {
    ensureFileExists();
  }

  static const String _kCustomDevicesConfigName = 'custom_devices.json';
  static const String _kCustomDevicesConfigKey = 'custom-devices';
  static const String _kSchema = r'$schema';
  static const String _kCustomDevices = 'custom-devices';

  final FileSystem _fileSystem;
  final Logger _logger;
  final Config _config;

  String get _defaultSchema {
    final Uri uri = _fileSystem
        .directory(Cache.flutterRoot)
        .childDirectory('packages')
        .childDirectory('flutter_tools')
        .childDirectory('static')
        .childFile('custom-devices.schema.json')
        .uri;
    assert(uri.isAbsolute);
    return uri.toString();
  }

  void ensureFileExists() {
    if (!_fileSystem.file(_config.configPath).existsSync()) {
      _config.setValue(_kSchema, _defaultSchema);
      _config.setValue(_kCustomDevices, <dynamic>[]);
    }
  }

  List<dynamic>? _getDevicesJsonValue() {
    final dynamic json = _config.getValue(_kCustomDevicesConfigKey);
    if (json == null) {
      return null;
    } else if (json is! List) {
      const String msg =
          "Could not load custom devices config. config['$_kCustomDevicesConfigKey'] is not a JSON array.";
      _logger.printError(msg);
      throw const ELinuxRemoteDeviceRevivalException(msg);
    }

    return json;
  }

  List<ELinuxRemoteDeviceConfig> get devices {
    final List<dynamic>? typedListNullable = _getDevicesJsonValue();
    if (typedListNullable == null) {
      return <ELinuxRemoteDeviceConfig>[];
    }

    final List<dynamic> typedList = typedListNullable;
    final List<ELinuxRemoteDeviceConfig> revived = <ELinuxRemoteDeviceConfig>[];
    for (final MapEntry<int, dynamic> entry in typedList.asMap().entries) {
      try {
        revived.add(ELinuxRemoteDeviceConfig.fromJson(entry.value));
      } on ELinuxRemoteDeviceRevivalException catch (_) {
        // TODO(hidenori): Corrensponds to the format difference
        // from the default schema and uncooment here.
        //
        //final String msg =
        //    'Could not load custom device from config index ${entry.key}: $e';
        //_logger.printError(msg);
        //throw ELinuxRemoteDeviceRevivalException(msg);
      }
    }

    return revived;
  }

  List<ELinuxRemoteDeviceConfig> tryGetDevices() {
    try {
      return devices;
    } on Exception {
      return <ELinuxRemoteDeviceConfig>[];
    }
  }

  set devices(List<ELinuxRemoteDeviceConfig> configs) {
    _config.setValue(
        _kCustomDevicesConfigKey,
        configs
            .map<dynamic>((ELinuxRemoteDeviceConfig c) => c.toJson())
            .toList());
  }

  void add(ELinuxRemoteDeviceConfig config) {
    _config.setValue(_kCustomDevicesConfigKey,
        <dynamic>[...?_getDevicesJsonValue(), config.toJson()]);
  }

  bool contains(String deviceId) {
    return devices
        .any((ELinuxRemoteDeviceConfig device) => device.id == deviceId);
  }

  bool remove(String deviceId) {
    final List<ELinuxRemoteDeviceConfig> modifiedDevices = devices;
    final ELinuxRemoteDeviceConfig? device = modifiedDevices
        .cast<ELinuxRemoteDeviceConfig?>()
        .firstWhere((ELinuxRemoteDeviceConfig? d) => d!.id == deviceId,
            orElse: () => null);

    if (device == null) {
      return false;
    }

    modifiedDevices.remove(device);
    devices = modifiedDevices;
    return true;
  }

  String get configPath => _config.configPath;

  void forEach(Null Function(int value) param0, void add) {}
}
