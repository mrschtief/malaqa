import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:malaqa/malaqa.dart';

void main() {
  test('preProcessFace returns 112x112x3 normalized tensor', () {
    final source = img.Image(width: 2, height: 2);
    source.setPixelRgba(0, 0, 255, 128, 0, 255);
    source.setPixelRgba(1, 0, 255, 128, 0, 255);
    source.setPixelRgba(0, 1, 255, 128, 0, 255);
    source.setPixelRgba(1, 1, 255, 128, 0, 255);

    final tensor = ImageConverter.preProcessFace(source);

    expect(tensor.length, equals(112 * 112 * 3));
    expect(tensor[0], closeTo((255 - 128) / 128.0, 1e-6));
    expect(tensor[1], closeTo((128 - 128) / 128.0, 1e-6));
    expect(tensor[2], closeTo((0 - 128) / 128.0, 1e-6));
  });
}
