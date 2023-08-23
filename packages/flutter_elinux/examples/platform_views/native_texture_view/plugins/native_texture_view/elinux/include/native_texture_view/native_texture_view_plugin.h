#ifndef FLUTTER_PLUGIN_NATIVE_TEXTURE_VIEW_PLUGIN_H_
#define FLUTTER_PLUGIN_NATIVE_TEXTURE_VIEW_PLUGIN_H_

#include <flutter_plugin_registrar.h>

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __attribute__((visibility("default")))
#else
#define FLUTTER_PLUGIN_EXPORT
#endif

#if defined(__cplusplus)
extern "C" {
#endif

FLUTTER_PLUGIN_EXPORT void NativeTextureViewPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

#if defined(__cplusplus)
} // extern "C"
#endif

#endif // FLUTTER_PLUGIN_NATIVE_TEXTURE_VIEW_PLUGIN_H_
