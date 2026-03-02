import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:matrix_gesture_detector/matrix_gesture_detector.dart';
import '../../utils/app_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/cloudinary_service.dart';
import '../../widgets/banner_display.dart';

/// Full-screen banner editor.
///
/// Returns a [Map<String, dynamic>] (the bannerData) when the user taps Save,
/// or null when the user cancels.
class BannerEditorScreen extends StatefulWidget {
  const BannerEditorScreen({
    super.key,
    this.initialData,
    this.defaultColors = const [Color(0xFF6A11CB), Color(0xFF2575FC)],
  });

  final Map<String, dynamic>? initialData;
  final List<Color> defaultColors;

  @override
  State<BannerEditorScreen> createState() => _BannerEditorScreenState();
}

class _BannerEditorScreenState extends State<BannerEditorScreen> {
  // ─── Mode ──────────────────────────────────────────────────────────────────
  String _mode = 'text'; // 'image' | 'text'

  // ─── Text options ──────────────────────────────────────────────────────────
  final TextEditingController _textCtrl = TextEditingController();
  String _fontKey = 'default';
  Color _textColor = Colors.white;
  double _fontSize = 28;
  int _gradientIndex = 0;
  String _animation = 'none';
  String _textStyle = 'bold';
  double _animationSpeed = 1.0;
  Matrix4 _textMatrix = Matrix4.identity();

  // ─── Image options ─────────────────────────────────────────────────────────
  File? _imageFile;
  Uint8List? _imageBytes;
  String? _uploadedImageUrl;
  bool _isUploading = false;

  final _cloudinary = CloudinaryService();
  final _picker = ImagePicker();

  // ─── Gradient presets ──────────────────────────────────────────────────────
  static const _gradients = <List<Color>>[
    [Color(0xFF6A11CB), Color(0xFF2575FC)],
    [Color(0xFFFF416C), Color(0xFFFF4B2B)],
    [Color(0xFF000428), Color(0xFF004E92)],
    [Color(0xFF093637), Color(0xFF0D7377)],
    [Color(0xFF1a1a2e), Color(0xFFe43396)],
    [Color(0xFF11998e), Color(0xFF38ef7d)],
    [Color(0xFFf12711), Color(0xFFf5af19)],
    [Color(0xFF654ea3), Color(0xFFeaafc8)],
    [Color(0xFF0F2027), Color(0xFF2C5364)],
    [Color(0xFFDA4453), Color(0xFF89216B)],
    [Color(0xFF0B132B), Color(0xFF6FFFE9)],
    [Color(0xFFFC466B), Color(0xFF3F5EFB)],
    [Color(0xFF30CFD0), Color(0xFF330867)],
    [Color(0xFFFF9966), Color(0xFFFF5E62)],
    [Color(0xFF56CCF2), Color(0xFF2F80ED)],
    [Color(0xFF00C6FF), Color(0xFF0072FF)],
    [Color(0xFFF4D03F), Color(0xFF16A085)],
    [Color(0xFF667EEA), Color(0xFF764BA2)],
    [Color(0xFFFF0844), Color(0xFFFFB199)],
    [Color(0xFF200122), Color(0xFF6F0000)],
  ];

  // ─── Font options ──────────────────────────────────────────────────────────
  static const _fontOptions = [
    ('default', 'Default'),
    ('pacifico', 'Pacifico'),
    ('dancing', 'Dancing'),
    ('oswald', 'Oswald'),
    ('lexend', 'Lexend'),
    ('playfair', 'Playfair'),
    ('lobster', 'Lobster'),
    ('raleway', 'Raleway'),
    ('mono', 'Mono'),
    ('caveat', 'Caveat'),
    ('satisfy', 'Satisfy'),
    ('righteous', 'Righteous'),
  ];

  // ─── Preset text colors ────────────────────────────────────────────────────
  static const _colorPresets = <Color>[
    Colors.white,
    Colors.yellow,
    Color(0xFFFFD700),
    Colors.cyanAccent,
    Color(0xFFFF6B6B),
    Colors.lightGreenAccent,
    Colors.orangeAccent,
    Colors.pinkAccent,
    Colors.black,
    Color(0xFF90CAF9),
  ];

  // ─── Animation options ─────────────────────────────────────────────────────
  static const _animations = [
    ('none', 'None', Icons.text_fields),
    ('pulse', 'Pulse', Icons.expand),
    ('fade', 'Fade', Icons.opacity),
    ('shimmer', 'Shimmer', Icons.auto_awesome),
    ('slide', 'Slide', Icons.swap_horiz),
    ('wave', 'Wave', Icons.waves),
    ('bounce', 'Bounce', Icons.arrow_upward),
    ('glow', 'Glow', Icons.flare),
    ('typewriter', 'Typewriter', Icons.keyboard),
    ('rotate', 'Rotate', Icons.rotate_right),
    ('float', 'Float', Icons.air),
    ('flicker', 'Flicker', Icons.bolt),
  ];

  static const _textStyles = [
    ('bold', 'Bold', Icons.text_fields_rounded),
    ('neon', 'Neon', Icons.flash_on_rounded),
    ('outline', 'Outline', Icons.border_color_rounded),
    ('glass', 'Glass', Icons.blur_on_rounded),
    ('shadow', 'Shadow', Icons.layers_rounded),
  ];

  @override
  void initState() {
    super.initState();

    // load initial data
    final d = widget.initialData;
    if (d != null) {
      _mode = (d['type'] as String?) ?? 'text';
      _textCtrl.text = (d['text'] as String?) ?? '';
      _fontKey = (d['fontKey'] as String?) ?? 'default';
      final tc = d['textColor'];
      if (tc != null) _textColor = Color(tc as int);
      _fontSize = (d['fontSize'] as num?)?.toDouble() ?? 28.0;
      _gradientIndex = (d['gradientIndex'] as int?) ?? 0;
      _animation = (d['animation'] as String?) ?? 'none';
      _textStyle = (d['textStyle'] as String?) ?? 'bold';
      _animationSpeed =
          ((d['animationSpeed'] as num?)?.toDouble() ?? 1.0).clamp(0.6, 2.2);
      _uploadedImageUrl = d['imageUrl'] as String?;
      _textMatrix = _matrixFromDynamic(d['textMatrix']);
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  // ─── Current preview data ──────────────────────────────────────────────────

  Map<String, dynamic> get _previewData {
    if (_mode == 'image') {
      return {
        'type': 'image',
        'imageUrl': _uploadedImageUrl ?? '',
        'gradientIndex': _gradientIndex,
      };
    }
    return {
      'type': 'text',
      'text': _textCtrl.text,
      'fontKey': _fontKey,
      'textColor': _textColor.value, // ignore: deprecated_member_use
      'fontSize': _fontSize,
      'gradientIndex': _gradientIndex,
      'animation': _animation,
      'textStyle': _textStyle,
      'animationSpeed': _animationSpeed,
      'textMatrix': _textMatrix.storage.toList(),
    };
  }

  // ─── Image picker ─────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final xfile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (xfile == null) return;

    if (kIsWeb) {
      final bytes = await xfile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _uploadedImageUrl = null; // will upload on save
      });
    } else {
      setState(() {
        _imageFile = File(xfile.path);
        _uploadedImageUrl = null;
      });
    }
  }

  Future<String?> _uploadBannerImage() async {
    setState(() => _isUploading = true);
    try {
      String? url;
      if (kIsWeb && _imageBytes != null) {
        url = await _cloudinary.uploadImageBytes(
          _imageBytes!,
          folder: 'banners',
        );
      } else if (!kIsWeb && _imageFile != null) {
        url = await _cloudinary.uploadImage(
          _imageFile!,
          folder: 'banners',
        );
      }
      return url;
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // ─── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_mode == 'image' &&
        (_imageFile != null || _imageBytes != null) &&
        _uploadedImageUrl == null) {
      final url = await _uploadBannerImage();
      if (url == null) {
        if (!mounted) return;
        AppDialog.error(context, 'Image upload failed — please try again');
        return;
      }
      _uploadedImageUrl = url;
    }

    if (!mounted) return;
    Navigator.pop(context, _previewData);
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  TextStyle _fontPreviewStyle(String key) {
    const base = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
    switch (key) {
      case 'pacifico':
        return GoogleFonts.pacifico(textStyle: base);
      case 'dancing':
        return GoogleFonts.dancingScript(textStyle: base);
      case 'oswald':
        return GoogleFonts.oswald(textStyle: base);
      case 'lexend':
        return GoogleFonts.lexend(textStyle: base);
      case 'playfair':
        return GoogleFonts.playfairDisplay(textStyle: base);
      case 'lobster':
        return GoogleFonts.lobster(textStyle: base);
      case 'raleway':
        return GoogleFonts.raleway(textStyle: base);
      case 'mono':
        return GoogleFonts.spaceMono(textStyle: base);
      case 'caveat':
        return GoogleFonts.caveat(textStyle: base);
      case 'satisfy':
        return GoogleFonts.satisfy(textStyle: base);
      case 'righteous':
        return GoogleFonts.righteous(textStyle: base);
      default:
        return base;
    }
  }

  Matrix4 _matrixFromDynamic(dynamic raw) {
    if (raw is List && raw.length == 16) {
      final values = <double>[];
      for (final v in raw) {
        if (v is num) {
          values.add(v.toDouble());
        } else {
          return Matrix4.identity();
        }
      }
      return Matrix4.fromList(values);
    }
    return Matrix4.identity();
  }

  void _applyTextTransform(
    Matrix4 translationDelta,
    Matrix4 scaleDelta,
    Matrix4 rotationDelta,
  ) {
    setState(() {
      _textMatrix = MatrixGestureDetector.compose(
        _textMatrix,
        translationDelta,
        scaleDelta,
        rotationDelta,
      );
    });
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Edit Banner',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isUploading ? null : _save,
            child: const Text('Save',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Live preview ──
          _buildPreview(),

          // ── Mode tabs ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'text',
                    label: Text('Text'),
                    icon: Icon(Icons.text_fields)),
                ButtonSegment(
                    value: 'image',
                    label: Text('Image'),
                    icon: Icon(Icons.image)),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>((s) {
                  if (s.contains(WidgetState.selected)) {
                    return const Color(0xFF6A11CB);
                  }
                  return Colors.white;
                }),
                foregroundColor: WidgetStateProperty.resolveWith<Color>((s) {
                  if (s.contains(WidgetState.selected)) return Colors.white;
                  return const Color(0xFF6A11CB);
                }),
              ),
            ),
          ),

          // ── Editor options ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child:
                  _mode == 'text' ? _buildTextOptions() : _buildImageOptions(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Preview section ──────────────────────────────────────────────────────

  Widget _buildPreview() {
    final imgAvailable = _imageBytes != null || _imageFile != null;
    // Build a temporary preview data that uses local bytes if available
    Map<String, dynamic> previewData = _previewData;
    if (_mode == 'image' && imgAvailable && _uploadedImageUrl == null) {
      // Show local image as gradient (can't use byte URL in BannerDisplay)
      previewData = {'type': 'none', 'gradientIndex': _gradientIndex};
    } else if (_mode == 'text') {
      // Interactive text is rendered by BannerDisplay using textMatrix;
      // preview always remains in text mode.
      previewData = {
        ...previewData,
        'type': 'text',
        'textMatrix': _textMatrix.storage.toList(),
      };
    }

    return Stack(
      children: [
        // Gradient/text banner preview
        BannerDisplay(
          bannerData: previewData,
          defaultColors: widget.defaultColors,
          height: 180,
        ),

        // If image mode and local bytes — overlay the actual image
        if (_mode == 'image' && imgAvailable)
          Positioned.fill(
            child: kIsWeb && _imageBytes != null
                ? Image.memory(_imageBytes!, fit: BoxFit.cover, height: 180)
                : _imageFile != null
                    ? Image.file(_imageFile!, fit: BoxFit.cover, height: 180)
                    : const SizedBox(),
          ),

        // Gesture layer: move / scale / rotate text while keeping JSON editable.
        if (_mode == 'text')
          Positioned.fill(
            child: MatrixGestureDetector(
              clipChild: false,
              onMatrixUpdate: (_, td, sd, rd) =>
                  _applyTextTransform(td, sd, rd),
              child: Container(color: Colors.transparent),
            ),
          ),

        // Preview label
        const Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black26,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Preview',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Text options ─────────────────────────────────────────────────────────

  Widget _buildTextOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Text input
        _sectionLabel('Banner Text'),
        TextField(
          controller: _textCtrl,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Type your banner text…',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          maxLength: 60,
          maxLines: 2,
        ),
        const SizedBox(height: 16),

        // Font picker
        _sectionLabel('Font'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _fontOptions.map((opt) {
              final (key, label) = opt;
              final selected = _fontKey == key;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _fontKey = key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF6A11CB) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF6A11CB)
                            : Colors.grey[300]!,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                  color: const Color(0xFF6A11CB)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 8)
                            ]
                          : [],
                    ),
                    child: Text(
                      label,
                      style: _fontPreviewStyle(key).copyWith(
                        color: selected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Text color
        _sectionLabel('Text Color'),
        _buildColorPicker(),
        const SizedBox(height: 16),

        // Text style
        _sectionLabel('Text Style'),
        _buildTextStylePicker(),
        const SizedBox(height: 16),

        // Font size slider
        _sectionLabel('Size: ${_fontSize.round()}px'),
        Slider(
          value: _fontSize,
          min: 16,
          max: 56,
          divisions: 20,
          activeColor: const Color(0xFF6A11CB),
          onChanged: (v) => setState(() => _fontSize = v),
        ),
        const SizedBox(height: 16),

        // Background gradient
        _sectionLabel('Background'),
        _buildGradientPicker(),
        const SizedBox(height: 16),

        // Animation
        _sectionLabel('Text Animation'),
        _buildAnimationPicker(),
        const SizedBox(height: 16),
        _sectionLabel(
            'Animation Speed: ${_animationSpeed.toStringAsFixed(1)}x'),
        Slider(
          value: _animationSpeed,
          min: 0.6,
          max: 2.2,
          divisions: 16,
          activeColor: const Color(0xFF6A11CB),
          onChanged: (v) => setState(() => _animationSpeed = v),
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _textMatrix = Matrix4.identity()),
                icon: const Icon(Icons.replay_rounded, size: 18),
                label: const Text('Reset Text Position'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6A11CB),
                  side: const BorderSide(color: Color(0xFF6A11CB)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Tip: Drag to move, pinch to zoom, and rotate with two fingers on the preview.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─── Image options ────────────────────────────────────────────────────────

  Widget _buildImageOptions() {
    final hasLocal = _imageBytes != null || _imageFile != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // Pick image button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.add_photo_alternate_rounded),
            label: Text(hasLocal || _uploadedImageUrl != null
                ? 'Choose Different Image'
                : 'Choose from Gallery'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A11CB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 12),

        if (hasLocal || _uploadedImageUrl != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasLocal
                        ? 'Image selected — tap Save to apply'
                        : 'Current banner image loaded',
                    style: const TextStyle(
                        color: Colors.green, fontWeight: FontWeight.w500),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    _imageFile = null;
                    _imageBytes = null;
                    _uploadedImageUrl = null;
                  }),
                  child: const Icon(Icons.close, color: Colors.red, size: 18),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),
        _sectionLabel('Background (if image fails to load)'),
        _buildGradientPicker(),
        const SizedBox(height: 24),

        // Info tip
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_rounded, color: Colors.blue, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'For best results, use a wide landscape image '
                  '(at least 800 × 200 px). The image will be cropped '
                  'to fill the banner area.',
                  style: TextStyle(fontSize: 13, color: Colors.blueGrey),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─── Color picker ────────────────────────────────────────────────────────

  Widget _buildColorPicker() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ..._colorPresets.map((c) {
          final selected = _textColor == c;
          final tickColor =
              c.computeLuminance() > 0.6 ? Colors.black87 : Colors.white;
          return GestureDetector(
            onTap: () => setState(() => _textColor = c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? const Color(0xFF6A11CB) : Colors.grey[300]!,
                  width: selected ? 3 : 1.5,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                            color: c.withValues(alpha: 0.5), blurRadius: 6)
                      ]
                    : [],
              ),
              child: selected
                  ? Icon(Icons.check_rounded, color: tickColor, size: 16)
                  : null,
            ),
          );
        }),
        // Custom color
        GestureDetector(
          onTap: _pickCustomColor,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const SweepGradient(colors: [
                Colors.red,
                Colors.yellow,
                Colors.green,
                Colors.cyan,
                Colors.blue,
                Colors.purple,
                Colors.red,
              ]),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[300]!, width: 1.5),
            ),
            child: const Icon(Icons.colorize_rounded,
                color: Colors.white, size: 16),
          ),
        ),
      ],
    );
  }

  Future<void> _pickCustomColor() async {
    var current = HSVColor.fromColor(_textColor);
    final picked = await showModalBottomSheet<Color>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final color = current.toColor();
            return SafeArea(
              child: Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FF),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 5,
                      width: 56,
                      decoration: BoxDecoration(
                        color: Colors.grey[350],
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withValues(alpha: 0.92),
                            color.withValues(alpha: 0.64),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '#${_toHexRgb(color)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const Text(
                            'Live',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _colorSliderRow(
                      label: 'Hue',
                      value: current.hue,
                      min: 0,
                      max: 360,
                      activeColor: color,
                      onChanged: (v) => setSheet(
                        () => current = current.withHue(v),
                      ),
                    ),
                    _colorSliderRow(
                      label: 'Saturation',
                      value: current.saturation,
                      min: 0,
                      max: 1,
                      activeColor: color,
                      onChanged: (v) => setSheet(
                        () => current = current.withSaturation(v),
                      ),
                    ),
                    _colorSliderRow(
                      label: 'Brightness',
                      value: current.value,
                      min: 0,
                      max: 1,
                      activeColor: color,
                      onChanged: (v) => setSheet(
                        () => current = current.withValue(v),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF6A11CB),
                                side:
                                    const BorderSide(color: Color(0xFF6A11CB)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, color),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6A11CB),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Apply Color'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (picked != null) setState(() => _textColor = picked);
  }

  String _toHexRgb(Color color) {
    int to8(num channel) {
      final value = channel <= 1 ? (channel * 255.0) : channel.toDouble();
      return value.round().clamp(0, 255);
    }

    final r = to8(color.r).toRadixString(16).padLeft(2, '0');
    final g = to8(color.g).toRadixString(16).padLeft(2, '0');
    final b = to8(color.b).toRadixString(16).padLeft(2, '0');
    return '$r$g$b'.toUpperCase();
  }

  Widget _colorSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required Color activeColor,
    required ValueChanged<double> onChanged,
  }) {
    final normalized = (value - min) / (max - min);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3B3E5A),
                ),
              ),
              const Spacer(),
              Text(
                '${(normalized * 100).round()}%',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: activeColor,
              inactiveTrackColor: activeColor.withValues(alpha: 0.18),
              thumbColor: activeColor,
              overlayColor: activeColor.withValues(alpha: 0.15),
              trackHeight: 4,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Gradient picker ──────────────────────────────────────────────────────

  Widget _buildGradientPicker() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_gradients.length, (i) {
          final selected = _gradientIndex == i;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => setState(() => _gradientIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 72,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: _gradients[i],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? Colors.white : Colors.transparent,
                    width: 2.5,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                              color: _gradients[i][0].withValues(alpha: 0.5),
                              blurRadius: 8)
                        ]
                      : [],
                ),
                child: selected
                    ? const Center(
                        child: Icon(Icons.check_rounded,
                            color: Colors.white, size: 18))
                    : null,
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── Animation picker ──────────────────────────────────────────────────────

  Widget _buildTextStylePicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _textStyles.map((opt) {
        final (key, label, icon) = opt;
        final selected = _textStyle == key;
        return GestureDetector(
          onTap: () => setState(() => _textStyle = key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                      colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: selected ? null : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? Colors.transparent : Colors.grey[300]!,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF6A11CB).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? Colors.white : Colors.grey[700],
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAnimationPicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _animations.map((opt) {
        final (key, label, icon) = opt;
        final selected = _animation == key;
        return GestureDetector(
          onTap: () => setState(() => _animation = key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF6A11CB) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? const Color(0xFF6A11CB) : Colors.grey[300]!,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                          color: const Color(0xFF6A11CB).withValues(alpha: 0.3),
                          blurRadius: 6)
                    ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 16,
                    color: selected ? Colors.white : Colors.grey[600]),
                const SizedBox(width: 5),
                Text(label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    )),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Color(0xFF444466))),
      );
}
