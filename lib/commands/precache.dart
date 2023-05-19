// Copyright 2023 Sony Group Corporation. All rights reserved.
// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/precache.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';

import '../elinux_cache.dart';

class ELinuxPrecacheCommand extends PrecacheCommand {
  ELinuxPrecacheCommand({
    super.verboseHelp,
    required super.cache,
    required super.platform,
    required super.logger,
    required super.featureFlags,
  })  : _cache = cache,
        _platform = platform {
    argParser.addFlag(
      'elinux',
      help: 'Precache artifacts for Embedded Linux development.',
    );
  }

  final Cache _cache;
  final Platform _platform;

  bool get _includeOtherPlatforms =>
      boolArg('android') ||
      DevelopmentArtifact.values.any((DevelopmentArtifact artifact) =>
          boolArg(artifact.name) && argResults!.wasParsed(artifact.name));

  @override
  Future<FlutterCommandResult> runCommand() async {
    final bool includeAllPlatforms = boolArg('all-platforms');
    final bool includeELinux = boolArg('elinux');
    final bool includeDefaults = !includeELinux && !_includeOtherPlatforms;

    const String elinuxStampName = 'elinux-sdk';

    // Re-lock the cache.
    if (_platform.environment['FLUTTER_ALREADY_LOCKED'] != 'true') {
      await _cache.lock();
    }

    if (includeAllPlatforms || includeDefaults || includeELinux) {
      if (boolArg('force')) {
        _cache.setStampFor(elinuxStampName, '');
      }
      await _cache.updateAll(<DevelopmentArtifact>{
        ELinuxDevelopmentArtifact.elinux,
      });
    }

    if (includeAllPlatforms || includeDefaults || _includeOtherPlatforms) {
      // If the '--force' option is used, the super.runCommand() will delete
      // the elinux's stamp file. It should be restored.
      final String? elinuxStamp = _cache.getStampFor(elinuxStampName);
      final FlutterCommandResult result = await super.runCommand();
      if (elinuxStamp != null) {
        _cache.setStampFor(elinuxStampName, elinuxStamp);
      }
      return result;
    }

    return FlutterCommandResult.success();
  }
}
