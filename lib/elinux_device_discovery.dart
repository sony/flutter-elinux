// Copyright 2021 Sony Group Corporation. All rights reserved.
// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:io';

import 'package:flutter_tools/src/android/android_workflow.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/context.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/os.dart';
import 'package:flutter_tools/src/base/process.dart';
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
import 'elinux_remote_device_config.dart';
import 'elinux_remote_devices_config.dart';

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
class ELinuxDeviceDiscovery extends PollingDeviceDiscovery {
  ELinuxDeviceDiscovery({
    @required ELinuxWorkflow eLinuxWorkflow,
    @required ProcessManager processManager,
    @required Logger logger,
  })  : _eLinuxWorkflow = eLinuxWorkflow,
        _logger = logger,
        _processManager = processManager,
        _processUtils =
            ProcessUtils(logger: logger, processManager: processManager),
        _eLinuxRemoteDevicesConfig = ELinuxRemoteDevicesConfig(
          platform: globals.platform,
          fileSystem: globals.fs,
          logger: logger,
        ),
        super('eLinux devices');

  final ELinuxWorkflow _eLinuxWorkflow;
  final Logger _logger;
  final ProcessManager _processManager;
  final ProcessUtils _processUtils;
  final ELinuxRemoteDevicesConfig _eLinuxRemoteDevicesConfig;

  @override
  bool get supportsPlatform => _eLinuxWorkflow.appliesToHostPlatform;

  @override
  bool get canListAnything => _eLinuxWorkflow.canListDevices;

  @override
  Future<List<Device>> pollingGetDevices({Duration timeout}) async {
    if (!canListAnything) {
      return const <Device>[];
    }

    final List<ELinuxDevice> devices = <ELinuxDevice>[];

    // Adds current desktop host.
    devices.add(
      ELinuxDevice('elinux-wayland',
          config: null,
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
    );
    devices.add(
      ELinuxDevice('elinux-x11',
          config: null,
          desktop: true,
          targetArch: _getCurrentHostPlatformArchName(),
          backendType: 'x11',
          logger: _logger ?? globals.logger,
          processManager: _processManager ?? globals.processManager,
          operatingSystemUtils: OperatingSystemUtils(
            fileSystem: globals.fs,
            logger: _logger ?? globals.logger,
            platform: globals.platform,
            processManager: const LocalProcessManager(),
          )),
    );

    // Adds remote devices.
    for (final ELinuxRemoteDeviceConfig remoteDevice
        in _eLinuxRemoteDevicesConfig.devices) {
      if (!remoteDevice.enabled) {
        continue;
      }

      String stdout;
      RunResult result;
      try {
        result = await _processUtils.run(remoteDevice.pingCommand,
            throwOnError: true);
        stdout = result.stdout.trim();
      } on ProcessException catch (ex) {
        _logger.printError('ping failed to list attached devices:\n$ex');
        continue;
      }

      if (result.exitCode == 0 &&
          stdout.contains(remoteDevice.pingSuccessRegex)) {
        final ELinuxDevice device = ELinuxDevice(remoteDevice.id,
            config: remoteDevice,
            desktop: false,
            targetArch: remoteDevice.platform,
            backendType: remoteDevice.backend,
            sdkNameAndVersion: remoteDevice.sdkNameAndVersion,
            logger: _logger ?? globals.logger,
            processManager: _processManager ?? globals.processManager,
            operatingSystemUtils: OperatingSystemUtils(
              fileSystem: globals.fs,
              logger: _logger ?? globals.logger,
              platform: globals.platform,
              processManager: const LocalProcessManager(),
            ));
        devices.add(device);
      }
    }

    return devices;
  }

  @override
  Future<List<String>> getDiagnostics() async => const <String>[];

  String _getCurrentHostPlatformArchName() {
    final HostPlatform hostPlatform = getCurrentHostPlatform();
    return getNameForHostPlatformArch(hostPlatform);
  }

  @override
  List<String> get wellKnownIds => const <String>['elinux'];
}
