import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

class OcrService {
  static const _channel = MethodChannel('bookapp/ocr');

  /// Renders the given [pageNumber] (1-based) of the PDF at [filePath] and
  /// sends the image to the Windows platform OCR engine.
  static Future<String> recognizePage(String filePath, int pageNumber) async {
    final pngBytes = await renderPageToPng(filePath, pageNumber);
    return recognizeFromBytes(pngBytes);
  }

  /// Render a PDF page to PNG bytes. Also returns the ui.Image via [onImage]
  /// if provided (caller must dispose it).
  static Future<Uint8List> renderPageToPng(
    String filePath,
    int pageNumber, {
    double scale = 2.0,
  }) async {
    final doc = await PdfDocument.openFile(filePath);
    try {
      final page = doc.pages[pageNumber - 1];
      final renderWidth = (page.width * scale).toInt();
      final renderHeight = (page.height * scale).toInt();

      final pdfImage = await page.render(
        fullWidth: page.width * scale,
        fullHeight: page.height * scale,
        width: renderWidth,
        height: renderHeight,
        backgroundColor: const ui.Color(0xFFFFFFFF),
      );

      if (pdfImage == null) {
        throw Exception('Failed to render page $pageNumber');
      }

      final uiImage = await pdfImage.createImage();
      pdfImage.dispose();

      final byteData =
          await uiImage.toByteData(format: ui.ImageByteFormat.png);
      uiImage.dispose();

      if (byteData == null) {
        throw Exception('Failed to encode page image to PNG');
      }

      return byteData.buffer.asUint8List();
    } finally {
      await doc.dispose();
    }
  }

  /// Send raw PNG bytes to the native OCR engine.
  static Future<String> recognizeFromBytes(Uint8List pngBytes) async {
    final result = await _channel.invokeMethod<String>('recognize', {
      'imageBytes': pngBytes,
    });
    return result ?? '';
  }

  /// Crop a [ui.Image] to [rect] and return PNG bytes.
  static Future<Uint8List> cropImageToPng(ui.Image image, Rect rect) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      image,
      rect,
      Rect.fromLTWH(0, 0, rect.width, rect.height),
      ui.Paint(),
    );
    final picture = recorder.endRecording();
    final cropped =
        await picture.toImage(rect.width.toInt(), rect.height.toInt());
    picture.dispose();

    final byteData =
        await cropped.toByteData(format: ui.ImageByteFormat.png);
    cropped.dispose();

    if (byteData == null) {
      throw Exception('Failed to encode cropped image');
    }
    return byteData.buffer.asUint8List();
  }
}
