/// Configuration model for DiceBear avatar generation.
///
/// Stores style + seed + color choices.  The [url] getter builds the
/// correct DiceBear v9 API URL from these values.
class DiceBearConfig {
  static const String _base = 'https://api.dicebear.com/9.x';

  // ── Styles ──────────────────────────────────────────────────────────────
  static const List<Map<String, String>> styles = [
    {'id': 'adventurer',        'label': 'Adventurer'},
    {'id': 'avataaars',         'label': 'Avataaars'},
    {'id': 'micah',             'label': 'Micah'},
    {'id': 'lorelei',           'label': 'Lorelei'},
    {'id': 'big-ears',          'label': 'Big Ears'},
    {'id': 'pixel-art',         'label': 'Pixel Art'},
    {'id': 'notionists-neutral','label': 'Notionists'},
    {'id': 'croodles',          'label': 'Croodles'},
  ];

  // ── Skin colours (hex, no #) ─────────────────────────────────────────────
  static const List<String> skinColors = [
    '614335', // very dark
    'ae5d29', // dark
    'd78774', // medium
    'ecad80', // tan
    'f2d3b1', // light
    'fbd9b5', // very light
  ];

  // ── Hair colours (hex, no #) ─────────────────────────────────────────────
  static const List<String> hairColors = [
    '0e0e0e', // black
    '3d2214', // very dark brown
    '6d4c41', // dark brown
    'a55728', // brown
    'b58143', // auburn
    'd6b370', // blonde
    'f9f9f9', // white / grey
    'c8102e', // red
    'e91e63', // pink
    '7b68ee', // purple
  ];

  // ── Background colours (hex, no #) ───────────────────────────────────────
  static const List<String> bgColors = [
    'b6e3f4', // sky blue
    'c0aede', // lavender
    'd1d4f9', // periwinkle
    'ffd5dc', // pink
    'ffdfbf', // peach
    'c8e6c9', // light green
    'fff9c4', // yellow
    'e0e0e0', // grey
  ];

  // ── Fields ───────────────────────────────────────────────────────────────
  final String style;
  final String seed;
  final String backgroundColor;
  final String? skinColor;
  final String? hairColor;

  const DiceBearConfig({
    this.style = 'adventurer',
    required this.seed,
    this.backgroundColor = 'b6e3f4',
    this.skinColor,
    this.hairColor,
  });

  // ── URL builder ──────────────────────────────────────────────────────────
  String get url {
    final params = <String, String>{
      'seed': seed,
      'size': '256',
      'backgroundColor': backgroundColor,
    };
    if (skinColor != null) params['skinColor'] = skinColor!;
    if (hairColor != null) params['hairColor'] = hairColor!;
    final query = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return '$_base/$style/png?$query';
  }

  // ── Serialisation ────────────────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
        'type': 'dicebear',
        'style': style,
        'seed': seed,
        'backgroundColor': backgroundColor,
        if (skinColor != null) 'skinColor': skinColor!,
        if (hairColor != null) 'hairColor': hairColor!,
      };

  factory DiceBearConfig.fromMap(Map<String, dynamic> map) => DiceBearConfig(
        style: (map['style'] as String?) ?? 'adventurer',
        seed: (map['seed'] as String?) ?? 'user',
        backgroundColor: (map['backgroundColor'] as String?) ?? 'b6e3f4',
        skinColor: map['skinColor'] as String?,
        hairColor: map['hairColor'] as String?,
      );

  DiceBearConfig copyWith({
    String? style,
    String? seed,
    String? backgroundColor,
    String? skinColor,
    String? hairColor,
  }) =>
      DiceBearConfig(
        style: style ?? this.style,
        seed: seed ?? this.seed,
        backgroundColor: backgroundColor ?? this.backgroundColor,
        skinColor: skinColor ?? this.skinColor,
        hairColor: hairColor ?? this.hairColor,
      );

  /// Returns true when a config map is DiceBear-format.
  static bool isDiceBear(Map<String, dynamic>? map) =>
      map != null && map['type'] == 'dicebear';

  @override
  String toString() => 'DiceBearConfig(style: $style, seed: $seed)';
}
