#include "include/native_texture_view/native_texture_view_plugin.h"

#include <flutter/plugin_registrar.h>
#include <flutter_elinux.h>
#include <flutter_platform_views.h>

#include "native_texture_view_factory.h"

namespace {
class NativeTextureViewPlugin : public flutter::Plugin {
public:
  static void RegisterWithRegistrar(flutter::PluginRegistrar *registrar) {
    auto plugin = std::make_unique<NativeTextureViewPlugin>();
    registrar->AddPlugin(std::move(plugin));
  }

  NativeTextureViewPlugin() {}

  virtual ~NativeTextureViewPlugin() {}
};
} // namespace

void NativeTextureViewPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter::PluginRegistrar *plugin_registrar =
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrar>(registrar);

  NativeTextureViewPlugin::RegisterWithRegistrar(plugin_registrar);
  FlutterDesktopRegisterPlatformViewFactory(
      registrar, "plugins.flutter.io/native_texture_view",
      std::make_unique<NativeTextureViewFactory>(plugin_registrar));
}
