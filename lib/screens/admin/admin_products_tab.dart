import 'dart:convert';
import 'dart:async';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xls;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:super_clipboard/super_clipboard.dart';

import '../../models/product_model.dart';
import '../../models/user_model.dart';
import '../../services/cloudinary_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_dialog.dart';
import '../../utils/download_file.dart' as file_downloader;
import '../../utils/user_roles.dart';
import '../../utils/web_image_loader.dart';
import '../../utils/xlsx_embedded_image_parser.dart';
import '../../widgets/app_popup.dart';

class AdminProductsTab extends StatefulWidget {
  const AdminProductsTab({
    super.key,
    required this.firestoreService,
  });

  final FirestoreService firestoreService;

  @override
  State<AdminProductsTab> createState() => _AdminProductsTabState();
}

class _AdminProductsTabState extends State<AdminProductsTab> {
  static const Color _adminPrimary = Color(0xFF6A4CFF);
  static const Color _adminSecondary = Color(0xFF00B8D4);
  static const Color _adminRose = Color(0xFFFF5C8A);
  static const Color _adminSurface = Color(0xFFF8FAFF);

  final CloudinaryService _cloudinaryService = CloudinaryService();
  final ImagePicker _picker = ImagePicker();

  final _officialNameController = TextEditingController();
  final _officialDescController = TextEditingController();
  final _officialPriceController = TextEditingController();
  final _officialStockController = TextEditingController(text: '1');
  String _officialCategory = AppConstants.categories.first;
  String? _officialImageUrl;

  String? _adminLogoUrl;
  bool _isUploadingLogo = false;
  bool _isCreatingOfficial = false;
  bool _isBulkSubmitting = false;
  bool _isImportingBulk = false;
  _BulkImportSummary? _lastImportSummary;
  final List<_BulkImportSummary> _importHistory = [];

  List<UserModel> _skilledUsers = [];
  bool _isLoadingUsers = true;

  final List<_BulkProductDraft> _bulkDrafts = [_BulkProductDraft()];
  void Function(ClipboardReadEvent event)? _webPasteListener;

  @override
  void initState() {
    super.initState();
    _loadSkilledUsers();
    _loadAdminLogo();
    if (kIsWeb) {
      _configureWebPasteListener();
    }
  }

  @override
  void dispose() {
    _officialNameController.dispose();
    _officialDescController.dispose();
    _officialPriceController.dispose();
    _officialStockController.dispose();

    for (final draft in _bulkDrafts) {
      draft.dispose();
    }

    if (kIsWeb) {
      final events = ClipboardEvents.instance;
      if (_webPasteListener != null && events != null) {
        events.unregisterPasteEventListener(_webPasteListener!);
      }
    }

    super.dispose();
  }

  Widget _sectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _configureWebPasteListener() {
    if (!kIsWeb) return;
    final events = ClipboardEvents.instance;
    if (events == null) return;

    _webPasteListener = (event) async {
      if (!mounted) return;

      int focusedIndex = -1;
      for (var i = 0; i < _bulkDrafts.length; i++) {
        if (_bulkDrafts[i].imagePasteFocusNode.hasFocus) {
          focusedIndex = i;
          break;
        }
      }

      if (focusedIndex == -1) return;

      try {
        final reader = await event.getClipboardReader();
        await _pasteBulkImageFromClipboard(
          focusedIndex,
          reader: reader,
          showSuccessToast: false,
        );
      } catch (e) {
        if (!mounted) return;
        AppPopup.show(
          context,
          message: 'Could not paste image: $e',
          type: PopupType.error,
        );
      }
    };

    events.registerPasteEventListener(_webPasteListener!);
  }

  Future<void> _loadAdminLogo() async {
    final adminId = FirebaseAuth.instance.currentUser?.uid;
    if (adminId == null) return;

    try {
      final user = await widget.firestoreService.getUserById(adminId);
      if (!mounted) return;
      setState(() {
        _adminLogoUrl = user?.profilePhoto;
      });
    } catch (_) {}
  }

  Future<void> _loadSkilledUsers() async {
    setState(() => _isLoadingUsers = true);
    try {
      final users = await widget.firestoreService.getAllUsers(limit: 500);
      final filtered = users
          .where((u) => u.role == UserRoles.skilledPerson)
          .where((u) => u.isActive)
          .where((u) => u.isSuspended != true)
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _skilledUsers = filtered;
        _isLoadingUsers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingUsers = false);
    }
  }

  Future<void> _uploadAdminLogo() async {
    final adminId = FirebaseAuth.instance.currentUser?.uid;
    if (adminId == null) return;

    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return;

    setState(() => _isUploadingLogo = true);
    try {
      final bytes = await picked.readAsBytes();
      final url = await _cloudinaryService.uploadImageBytes(
        bytes,
        folder: 'skillshare_admin',
        filename: 'admin_logo_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      if (url == null || url.isEmpty) {
        throw Exception('Logo upload failed.');
      }

      await widget.firestoreService.updateUserProfilePhoto(adminId, url);

      if (!mounted) return;
      setState(() => _adminLogoUrl = url);
      AppPopup.show(
        context,
        message: 'Admin logo updated successfully',
        type: PopupType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppPopup.show(
        context,
        message: 'Logo upload failed: $e',
        type: PopupType.error,
      );
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
    }
  }

  Future<void> _pickOfficialProductImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return;

    try {
      final bytes = await picked.readAsBytes();
      final url = await _cloudinaryService.uploadImageBytes(
        bytes,
        folder: 'skillshare_products',
        filename: 'skillshare_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      if (!mounted) return;
      if (url == null || url.isEmpty) {
        AppPopup.show(
          context,
          message: 'Image upload failed',
          type: PopupType.error,
        );
        return;
      }
      setState(() => _officialImageUrl = url);
      AppPopup.show(
        context,
        message: 'Image uploaded',
        type: PopupType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppPopup.show(
        context,
        message: 'Image upload failed: $e',
        type: PopupType.error,
      );
    }
  }

  Future<void> _createOfficialProduct() async {
    final adminId = FirebaseAuth.instance.currentUser?.uid;
    if (adminId == null) return;

    final name = _officialNameController.text.trim();
    final description = _officialDescController.text.trim();
    final price = double.tryParse(_officialPriceController.text.trim());
    final stock = int.tryParse(_officialStockController.text.trim()) ?? 0;

    if (name.isEmpty || description.isEmpty || price == null || price <= 0) {
      AppPopup.show(
        context,
        message: 'Please fill valid product name, description and price',
        type: PopupType.warning,
      );
      return;
    }

    setState(() => _isCreatingOfficial = true);
    try {
      final product = ProductModel(
        id: '',
        userId: adminId,
        sourceType: 'skillshare',
        displayShopName: 'SkillShare Official',
        assignedByAdminId: adminId,
        name: name,
        description: description,
        price: price,
        images: _officialImageUrl == null ? [] : [_officialImageUrl!],
        category: _officialCategory,
        stock: stock <= 0 ? 1 : stock,
        isAvailable: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await widget.firestoreService.createProduct(
        product,
        bypassSellerVerification: true,
      );

      if (!mounted) return;
      _officialNameController.clear();
      _officialDescController.clear();
      _officialPriceController.clear();
      _officialStockController.text = '1';
      setState(() {
        _officialImageUrl = null;
      });

      AppPopup.show(
        context,
        message: 'SkillShare product added',
        type: PopupType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppPopup.show(
        context,
        message: 'Failed to add product: $e',
        type: PopupType.error,
      );
    } finally {
      if (mounted) setState(() => _isCreatingOfficial = false);
    }
  }

  Future<void> _pickBulkImage(int index) async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return;

    try {
      final Uint8List bytes = await picked.readAsBytes();
      if (!mounted || index < 0 || index >= _bulkDrafts.length) return;
      final draft = _bulkDrafts[index];
      _setDraftImageUploading(draft, bytes);
      unawaited(
        _uploadDraftImage(
          draft,
          bytes,
          filenamePrefix: 'assigned',
          index: index,
          showSuccessToast: false,
          failureMessage: 'Image upload failed',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppPopup.show(
        context,
        message: 'Image upload failed: $e',
        type: PopupType.error,
      );
    }
  }

  Future<void> _pasteBulkImageFromClipboard(
    int index, {
    ClipboardReader? reader,
    bool showSuccessToast = true,
  }) async {
    try {
      final clipboardReader = reader ?? await SystemClipboard.instance?.read();
      if (clipboardReader == null) {
        if (!mounted) return;
        AppPopup.show(
          context,
          message: 'Clipboard image paste is not available on this device',
          type: PopupType.warning,
        );
        return;
      }

      final bytes = await _readImageBytesFromReader(clipboardReader);
      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;
        AppPopup.show(
          context,
          message: 'Copy an image first, then use Paste Image',
          type: PopupType.warning,
        );
        return;
      }

      if (!mounted || index < 0 || index >= _bulkDrafts.length) return;
      final draft = _bulkDrafts[index];
      _setDraftImageUploading(draft, bytes);
      unawaited(
        _uploadDraftImage(
          draft,
          bytes,
          filenamePrefix: 'assigned_clip',
          index: index,
          showSuccessToast: showSuccessToast,
          failureMessage: 'Clipboard image upload failed',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppPopup.show(
        context,
        message: 'Could not paste image: $e',
        type: PopupType.error,
      );
    }
  }

  void _setDraftImageUploading(_BulkProductDraft draft, Uint8List bytes) {
    if (!mounted) return;
    setState(() {
      draft.localImagePreviewBytes = bytes;
      draft.imageUrl = null;
      draft.imageUrlController.clear();
      draft.imageUploadError = null;
      draft.isImageUploading = true;
      draft.imageLinkStatus = _ImageLinkStatus.idle;
      draft.imageLinkValidationMessage = null;
    });
  }

  Future<void> _validateDraftImageUrl(
    _BulkProductDraft draft, {
    bool showSuccessToast = false,
    bool showFailureToast = true,
  }) async {
    final rawUrl = draft.imageUrlController.text.trim();

    if (rawUrl.isEmpty) {
      if (!mounted || !_bulkDrafts.contains(draft)) return;
      setState(() {
        draft.imageUrl = null;
        draft.imageLinkStatus = _ImageLinkStatus.idle;
        draft.imageLinkValidationMessage = null;
      });
      return;
    }

    if (!mounted || !_bulkDrafts.contains(draft)) return;
    setState(() {
      draft.imageUrl = rawUrl;
      draft.imageLinkStatus = _ImageLinkStatus.validating;
      draft.imageLinkValidationMessage = 'Checking image link...';
    });

    try {
      final uri = Uri.tryParse(rawUrl);
      if (uri == null) {
        throw Exception('Invalid URL format');
      }

      if (rawUrl.startsWith('data:image')) {
        // Base64 data URLs are valid local image payloads.
      } else if (uri.scheme == 'http' || uri.scheme == 'https') {
        final bytes = await NetworkAssetBundle(uri)
            .load(uri.toString())
            .timeout(const Duration(seconds: 8));
        if (bytes.lengthInBytes == 0) {
          throw Exception('Image URL returned empty content');
        }
      } else {
        throw Exception('Only http/https or data:image URLs are supported');
      }

      if (!mounted || !_bulkDrafts.contains(draft)) return;
      setState(() {
        draft.imageUrl = rawUrl;
        draft.imageLinkStatus = _ImageLinkStatus.valid;
        draft.imageLinkValidationMessage = 'Image link looks good';
      });

      if (showSuccessToast) {
        AppPopup.show(
          context,
          message: 'Image link is valid',
          type: PopupType.success,
        );
      }
    } catch (e) {
      if (!mounted || !_bulkDrafts.contains(draft)) return;
      setState(() {
        draft.imageLinkStatus = _ImageLinkStatus.invalid;
        draft.imageLinkValidationMessage = 'Image preview failed';
      });
      if (showFailureToast) {
        AppPopup.show(
          context,
          message: 'Image link failed: $e',
          type: PopupType.warning,
        );
      }
    }
  }

  void _validateImportedImageUrlsInBackground(List<_BulkProductDraft> drafts) {
    unawaited(() async {
      for (final draft in drafts) {
        if (!mounted || !_bulkDrafts.contains(draft)) return;
        final url = draft.imageUrlController.text.trim();
        if (url.isEmpty || draft.localImagePreviewBytes != null) continue;
        await _validateDraftImageUrl(draft, showFailureToast: false);
      }
    }());
  }

  Future<void> _uploadDraftImage(
    _BulkProductDraft draft,
    Uint8List bytes, {
    required String filenamePrefix,
    required int index,
    required bool showSuccessToast,
    required String failureMessage,
  }) async {
    try {
      final url = await _cloudinaryService.uploadImageBytes(
        bytes,
        folder: 'assigned_products',
        filename:
            '${filenamePrefix}_${DateTime.now().millisecondsSinceEpoch}_$index.jpg',
      );

      if (!mounted || !_bulkDrafts.contains(draft)) return;

      if (url == null || url.isEmpty) {
        setState(() {
          draft.imageUploadError = failureMessage;
          draft.isImageUploading = false;
        });
        AppPopup.show(
          context,
          message: failureMessage,
          type: PopupType.error,
        );
        return;
      }

      setState(() {
        draft.imageUrl = url;
        draft.imageUrlController.text = url;
        draft.imageUploadError = null;
        draft.isImageUploading = false;
        draft.imageLinkStatus = _ImageLinkStatus.valid;
        draft.imageLinkValidationMessage = 'Uploaded image is ready';
      });

      if (showSuccessToast) {
        AppPopup.show(
          context,
          message: 'Pasted image added',
          type: PopupType.success,
        );
      }
    } catch (e) {
      if (!mounted || !_bulkDrafts.contains(draft)) return;
      setState(() {
        draft.imageUploadError = '$failureMessage: $e';
        draft.isImageUploading = false;
      });
      AppPopup.show(
        context,
        message: '$failureMessage: $e',
        type: PopupType.error,
      );
    }
  }

  Future<Uint8List?> _readImageBytesFromReader(ClipboardReader reader) async {
    const imageFormats = <FileFormat>[
      Formats.png,
      Formats.jpeg,
      Formats.gif,
      Formats.webp,
      Formats.bmp,
      Formats.tiff,
    ];

    for (final format in imageFormats) {
      if (!reader.canProvide(format)) continue;
      final file = await _readClipboardFile(reader, format);
      if (file == null) continue;
      final bytes = await file.readAll();
      file.close();
      if (bytes.isNotEmpty) {
        return bytes;
      }
    }

    return null;
  }

  Future<DataReaderFile?> _readClipboardFile(
    ClipboardReader reader,
    FileFormat format,
  ) async {
    final completer = Completer<DataReaderFile?>();
    final progress = reader.getFile(
      format,
      (file) {
        if (!completer.isCompleted) {
          completer.complete(file);
        }
      },
      onError: (error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
    );

    if (progress == null) {
      return null;
    }

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => null,
    );
  }

  String _normalizeHeader(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('_', '')
        .replaceAll(' ', '')
        .replaceAll('-', '');
  }

  String _cellToText(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  String _normalizeImportedImageUrl(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return '';

    if (value.startsWith('data:image')) {
      return value;
    }

    // Remove wrapping quotes that can appear in CSV export/import.
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.substring(1, value.length - 1).trim();
    }

    // Keep only the first comma-separated segment for malformed rows where
    // columns leaked into this field.
    if (value.contains(',')) {
      final firstSegment = value.split(',').first.trim();
      if (firstSegment.startsWith('http://') ||
          firstSegment.startsWith('https://')) {
        value = firstSegment;
      }
    }

    // Recover cases like "...jpgSpider Plant..." by trimming to first known
    // image extension when trailing text was appended.
    final extensionMatch = RegExp(
      r'\.(jpg|jpeg|png|webp|gif|bmp)',
      caseSensitive: false,
    ).firstMatch(value);
    if (extensionMatch != null) {
      final extEnd = extensionMatch.end;
      final hasQueryAfter =
          extEnd < value.length && value.substring(extEnd).startsWith('?');
      if (!hasQueryAfter && extEnd < value.length) {
        value = value.substring(0, extEnd);
      }
    }

    final uri = Uri.tryParse(value);
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      return '';
    }

    return value;
  }

  String _extractImageUrlFromRow(List<dynamic> row, int? imageUrlIdx) {
    final candidates = <String>[];

    if (imageUrlIdx != null && imageUrlIdx >= 0 && imageUrlIdx < row.length) {
      candidates.add(_cellToText(row[imageUrlIdx]));
    }

    for (final cell in row) {
      final text = _cellToText(cell);
      if (text.isEmpty) continue;
      if (text.startsWith('http://') ||
          text.startsWith('https://') ||
          text.startsWith('data:image')) {
        candidates.add(text);
      }
    }

    for (final candidate in candidates) {
      if (candidate.startsWith('data:image')) return candidate;
      final normalized = _normalizeImportedImageUrl(candidate);
      if (normalized.isNotEmpty) return normalized;
    }

    return '';
  }

  List<List<dynamic>> _parseCsvRows(Uint8List bytes) {
    final raw = utf8.decode(bytes, allowMalformed: true);
    return const CsvDecoder(
      dynamicTyping: false,
    ).convert(raw);
  }

  List<List<dynamic>> _parseExcelRows(Uint8List bytes) {
    final excel = xls.Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return const [];

    List<List<dynamic>> bestRows = const [];
    var bestScore = -1;

    for (final table in excel.tables.values) {
      if (table.rows.isEmpty) continue;

      final rows = table.rows
          .map(
            (row) => row
                .map((cell) => cell?.value?.toString() ?? '')
                .toList(growable: false),
          )
          .toList(growable: false);

      final score = _scoreExcelSheet(rows);
      if (score > bestScore) {
        bestScore = score;
        bestRows = rows;
      }
    }

    return bestRows;
  }

  int _scoreExcelSheet(List<List<dynamic>> rows) {
    if (rows.isEmpty) return -1;

    final headerKeys = rows.first
        .map((cell) => _normalizeHeader(_cellToText(cell)))
        .where((key) => key.isNotEmpty)
        .toSet();

    var score = rows.length * 10;

    void addIfHas(Iterable<String> candidates, int weight) {
      if (candidates.any(headerKeys.contains)) {
        score += weight;
      }
    }

    addIfHas(const ['name', 'productname', 'title'], 80);
    addIfHas(const ['description', 'details', 'desc'], 80);
    addIfHas(const ['price', 'amount', 'mrp'], 80);
    addIfHas(const ['quantity', 'qty', 'stock'], 80);
    addIfHas(const ['category', 'productcategory'], 20);
    addIfHas(const ['imageurl', 'imagelink', 'image'], 20);
    addIfHas(const ['assigneeuserid', 'assigneeid', 'email', 'assigneename'], 20);

    return score;
  }

  String? _findAssigneeId(
    Map<String, int> headerIndex,
    List<dynamic> row,
  ) {
    String valueFor(List<String> candidates) {
      for (final key in candidates) {
        final idx = headerIndex[key];
        if (idx != null && idx < row.length) {
          final value = _cellToText(row[idx]);
          if (value.isNotEmpty) return value;
        }
      }
      return '';
    }

    final byId = valueFor(const [
      'assigneeuserid',
      'assigneeid',
      'userid',
      'skilleduserid',
    ]);
    if (byId.isNotEmpty) {
      final matched = _skilledUsers.where((u) => u.uid == byId).toList();
      if (matched.isNotEmpty) return matched.first.uid;
    }

    final byEmail = valueFor(const [
      'assigneeemail',
      'email',
      'skilledemail',
    ]).toLowerCase();
    if (byEmail.isNotEmpty) {
      final matched = _skilledUsers
          .where((u) => u.email.trim().toLowerCase() == byEmail)
          .toList();
      if (matched.isNotEmpty) return matched.first.uid;
    }

    final byName = valueFor(const [
      'assigneename',
      'username',
      'skilledname',
      'nameoftheperson',
    ]).toLowerCase();
    if (byName.isNotEmpty) {
      final matched = _skilledUsers
          .where((u) => u.name.trim().toLowerCase() == byName)
          .toList();
      if (matched.isNotEmpty) return matched.first.uid;
    }

    return null;
  }

  Future<void> _importBulkFromFile() async {
    if (_isLoadingUsers || _skilledUsers.isEmpty) {
      AppPopup.show(
        context,
        message: 'No skilled users loaded yet for assignment mapping',
        type: PopupType.warning,
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx'],
      withData: true,
    );

    if (!mounted) return;

    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      AppPopup.show(
        context,
        message: 'Could not read file bytes',
        type: PopupType.error,
      );
      return;
    }

    final ext = (file.extension ?? '').toLowerCase();
    final isXlsx = ext == 'xlsx';

    setState(() => _isImportingBulk = true);
    try {
      final rows = isXlsx ? _parseExcelRows(bytes) : _parseCsvRows(bytes);
      final excelRowImages = isXlsx
          ? XlsxEmbeddedImageParser.extractFirstSheetRowImages(bytes)
          : const <int, Uint8List>{};

      if (rows.length < 2) {
        throw Exception('File must contain header row + at least one data row.');
      }

      final headersRaw = rows.first.map((e) => _cellToText(e)).toList();
      final headerIndex = <String, int>{};
      for (var i = 0; i < headersRaw.length; i++) {
        final key = _normalizeHeader(headersRaw[i]);
        if (key.isNotEmpty) headerIndex[key] = i;
      }

      int? idxFor(List<String> keys) {
        for (final key in keys) {
          if (headerIndex.containsKey(key)) return headerIndex[key];
        }
        return null;
      }

      final nameIdx = idxFor(const ['name', 'productname', 'title']);
      final descIdx = idxFor(const ['description', 'details', 'desc']);
      final priceIdx = idxFor(const ['price', 'amount', 'mrp']);
      final qtyIdx = idxFor(const ['quantity', 'qty', 'stock']);
      final categoryIdx = idxFor(const ['category', 'productcategory']);
      final imageUrlIdx = idxFor(const ['imageurl', 'imagelink', 'image']);

      if (nameIdx == null || descIdx == null || priceIdx == null || qtyIdx == null) {
        throw Exception(
          'Missing required columns. Required: name, description, price, quantity/stock.',
        );
      }

      final imported = <_BulkProductDraft>[];
      var extractedImageCount = 0;
      var imageUrlProvidedCount = 0;
      var missingImageCount = 0;
      var unmappedAssigneeCount = 0;
      var skippedEmptyRowCount = 0;
      var invalidPriceRowCount = 0;
      var invalidStockRowCount = 0;
      var processedRowCount = 0;

      for (var r = 1; r < rows.length; r++) {
        final row = rows[r];
        if (row.isEmpty) {
          skippedEmptyRowCount++;
          continue;
        }

        final name = nameIdx < row.length ? _cellToText(row[nameIdx]) : '';
        final desc = descIdx < row.length ? _cellToText(row[descIdx]) : '';
        final priceText = priceIdx < row.length ? _cellToText(row[priceIdx]) : '';
        final qtyText = qtyIdx < row.length ? _cellToText(row[qtyIdx]) : '';
        final category = categoryIdx != null && categoryIdx < row.length
            ? _cellToText(row[categoryIdx])
            : '';
        final imageUrl = _extractImageUrlFromRow(row, imageUrlIdx);

        if (name.isEmpty && desc.isEmpty && priceText.isEmpty && qtyText.isEmpty) {
          skippedEmptyRowCount++;
          continue;
        }

        processedRowCount++;

        final draft = _BulkProductDraft();
        draft.nameController.text = name;
        draft.descController.text = desc;
        draft.priceController.text = priceText;
        draft.stockController.text = qtyText.isEmpty ? '1' : qtyText;
        if (category.isNotEmpty && AppConstants.categories.contains(category)) {
          draft.category = category;
        }
        if (imageUrl.isNotEmpty) {
          draft.imageUrl = imageUrl;
          draft.imageUrlController.text = imageUrl;
          draft.imageLinkStatus = _ImageLinkStatus.validating;
          draft.imageLinkValidationMessage = 'Checking imported link...';
          imageUrlProvidedCount++;
        }

        if ((draft.imageUrl == null || draft.imageUrl!.isEmpty) &&
            excelRowImages.containsKey(r)) {
          final extractedBytes = excelRowImages[r]!;
          final uploaded = await _cloudinaryService.uploadImageBytes(
            extractedBytes,
            folder: 'assigned_products',
            filename:
                'assigned_xlsx_row_${r + 1}_${DateTime.now().millisecondsSinceEpoch}.png',
          );
          if (uploaded != null && uploaded.isNotEmpty) {
            draft.imageUrl = uploaded;
            draft.imageUrlController.text = uploaded;
            draft.imageLinkStatus = _ImageLinkStatus.valid;
            draft.imageLinkValidationMessage = 'Embedded image uploaded';
            extractedImageCount++;
          }
        }

        draft.assigneeUserId = _findAssigneeId(headerIndex, row);
        if (draft.assigneeUserId == null || draft.assigneeUserId!.isEmpty) {
          unmappedAssigneeCount++;
        }

        final parsedPrice = double.tryParse(priceText);
        if (parsedPrice == null || parsedPrice <= 0) {
          invalidPriceRowCount++;
        }

        final parsedStock = int.tryParse(draft.stockController.text.trim()) ?? 0;
        if (parsedStock <= 0) {
          invalidStockRowCount++;
        }

        if (draft.imageUrl == null || draft.imageUrl!.trim().isEmpty) {
          missingImageCount++;
        }

        imported.add(draft);
      }

      if (imported.isEmpty) {
        throw Exception('No valid rows were found in the file.');
      }

      for (final draft in _bulkDrafts) {
        draft.dispose();
      }

      if (!mounted) return;
      final summary = _BulkImportSummary(
        fileName: file.name,
        isXlsx: isXlsx,
        processedRows: processedRowCount,
        importedRows: imported.length,
        skippedEmptyRows: skippedEmptyRowCount,
        imageUrlProvidedRows: imageUrlProvidedCount,
        extractedImageRows: extractedImageCount,
        missingImageRows: missingImageCount,
        unmappedAssigneeRows: unmappedAssigneeCount,
        invalidPriceRows: invalidPriceRowCount,
        invalidStockRows: invalidStockRowCount,
        importedAt: DateTime.now(),
      );

      setState(() {
        _bulkDrafts
          ..clear()
          ..addAll(imported);

        _lastImportSummary = summary;
        _recordImportSummary(summary);
      });

      _validateImportedImageUrlsInBackground(imported);

      AppPopup.show(
        context,
        message:
            'Imported ${imported.length} draft product(s). '
            '${extractedImageCount > 0 ? 'Auto-attached $extractedImageCount image(s) from XLSX. ' : ''}'
            'Add/review images, then click Assign Bulk Products.',
        type: PopupType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppPopup.show(
        context,
        message: 'Import failed: $e',
        type: PopupType.error,
      );
    } finally {
      if (mounted) setState(() => _isImportingBulk = false);
    }
  }

  Future<void> _downloadSampleCsvTemplate() async {
    try {
      final rows = <List<dynamic>>[
        const [
          'name',
          'description',
          'price',
          'quantity',
          'category',
          'assigneeEmail',
          'imageUrl',
        ],
        const [
          'Premium Hammer Set',
          'Heavy duty steel hammer set for professional carpentry',
          '1499',
          '25',
          'Carpentry',
          'skilled1@example.com',
          'https://example.com/images/hammer.jpg',
        ],
        const [
          'Designer Tailoring Kit',
          'Complete tailoring toolkit for boutique jobs',
          '2199',
          '12',
          'Tailoring',
          'skilled2@example.com',
          'https://example.com/images/tailoring.jpg',
        ],
      ];

      final csv = const CsvEncoder().convert(rows);
      final bytes = Uint8List.fromList(utf8.encode(csv));

      if (kIsWeb) {
        await file_downloader.downloadTextFile(
          fileName: 'skillshare_bulk_products_sample.csv',
          content: csv,
        );

        if (!mounted) return;
        AppPopup.show(
          context,
          message:
              'Sample CSV downloaded. Fill it and upload using Import CSV / Excel.',
          type: PopupType.success,
        );
        return;
      }

      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Sample Bulk Product Template',
        fileName: 'skillshare_bulk_products_sample.csv',
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        bytes: bytes,
      );

      if (!mounted) return;
      if (savedPath == null || savedPath.trim().isEmpty) {
        AppPopup.show(
          context,
          message: 'Sample download cancelled',
          type: PopupType.warning,
        );
        return;
      }

      AppPopup.show(
        context,
        message:
            'Sample CSV downloaded. Fill it and upload using Import CSV / Excel.',
        type: PopupType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppPopup.show(
        context,
        message: 'Could not download sample template: $e',
        type: PopupType.error,
      );
    }
  }

  Future<void> _submitBulkAssignments() async {
    final adminId = FirebaseAuth.instance.currentUser?.uid;
    if (adminId == null) return;

    if (_bulkDrafts.isEmpty) return;

    for (final d in _bulkDrafts) {
      final name = d.nameController.text.trim();
      final desc = d.descController.text.trim();
      final price = double.tryParse(d.priceController.text.trim());
      final stock = int.tryParse(d.stockController.text.trim()) ?? 0;
      if (d.assigneeUserId == null ||
          d.assigneeUserId!.isEmpty ||
          name.isEmpty ||
          desc.isEmpty ||
          price == null ||
          price <= 0 ||
          stock <= 0 ||
          d.imageUrl == null ||
          d.imageUrl!.isEmpty) {
        AppPopup.show(
          context,
          message:
              'Each bulk row needs: skilled person, name, description, price, stock, and product photo',
          type: PopupType.warning,
        );
        return;
      }
    }

    final confirm = await AppDialog.confirm(
      context,
      title: 'Assign Bulk Products',
      message:
          'Create ${_bulkDrafts.length} products and assign them to selected skilled persons?',
      confirmText: 'Assign',
      cancelText: 'Cancel',
      gradientColors: const [Color(0xFF1565C0), Color(0xFF26A69A)],
      icon: Icons.inventory_2,
    );
    if (confirm != true) return;

    setState(() => _isBulkSubmitting = true);
    try {
      for (final d in _bulkDrafts) {
        final assignedUserId = d.assigneeUserId!;
        final p = ProductModel(
          id: '',
          userId: assignedUserId,
          sourceType: 'seller',
          assignedByAdminId: adminId,
          name: d.nameController.text.trim(),
          description: d.descController.text.trim(),
          price: double.parse(d.priceController.text.trim()),
          images: d.imageUrl == null ? [] : [d.imageUrl!],
          category: d.category,
          stock: int.parse(d.stockController.text.trim()),
          isAvailable: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await widget.firestoreService.createProduct(
          p,
          bypassSellerVerification: true,
        );
      }

      if (!mounted) return;
      for (final d in _bulkDrafts) {
        d.dispose();
      }
      setState(() {
        _bulkDrafts
          ..clear()
          ..add(_BulkProductDraft());
      });

      AppPopup.show(
        context,
        message: 'Bulk products assigned successfully',
        type: PopupType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppPopup.show(
        context,
        message: 'Bulk assignment failed: $e',
        type: PopupType.error,
      );
    } finally {
      if (mounted) setState(() => _isBulkSubmitting = false);
    }
  }

  bool _isDraftValid(_BulkProductDraft d) {
    return _draftValidationIssues(d).isEmpty;
  }

  List<String> _draftValidationIssues(_BulkProductDraft d) {
    final name = d.nameController.text.trim();
    final desc = d.descController.text.trim();
    final price = double.tryParse(d.priceController.text.trim());
    final stock = int.tryParse(d.stockController.text.trim()) ?? 0;
    final issues = <String>[];

    if (d.assigneeUserId == null || d.assigneeUserId!.isEmpty) {
      issues.add('Assignee is required');
    }
    if (name.isEmpty) {
      issues.add('Name is required');
    }
    if (desc.isEmpty) {
      issues.add('Description is required');
    }
    if (price == null || price <= 0) {
      issues.add('Price must be greater than 0');
    }
    if (stock <= 0) {
      issues.add('Stock must be greater than 0');
    }
    if (d.isImageUploading) {
      issues.add('Image upload in progress');
    }
    if (d.imageUrl == null || d.imageUrl!.trim().isEmpty) {
      issues.add('Image is required');
    }
    if (d.imageLinkStatus == _ImageLinkStatus.invalid) {
      issues.add('Image link is invalid');
    }

    return issues;
  }

  void _recordImportSummary(_BulkImportSummary summary) {
    _importHistory.insert(0, summary);
    if (_importHistory.length > 10) {
      _importHistory.removeRange(10, _importHistory.length);
    }
  }

  String _csvSafeFileTimestamp(DateTime dt) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${dt.year}${two(dt.month)}${two(dt.day)}_${two(dt.hour)}${two(dt.minute)}${two(dt.second)}';
  }

  Future<void> _exportInvalidRowsCsv() async {
    if (_bulkDrafts.isEmpty) {
      AppPopup.show(
        context,
        message: 'No rows available for export.',
        type: PopupType.info,
      );
      return;
    }

    final rows = <List<dynamic>>[
      const [
        'rowNumber',
        'issues',
        'name',
        'description',
        'price',
        'quantity',
        'category',
        'assigneeUserId',
        'imageUrl',
      ],
    ];

    for (var i = 0; i < _bulkDrafts.length; i++) {
      final draft = _bulkDrafts[i];
      final issues = _draftValidationIssues(draft);
      if (issues.isEmpty) continue;

      rows.add([
        i + 1,
        issues.join(' | '),
        draft.nameController.text.trim(),
        draft.descController.text.trim(),
        draft.priceController.text.trim(),
        draft.stockController.text.trim(),
        draft.category,
        draft.assigneeUserId ?? '',
        draft.imageUrl ?? '',
      ]);
    }

    if (rows.length == 1) {
      AppPopup.show(
        context,
        message: 'No invalid rows found to export.',
        type: PopupType.info,
      );
      return;
    }

    final csv = const CsvEncoder().convert(rows);

    try {
      if (kIsWeb) {
        await file_downloader.downloadTextFile(
          fileName:
              'skillshare_failed_rows_${_csvSafeFileTimestamp(DateTime.now())}.csv',
          content: csv,
        );
      } else {
        final bytes = Uint8List.fromList(utf8.encode(csv));
        final savedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Failed Bulk Rows CSV',
          fileName:
              'skillshare_failed_rows_${_csvSafeFileTimestamp(DateTime.now())}.csv',
          type: FileType.custom,
          allowedExtensions: const ['csv'],
          bytes: bytes,
        );

        if (savedPath == null || savedPath.trim().isEmpty) {
          if (!mounted) return;
          AppPopup.show(
            context,
            message: 'Export cancelled.',
            type: PopupType.warning,
          );
          return;
        }
      }

      if (!mounted) return;
      AppPopup.show(
        context,
        message: 'Failed rows CSV exported successfully.',
        type: PopupType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppPopup.show(
        context,
        message: 'Failed rows export failed: $e',
        type: PopupType.error,
      );
    }
  }

  void _clearRowImage(int index) {
    final draft = _bulkDrafts[index];
    setState(() {
      draft.imageUrl = null;
      draft.imageUrlController.clear();
      draft.localImagePreviewBytes = null;
      draft.imageUploadError = null;
      draft.isImageUploading = false;
      draft.imageLinkStatus = _ImageLinkStatus.idle;
      draft.imageLinkValidationMessage = null;
    });
  }

  void _duplicateRow(int index) {
    final source = _bulkDrafts[index];
    final copy = _BulkProductDraft();
    copy.assigneeUserId = source.assigneeUserId;
    copy.nameController.text = source.nameController.text;
    copy.descController.text = source.descController.text;
    copy.priceController.text = source.priceController.text;
    copy.stockController.text = source.stockController.text;
    copy.category = source.category;
    copy.imageUrl = source.imageUrl;
    copy.imageUrlController.text = source.imageUrlController.text;
    copy.localImagePreviewBytes = source.localImagePreviewBytes;
    copy.imageUploadError = source.imageUploadError;
    copy.imageLinkStatus = source.imageLinkStatus;
    copy.imageLinkValidationMessage = source.imageLinkValidationMessage;
    copy.isImageUploading = false;

    setState(() {
      _bulkDrafts.insert(index + 1, copy);
    });
  }

  void _validateRowsAndShowSummary() {
    final invalidRows = <String>[];
    for (var i = 0; i < _bulkDrafts.length; i++) {
      final issues = _draftValidationIssues(_bulkDrafts[i]);
      if (issues.isNotEmpty) {
        invalidRows.add('R${i + 1}: ${issues.join(' | ')}');
      }
    }

    if (invalidRows.isEmpty) {
      AppPopup.show(
        context,
        message: 'All ${_bulkDrafts.length} row(s) are valid for publish.',
        type: PopupType.success,
      );
      return;
    }

    final preview = invalidRows.take(5).join(' | ');
    AppPopup.show(
      context,
      message:
          'Invalid rows (${invalidRows.length}): $preview${invalidRows.length > 5 ? ' ...' : ''}',
      type: PopupType.warning,
    );
  }

  void _removeInvalidRows() {
    if (_bulkDrafts.isEmpty) return;

    final invalidIndexes = <int>[];
    for (var i = 0; i < _bulkDrafts.length; i++) {
      if (!_isDraftValid(_bulkDrafts[i])) {
        invalidIndexes.add(i);
      }
    }

    if (invalidIndexes.isEmpty) {
      AppPopup.show(
        context,
        message: 'No invalid rows found.',
        type: PopupType.info,
      );
      return;
    }

    setState(() {
      for (var i = invalidIndexes.length - 1; i >= 0; i--) {
        final idx = invalidIndexes[i];
        final draft = _bulkDrafts.removeAt(idx);
        draft.dispose();
      }
      if (_bulkDrafts.isEmpty) {
        _bulkDrafts.add(_BulkProductDraft());
      }
    });

    AppPopup.show(
      context,
      message: 'Removed ${invalidIndexes.length} invalid row(s).',
      type: PopupType.success,
    );
  }

  Future<void> _deleteProduct(ProductModel product) async {
    final confirm = await AppDialog.confirm(
      context,
      title: 'Delete Product',
      message: 'Delete "${product.name}" permanently?',
      confirmText: 'Delete',
      icon: Icons.delete_forever,
      gradientColors: const [Color(0xFFD32F2F), Color(0xFFFF7043)],
    );
    if (confirm != true) return;

    try {
      await widget.firestoreService.deleteProduct(product.id);
      if (!mounted) return;
      AppPopup.show(
        context,
        message: 'Product deleted',
        type: PopupType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppPopup.show(
        context,
        message: 'Delete failed: $e',
        type: PopupType.error,
      );
    }
  }

  Future<void> _editProduct(ProductModel product) async {
    final nameController = TextEditingController(text: product.name);
    final descController = TextEditingController(text: product.description);
    final priceController =
        TextEditingController(text: product.price.toStringAsFixed(0));
    final stockController = TextEditingController(text: '${product.stock}');
    final existingImages = product.images
      .map((url) => url.trim().startsWith('data:image')
        ? url.trim()
        : _normalizeImportedImageUrl(url))
      .where((url) => url.trim().isNotEmpty)
      .toList();
    final oldPrimaryImageUrl =
        existingImages.isNotEmpty ? existingImages.first : '';
    final imageUrlController = TextEditingController(text: oldPrimaryImageUrl);

    var category = product.category;
    var isAvailable = product.isAvailable;
    var primaryImageUrl = oldPrimaryImageUrl;
    var isUploadingEditImage = false;
    String? imageEditStatus;

    final shouldSave = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (_, setLocalState) {
            Future<void> pickAndUploadReplacement() async {
              final XFile? picked = await _picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 90,
              );
              if (picked == null) return;

              setLocalState(() {
                isUploadingEditImage = true;
                imageEditStatus = 'Uploading replacement image...';
              });

              try {
                final bytes = await picked.readAsBytes();
                final folder = product.sourceType == 'skillshare'
                    ? 'skillshare_products'
                    : 'assigned_products';
                final url = await _cloudinaryService.uploadImageBytes(
                  bytes,
                  folder: folder,
                  filename:
                      'edit_${product.id}_${DateTime.now().millisecondsSinceEpoch}.jpg',
                );

                if (url == null || url.isEmpty) {
                  throw Exception('Image upload failed');
                }

                if (!ctx.mounted) return;
                setLocalState(() {
                  primaryImageUrl = url;
                  imageUrlController.text = url;
                  imageEditStatus = 'Image replaced successfully';
                  isUploadingEditImage = false;
                });
              } catch (e) {
                if (!ctx.mounted) return;
                setLocalState(() {
                  imageEditStatus = 'Image upload failed: $e';
                  isUploadingEditImage = false;
                });
              }
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 640,
                  maxHeight: MediaQuery.of(ctx).size.height * 0.9,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFDFEFF), Color(0xFFF3F5FF), Color(0xFFFFF6FC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFD9DFFD)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4A3B8F).withValues(alpha: 0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF304FFE), Color(0xFF7B1FA2), Color(0xFFE91E63)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                          ),
                        ),
                        child: const Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Color(0x2AFFFFFF),
                              child: Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Edit Product',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Update image, details and availability',
                                    style: TextStyle(color: Color(0xFFE3E7FF), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: double.infinity,
                                height: 150,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFEAF1FF), Color(0xFFF7EDFF)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFD2DCFF)),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: primaryImageUrl.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'No image selected',
                                          style: TextStyle(
                                            color: Color(0xFF5B5E74),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      )
                                    : WebImageLoader.loadImage(
                                        imageUrl: primaryImageUrl,
                                        fit: BoxFit.cover,
                                        errorWidget: const Center(
                                          child: Text(
                                            'Could not preview image',
                                            style: TextStyle(
                                              color: Colors.redAccent,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed:
                                        isUploadingEditImage ? null : pickAndUploadReplacement,
                                    icon: isUploadingEditImage
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Icon(Icons.photo),
                                    label: const Text('Replace Image'),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: isUploadingEditImage
                                        ? null
                                        : () {
                                            setLocalState(() {
                                              primaryImageUrl = '';
                                              imageUrlController.clear();
                                              imageEditStatus = 'Image removed';
                                            });
                                          },
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Clear'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: imageUrlController,
                                decoration: const InputDecoration(
                                  labelText: 'Image URL',
                                  prefixIcon: Icon(Icons.link_rounded),
                                ),
                                onChanged: (value) {
                                  setLocalState(() {
                                    primaryImageUrl = value.trim();
                                    imageEditStatus = null;
                                  });
                                },
                              ),
                              if (imageEditStatus != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: imageEditStatus!.startsWith('Image upload failed')
                                        ? const Color(0xFFFFEBEE)
                                        : const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    imageEditStatus!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: imageEditStatus!.startsWith('Image upload failed')
                                          ? const Color(0xFFC62828)
                                          : const Color(0xFF2E7D32),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              TextField(
                                controller: nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Name',
                                  prefixIcon: Icon(Icons.label_rounded),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: descController,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  labelText: 'Description',
                                  prefixIcon: Icon(Icons.notes_rounded),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: priceController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Price',
                                  prefixIcon: Icon(Icons.currency_rupee_rounded),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: stockController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Stock',
                                  prefixIcon: Icon(Icons.inventory_2_rounded),
                                ),
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                value: AppConstants.categories.contains(category)
                                    ? category
                                    : AppConstants.categories.first,
                                items: AppConstants.categories
                                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setLocalState(() => category = value);
                                  }
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                  prefixIcon: Icon(Icons.category_rounded),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F9FF),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFD8E0FF)),
                                ),
                                child: SwitchListTile(
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                  value: isAvailable,
                                  title: const Text('Available'),
                                  subtitle: const Text('Toggle product visibility for shoppers'),
                                  onChanged: (value) {
                                    setLocalState(() => isAvailable = value);
                                  },
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF304FFE), Color(0xFF7B1FA2)],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ElevatedButton(
                                  onPressed: isUploadingEditImage
                                      ? null
                                      : () => Navigator.of(ctx).pop(true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                  ),
                                  child: const Text(
                                    'Save Changes',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (shouldSave != true) {
      nameController.dispose();
      descController.dispose();
      priceController.dispose();
      stockController.dispose();
      imageUrlController.dispose();
      return;
    }

    final updatedName = nameController.text.trim();
    final updatedDesc = descController.text.trim();
    final updatedPrice = double.tryParse(priceController.text.trim());
    final updatedStock = int.tryParse(stockController.text.trim()) ?? 0;
    final updatedPrimaryImageUrl = imageUrlController.text.trim();

    final retainedSecondaryImages = existingImages
      .where((url) => url.trim().isNotEmpty)
      .where((url) => url != oldPrimaryImageUrl)
      .where((url) => url != updatedPrimaryImageUrl)
      .toList();

    final updatedImages = updatedPrimaryImageUrl.isEmpty
      ? retainedSecondaryImages
      : <String>[updatedPrimaryImageUrl, ...retainedSecondaryImages];

    nameController.dispose();
    descController.dispose();
    priceController.dispose();
    stockController.dispose();
    imageUrlController.dispose();

    if (updatedName.isEmpty || updatedDesc.isEmpty || updatedPrice == null) {
      if (!mounted) return;
      AppPopup.show(
        context,
        message: 'Please provide valid name, description and price.',
        type: PopupType.warning,
      );
      return;
    }

    try {
      await widget.firestoreService.updateProduct(
        ProductModel(
          id: product.id,
          userId: product.userId,
          sourceType: product.sourceType,
          displayShopName: product.displayShopName,
          assignedByAdminId: product.assignedByAdminId,
          name: updatedName,
          description: updatedDesc,
          price: updatedPrice,
          images: updatedImages,
          category: category,
          stock: updatedStock,
          isAvailable: isAvailable,
          rating: product.rating,
          reviewCount: product.reviewCount,
          createdAt: product.createdAt,
          updatedAt: DateTime.now(),
        ),
      );

      if (!mounted) return;
      AppPopup.show(
        context,
        message: 'Product updated successfully',
        type: PopupType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppPopup.show(
        context,
        message: 'Update failed: $e',
        type: PopupType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themed = Theme.of(context).copyWith(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(
          color: Color(0xFF4B587C),
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD7DDF3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD7DDF3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _adminPrimary, width: 1.6),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _adminPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _adminPrimary,
          side: BorderSide(color: _adminPrimary.withValues(alpha: 0.45)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );

    return Theme(
      data: themed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _adminSurface,
              Colors.white,
              _adminSecondary.withValues(alpha: 0.04),
            ],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadSkilledUsers();
            await _loadAdminLogo();
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildAdminLogoCard(),
              const SizedBox(height: 14),
              _buildOfficialProductCard(),
              const SizedBox(height: 14),
              _buildBulkAssignCard(),
              const SizedBox(height: 14),
              _buildManageProductsCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminLogoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE2F8)),
        boxShadow: [
          BoxShadow(
            color: _adminPrimary.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(
              icon: Icons.verified_user,
              title: 'Admin Brand / Profile Photo',
              subtitle: 'Keep your admin identity and brand visuals updated.',
              gradient: const [Color(0xFF3A5BFF), Color(0xFF00ACC1)],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFEEEAF9),
                  backgroundImage:
                    (_adminLogoUrl != null && _adminLogoUrl!.isNotEmpty)
                      ? WebImageLoader.getImageProvider(_adminLogoUrl)
                      : null,
                  child: (_adminLogoUrl == null || _adminLogoUrl!.isEmpty)
                      ? const Icon(Icons.shield, color: Color(0xFF512DA8))
                      : null,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Upload the SkillShare logo as the admin profile image.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isUploadingLogo ? null : _uploadAdminLogo,
                  icon: _isUploadingLogo
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload),
                  label: const Text('Upload'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfficialProductCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE2F8)),
        boxShadow: [
          BoxShadow(
            color: _adminRose.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(
              icon: Icons.workspace_premium,
              title: 'Add Official SkillShare Product',
              subtitle:
                  'These are published as SkillShare Official products.',
              gradient: const [Color(0xFF8E24AA), Color(0xFFFF5C8A)],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _officialNameController,
              decoration: const InputDecoration(
                labelText: 'Product name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _officialDescController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _officialPriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _officialStockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Stock',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _officialCategory,
              items: AppConstants.categories
                  .map(
                    (c) => DropdownMenuItem<String>(
                      value: c,
                      child: Text(c),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _officialCategory = v);
              },
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickOfficialProductImage,
                  icon: const Icon(Icons.photo),
                  label: Text(
                    _officialImageUrl == null ? 'Upload photo' : 'Photo added',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _officialImageUrl == null
                        ? 'No image selected'
                        : 'Image uploaded',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isCreatingOfficial ? null : _createOfficialProduct,
                icon: _isCreatingOfficial
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_box),
                label: const Text('Add SkillShare Product'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkAssignCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE2F8)),
        boxShadow: [
          BoxShadow(
            color: _adminSecondary.withValues(alpha: 0.11),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(
              icon: Icons.auto_awesome,
              title: 'Bulk Add And Assign To Skilled Persons',
              subtitle:
                  'Import, validate, preview, and assign products in one flow.',
              gradient: const [Color(0xFF00A3A3), Color(0xFF3F51B5)],
            ),
            const SizedBox(height: 8),
            const Text(
              'Create multiple products and map each one to a skilled person. Products then appear in that person\'s login/shop.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            const Text(
              'Import columns: name, description, price, quantity (or stock), category, one assignee column (assigneeEmail or assigneeUserId or assigneeName), and optional imageUrl. If imageUrl is not provided, add images manually before publish.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            if (_isLoadingUsers)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_skilledUsers.isEmpty)
              const Text(
                'No active skilled persons found.',
                style: TextStyle(color: Colors.redAccent),
              )
            else
              Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed:
                              _isImportingBulk ? null : _importBulkFromFile,
                          icon: _isImportingBulk
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.upload_file),
                          label: const Text('Import CSV / Excel'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _downloadSampleCsvTemplate,
                          icon: const Icon(Icons.download),
                          label: const Text('Download Sample CSV'),
                        ),
                      ],
                    ),
                  ),
                  if (_lastImportSummary != null) ...[
                    const SizedBox(height: 10),
                    _buildImportSummaryCard(_lastImportSummary!),
                  ],
                  if (_importHistory.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildImportHistoryCard(),
                  ],
                  const SizedBox(height: 8),
                  ...List.generate(_bulkDrafts.length, (index) {
                    final draft = _bulkDrafts[index];
                    return _buildBulkRow(index, draft);
                  }),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() => _bulkDrafts.add(_BulkProductDraft()));
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add row'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _validateRowsAndShowSummary,
                        icon: const Icon(Icons.rule),
                        label: const Text('Validate rows'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _removeInvalidRows,
                        icon: const Icon(Icons.cleaning_services_outlined),
                        label: const Text('Remove invalid'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _exportInvalidRowsCsv,
                        icon: const Icon(Icons.file_download_outlined),
                        label: const Text('Export failed rows'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          _isBulkSubmitting ? null : _submitBulkAssignments,
                      icon: _isBulkSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.assignment_turned_in),
                      label: const Text('Assign Bulk Products'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkRow(int index, _BulkProductDraft draft) {
    final issues = _draftValidationIssues(draft);
    final isValid = issues.isEmpty;
    final screenWidth = MediaQuery.of(context).size.width;
    final previewHeight = screenWidth >= 1400
      ? 220.0
      : screenWidth >= 1000
        ? 180.0
        : 120.0;

    return GestureDetector(
      onTap: () => draft.imagePasteFocusNode.requestFocus(),
      child: Focus(
        focusNode: draft.imagePasteFocusNode,
        onKeyEvent: (_, event) {
          final isCtrlV = event is KeyDownEvent &&
              HardwareKeyboard.instance.isControlPressed &&
              event.logicalKey == LogicalKeyboardKey.keyV;
          if (isCtrlV) {
            unawaited(_pasteBulkImageFromClipboard(index));
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                isValid
                    ? const Color(0xFFF8FCFF)
                    : const Color(0xFFFFF6F8),
                Colors.white,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: draft.imagePasteFocusNode.hasFocus
                  ? const Color(0xFF1565C0)
                  : (isValid
                      ? const Color(0xFFD0DEFF)
                      : const Color(0xFFFFCDD2)),
              width: draft.imagePasteFocusNode.hasFocus ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Product ${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Tooltip(
                    message: isValid
                        ? 'Row is valid'
                        : 'Issues: ${issues.join(' • ')}',
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isValid
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isValid
                              ? const Color(0xFF66BB6A)
                              : const Color(0xFFE57373),
                        ),
                      ),
                      child: Text(
                        isValid ? 'Ready' : '${issues.length} issue(s)',
                        style: TextStyle(
                          fontSize: 11,
                          color: isValid
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFC62828),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Duplicate this row',
                    onPressed: () => _duplicateRow(index),
                    icon: const Icon(Icons.copy, color: Color(0xFF1565C0)),
                  ),
                  IconButton(
                    tooltip: 'Remove this row',
                    onPressed: _bulkDrafts.length > 1
                        ? () {
                            setState(() {
                              final removed = _bulkDrafts.removeAt(index);
                              removed.dispose();
                            });
                          }
                        : null,
                    icon:
                        const Icon(Icons.delete_outline, color: Colors.redAccent),
                  ),
                ],
              ),
              if (!isValid) ...[
                const SizedBox(height: 6),
                Text(
                  'Missing: ${issues.join(' | ')}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFC62828),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              const Text(
                'Tip: click this row and press Ctrl+V to paste product image',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: draft.assigneeUserId,
                decoration: const InputDecoration(
                  labelText: 'Assign to skilled person',
                  border: OutlineInputBorder(),
                ),
                items: _skilledUsers
                    .map(
                      (u) => DropdownMenuItem<String>(
                        value: u.uid,
                        child: Text('${u.name} (${u.email})'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => draft.assigneeUserId = v),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: draft.nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: draft.descController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: draft.priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Price',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: draft.stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Stock',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: draft.category,
                items: AppConstants.categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => draft.category = v);
                },
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: draft.imageUrlController,
                decoration: InputDecoration(
                  labelText: 'Image URL (optional - can edit imported links)',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: 'Validate image link',
                    onPressed: draft.isImageUploading
                        ? null
                        : () => _validateDraftImageUrl(
                              draft,
                              showSuccessToast: true,
                            ),
                    icon: draft.imageLinkStatus == _ImageLinkStatus.validating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.link),
                  ),
                ),
                onChanged: (value) {
                  final trimmed = value.trim();
                  setState(() {
                    draft.imageUrl = trimmed.isEmpty ? null : trimmed;
                    draft.imageLinkStatus = _ImageLinkStatus.idle;
                    draft.imageLinkValidationMessage = null;
                    draft.localImagePreviewBytes = null;
                  });
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pickBulkImage(index),
                    icon: const Icon(Icons.photo),
                    label: Text(
                      draft.isImageUploading
                          ? 'Uploading...'
                          : (draft.imageUrl == null ? 'Upload photo' : 'Photo added'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: draft.isImageUploading
                        ? null
                        : () => _pasteBulkImageFromClipboard(index),
                    icon: const Icon(Icons.content_paste),
                    label: const Text('Paste image'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Clear image',
                    onPressed: (draft.imageUrl != null && draft.imageUrl!.isNotEmpty) ||
                            draft.localImagePreviewBytes != null ||
                            draft.isImageUploading
                        ? () => _clearRowImage(index)
                        : null,
                    icon: const Icon(Icons.image_not_supported_outlined,
                        color: Colors.redAccent),
                  ),
                  const SizedBox(width: 8),
                  if (draft.localImagePreviewBytes != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.memory(
                          draft.localImagePreviewBytes!,
                          width: 34,
                          height: 34,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      draft.isImageUploading
                          ? 'Image pasted. Uploading in background...'
                          : (draft.imageUploadError != null
                              ? 'Upload failed. Paste again or upload photo.'
                              : (draft.imageLinkValidationMessage ??
                                  (draft.imageUrl == null
                                      ? 'No image selected'
                                      : 'Image added. Click link icon to validate preview.'))),
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (draft.localImagePreviewBytes != null ||
                  (draft.imageUrl != null && draft.imageUrl!.trim().isNotEmpty)) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: previewHeight,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6FB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDCE3F1)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: draft.localImagePreviewBytes != null
                      ? Padding(
                          padding: const EdgeInsets.all(6),
                          child: Image.memory(
                            draft.localImagePreviewBytes!,
                            fit: BoxFit.contain,
                          ),
                        )
                      : WebImageLoader.loadImage(
                          imageUrl: draft.imageUrl,
                          fit: BoxFit.contain,
                          errorWidget: const Center(
                            child: Text(
                              'Could not preview image. Update link and retry.',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImportSummaryCard(_BulkImportSummary summary) {
    Widget stat(String label, int value, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '$label: $value',
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFEFF6FF),
            _adminSecondary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCFE0FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Import Summary • ${summary.fileName}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            '${summary.isXlsx ? 'XLSX' : 'CSV'} • '
            'Imported at ${summary.importedAt.hour.toString().padLeft(2, '0')}:${summary.importedAt.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              stat('Processed', summary.processedRows, const Color(0xFF1565C0)),
              stat('Imported', summary.importedRows, const Color(0xFF2E7D32)),
              stat('Skipped Empty', summary.skippedEmptyRows,
                  const Color(0xFF6D4C41)),
              stat('Image URL', summary.imageUrlProvidedRows,
                  const Color(0xFF512DA8)),
              stat('Extracted Images', summary.extractedImageRows,
                  const Color(0xFF00897B)),
              stat('Missing Image', summary.missingImageRows, Colors.redAccent),
              stat('Unmapped Assignee', summary.unmappedAssigneeRows,
                  Colors.orange),
              stat('Invalid Price', summary.invalidPriceRows,
                  const Color(0xFFD84315)),
              stat('Invalid Stock', summary.invalidStockRows,
                  const Color(0xFFAD1457)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImportHistoryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF3F5FF),
            _adminPrimary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E3FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Import History (Last 10)',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ..._importHistory.map((item) {
            final issues = item.missingImageRows +
                item.unmappedAssigneeRows +
                item.invalidPriceRows +
                item.invalidStockRows;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.fileName} • ${item.isXlsx ? 'XLSX' : 'CSV'} • ${item.importedRows}/${item.processedRows} row(s)',
                      style:
                          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    issues == 0 ? 'Clean' : '$issues issue(s)',
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          issues == 0 ? const Color(0xFF2E7D32) : Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildManageProductsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE2F8)),
        boxShadow: [
          BoxShadow(
            color: _adminPrimary.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(
              icon: Icons.inventory_2,
              title: 'Manage Products (Edit / Delete)',
              subtitle:
                  'Quickly review and update all listed products.',
              gradient: const [Color(0xFF5E35B1), Color(0xFF1E88E5)],
            ),
            const SizedBox(height: 10),
            StreamBuilder<List<ProductModel>>(
              stream: widget.firestoreService.streamAllProductsForAdmin(
                limit: 400,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final products = snapshot.data ?? [];
                if (products.isEmpty) {
                  return const Text('No products found.');
                }

                final sortedProducts = [...products]
                  ..sort((a, b) {
                    final aIssues = _productAttentionIssues(a).isNotEmpty;
                    final bIssues = _productAttentionIssues(b).isNotEmpty;
                    if (aIssues == bIssues) {
                      return b.updatedAt.compareTo(a.updatedAt);
                    }
                    return aIssues ? -1 : 1;
                  });

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sortedProducts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final p = sortedProducts[index];
                    final isSkillShare = p.sourceType == 'skillshare';
                    final attentionIssues = _productAttentionIssues(p);
                    final needsAttention = attentionIssues.isNotEmpty;
                    return Container(
                      decoration: BoxDecoration(
                        color: needsAttention
                            ? const Color(0xFFFFF7F2)
                            : const Color(0xFFF8FAFF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: needsAttention
                              ? const Color(0xFFFFCC80)
                              : const Color(0xFFE3E8FA),
                          width: needsAttention ? 1.3 : 1,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          backgroundColor:
                              isSkillShare ? const Color(0xFFEEEAF9) : null,
                          backgroundImage:
                            p.images.isNotEmpty ? WebImageLoader.getImageProvider(p.images.first) : null,
                          child: p.images.isEmpty
                              ? Icon(
                                  isSkillShare ? Icons.verified : Icons.inventory_2,
                                  color: isSkillShare
                                      ? const Color(0xFF512DA8)
                                      : Colors.blueGrey,
                                )
                              : null,
                        ),
                        title: Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${isSkillShare ? 'SkillShare Official' : 'Assigned/Seller'} • '
                              '₹${p.price.toStringAsFixed(0)} • '
                              'Stock: ${p.stock} • '
                              '${p.isAvailable ? 'Available' : 'Unavailable'}',
                            ),
                            if (needsAttention)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFEBD9),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'Needs attention: ${attentionIssues.join(' • ')}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFFB45309),
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            if (needsAttention)
                              const Padding(
                                padding: EdgeInsets.only(top: 10),
                                child: Icon(
                                  Icons.warning_amber_rounded,
                                  color: Color(0xFFB45309),
                                  size: 18,
                                ),
                              ),
                            IconButton(
                              onPressed: () => _editProduct(p),
                              icon:
                                  const Icon(Icons.edit, color: Color(0xFF1565C0)),
                            ),
                            IconButton(
                              onPressed: () => _deleteProduct(p),
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<String> _productAttentionIssues(ProductModel product) {
    final issues = <String>[];

    if (product.images.isEmpty ||
        product.images.every((url) => url.trim().isEmpty)) {
      issues.add('No image');
    }
    if (product.name.trim().isEmpty) {
      issues.add('Missing name');
    }
    if (product.description.trim().isEmpty) {
      issues.add('Missing description');
    }
    if (product.price <= 0) {
      issues.add('Invalid price');
    }
    if (product.stock < 0) {
      issues.add('Negative stock');
    }

    return issues;
  }
}

class _BulkProductDraft {
  _BulkProductDraft();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController stockController = TextEditingController(text: '1');
  final TextEditingController imageUrlController = TextEditingController();
  final FocusNode imagePasteFocusNode = FocusNode();

  String category = AppConstants.categories.first;
  String? assigneeUserId;
  String? imageUrl;
  Uint8List? localImagePreviewBytes;
  String? imageUploadError;
  bool isImageUploading = false;
  _ImageLinkStatus imageLinkStatus = _ImageLinkStatus.idle;
  String? imageLinkValidationMessage;

  void dispose() {
    nameController.dispose();
    descController.dispose();
    priceController.dispose();
    stockController.dispose();
    imageUrlController.dispose();
    imagePasteFocusNode.dispose();
  }
}

enum _ImageLinkStatus { idle, validating, valid, invalid }

class _BulkImportSummary {
  final String fileName;
  final bool isXlsx;
  final int processedRows;
  final int importedRows;
  final int skippedEmptyRows;
  final int imageUrlProvidedRows;
  final int extractedImageRows;
  final int missingImageRows;
  final int unmappedAssigneeRows;
  final int invalidPriceRows;
  final int invalidStockRows;
  final DateTime importedAt;

  const _BulkImportSummary({
    required this.fileName,
    required this.isXlsx,
    required this.processedRows,
    required this.importedRows,
    required this.skippedEmptyRows,
    required this.imageUrlProvidedRows,
    required this.extractedImageRows,
    required this.missingImageRows,
    required this.unmappedAssigneeRows,
    required this.invalidPriceRows,
    required this.invalidStockRows,
    required this.importedAt,
  });
}
