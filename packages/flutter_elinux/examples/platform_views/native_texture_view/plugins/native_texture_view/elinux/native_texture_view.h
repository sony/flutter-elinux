#ifndef FLUTTER_PLUGIN_NATIVE_TEXTURE_VIEW_H_
#define FLUTTER_PLUGIN_NATIVE_TEXTURE_VIEW_H_

#include <flutter/plugin_registrar.h>
#include <flutter/texture_registrar.h>
#include <flutter_platform_views.h>

#include <memory>

namespace {
class ColorBarTexture {
public:
  ColorBarTexture();
  virtual ~ColorBarTexture() {}
  const FlutterDesktopPixelBuffer *CopyBuffer(size_t width, size_t height);

private:
  void PrepareBuffer();

  std::unique_ptr<FlutterDesktopPixelBuffer> buffer_;
  std::unique_ptr<uint8_t> pixels_;
  int32_t request_count_;
};
} // namespace

class NativeTextureView : public FlutterDesktopPlatformView {
public:
  NativeTextureView(flutter::PluginRegistrar *registrar, int view_id,
                    flutter::TextureRegistrar *texture_registrar, double width,
                    double height, const std::vector<uint8_t> &params);
  ~NativeTextureView();

  virtual void Dispose() override;

  virtual void ClearFocus() override;

  virtual void Resize(double width, double height) override;

  virtual void Touch(int device_id, int event_type, double x,
                     double y) override;

  virtual void Offset(double top, double left) override;

private:
  flutter::TextureRegistrar *texture_registrar_;
  std::unique_ptr<flutter::TextureVariant> texture_;
  std::unique_ptr<ColorBarTexture> color_bar_texture_;
  double width_;
  double height_;
};

#endif // FLUTTER_PLUGIN_NATIVE_TEXTURE_VIEW_H_
