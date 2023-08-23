#ifndef FLUTTER_PLUGIN_NATIVE_TEXTURE_VIEW_FACTORY_H_
#define FLUTTER_PLUGIN_NATIVE_TEXTURE_VIEW_FACTORY_H_

#include <flutter/plugin_registrar.h>
#include <flutter/texture_registrar.h>
#include <flutter_platform_views.h>

#include <vector>

class NativeTextureViewFactory : public FlutterDesktopPlatformViewFactory {
public:
  NativeTextureViewFactory(flutter::PluginRegistrar *registrar);

  virtual FlutterDesktopPlatformView *
  Create(int view_id, double width, double height,
         const std::vector<uint8_t> &params) override;

  virtual void Dispose() override;

private:
  flutter::TextureRegistrar *texture_registrar_ = nullptr;
};

#endif // FLUTTER_PLUGIN_NATIVE_TEXTURE_VIEW_FACTORY_H_
