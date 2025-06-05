// Copyright 2023 Sony Group Corporation. All rights reserved.
// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:file/file.dart';
import 'package:flutter_tools/src/convert.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/project.dart';

const String kConfigNameAttach = 'flutter-elinux: Attach';

String _processJson(String jsonString) {
  // The extended JSON format used by launch.json files allows comments and
  // trailing commas. Remove them to prevent decoding errors.
  final RegExp comments = RegExp(r'(?<![:"/])(/\*([^*]|[\r\n]|(\*+([^*/]|[\r\n])))*\*+/|//.*\n?)');
  final RegExp trailingCommas = RegExp(r',(?=\s*?[\}\]])');
  return jsonString.replaceAll(comments, '').replaceAll(trailingCommas, '').trim();
}

void updateLaunchJsonFile(FlutterProject project, Uri vmServiceUri) {
  if (project.directory.basename == 'example') {
    final FlutterProject parentProject = FlutterProject.fromDirectory(project.directory.parent);
    if (parentProject.pubspecFile.existsSync()) {
      updateLaunchJsonFile(parentProject, vmServiceUri);
    }
  }

  final File launchJsonFile = project.directory.childDirectory('.vscode').childFile('launch.json');
  String jsonString = '';
  if (launchJsonFile.existsSync()) {
    jsonString = _processJson(launchJsonFile.readAsStringSync());
  }

  Map<Object?, Object?> decoded = <Object?, Object?>{};
  if (jsonString.isNotEmpty) {
    try {
      decoded = jsonDecode(jsonString) as Map<Object?, Object?>;
    } on FormatException catch (error) {
      globals.printError('Failed to parse ${launchJsonFile.path}:\n$error');
      return;
    }
  }
  decoded['version'] ??= '0.2.0';
  decoded['configurations'] ??= <Object?>[];

  final List<Object?> configs = decoded['configurations']! as List<Object?>;
  if (!configs.any((Object? config) => config is Map && config['name'] == kConfigNameAttach)) {
    configs.add(<String, String>{
      'name': kConfigNameAttach,
      'request': 'attach',
      'type': 'dart',
      'deviceId': 'flutter-tester',
    });
  }
  for (final Object? config in configs) {
    if (config is! Map || config['name'] != kConfigNameAttach) {
      continue;
    }
    config['cwd'] = project.hasExampleApp ? r'${workspaceFolder}/example' : r'${workspaceFolder}';
    config['vmServiceUri'] = vmServiceUri.toString();
  }

  const JsonEncoder encoder = JsonEncoder.withIndent('    ');
  launchJsonFile
    ..createSync(recursive: true)
    ..writeAsStringSync(encoder.convert(decoded));
}
