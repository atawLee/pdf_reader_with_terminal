import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

class OcrService {
  static const _channel = MethodChannel('bookapp/ocr');

  /// Renders the given [pageNumber] (1-based) of the PDF at [filePath] and
  /// sends the image to the Windows platform OCR engine.
  static Future<String> recognizePage(String filePath, int pageNumber) async {
    final doc = await PdfDocument.openFile(filePath);
    try {
      final page = doc.pages[pageNumber - 1];

      // Render at 2x for better OCR accuracy.
      const scale = 2.0;
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

      // Encode to PNG for the native side.
      final uiImage = await pdfImage.createImage();
      pdfImage.dispose();

      final byteData =
          await uiImage.toByteData(format: ui.ImageByteFormat.png);
      uiImage.dispose();

      if (byteData == null) {
        throw Exception('Failed to encode page image to PNG');
      }

      final pngBytes = byteData.buffer.asUint8List();

      final result = await _channel.invokeMethod<String>('recognize', {
        'imageBytes': pngBytes,
      });

      return result ?? '';
    } finally {
      await doc.dispose();
    }
  }
}
