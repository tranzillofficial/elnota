import 'package:flutter/foundation.dart';
import 'package:imcodec/imcodec.dart' as img;

abstract class ProductImageService {
  static Future<Uint8List> compress(Uint8List bytes) =>
      compute(_compress, bytes);
  static Uint8List _compress(Uint8List bytes) {
    if (bytes.length > 10 * 1024 * 1024) {
      throw const FormatException('اختر صورة أصغر من 10 ميجابايت');
    }
    var image = switch (img.ImageFormat.sniff(bytes)) {
      img.ImageFormat.jpeg => img.decodeJpg(
        bytes,
        options: const img.JpegDecodeOptions(maxPixels: 24000000),
      ),
      img.ImageFormat.png => img.decodePng(
        bytes,
        options: const img.PngDecodeOptions(maxPixels: 24000000),
      ),
      img.ImageFormat.webp => img.decodeWebP(
        bytes,
        options: const img.WebPDecodeOptions(maxPixels: 24000000),
      ),
      _ => throw const FormatException('اختر صورة JPG أو PNG أو WebP'),
    };
    if (image.width > 960 || image.height > 960) {
      final scale =
          960 / (image.width > image.height ? image.width : image.height);
      image = _resize(
        image,
        (image.width * scale).round().clamp(1, 960),
        (image.height * scale).round().clamp(1, 960),
      );
    }
    var result = img.encodeWebP(
      image,
      options: const img.WebPEncodeOptions(quality: 80),
    );
    while (result.length > 512 * 1024 &&
        image.width > 160 &&
        image.height > 160) {
      image = _resize(
        image,
        (image.width * .75).round(),
        (image.height * .75).round(),
      );
      result = img.encodeWebP(
        image,
        options: const img.WebPEncodeOptions(quality: 72),
      );
    }
    if (result.length > 512 * 1024) {
      throw const FormatException('تعذر ضغط الصورة للحجم المناسب');
    }
    return result;
  }

  static img.Image _resize(img.Image source, int width, int height) {
    final output = img.Image(width: width, height: height);
    for (var y = 0; y < height; y++) {
      final sy = (y + .5) * source.height / height - .5;
      final y0 = sy.floor().clamp(0, source.height - 1),
          y1 = (y0 + 1).clamp(0, source.height - 1);
      final dy = (sy - y0).clamp(0.0, 1.0);
      for (var x = 0; x < width; x++) {
        final sx = (x + .5) * source.width / width - .5;
        final x0 = sx.floor().clamp(0, source.width - 1),
            x1 = (x0 + 1).clamp(0, source.width - 1);
        final dx = (sx - x0).clamp(0.0, 1.0);
        for (var channel = 0; channel < 4; channel++) {
          final top =
              source.bytes[(y0 * source.width + x0) * 4 + channel] * (1 - dx) +
              source.bytes[(y0 * source.width + x1) * 4 + channel] * dx;
          final bottom =
              source.bytes[(y1 * source.width + x0) * 4 + channel] * (1 - dx) +
              source.bytes[(y1 * source.width + x1) * 4 + channel] * dx;
          output.bytes[(y * width + x) * 4 + channel] =
              (top * (1 - dy) + bottom * dy).round().clamp(0, 255);
        }
      }
    }
    return output;
  }
}
