// Copyright 2021 Sony Group Corporation. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_tools/src/android/android_device.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/os.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/convert.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/device_port_forwarder.dart';
import 'package:flutter_tools/src/project.dart';
import 'package:flutter_tools/src/protocol_discovery.dart';

import 'package:meta/meta.dart';
import 'package:process/process.dart';

import 'elinux_builder.dart';
import 'elinux_package.dart';

/// eLinux device implementation.
///
/// See: [DesktopDevice] in `desktop_device.dart`
class ELinuxDevice extends Device {
  ELinuxDevice(
    String id, {
    @required bool desktop,
    @required String backendType,
    @required String targetArch,
    @required Logger logger,
    @required ProcessManager processManager,
    @required OperatingSystemUtils operatingSystemUtils,
  })  : _desktop = desktop,
        _backendType = backendType,
        _targetArch = targetArch,
        _logger = logger,
        _processManager = processManager,
        _operatingSystemUtils = operatingSystemUtils,
        super(id,
            category: Category.desktop,
            platformType: PlatformType.custom,
            ephemeral: true);

  final bool _desktop;
  final String _backendType;
  final String _targetArch;
  final Logger _logger;
  final ProcessManager _processManager;
  final OperatingSystemUtils _operatingSystemUtils;
  final Set<Process> _runningProcesses = <Process>{};
  final ELinuxLogReader _logReader = ELinuxLogReader();

  @override
  Future<bool> get isLocalEmulator async => false;

  @override
  Future<String> get emulatorId async => null;

  @override
  Future<TargetPlatform> get targetPlatform async {
    // Use tester as a platform identifer for eLinux.
    // There's currently no other choice because getNameForTargetPlatform()
    // throws an error for unknown platform types.
    return TargetPlatform.tester;
  }

  @override
  bool supportsRuntimeMode(BuildMode buildMode) =>
      buildMode != BuildMode.jitRelease;

  @override
  Future<String> get sdkNameAndVersion async => _operatingSystemUtils.name;

  @override
  String get name => 'eLinux';

  @override
  Future<bool> isAppInstalled(ELinuxApp app, {String userIdentifier}) async {
    return true;
  }

  @override
  Future<bool> isLatestBuildInstalled(ELinuxApp app) async {
    return true;
  }

  @override
  Future<bool> installApp(ELinuxApp app, {String userIdentifier}) async {
    return true;
  }

  @override
  Future<bool> uninstallApp(ELinuxApp app, {String userIdentifier}) async {
    return true;
  }

  /// Source: [AndroidDevice.startApp] in `android_device.dart`
  @override
  Future<LaunchResult> startApp(
    ELinuxApp package, {
    String mainPath,
    String route,
    DebuggingOptions debuggingOptions,
    Map<String, dynamic> platformArgs,
    bool prebuiltApplication = false,
    bool ipv6 = false,
    String userIdentifier,
  }) async {
    if (!prebuiltApplication) {
      _logger.printTrace('Building app');
      await buildForDevice(
        package,
        buildInfo: debuggingOptions.buildInfo,
        mainPath: mainPath,
      );
    }

    // Ensure that the executable is locatable.
    final BuildMode buildMode = debuggingOptions?.buildInfo?.mode;
    final bool traceStartup = platformArgs['trace-startup'] as bool ?? false;
    final String executable = executablePathForDevice(package, buildMode);
    const String executableOptions = '--bundle=./';
    if (executable == null) {
      _logger.printError('Unable to find executable to run');
      return LaunchResult.failed();
    }

    final Process process = await _processManager.start(
      <String>[
        executable,
        executableOptions,
        if (_desktop && _backendType == 'wayland') '-d',
        ...?debuggingOptions?.dartEntrypointArgs,
      ],
      environment: _computeEnvironment(debuggingOptions, traceStartup, route),
    );
    _runningProcesses.add(process);
    unawaited(process.exitCode.then((_) => _runningProcesses.remove(process)));

    _logReader.initializeProcess(process);
    if (debuggingOptions?.buildInfo?.isRelease == true) {
      return LaunchResult.succeeded();
    }
    final ProtocolDiscovery observatoryDiscovery =
        ProtocolDiscovery.observatory(
      _logReader,
      devicePort: debuggingOptions?.deviceVmServicePort,
      hostPort: debuggingOptions?.hostVmServicePort,
      ipv6: ipv6,
      logger: _logger,
    );
    try {
      final Uri observatoryUri = await observatoryDiscovery.uri;
      if (observatoryUri != null) {
        onAttached(package, buildMode, process);
        return LaunchResult.succeeded(observatoryUri: observatoryUri);
      }
      _logger.printError(
        'Error waiting for a debug connection: '
        'The log reader stopped unexpectedly.',
      );
    } on Exception catch (error) {
      _logger.printError('Error waiting for a debug connection: $error');
    } finally {
      await observatoryDiscovery.cancel();
    }
    return LaunchResult.failed();
  }

  @override
  Future<bool> stopApp(ELinuxApp app, {String userIdentifier}) async {
    bool succeeded = true;
    // Walk a copy of _runningProcesses, since the exit handler removes from the
    // set.
    for (final Process process in Set<Process>.of(_runningProcesses)) {
      succeeded &= _processManager.killPid(process.pid);
    }
    return succeeded;
  }

  @override
  void clearLogs() {}

  @override
  FutureOr<DeviceLogReader> getLogReader({
    ELinuxApp app,
    bool includePastLogs = false,
  }) =>
      _logReader;

  @override
  DevicePortForwarder get portForwarder => null;

  @override
  bool isSupported() => true;

  @override
  bool get supportsScreenshot => false;

  @override
  bool isSupportedForProject(FlutterProject flutterProject) {
    return flutterProject.isModule &&
        flutterProject.directory.childDirectory('elinux').existsSync();
  }

  @override
  Future<void> dispose() async {}

  Future<void> buildForDevice(
    ELinuxApp package, {
    String mainPath,
    BuildInfo buildInfo,
  }) async {
    final FlutterProject project = FlutterProject.current();
    final ELinuxBuildInfo eLinuxBuildInfo = ELinuxBuildInfo(
      buildInfo,
      targetArch: _targetArch,
      targetBackendType: _backendType,
    );
    await ELinuxBuilder.buildBundle(
      project: project,
      targetFile: mainPath,
      eLinuxBuildInfo: eLinuxBuildInfo,
    );
    package = ELinuxApp.fromELinuxProject(project);
  }

  String executablePathForDevice(ELinuxApp package, BuildMode buildMode) {
    return package.executable(buildMode, _targetArch);
  }

  void onAttached(ELinuxApp package, BuildMode buildMode, Process process) {}

  /// Computes a set of environment variables used to pass debugging information
  /// to the engine without interfering with application level command line
  /// arguments.
  ///
  /// The format of the environment variables is:
  ///   * FLUTTER_ENGINE_SWITCHES to the number of switches.
  ///   * FLUTTER_ENGINE_SWITCH_<N> (indexing from 1) to the individual switches.
  Map<String, String> _computeEnvironment(
      DebuggingOptions debuggingOptions, bool traceStartup, String route) {
    int flags = 0;
    final Map<String, String> environment = <String, String>{};

    void addFlag(String value) {
      flags += 1;
      environment['FLUTTER_ENGINE_SWITCH_$flags'] = value;
    }

    void finish() {
      environment['FLUTTER_ENGINE_SWITCHES'] = flags.toString();
    }

    addFlag('enable-dart-profiling=true');
    addFlag('enable-background-compilation=true');

    if (traceStartup) {
      addFlag('trace-startup=true');
    }
    if (route != null) {
      addFlag('route=$route');
    }
    if (debuggingOptions.enableSoftwareRendering) {
      addFlag('enable-software-rendering=true');
    }
    if (debuggingOptions.skiaDeterministicRendering) {
      addFlag('skia-deterministic-rendering=true');
    }
    if (debuggingOptions.traceSkia) {
      addFlag('trace-skia=true');
    }
    if (debuggingOptions.traceAllowlist != null) {
      addFlag('trace-allowlist=${debuggingOptions.traceAllowlist}');
    }
    if (debuggingOptions.traceSkiaAllowlist != null) {
      addFlag('trace-skia-allowlist=${debuggingOptions.traceSkiaAllowlist}');
    }
    if (debuggingOptions.traceSystrace) {
      addFlag('trace-systrace=true');
    }
    if (debuggingOptions.endlessTraceBuffer) {
      addFlag('endless-trace-buffer=true');
    }
    if (debuggingOptions.dumpSkpOnShaderCompilation) {
      addFlag('dump-skp-on-shader-compilation=true');
    }
    if (debuggingOptions.cacheSkSL) {
      addFlag('cache-sksl=true');
    }
    if (debuggingOptions.purgePersistentCache) {
      addFlag('purge-persistent-cache=true');
    }
    // Options only supported when there is a VM Service connection between the
    // tool and the device, usually in debug or profile mode.
    if (debuggingOptions.debuggingEnabled) {
      if (debuggingOptions.deviceVmServicePort != null) {
        addFlag('observatory-port=${debuggingOptions.deviceVmServicePort}');
      }
      if (debuggingOptions.buildInfo.isDebug) {
        addFlag('enable-checked-mode=true');
        addFlag('verify-entry-points=true');
      }
      if (debuggingOptions.startPaused) {
        addFlag('start-paused=true');
      }
      if (debuggingOptions.disableServiceAuthCodes) {
        addFlag('disable-service-auth-codes=true');
      }
      final String dartVmFlags = computeDartVmFlags(debuggingOptions);
      if (dartVmFlags.isNotEmpty) {
        addFlag('dart-flags=$dartVmFlags');
      }
      if (debuggingOptions.useTestFonts) {
        addFlag('use-test-fonts=true');
      }
      if (debuggingOptions.verboseSystemLogs) {
        addFlag('verbose-logging=true');
      }
    }
    finish();
    return environment;
  }
}

class ELinuxLogReader extends DeviceLogReader {
  final StreamController<List<int>> _inputController =
      StreamController<List<int>>.broadcast();

  void initializeProcess(Process process) {
    process.stdout.listen(_inputController.add);
    process.stderr.listen(_inputController.add);
    process.exitCode.whenComplete(_inputController.close);
  }

  @override
  Stream<String> get logLines {
    return _inputController.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());
  }

  @override
  String get name => 'eLinux';

  @override
  void dispose() {}
}
