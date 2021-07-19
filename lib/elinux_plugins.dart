// Copyright 2021 Sony Group Corporation. All rights reserved.
// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:convert';

import 'package:file/file.dart';
import 'package:flutter_tools/src/base/error_handling_io.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/terminal.dart';
import 'package:flutter_tools/src/build_system/targets/web.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/dart/language_version.dart';
import 'package:flutter_tools/src/dart/package_map.dart';
import 'package:flutter_tools/src/flutter_plugins.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/platform_plugins.dart';
import 'package:flutter_tools/src/plugins.dart';
import 'package:flutter_tools/src/project.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';

import 'package:meta/meta.dart';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

import 'elinux_cmake_project.dart';

/// Contains the parameters to template a elinux plugin.
///
/// The [name] of the plugin is required. Either [dartPluginClass] or
/// [pluginClass] are required. [pluginClass] will be the entry point to the
/// plugin's native code. If [pluginClass] is not empty, the [fileName]
/// containing the plugin's code is required.
///
/// Source: [LinuxPlugin] in `platform_plugins.dart`
class ELinuxPlugin extends PluginPlatform implements NativeOrDartPlugin {
  ELinuxPlugin({
    @required this.name,
    @required this.directory,
    this.pluginClass,
    this.dartPluginClass,
    this.fileName,
    this.dependencies,
  }) : assert(pluginClass != null || dartPluginClass != null);

  factory ELinuxPlugin.fromYaml(String name, Directory directory, YamlMap yaml,
      List<String> dependencies) {
    assert(validate(yaml));
    return ELinuxPlugin(
        name: name,
        directory: directory,
        pluginClass: yaml[kPluginClass] as String,
        dartPluginClass: yaml[kDartPluginClass] as String,
        fileName: yaml['fileName'] as String,
        dependencies: dependencies);
  }

  static bool validate(YamlMap yaml) {
    if (yaml == null) {
      return false;
    }
    return yaml[kPluginClass] is String || yaml[kDartPluginClass] is String;
  }

  static const String kConfigKey = 'elinux';

  final String name;
  final Directory directory;
  final String pluginClass;
  final String dartPluginClass;
  final String fileName;
  final List<String> dependencies;

  @override
  bool isNative() => pluginClass != null;

  @override
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      if (pluginClass != null) 'class': pluginClass,
      if (dartPluginClass != null) 'dartPluginClass': dartPluginClass,
      'file': fileName,
    };
  }

  String get path => directory.parent.path;

  File get projectFile => directory.childFile('project_def.prop');

  final RegExp _propertyFormat = RegExp(r'(\S+)\s*\+?=(.*)');

  Map<String, String> _properties;

  String getProperty(String key) {
    if (_properties == null) {
      if (!projectFile.existsSync()) {
        return null;
      }
      _properties = <String, String>{};

      for (final String line in projectFile.readAsLinesSync()) {
        final Match match = _propertyFormat.firstMatch(line);
        if (match == null) {
          continue;
        }
        final String key = match.group(1);
        final String value = match.group(2).trim();
        _properties[key] = value;
      }
    }
    return _properties.containsKey(key) ? _properties[key] : null;
  }

  List<String> getPropertyAsAbsolutePaths(String key) {
    final String property = getProperty(key);
    if (property == null) {
      return <String>[];
    }

    final List<String> paths = <String>[];
    for (final String element in property.split(' ')) {
      if (globals.fs.path.isAbsolute(element)) {
        paths.add(element);
      } else {
        paths.add(globals.fs.path
            .normalize(globals.fs.path.join(directory.path, element)));
      }
    }
    return paths;
  }
}

/// Any [FlutterCommand] that invokes [usesPubOption] or [targetFile] should
/// depend on this mixin to ensure plugins are correctly configured for eLinux.
///
/// See: [FlutterCommand.verifyThenRunCommand] in `flutter_command.dart`
mixin ELinuxExtension on FlutterCommand {
  String _entrypoint;

  bool get _usesTargetOption => argParser.options.containsKey('target');

  @override
  Future<FlutterCommandResult> verifyThenRunCommand(String commandPath) async {
    if (super.shouldRunPub) {
      // TODO(swift-kim): Should run pub get first before injecting plugins.
      await ensureReadyForELinuxTooling(FlutterProject.current());
    }
    if (_usesTargetOption) {
      _entrypoint =
          await _createEntrypoint(FlutterProject.current(), super.targetFile);
    }
    return super.verifyThenRunCommand(commandPath);
  }

  @override
  String get targetFile => _entrypoint ?? super.targetFile;
}

/// Creates an entrypoint wrapper of [targetFile] and returns its path.
/// This effectively adds support for Dart plugins.
///
/// Source: [WebEntrypointTarget.build] in `web.dart`
Future<String> _createEntrypoint(
    FlutterProject project, String targetFile) async {
  final List<ELinuxPlugin> dartPlugins =
      await findELinuxPlugins(project, dartOnly: true);
  if (dartPlugins.isEmpty) {
    return targetFile;
  }

  final ELinuxProject eLinuxProject = ELinuxProject.fromFlutter(project);
  if (!eLinuxProject.existsSync()) {
    return targetFile;
  }

  final File entrypoint = eLinuxProject.managedDirectory.childFile('main.dart')
    ..createSync(recursive: true);
  final PackageConfig packageConfig = await loadPackageConfigWithLogging(
    project.directory.childFile('.packages'),
    logger: globals.logger,
  );
  final FlutterProject flutterProject = FlutterProject.current();
  final LanguageVersion languageVersion = determineLanguageVersion(
    globals.fs.file(targetFile),
    packageConfig[flutterProject.manifest.appName],
    Cache.flutterRoot,
  );

  final Uri mainUri = globals.fs.file(targetFile).absolute.uri;
  final String mainImport =
      packageConfig.toPackageUri(mainUri)?.toString() ?? mainUri.toString();

  entrypoint.writeAsStringSync('''
//
// Generated file. Do not edit.
//
// @dart=${languageVersion.major}.${languageVersion.minor}

import '$mainImport' as entrypoint;
import 'generated_plugin_registrant.dart';

Future<void> main() async {
  registerPlugins();
  entrypoint.main();
}
''');
  return entrypoint.path;
}

const List<String> _knownPlugins = <String>[
  'audioplayers',
  'battery',
  'battery_plus',
  'camera',
  'connectivity',
  'device_info',
  'flutter_tts',
  'image_picker',
  'integration_test',
  'package_info',
  'package_info_plus',
  'path_provider',
  'permission_handler',
  'sensors',
  'sensors_plus',
  'share',
  'shared_preferences',
  'url_launcher',
  'video_player',
  'webview_flutter',
  'wifi_info_flutter',
];

/// This function must be called whenever [FlutterProject.regeneratePlatformSpecificTooling]
/// or [FlutterProject.ensureReadyForPlatformSpecificTooling] is called.
///
/// See: [FlutterProject.ensureReadyForPlatformSpecificTooling] in `project.dart`
Future<void> ensureReadyForELinuxTooling(FlutterProject project) async {
  if (!project.directory.existsSync() ||
      project.hasExampleApp ||
      project.isPlugin) {
    return;
  }
  final ELinuxProject eLinuxProject = ELinuxProject.fromFlutter(project);
  await eLinuxProject.ensureReadyForPlatformSpecificTooling();

  await injectELinuxPlugins(project);
}

/// See: [refreshPluginsList] in `plugins.dart`
Future<void> refreshELinuxPluginsList(FlutterProject project) async {
  final List<ELinuxPlugin> plugins = await findELinuxPlugins(project);
  // Sort the plugins by name to keep ordering stable in generated files.
  plugins.sort((ELinuxPlugin left, ELinuxPlugin right) =>
      left.name.compareTo(right.name));

  final bool legacyChanged =
      _writeELinuxFlutterPluginsListLegacy(project, plugins);
  final bool changed = await _writeELinuxFlutterPluginsList(project, plugins);
  if (changed || legacyChanged) {
    createPluginSymlinks(project, force: true);
  }
}

/// See: [_writeFlutterPluginsListLegacy] in `plugins.dart`
bool _writeELinuxFlutterPluginsListLegacy(
    FlutterProject project, List<ELinuxPlugin> plugins) {
  final File pluginsFile = project.flutterPluginsFile;
  if (plugins.isEmpty) {
    return ErrorHandlingFileSystem.deleteIfExists(pluginsFile);
  }

  const String info =
      'This is a generated file; do not edit or check into version control.';
  final StringBuffer flutterPluginsBuffer = StringBuffer('# $info\n');

  for (final ELinuxPlugin plugin in plugins) {
    flutterPluginsBuffer
        .write('${plugin.name}=${globals.fsUtils.escapePath(plugin.path)}\n');
  }
  final String oldPluginFileContent = _readFileContent(pluginsFile);
  final String pluginFileContent = flutterPluginsBuffer.toString();
  pluginsFile.writeAsStringSync(pluginFileContent, flush: true);

  return oldPluginFileContent != _readFileContent(pluginsFile);
}

// Key strings for the .flutter-plugins-dependencies file.
const String _kFlutterPluginsPluginListKey = 'plugins';
const String _kFlutterPluginsNameKey = 'name';
const String _kFlutterPluginsPathKey = 'path';
const String _kFlutterPluginsDependenciesKey = 'dependencies';

/// See: [_writeFlutterPluginsList] in `plugins.dart`
Future<bool> _writeELinuxFlutterPluginsList(
    FlutterProject project, List<ELinuxPlugin> plugins) async {
  final File pluginsFile = project.flutterPluginsDependenciesFile;
  if (plugins.isEmpty) {
    return ErrorHandlingFileSystem.deleteIfExists(pluginsFile);
  }

  final String iosKey = project.ios.pluginConfigKey;
  final String androidKey = project.android.pluginConfigKey;
  final String macosKey = project.macos.pluginConfigKey;
  final String linuxKey = project.linux.pluginConfigKey;
  final String windowsKey = project.windows.pluginConfigKey;
  final String webKey = project.web.pluginConfigKey;
  final String elinuxKey = ELinuxProject.fromFlutter(project).pluginConfigKey;

  final Map<String, Object> pluginsMap = <String, Object>{};
  {
    final List<Plugin> plugins = await findPlugins(project);
    pluginsMap[iosKey] = _filterPluginsByPlatform(plugins, iosKey);
    pluginsMap[androidKey] = _filterPluginsByPlatform(plugins, androidKey);
    pluginsMap[macosKey] = _filterPluginsByPlatform(plugins, macosKey);
    pluginsMap[linuxKey] = _filterPluginsByPlatform(plugins, linuxKey);
    pluginsMap[windowsKey] = _filterPluginsByPlatform(plugins, windowsKey);
    pluginsMap[webKey] = _filterPluginsByPlatform(plugins, webKey);
  }
  pluginsMap[elinuxKey] = _filterELinuxPluginsByPlatform(plugins, elinuxKey);

  final Map<String, Object> result = <String, Object>{};
  result['info'] =
      'This is a generated file; do not edit or check into version control.';
  result[_kFlutterPluginsPluginListKey] = pluginsMap;

  /// The dependencyGraph object is kept for backwards compatibility, but
  /// should be removed once migration is complete.
  /// https://github.com/flutter/flutter/issues/48918
  result['dependencyGraph'] = _createPluginLegacyDependencyGraph(plugins);
  result['date_created'] = globals.systemClock.now().toString();
  result['version'] = globals.flutterVersion.frameworkVersion;

  // Only notify if the plugins list has changed. [date_created] will always be different,
  // [version] is not relevant for this check.
  const bool pluginsChanged = true;
  //final String oldPluginsFileStringContent = _readFileContent(pluginsFile);
  //if (oldPluginsFileStringContent != null) {
  //  pluginsChanged =
  //      oldPluginsFileStringContent.contains(pluginsMap.toString());
  //}
  final String pluginFileContent = json.encode(result);
  pluginsFile.writeAsStringSync(pluginFileContent, flush: true);

  return pluginsChanged;
}

/// See: [_filterPluginsByPlatform] in `plugins.dart` (exact copy)
List<Map<String, Object>> _filterPluginsByPlatform(
    List<Plugin> plugins, String platformKey) {
  final Iterable<Plugin> platformPlugins = plugins.where((Plugin p) {
    return p.platforms.containsKey(platformKey);
  });

  final Set<String> pluginNames =
      platformPlugins.map((Plugin plugin) => plugin.name).toSet();
  final List<Map<String, Object>> pluginInfo = <Map<String, Object>>[];
  for (final Plugin plugin in platformPlugins) {
    pluginInfo.add(<String, Object>{
      _kFlutterPluginsNameKey: plugin.name,
      _kFlutterPluginsPathKey: globals.fsUtils.escapePath(plugin.path),
      _kFlutterPluginsDependenciesKey: <String>[
        ...plugin.dependencies.where(pluginNames.contains)
      ],
    });
  }
  return pluginInfo;
}

/// See: [_filterPluginsByPlatform] in `plugins.dart`
List<Map<String, Object>> _filterELinuxPluginsByPlatform(
    List<ELinuxPlugin> plugins, String platformKey) {
  final Set<String> pluginNames =
      plugins.map((ELinuxPlugin plugin) => plugin.name).toSet();
  final List<Map<String, Object>> pluginInfo = <Map<String, Object>>[];
  for (final ELinuxPlugin plugin in plugins) {
    pluginInfo.add(<String, Object>{
      _kFlutterPluginsNameKey: plugin.name,
      _kFlutterPluginsPathKey: globals.fsUtils.escapePath(plugin.path),
      _kFlutterPluginsDependenciesKey: <String>[
        ...plugin.dependencies.where(pluginNames.contains)
      ],
    });
  }
  return pluginInfo;
}

/// See: [_createPluginLegacyDependencyGraph] in `plugins.dart`
List<Object> _createPluginLegacyDependencyGraph(List<ELinuxPlugin> plugins) {
  final List<Object> directAppDependencies = <Object>[];
  final Set<String> pluginNames =
      plugins.map((ELinuxPlugin plugin) => plugin.name).toSet();
  for (final ELinuxPlugin plugin in plugins) {
    directAppDependencies.add(<String, Object>{
      'name': plugin.name,
      // Extract the plugin dependencies which happen to be plugins.
      'dependencies': <String>[
        ...plugin.dependencies.where(pluginNames.contains)
      ],
    });
  }
  return directAppDependencies;
}

/// See: [injectPlugins] in `plugins.dart`
Future<void> injectELinuxPlugins(FlutterProject project) async {
  final ELinuxProject eLinuxProject = ELinuxProject.fromFlutter(project);
  if (eLinuxProject.existsSync()) {
    final List<ELinuxPlugin> dartPlugins =
        await findELinuxPlugins(project, dartOnly: true);
    final List<ELinuxPlugin> nativePlugins =
        await findELinuxPlugins(project, nativeOnly: true);
    _writeDartPluginRegistrant(eLinuxProject.managedDirectory, dartPlugins);
    _writePluginCmakefileTemplate(
        eLinuxProject, eLinuxProject.managedDirectory, nativePlugins);
  }

  final List<String> plugins = (await findELinuxPlugins(project))
      .map((ELinuxPlugin p) => p.name)
      .toList();
  for (final String plugin in plugins) {
    final String eLinuxPlugin = '${plugin}_elinux';
    if (_knownPlugins.contains(plugin) && !plugins.contains(eLinuxPlugin)) {
      globals.printStatus(
        '$eLinuxPlugin is available on pub.dev. Did you forget to add to pubspec.yaml?',
        color: TerminalColor.yellow,
      );
    }
  }
}

/// Source: [findPlugins] in `plugins.dart`
Future<List<ELinuxPlugin>> findELinuxPlugins(
  FlutterProject project, {
  bool dartOnly = false,
  bool nativeOnly = false,
  bool throwOnError = true,
}) async {
  final List<ELinuxPlugin> plugins = <ELinuxPlugin>[];
  final File packagesFile = project.directory.childFile('.packages');
  final PackageConfig packageConfig = await loadPackageConfigWithLogging(
    packagesFile,
    logger: globals.logger,
    throwOnError: throwOnError,
  );
  for (final Package package in packageConfig.packages) {
    final Uri packageRoot = package.packageUriRoot.resolve('..');
    final ELinuxPlugin plugin = _pluginFromPackage(package.name, packageRoot);
    if (plugin == null) {
      continue;
    } else if (nativeOnly && plugin.pluginClass == null) {
      continue;
    } else if (dartOnly && plugin.dartPluginClass == null) {
      continue;
    }
    plugins.add(plugin);
  }
  return plugins;
}

/// Source: [_pluginFromPackage] in `plugins.dart`
ELinuxPlugin _pluginFromPackage(String name, Uri packageRoot) {
  final String pubspecPath =
      globals.fs.path.fromUri(packageRoot.resolve('pubspec.yaml'));
  if (!globals.fs.isFileSync(pubspecPath)) {
    return null;
  }

  dynamic pubspec;
  try {
    pubspec = loadYaml(globals.fs.file(pubspecPath).readAsStringSync());
  } on YamlException catch (err) {
    globals.printTrace('Failed to parse plugin manifest for $name: $err');
  }
  if (pubspec == null) {
    return null;
  }
  final dynamic flutterConfig = pubspec['flutter'];
  if (flutterConfig == null || !(flutterConfig.containsKey('plugin') as bool)) {
    return null;
  }

  final Directory packageDir = globals.fs.directory(packageRoot);
  globals.printTrace('Found plugin $name at ${packageDir.path}');

  final YamlMap pluginYaml = flutterConfig['plugin'] as YamlMap;
  if (pluginYaml == null || pluginYaml['platforms'] == null) {
    return null;
  }
  final YamlMap platformsYaml = pluginYaml['platforms'] as YamlMap;
  if (platformsYaml == null || platformsYaml[ELinuxPlugin.kConfigKey] == null) {
    return null;
  }
  final YamlMap dependencies = pubspec['dependencies'] as YamlMap;
  return ELinuxPlugin.fromYaml(
    name,
    packageDir.childDirectory('elinux'),
    platformsYaml[ELinuxPlugin.kConfigKey] as YamlMap,
    dependencies == null
        ? <String>[]
        : <String>[...dependencies.keys.cast<String>()],
  );
}

/// See: [_writeWebPluginRegistrant] in `plugins.dart`
void _writeDartPluginRegistrant(
  Directory registryDirectory,
  List<ELinuxPlugin> plugins,
) {
  final List<Map<String, dynamic>> pluginConfigs =
      plugins.map((ELinuxPlugin plugin) => plugin.toMap()).toList();
  final Map<String, dynamic> context = <String, dynamic>{
    'plugins': pluginConfigs,
  };
  _renderTemplateToFile(
    '''
//
// Generated file. Do not edit.
//

// ignore_for_file: lines_longer_than_80_chars

{{#plugins}}
import 'package:{{name}}/{{name}}.dart';
{{/plugins}}

// ignore: public_member_api_docs
void registerPlugins() {
{{#plugins}}
  {{dartPluginClass}}.register();
{{/plugins}}
}
''',
    context,
    registryDirectory.childFile('generated_plugin_registrant.dart').path,
  );
}

/// See: [_writeWindowsPluginFiles] in `plugins.dart`
void _writePluginCmakefileTemplate(
  ELinuxProject eLinuxProject,
  Directory registryDirectory,
  List<ELinuxPlugin> plugins,
) {
  final List<Map<String, dynamic>> pluginConfigs =
      plugins.map((ELinuxPlugin plugin) => plugin.toMap()).toList();
  final Map<String, dynamic> context = <String, dynamic>{
    'plugins': pluginConfigs,
    'pluginsDir': _cmakeRelativePluginSymlinkDirectoryPath(eLinuxProject),
  };
  _renderTemplateToFile(
    '''
//
// Generated file. Do not edit.
//

#ifndef GENERATED_PLUGIN_REGISTRANT_
#define GENERATED_PLUGIN_REGISTRANT_

#include <flutter/plugin_registry.h>

// Registers Flutter plugins.
void RegisterPlugins(flutter::PluginRegistry* registry);

#endif  // GENERATED_PLUGIN_REGISTRANT_
''',
    context,
    registryDirectory.childFile('generated_plugin_registrant.h').path,
  );
  _renderTemplateToFile(
    '''
//
// Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

void RegisterPlugins(flutter::PluginRegistry* registry) {
}
''',
    context,
    registryDirectory.childFile('generated_plugin_registrant.cc').path,
  );
  _renderTemplateToFile(
    r'''
#
# Generated file, do not edit.
#

list(APPEND FLUTTER_PLUGIN_LIST
{{#plugins}}
  {{name}}
{{/plugins}}
)

set(PLUGIN_BUNDLED_LIBRARIES)

foreach(plugin ${FLUTTER_PLUGIN_LIST})
  add_subdirectory({{pluginsDir}}/${plugin}/elinux plugins/${plugin})
  target_link_libraries(${BINARY_NAME} PRIVATE ${plugin}_plugin)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES $<TARGET_FILE:${plugin}_plugin>)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${plugin}_bundled_libraries})
endforeach(plugin)
''',
    context,
    registryDirectory.childFile('generated_plugins.cmake').path,
  );
}

/// Source: [_cmakeRelativePluginSymlinkDirectoryPath] in `flutter_plugins.dart`
String _cmakeRelativePluginSymlinkDirectoryPath(CmakeBasedProject project) {
  final FileSystem fileSystem = project.pluginSymlinkDirectory.fileSystem;
  final String makefileDirPath = project.cmakeFile.parent.absolute.path;
  // CMake always uses posix-style path separators, regardless of the platform.
  final path.Context cmakePathContext = path.Context(style: path.Style.posix);
  final List<String> relativePathComponents =
      fileSystem.path.split(fileSystem.path.relative(
    project.pluginSymlinkDirectory.absolute.path,
    from: makefileDirPath,
  ));
  return cmakePathContext.joinAll(relativePathComponents);
}

/// Source: [_renderTemplateToFile] in `plugins.dart` (exact copy)
void _renderTemplateToFile(String template, dynamic context, String filePath) {
  final String renderedTemplate = globals.templateRenderer
      .renderString(template, context, htmlEscapeValues: false);
  final File file = globals.fs.file(filePath);
  file.createSync(recursive: true);
  file.writeAsStringSync(renderedTemplate);
}

/// Source: [createPluginSymlinks] in `flutter_plugins.dart`
void createPluginSymlinks(FlutterProject project, {bool force = false}) {
  Map<String, Object> platformPlugins;
  final String pluginFileContent =
      _readFileContent(project.flutterPluginsDependenciesFile);
  if (pluginFileContent != null) {
    final Map<String, Object> pluginInfo =
        json.decode(pluginFileContent) as Map<String, Object>;
    platformPlugins =
        pluginInfo[_kFlutterPluginsPluginListKey] as Map<String, Object>;
  }
  platformPlugins ??= <String, Object>{};

  final ELinuxProject eLinuxProject = ELinuxProject.fromFlutter(project);
  if (eLinuxProject.existsSync()) {
    _createPlatformPluginSymlinks(
      eLinuxProject.pluginSymlinkDirectory,
      platformPlugins[eLinuxProject.pluginConfigKey] as List<Object>,
      force: force,
    );
  }
}

/// Returns the contents of [File] or [null] if that file does not exist.
String _readFileContent(File file) {
  return file.existsSync() ? file.readAsStringSync() : null;
}

/// Creates [symlinkDirectory] containing symlinks to each plugin listed in [platformPlugins].
///
/// If [force] is true, the directory will be created only if missing.
void _createPlatformPluginSymlinks(
    Directory symlinkDirectory, List<Object> platformPlugins,
    {bool force = false}) {
  if (force && symlinkDirectory.existsSync()) {
    // Start fresh to avoid stale links.
    symlinkDirectory.deleteSync(recursive: true);
  }
  symlinkDirectory.createSync(recursive: true);
  if (platformPlugins == null) {
    return;
  }
  for (final Map<String, Object> pluginInfo
      in platformPlugins.cast<Map<String, Object>>()) {
    final String name = pluginInfo[_kFlutterPluginsNameKey] as String;
    final String path = pluginInfo[_kFlutterPluginsPathKey] as String;
    final Link link = symlinkDirectory.childLink(name);
    if (link.existsSync()) {
      continue;
    }
    try {
      link.createSync(path);
    } on FileSystemException catch (e) {
      handleSymlinkException(e, platform: globals.platform, os: globals.os);
      rethrow;
    }
  }
}
