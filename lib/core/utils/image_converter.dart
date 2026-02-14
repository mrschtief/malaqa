import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

import '../../domain/interfaces/biometric_scanner.dart';

class ImageConverter {
  static img.Image? cameraImageToImage({
    required CameraImage image,
    required int rotationDegrees,
  }) {
    final rawImage = switch (image.format.group) {
      ImageFormatGroup.yuv420 => _convertYuv420(image),
      ImageFormatGroup.bgra8888 => _convertBgra8888(image),
      _ => null,
    };

    if (rawImage == null) {
      return null;
    }
    final normalizedRotation = ((rotationDegrees % 360) + 360) % 360;
    if (normalizedRotation == 0) {
      return rawImage;
    }
    return img.copyRotate(rawImage, angle: normalizedRotation);
  }

  static img.Image? cropFace({
    required img.Image image,
    required FaceBounds faceBounds,
    double paddingFactor = 0.10,
  }) {
    if (faceBounds.width <= 0 || faceBounds.height <= 0) {
      return null;
    }

    final padX = faceBounds.width * paddingFactor;
    final padY = faceBounds.height * paddingFactor;

    final left = (faceBounds.left - padX).floor();
    final top = (faceBounds.top - padY).floor();
    final right = (faceBounds.right + padX).ceil();
    final bottom = (faceBounds.bottom + padY).ceil();

    final x = left.clamp(0, image.width - 1);
    final y = top.clamp(0, image.height - 1);
    final cropRight = right.clamp(x + 1, image.width);
    final cropBottom = bottom.clamp(y + 1, image.height);
    final width = cropRight - x;
    final height = cropBottom - y;

    if (width <= 0 || height <= 0) {
      return null;
    }

    return img.copyCrop(
      image,
      x: x,
      y: y,
      width: width,
      height: height,
    );
  }

  static Float32List preProcessFace(img.Image faceImage) {
    final resized = img.copyResize(
      faceImage,
      width: 112,
      height: 112,
      interpolation: img.Interpolation.linear,
    );

    final input = Float32List(112 * 112 * 3);
    var index = 0;
    for (var y = 0; y < 112; y++) {
      for (var x = 0; x < 112; x++) {
        final pixel = resized.getPixel(x, y);
        input[index++] = (pixel.r - 128.0) / 128.0;
        input[index++] = (pixel.g - 128.0) / 128.0;
        input[index++] = (pixel.b - 128.0) / 128.0;
      }
    }
    return input;
  }

  static img.Image? _convertBgra8888(CameraImage image) {
    if (image.planes.isEmpty) {
      return null;
    }

    final plane = image.planes.first;
    final bytes = plane.bytes;
    final bytesPerRow = plane.bytesPerRow;
    final converted = img.Image(
      width: image.width,
      height: image.height,
      numChannels: 4,
    );

    for (var y = 0; y < image.height; y++) {
      final rowOffset = y * bytesPerRow;
      for (var x = 0; x < image.width; x++) {
        final pixelOffset = rowOffset + (x * 4);
        if (pixelOffset + 3 >= bytes.length) {
          continue;
        }
        final b = bytes[pixelOffset];
        final g = bytes[pixelOffset + 1];
        final r = bytes[pixelOffset + 2];
        final a = bytes[pixelOffset + 3];
        converted.setPixelRgba(x, y, r, g, b, a);
      }
    }

    return converted;
  }

  static img.Image? _convertYuv420(CameraImage image) {
    if (image.planes.length < 3) {
      return null;
    }

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;

    final converted = img.Image(
      width: image.width,
      height: image.height,
    );

    for (var y = 0; y < image.height; y++) {
      final yRowOffset = y * yPlane.bytesPerRow;
      final uvRowOffset = (y >> 1) * uvRowStride;
      for (var x = 0; x < image.width; x++) {
        final yIndex = yRowOffset + x;
        final uvIndex = uvRowOffset + ((x >> 1) * uvPixelStride);

        if (yIndex >= yPlane.bytes.length ||
            uvIndex >= uPlane.bytes.length ||
            uvIndex >= vPlane.bytes.length) {
          continue;
        }

        final yp = yPlane.bytes[yIndex].toDouble();
        final up = uPlane.bytes[uvIndex].toDouble();
        final vp = vPlane.bytes[uvIndex].toDouble();

        final r = (yp + 1.402 * (vp - 128.0)).round().clamp(0, 255);
        final g = (yp - 0.344136 * (up - 128.0) - 0.714136 * (vp - 128.0))
            .round()
            .clamp(0, 255);
        final b = (yp + 1.772 * (up - 128.0)).round().clamp(0, 255);

        converted.setPixelRgba(x, y, r, g, b, 255);
      }
    }

    return converted;
  }
}
