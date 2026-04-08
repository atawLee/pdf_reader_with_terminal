// Override _HAS_EXCEPTIONS before any includes so C++/WinRT works correctly.
#pragma push_macro("_HAS_EXCEPTIONS")
#undef _HAS_EXCEPTIONS
#define _HAS_EXCEPTIONS 1

#include "ocr_handler.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Graphics.Imaging.h>
#include <winrt/Windows.Media.Ocr.h>
#include <winrt/Windows.Storage.Streams.h>

#pragma pop_macro("_HAS_EXCEPTIONS")

#include <memory>
#include <string>
#include <thread>
#include <vector>

using namespace winrt;
using namespace Windows::Foundation;
using namespace Windows::Graphics::Imaging;
using namespace Windows::Media::Ocr;
using namespace Windows::Storage::Streams;

namespace {

std::string PerformOcr(const std::vector<uint8_t>& png_bytes) {
  init_apartment(apartment_type::multi_threaded);

  // Write PNG bytes into an in-memory stream.
  InMemoryRandomAccessStream stream;
  DataWriter writer(stream);
  writer.WriteBytes(
      array_view<const uint8_t>(png_bytes.data(),
                                static_cast<uint32_t>(png_bytes.size())));
  writer.StoreAsync().get();
  writer.DetachStream();
  stream.Seek(0);

  // Decode to SoftwareBitmap.
  auto decoder = BitmapDecoder::CreateAsync(stream).get();
  auto bitmap = decoder.GetSoftwareBitmapAsync().get();

  // OcrEngine requires Bgra8 / Premultiplied.
  if (bitmap.BitmapPixelFormat() != BitmapPixelFormat::Bgra8 ||
      bitmap.BitmapAlphaMode() != BitmapAlphaMode::Premultiplied) {
    bitmap = SoftwareBitmap::Convert(bitmap, BitmapPixelFormat::Bgra8,
                                     BitmapAlphaMode::Premultiplied);
  }

  // Create OCR engine from the user's profile languages.
  auto engine = OcrEngine::TryCreateFromUserProfileLanguages();
  if (!engine) {
    return "[OCR engine not available - check Windows language packs]";
  }

  auto result = engine.RecognizeAsync(bitmap).get();
  return to_string(result.Text());
}

}  // namespace

void RegisterOcrChannel(flutter::FlutterEngine* engine) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      engine->messenger(), "bookapp/ocr",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name() != "recognize") {
          result->NotImplemented();
          return;
        }

        const auto* args =
            std::get_if<flutter::EncodableMap>(call.arguments());
        if (!args) {
          result->Error("INVALID_ARGS", "Expected map arguments");
          return;
        }

        auto bytes_it =
            args->find(flutter::EncodableValue("imageBytes"));
        if (bytes_it == args->end()) {
          result->Error("INVALID_ARGS", "Missing imageBytes");
          return;
        }

        const auto* png_bytes =
            std::get_if<std::vector<uint8_t>>(&bytes_it->second);
        if (!png_bytes || png_bytes->empty()) {
          result->Error("INVALID_ARGS", "imageBytes is empty or wrong type");
          return;
        }

        // Move result & data to a background thread so the UI stays responsive.
        auto shared_result =
            std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(
                std::move(result));
        auto data = *png_bytes;

        std::thread([shared_result,
                     data = std::move(data)]() {
          try {
            auto text = PerformOcr(data);
            shared_result->Success(flutter::EncodableValue(text));
          } catch (const hresult_error& e) {
            shared_result->Error("OCR_ERROR", to_string(e.message()));
          } catch (const std::exception& e) {
            shared_result->Error("OCR_ERROR", e.what());
          } catch (...) {
            shared_result->Error("OCR_ERROR", "Unknown OCR error");
          }
        }).detach();
      });
}
