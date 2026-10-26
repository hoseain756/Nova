import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/features/player/engine/picture_quality.dart';

void main() {
  test('unknown and missing quality settings preserve native defaults', () {
    expect(
        PictureQualityPreset.fromSettings({}), PictureQualityPreset.balanced);
    expect(PictureQualityPreset.fromValue('unexpected'),
        PictureQualityPreset.balanced);
    expect(PictureQualityPreset.balanced.mpvProperties, isEmpty);
  });

  test('mobile libmpv presets select lighter or sharper processing', () {
    expect(PictureQualityPreset.fromValue('performance').mpvProperties,
        containsPair('scale', 'bilinear'));
    expect(PictureQualityPreset.fromValue('performance').mpvProperties,
        containsPair('deband', 'no'));
    expect(PictureQualityPreset.fromValue('quality').mpvProperties,
        containsPair('scale', 'ewa_lanczossharp'));
    expect(PictureQualityPreset.fromValue('quality').mpvProperties,
        containsPair('deband', 'yes'));
  });
}
