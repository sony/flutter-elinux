// Copyright 2021 Sony Group Corporation. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:convert';
import 'dart:core';

import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/upgrade.dart';
import 'package:flutter_tools/src/globals_null_migrated.dart' as globals;
import 'package:flutter_tools/src/runner/flutter_command.dart';

import 'package:meta/meta.dart';

/// Source: [UpgradeCommand] in `upgrade.dart`
class ELinuxUpgradeCommand extends UpgradeCommand {
  ELinuxUpgradeCommand({
    @required bool verboseHelp,
  }) : super(verboseHelp: verboseHelp);

  @override
  Future<FlutterCommandResult> runCommand() {
    final ELinuxUpgradeCommandRunner commandRunner =
        ELinuxUpgradeCommandRunner();
    commandRunner.workingDirectory = stringArg('working-directory') ??
        globals.fs.directory(Cache.flutterRoot).parent.path;
    return commandRunner.runCommand(
      force: boolArg('force'),
      continueFlow: boolArg('continue'),
      testFlow: stringArg('working-directory') != null,
      verifyOnly: boolArg('verify-only'),
    );
  }
}

class ELinuxGitTagVersion {
  ELinuxGitTagVersion(
    this.hash,
    this.hashShort,
    this.gitTag,
  );

  /// The git hash (or an abbreviation thereof) for this commit.
  final String hash;

  /// The git short hash (or an abbreviation thereof) for this commit.
  final String hashShort;

  /// The git tag that is this version's closest ancestor.
  final String gitTag;
}

/// Source: [UpgradeCommandRunner] in `upgrade.dart`
@visibleForTesting
class ELinuxUpgradeCommandRunner {
  String workingDirectory;

  Future<FlutterCommandResult> runCommand({
    @required bool force,
    @required bool continueFlow,
    @required bool testFlow,
    @required bool verifyOnly,
  }) async {
    if (!continueFlow) {
      await runCommandFirstHalf(
        force: force,
        testFlow: testFlow,
        verifyOnly: verifyOnly,
      );
    }
    return FlutterCommandResult.success();
  }

  Future<void> runCommandFirstHalf({
    @required bool force,
    @required bool testFlow,
    @required bool verifyOnly,
  }) async {
    final ELinuxGitTagVersion upstreamVersion = await fetchLatestVersion();
    final ELinuxGitTagVersion currentVersion = await fetchCurrentVersion();

    if (currentVersion.hash == upstreamVersion.hash) {
      globals.printStatus('Flutter is already up to date');
      globals.printStatus(upstreamVersion.gitTag);
      return;
    }

    if (verifyOnly) {
      globals.printStatus('A new version of Flutter is available\n');
      globals.printStatus(
          'The latest version: ${upstreamVersion.gitTag} (revision ${upstreamVersion.hashShort})',
          emphasis: true);
      globals.printStatus(
          'Your current version: ${currentVersion.gitTag} (revision ${currentVersion.hashShort})\n');
      globals.printStatus('To upgrade now, run "flutter-elinux upgrade".');
      return;
    }
  }

  Future<ELinuxGitTagVersion> fetchLatestVersion() async {
    String latestTag;
    String latestTagHash;
    try {
      // Fetch upstream branch's commits and tags
      await globals.processUtils.run(
        <String>['git', 'fetch', '--tags'],
        throwOnError: true,
        workingDirectory: workingDirectory,
      );

      RunResult result = await globals.processUtils.run(
        <String>['git', 'tag', '-l', '--sort=-v:refname'],
        throwOnError: true,
        workingDirectory: workingDirectory,
      );
      final List<String> tags =
          const LineSplitter().convert(result.stdout.trim());
      if (tags.isEmpty) {
        throwToolExit(
            'Unable to upgrade Flutter: Your Flutter checkout does not have any tags.\n'
            'Re-install re-install flutter-elinux.');
      }

      // Gets the hash of the latest version.
      latestTag = tags[0];
      result = await globals.processUtils.run(
        <String>['git', 'rev-parse', latestTag],
        throwOnError: true,
        workingDirectory: workingDirectory,
      );
      latestTagHash = result.stdout.trim();
    } on Exception catch (_) {
      throwToolExit(
          'Unable to upgrade Flutter: The current Flutter branch/channel is '
          'not tracking any remote repository.\n'
          'Re-install re-install flutter-elinux.');
    }
    return ELinuxGitTagVersion(
        latestTagHash, latestTagHash.substring(0, 10), latestTag);
  }

  Future<ELinuxGitTagVersion> fetchCurrentVersion() async {
    String tag;
    String tagHash;
    try {
      RunResult result = await globals.processUtils.run(
        <String>['git', 'rev-parse', '--verify', 'HEAD'],
        throwOnError: true,
        workingDirectory: workingDirectory,
      );
      tagHash = result.stdout.trim();

      result = await globals.processUtils.run(
        <String>['git', 'describe', '--tags'],
        throwOnError: true,
        workingDirectory: workingDirectory,
      );
      tag = result.stdout.trim();
    } on Exception catch (e) {
      final String errorString = e.toString();
      if (errorString.contains('fatal: HEAD does not point to a branch')) {
        throwToolExit(
            'Unable to upgrade Flutter: Your Flutter checkout is currently not '
            'on a release branch.\n'
            'Re-install re-install flutter-elinux.');
      } else if (errorString
          .contains('fatal: no upstream configured for branch')) {
        throwToolExit(
            'Unable to upgrade Flutter: The current Flutter branch/channel is '
            'not tracking any remote repository.\n'
            'Re-install re-install flutter-elinux.');
      } else {
        throwToolExit(errorString);
      }
    }
    return ELinuxGitTagVersion(tagHash, tagHash.substring(0, 10), tag);
  }
}
