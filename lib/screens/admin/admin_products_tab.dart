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

  List<UserModel> _skilledUsers = [];
  bool _isLoadingUsers = true;

  final List<_BulkProductDraft> _bulkDrafts = [_BulkProductDraft()];
  void Function(ClipboardReadEvent event)? _webPasteListener;

  @override
  void initState() {
    super.initState();
    _loadSkilledUsers();
    _loadAdminLogo();
    _configureWebPasteListener();
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

    final events = ClipboardEvents.instance;
    if (_webPasteListener != null && events != null) {
      events.unregisterPasteEventListener(_webPasteListener!);
    }

    super.dispose();
  }

  void _configureWebPasteListener() {
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
      final url = await _cloudinaryService.uploadImageBytes(
        bytes,
        folder: 'assigned_products',
        filename: 'assigned_${DateTime.now().millisecondsSinceEpoch}_$index.jpg',
      );
      if (url == null || url.isEmpty) {
        if (!mounted) return;
        AppPopup.show(
          context,
          message: 'Image upload failed',
          type: PopupType.error,
        );
        return;
      }
      if (!mounted) return;
      setState(() => _bulkDrafts[index].imageUrl = url);
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

      final url = await _cloudinaryService.uploadImageBytes(
        bytes,
        folder: 'assigned_products',
        filename:
            'assigned_clip_${DateTime.now().millisecondsSinceEpoch}_$index.jpg',
      );

      if (url == null || url.isEmpty) {
        if (!mounted) return;
        AppPopup.show(
          context,
          message: 'Clipboard image upload failed',
          type: PopupType.error,
        );
        return;
      }

      if (!mounted) return;
      setState(() => _bulkDrafts[index].imageUrl = url);
      if (showSuccessToast) {
        AppPopup.show(
          context,
          message: 'Pasted image added',
          type: PopupType.success,
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppPopup.show(
        context,
        message: 'Could not paste image: $e',
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

  List<List<dynamic>> _parseCsvRows(Uint8List bytes) {
    final raw = utf8.decode(bytes, allowMalformed: true);
    return const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(raw);
  }

  List<List<dynamic>> _parseExcelRows(Uint8List bytes) {
    final excel = xls.Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return const [];

    final table = excel.tables.values.first;

    return table.rows
        .map(
          (row) => row
              .map((cell) => cell?.value?.toString() ?? '')
              .toList(growable: false),
        )
        .toList(growable: false);
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

    setState(() => _isImportingBulk = true);
    try {
      final rows = ext == 'xlsx' ? _parseExcelRows(bytes) : _parseCsvRows(bytes);
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

      if (nameIdx == null || descIdx == null || priceIdx == null || qtyIdx == null) {
        throw Exception(
          'Missing required columns. Required: name, description, price, quantity/stock.',
        );
      }

      final imported = <_BulkProductDraft>[];

      for (var r = 1; r < rows.length; r++) {
        final row = rows[r];
        if (row.isEmpty) continue;

        final name = nameIdx < row.length ? _cellToText(row[nameIdx]) : '';
        final desc = descIdx < row.length ? _cellToText(row[descIdx]) : '';
        final priceText = priceIdx < row.length ? _cellToText(row[priceIdx]) : '';
        final qtyText = qtyIdx < row.length ? _cellToText(row[qtyIdx]) : '';
        final category = categoryIdx != null && categoryIdx < row.length
            ? _cellToText(row[categoryIdx])
            : '';

        if (name.isEmpty && desc.isEmpty && priceText.isEmpty && qtyText.isEmpty) {
          continue;
        }

        final draft = _BulkProductDraft();
        draft.nameController.text = name;
        draft.descController.text = desc;
        draft.priceController.text = priceText;
        draft.stockController.text = qtyText.isEmpty ? '1' : qtyText;
        if (category.isNotEmpty && AppConstants.categories.contains(category)) {
          draft.category = category;
        }

        draft.assigneeUserId = _findAssigneeId(headerIndex, row);
        imported.add(draft);
      }

      if (imported.isEmpty) {
        throw Exception('No valid rows were found in the file.');
      }

      for (final draft in _bulkDrafts) {
        draft.dispose();
      }

      if (!mounted) return;
      setState(() {
        _bulkDrafts
          ..clear()
          ..addAll(imported);
      });

      AppPopup.show(
        context,
        message:
            'Imported ${imported.length} draft product(s). Add images, review rows, then click Assign Bulk Products.',
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
        ],
        const [
          'Premium Hammer Set',
          'Heavy duty steel hammer set for professional carpentry',
          '1499',
          '25',
          'Carpentry',
          'skilled1@example.com',
        ],
        const [
          'Designer Tailoring Kit',
          'Complete tailoring toolkit for boutique jobs',
          '2199',
          '12',
          'Tailoring',
          'skilled2@example.com',
        ],
      ];

      final csv = const ListToCsvConverter().convert(rows);
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
    var category = product.category;
    var isAvailable = product.isAvailable;

    final shouldSave = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Product'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Price'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Stock'),
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
                    category = value;
                  }
                },
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (_, setLocalState) => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isAvailable,
                  title: const Text('Available'),
                  onChanged: (value) {
                    setLocalState(() => isAvailable = value);
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (shouldSave != true) {
      nameController.dispose();
      descController.dispose();
      priceController.dispose();
      stockController.dispose();
      return;
    }

    final updatedName = nameController.text.trim();
    final updatedDesc = descController.text.trim();
    final updatedPrice = double.tryParse(priceController.text.trim());
    final updatedStock = int.tryParse(stockController.text.trim()) ?? 0;

    nameController.dispose();
    descController.dispose();
    priceController.dispose();
    stockController.dispose();

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
          images: product.images,
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
    return RefreshIndicator(
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
    );
  }

  Widget _buildAdminLogoCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admin Brand / Profile Photo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFEEEAF9),
                  backgroundImage:
                      (_adminLogoUrl != null && _adminLogoUrl!.isNotEmpty)
                          ? NetworkImage(_adminLogoUrl!)
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
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Official SkillShare Product',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'These products are shown as SkillShare Official, not as skilled-person products.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
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
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bulk Add And Assign To Skilled Persons',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Create multiple products and map each one to a skilled person. Products then appear in that person\'s login/shop.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            const Text(
              'Import columns: name, description, price, quantity (or stock), category, and one assignee column (assigneeEmail or assigneeUserId or assigneeName). Images are added manually after import and before publish.',
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
                  const SizedBox(height: 8),
                  ...List.generate(_bulkDrafts.length, (index) {
                    final draft = _bulkDrafts[index];
                    return _buildBulkRow(index, draft);
                  }),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() => _bulkDrafts.add(_BulkProductDraft()));
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add row'),
                      ),
                      const SizedBox(width: 8),
                      if (_bulkDrafts.length > 1)
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              final draft = _bulkDrafts.removeLast();
                              draft.dispose();
                            });
                          },
                          icon: const Icon(Icons.remove),
                          label: const Text('Remove row'),
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
            color: const Color(0xFFF6F7FB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: draft.imagePasteFocusNode.hasFocus
                  ? const Color(0xFF1565C0)
                  : const Color(0xFFE2E3EE),
              width: draft.imagePasteFocusNode.hasFocus ? 1.4 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(
            'Product ${index + 1}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
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
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickBulkImage(index),
                icon: const Icon(Icons.photo),
                label: Text(draft.imageUrl == null ? 'Upload photo' : 'Photo added'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _pasteBulkImageFromClipboard(index),
                icon: const Icon(Icons.content_paste),
                label: const Text('Paste image'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  draft.imageUrl == null ? 'No image selected' : 'Image uploaded',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManageProductsCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manage Products (Edit / Delete)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final p = products[index];
                    final isSkillShare = p.sourceType == 'skillshare';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor:
                            isSkillShare ? const Color(0xFFEEEAF9) : null,
                        backgroundImage:
                            p.images.isNotEmpty ? NetworkImage(p.images.first) : null,
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
                      ),
                      subtitle: Text(
                        '${isSkillShare ? 'SkillShare Official' : 'Assigned/Seller'} • '
                        '₹${p.price.toStringAsFixed(0)} • '
                        'Stock: ${p.stock} • '
                        '${p.isAvailable ? 'Available' : 'Unavailable'}',
                      ),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            onPressed: () => _editProduct(p),
                            icon: const Icon(Icons.edit, color: Color(0xFF1565C0)),
                          ),
                          IconButton(
                            onPressed: () => _deleteProduct(p),
                            icon:
                                const Icon(Icons.delete, color: Colors.redAccent),
                          ),
                        ],
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
}

class _BulkProductDraft {
  _BulkProductDraft();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController stockController = TextEditingController(text: '1');
  final FocusNode imagePasteFocusNode = FocusNode();

  String category = AppConstants.categories.first;
  String? assigneeUserId;
  String? imageUrl;

  void dispose() {
    nameController.dispose();
    descController.dispose();
    priceController.dispose();
    stockController.dispose();
    imagePasteFocusNode.dispose();
  }
}
