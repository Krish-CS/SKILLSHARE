import 'package:flutter/material.dart';
import '../utils/app_constants.dart';

/// Reusable filter bottom sheet for Home, Shop, and Explore screens.
///
/// Returns a [FilterResult] when the user taps "Apply", or null on cancel.
class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({
    super.key,
    required this.mode,
    this.initialCategory,
    this.initialSortBy,
    this.initialMinRating,
    this.initialMinPrice,
    this.initialMaxPrice,
    this.initialViewMode,
  });

  /// 'experts' for Home/Explore screens, 'products' for Shop screen.
  final String mode;
  final String? initialCategory;
  final String? initialSortBy;
  final double? initialMinRating;
  final double? initialMinPrice;
  final double? initialMaxPrice;
  final String? initialViewMode; // 'list' | 'grid'

  /// Show the filter bottom sheet and return the result.
  static Future<FilterResult?> show(
    BuildContext context, {
    required String mode,
    String? initialCategory,
    String? initialSortBy,
    double? initialMinRating,
    double? initialMinPrice,
    double? initialMaxPrice,
    String? initialViewMode,
  }) {
    return showModalBottomSheet<FilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterBottomSheet(
        mode: mode,
        initialCategory: initialCategory,
        initialSortBy: initialSortBy,
        initialMinRating: initialMinRating,
        initialMinPrice: initialMinPrice,
        initialMaxPrice: initialMaxPrice,
        initialViewMode: initialViewMode,
      ),
    );
  }

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late String? _category;
  late String _sortBy;
  late double _minRating;
  late double _minPrice;
  late double _maxPrice;
  late String _viewMode;

  bool get _isProductMode => widget.mode == 'products';

  List<String> get _categories => ['All', ...AppConstants.categories];

  // Sort options depending on mode
  List<(String, String, IconData)> get _sortOptions => _isProductMode
      ? [
          ('newest', 'New Arrivals', Icons.fiber_new_rounded),
          ('rating', 'Top Rated', Icons.star_rounded),
          ('price_low', 'Price: Low→High', Icons.arrow_upward_rounded),
          ('price_high', 'Price: High→Low', Icons.arrow_downward_rounded),
        ]
      : [
          ('rating', 'Top Rated', Icons.star_rounded),
          ('reviews', 'Most Reviewed', Icons.rate_review_rounded),
          ('projects', 'Most Projects', Icons.work_rounded),
          ('newest', 'Newest', Icons.fiber_new_rounded),
        ];

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    _sortBy = widget.initialSortBy ??
        (_isProductMode ? 'newest' : 'rating');
    _minRating = widget.initialMinRating ?? 0;
    _minPrice = widget.initialMinPrice ?? 0;
    _maxPrice = widget.initialMaxPrice ?? 50000;
    _viewMode = widget.initialViewMode ?? 'list';
  }

  void _reset() {
    setState(() {
      _category = null;
      _sortBy = _isProductMode ? 'newest' : 'rating';
      _minRating = 0;
      _minPrice = 0;
      _maxPrice = 50000;
      _viewMode = 'list';
    });
  }

  void _apply() {
    Navigator.pop(
      context,
      FilterResult(
        category: _category,
        sortBy: _sortBy,
        minRating: _minRating,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        viewMode: _viewMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6A11CB), Color(0xFFe43396)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.tune_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Filters & Sort',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _reset,
                  child: const Text('Reset',
                      style: TextStyle(color: Color(0xFF6A11CB))),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 16),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 4, 20, bottomPad + 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Sort By ──
                  _sectionTitle('Sort By', Icons.sort_rounded),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _sortOptions.map((opt) {
                      final (key, label, icon) = opt;
                      final selected = _sortBy == key;
                      return _filterChip(
                        label: label,
                        icon: icon,
                        selected: selected,
                        onTap: () => setState(() => _sortBy = key),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // ── Category ──
                  _sectionTitle('Category', Icons.category_rounded),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((cat) {
                      final selected =
                          (_category == cat) || (_category == null && cat == 'All');
                      return _filterChip(
                        label: cat,
                        selected: selected,
                        onTap: () => setState(() {
                          _category = cat == 'All' ? null : cat;
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // ── Minimum Rating ──
                  _sectionTitle(
                    'Minimum Rating: ${_minRating.toStringAsFixed(1)} ⭐',
                    Icons.star_half_rounded,
                  ),
                  const SizedBox(height: 4),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: const Color(0xFF6A11CB),
                      inactiveTrackColor: Colors.grey[200],
                      thumbColor: const Color(0xFF6A11CB),
                      overlayColor:
                          const Color(0xFF6A11CB).withValues(alpha: 0.15),
                      trackHeight: 4,
                    ),
                    child: Slider(
                      value: _minRating,
                      min: 0,
                      max: 5,
                      divisions: 10,
                      label: _minRating.toStringAsFixed(1),
                      onChanged: (v) => setState(() => _minRating = v),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Any', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      Text('5.0', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Price range (products only) ──
                  if (_isProductMode) ...[
                    _sectionTitle(
                      'Price Range: ₹${_minPrice.round()} – ₹${_maxPrice.round()}',
                      Icons.currency_rupee_rounded,
                    ),
                    const SizedBox(height: 4),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: const Color(0xFF6A11CB),
                        inactiveTrackColor: Colors.grey[200],
                        thumbColor: const Color(0xFF6A11CB),
                        overlayColor:
                            const Color(0xFF6A11CB).withValues(alpha: 0.15),
                        trackHeight: 4,
                      ),
                      child: RangeSlider(
                        values: RangeValues(_minPrice, _maxPrice),
                        min: 0,
                        max: 50000,
                        divisions: 100,
                        labels: RangeLabels(
                          '₹${_minPrice.round()}',
                          '₹${_maxPrice.round()}',
                        ),
                        onChanged: (v) => setState(() {
                          _minPrice = v.start;
                          _maxPrice = v.end;
                        }),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('₹0',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500])),
                        Text('₹50,000',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── View Mode (experts only) ──
                  if (!_isProductMode) ...[
                    _sectionTitle('View Mode', Icons.view_agenda_rounded),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _filterChip(
                          label: 'List',
                          icon: Icons.view_list_rounded,
                          selected: _viewMode == 'list',
                          onTap: () => setState(() => _viewMode = 'list'),
                        ),
                        const SizedBox(width: 10),
                        _filterChip(
                          label: 'Grid',
                          icon: Icons.grid_view_rounded,
                          selected: _viewMode == 'grid',
                          onTap: () => setState(() => _viewMode = 'grid'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),

          // ── Apply button ──
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6A11CB), Color(0xFFe43396)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6A11CB).withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _apply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_rounded, size: 20, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Apply Filters',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6A11CB)),
        const SizedBox(width: 6),
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xFF333355))),
      ],
    );
  }

  Widget _filterChip({
    required String label,
    IconData? icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFF6A11CB), Color(0xFFe43396)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: selected ? null : Colors.grey[50],
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? const Color(0xFF6A11CB) : Colors.grey[300]!,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFFe43396).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 15,
                  color: selected ? Colors.white : Colors.grey[600]),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey[800],
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Result returned when user applies filters.
class FilterResult {
  const FilterResult({
    this.category,
    this.sortBy,
    this.minRating,
    this.minPrice,
    this.maxPrice,
    this.viewMode,
  });
  final String? category;
  final String? sortBy;
  final double? minRating;
  final double? minPrice;
  final double? maxPrice;
  final String? viewMode;
}
