// Copyright 2021 Sony Group Corporation. All rights reserved.
// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:flutter_tools/src/android/android_device_discovery.dart';
import 'package:flutter_tools/src/android/android_workflow.dart';
import 'package:flutter_tools/src/base/context.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/os.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/context_runner.dart';
import 'package:flutter_tools/src/custom_devices/custom_devices_config.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/features.dart';
import 'package:flutter_tools/src/flutter_device_manager.dart';
import 'package:flutter_tools/src/fuchsia/fuchsia_workflow.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/macos/macos_workflow.dart';
import 'package:flutter_tools/src/windows/uwptool.dart';
import 'package:flutter_tools/src/windows/windows_workflow.dart';
import 'package:meta/meta.dart';
import 'package:process/process.dart';

import 'elinux_device.dart';
import 'elinux_doctor.dart';

/// An extended [FlutterDeviceManager] for managing eLinux devices.
class ELinuxDeviceManager extends FlutterDeviceManager {
  /// Source: [runInContext] in `context_runner.dart`
  ELinuxDeviceManager()
      : super(
          logger: globals.logger,
          processManager: globals.processManager,
          platform: globals.platform,
          androidSdk: globals.androidSdk,
          iosSimulatorUtils: globals.iosSimulatorUtils,
          featureFlags: featureFlags,
          fileSystem: globals.fs,
          iosWorkflow: globals.iosWorkflow,
          artifacts: globals.artifacts,
          flutterVersion: globals.flutterVersion,
          androidWorkflow: androidWorkflow,
          config: globals.config,
          fuchsiaWorkflow: fuchsiaWorkflow,
          xcDevice: globals.xcdevice,
          userMessages: globals.userMessages,
          windowsWorkflow: windowsWorkflow,
          macOSWorkflow: context.get<MacOSWorkflow>(),
          operatingSystemUtils: globals.os,
          terminal: globals.terminal,
          customDevicesConfig: CustomDevicesConfig(
            fileSystem: globals.fs,
            logger: globals.logger,
            platform: globals.platform,
          ),
          uwptool: UwpTool(
            artifacts: globals.artifacts,
            logger: globals.logger,
            processManager: globals.processManager,
          ),
        );

  final ELinuxDeviceDiscovery _eLinuxDeviceDiscovery = ELinuxDeviceDiscovery(
    eLinuxWorkflow: eLinuxWorkflow,
    logger: globals.logger,
    processManager: globals.processManager,
  );

  @override
  List<DeviceDiscovery> get deviceDiscoverers => <DeviceDiscovery>[
        ...super.deviceDiscoverers,
        _eLinuxDeviceDiscovery,
      ];
}

/// Device discovery for eLinux devices.
///
/// Source: [AndroidDevices] in `android_device_discovery.dart`
class ELinuxDeviceDiscovery extends PollingDeviceDiscovery {
  ELinuxDeviceDiscovery({
    @required ELinuxWorkflow eLinuxWorkflow,
    @required ProcessManager processManager,
    @required Logger logger,
  })  : _eLinuxWorkflow = eLinuxWorkflow,
        _logger = logger,
        _processManager = processManager,
        super('eLinux devices');

  final ELinuxWorkflow _eLinuxWorkflow;
  final Logger _logger;
  final ProcessManager _processManager;

  @override
  bool get supportsPlatform => _eLinuxWorkflow.appliesToHostPlatform;

  @override
  bool get canListAnything => _eLinuxWorkflow.canListDevices;

  @override
  Future<List<Device>> pollingGetDevices({Duration timeout}) async {
    if (!canListAnything) {
      return const <Device>[];
    }

    return <Device>[
      ELinuxDevice('eLinux',
          desktop: true,
          targetArch: _getCurrentHostPlatformArchName(),
          backendType: 'wayland',
          logger: _logger ?? globals.logger,
          processManager: _processManager ?? globals.processManager,
          operatingSystemUtils: OperatingSystemUtils(
            fileSystem: globals.fs,
            logger: _logger ?? globals.logger,
            platform: globals.platform,
            processManager: const LocalProcessManager(),
          )),
    ];
  }

  @override
  Future<List<String>> getDiagnostics() async => const <String>[];

  String _getCurrentHostPlatformArchName() {
    final HostPlatform hostPlatform = getCurrentHostPlatform();
    return getNameForHostPlatformArch(hostPlatform);
  }
}
