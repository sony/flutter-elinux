#include "native_texture_view.h"

namespace {

ColorBarTexture::ColorBarTexture() : request_count_(0) {
  constexpr size_t width = 1024;
  constexpr size_t height = 640;
  pixels_.reset(new uint8_t[width * height * 4]);

  buffer_ = std::make_unique<FlutterDesktopPixelBuffer>();
  buffer_->buffer = pixels_.get();
  buffer_->width = width;
  buffer_->height = height;
}

const FlutterDesktopPixelBuffer *ColorBarTexture::CopyBuffer(size_t width,
                                                             size_t height) {
  PrepareBuffer();
  request_count_++;
  return buffer_.get();
}

void ColorBarTexture::PrepareBuffer() {
  constexpr uint32_t kColorData[] = {0xFFFFFFFF, 0xFF00C0C0, 0xFFC0C000,
                                     0xFF00C000, 0xFFC000C0, 0xFF0000C0,
                                     0xFFC00000, 0xFF000000};
  auto data_num = sizeof(kColorData) / sizeof(uint32_t);

  auto *buffer = buffer_.get();
  auto pixel = const_cast<uint32_t *>(
      reinterpret_cast<const uint32_t *>(buffer->buffer));
  auto width = buffer->width;
  auto height = buffer->height;
  auto column_width = width / data_num;
  auto offset = request_count_ % 8;

  for (int i = 0; i < height; i++) {
    for (int j = 0; j < width; j++) {
      auto index = (j / column_width) + offset;
      index -= (index < data_num) ? 0 : data_num;
      *(pixel++) = kColorData[index];
    }
  }
}

} // namespace

NativeTextureView::NativeTextureView(
    flutter::PluginRegistrar *registrar, int view_id,
    flutter::TextureRegistrar *texture_registrar, double width, double height,
    const std::vector<uint8_t> &params)
    : FlutterDesktopPlatformView(registrar, view_id),
      texture_registrar_(texture_registrar), width_(width), height_(height) {
  color_bar_texture_ = std::make_unique<ColorBarTexture>();
  texture_ =
      std::make_unique<flutter::TextureVariant>(flutter::PixelBufferTexture(
          [this](size_t width,
                 size_t height) -> const FlutterDesktopPixelBuffer * {
            return color_bar_texture_->CopyBuffer(width, height);
          }));
  SetTextureId(texture_registrar_->RegisterTexture(texture_.get()));
}

NativeTextureView::~NativeTextureView() { Dispose(); }

void NativeTextureView::Dispose() {
  texture_registrar_->UnregisterTexture(GetTextureId());
}

void NativeTextureView::ClearFocus() {}

void NativeTextureView::Resize(double width, double height) {
  width_ = width;
  height_ = height;
}

void NativeTextureView::Touch(int device_id, int event_type, double x,
                              double y) {
  texture_registrar_->MarkTextureFrameAvailable(GetTextureId());
}

void NativeTextureView::Offset(double top, double left) {}
