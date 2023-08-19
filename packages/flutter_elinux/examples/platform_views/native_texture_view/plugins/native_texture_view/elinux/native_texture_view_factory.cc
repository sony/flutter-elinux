#include "native_texture_view_factory.h"

#include "native_texture_view.h"

NativeTextureViewFactory::NativeTextureViewFactory(
    flutter::PluginRegistrar *registrar)
    : FlutterDesktopPlatformViewFactory(registrar) {
  texture_registrar_ = registrar->texture_registrar();
}

FlutterDesktopPlatformView *
NativeTextureViewFactory::Create(int view_id, double width, double height,
                                 const std::vector<uint8_t> &params) {
  return new NativeTextureView(GetPluginRegistrar(), view_id,
                               texture_registrar_, width, height, params);
}

void NativeTextureViewFactory::Dispose() {}
