/// libmpv rendering presets. Balanced leaves the engine's existing defaults
/// untouched; the other presets are applied before opening each video.
enum PictureQualityPreset {
  performance,
  balanced,
  quality;

  static PictureQualityPreset fromValue(Object? value) => switch (value) {
        'performance' => PictureQualityPreset.performance,
        'quality' => PictureQualityPreset.quality,
        _ => PictureQualityPreset.balanced,
      };

  static PictureQualityPreset fromSettings(Map<String, dynamic> settings) =>
      fromValue(settings['mpvQuality']);

  Map<String, String> get mpvProperties => switch (this) {
        PictureQualityPreset.performance => const {
            'scale': 'bilinear',
            'cscale': 'bilinear',
            'dscale': 'bilinear',
            'deband': 'no',
            'dither': 'no',
          },
        PictureQualityPreset.balanced => const {},
        PictureQualityPreset.quality => const {
            'scale': 'ewa_lanczossharp',
            'cscale': 'ewa_lanczossharp',
            'dscale': 'mitchell',
            'deband': 'yes',
            'deband-iterations': '2',
            'dither-depth': 'auto',
          },
      };
}
