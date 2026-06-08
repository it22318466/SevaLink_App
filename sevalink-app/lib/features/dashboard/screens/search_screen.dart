import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../../providers/search_provider.dart';
import '../../../data/models/worker_search_result.dart';
import '../../../data/models/search_suggestion.dart';


// Category chip data

class _CategoryOption {
  final String label;
  final String apiValue;
  final IconData icon;
  const _CategoryOption(this.label, this.apiValue, this.icon);
}

const _kCategories = [
  _CategoryOption('Electrician', 'ELECTRICIAN', Icons.bolt_outlined),
  _CategoryOption('Plumber', 'PLUMBER', Icons.plumbing_outlined),
  _CategoryOption('Carpenter', 'CARPENTER', Icons.handyman_outlined),
  _CategoryOption('Painter', 'PAINTER', Icons.format_paint_outlined),
  _CategoryOption('Cleaner', 'CLEANER', Icons.auto_awesome_outlined),
  _CategoryOption('Mechanic', 'MECHANIC', Icons.settings_outlined),
  _CategoryOption('Gardener', 'GARDENER', Icons.eco_outlined),
  _CategoryOption('Technician', 'TECHNICIAN', Icons.laptop_chromebook_outlined),
];


// Search Screen

class SearchScreen extends ConsumerStatefulWidget {
  /// Optional pre-selected category (when tapping a category tile on dashboard)
  final String? initialCategory;

  const SearchScreen({super.key, this.initialCategory});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  Timer? _debounceSuggestions;
  String? _selectedCategory;

  // GPS coordinates — fetched silently on load for proximity sorting
  double? _lat;
  double? _lng;

  // Animation for the screen entrance
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  static const _primaryOrange = Color(0xFFD3410A);
  static const _orangeDark = Color(0xFFE8520B);
  static const _bg = Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();

    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _animController.forward();

    // Fetch GPS coordinates silently in background for proximity sorting
    _fetchLocation().then((_) {
      // After coords are ready, trigger pre-selected category or focus
      if (widget.initialCategory != null) {
        _selectedCategory = widget.initialCategory;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(searchProvider.notifier).searchByCategory(
                widget.initialCategory!,
                lat: _lat,
                lng: _lng,
              );
        });
      } else {
        // Auto-focus keyboard when no initial category
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _focusNode.requestFocus();
        });
      }
    });
  }

  /// Silently fetch device GPS coords. Failure is non-fatal — falls back to
  /// rating-based ordering on the backend.
  Future<void> _fetchLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low, // low accuracy is fast & battery-friendly
          timeLimit: Duration(seconds: 5),
        ),
      );

      if (mounted) {
        setState(() {
          _lat = position.latitude;
          _lng = position.longitude;
        });
      }
    } catch (_) {
      // Non-fatal: search without location if GPS unavailable
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _debounceSuggestions?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _animController.dispose();
    // Reset provider state when leaving screen
    ref.read(searchProvider.notifier).reset();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    // 1. Fetch suggestions quickly as the user types
    _debounceSuggestions?.cancel();
    _debounceSuggestions = Timer(const Duration(milliseconds: 150), () {
      ref.read(searchProvider.notifier).fetchSuggestions(value);
    });

    // 2. Perform search in background after normal debounce (450ms)
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      final trimmed = value.trim().toUpperCase();
      final matchedCat = _kCategories.firstWhere(
        (c) => c.apiValue == trimmed || c.label.toUpperCase() == trimmed,
        orElse: () => const _CategoryOption('', '', Icons.search),
      );

      if (matchedCat.apiValue.isNotEmpty) {
        setState(() => _selectedCategory = matchedCat.apiValue);
        ref.read(searchProvider.notifier).searchByCategory(
              matchedCat.apiValue,
              lat: _lat,
              lng: _lng,
            );
      } else {
        ref.read(searchProvider.notifier).search(
          value,
          category: _selectedCategory,
          lat: _lat,
          lng: _lng,
        );
      }
    });
  }

  void _onCategoryTap(_CategoryOption cat) {
    setState(() {
      if (_selectedCategory == cat.apiValue) {
        // Deselect
        _selectedCategory = null;
        ref.read(searchProvider.notifier).search(
          _controller.text,
          category: null,
          lat: _lat,
          lng: _lng,
        );
      } else {
        _selectedCategory = cat.apiValue;
        ref.read(searchProvider.notifier).search(
              _controller.text,
              category: cat.apiValue,
              lat: _lat,
              lng: _lng,
            );
      }
    });
  }

  void _clearSearch() {
    _controller.clear();
    setState(() => _selectedCategory = null);
    ref.read(searchProvider.notifier).reset();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);

    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Column(
            children: [
              _buildHeader(searchState),
              _buildCategoryChips(),
              Expanded(child: _buildBody(searchState)),
            ],
          ),
        ),
      ),
    );
  }

  //  Header with search bar
  Widget _buildHeader(SearchState searchState) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_orangeDark, _primaryOrange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Back button
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Find a Worker',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      'Search by name, category or skill',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Search input
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(Icons.search_rounded,
                    color: Colors.grey.shade400, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: _onQueryChanged,
                    style: const TextStyle(
                        fontSize: 16, color: Color(0xFF1A1A1A)),
                    decoration: InputDecoration(
                      hintText: 'e.g. Plumber, Sunil, Electrician...',
                      hintStyle: TextStyle(
                          color: Colors.grey.shade400, fontSize: 15),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (v) => ref
                        .read(searchProvider.notifier)
                        .search(v, category: _selectedCategory),
                  ),
                ),
                if (_controller.text.isNotEmpty || _selectedCategory != null)
                  GestureDetector(
                    onTap: _clearSearch,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(Icons.close_rounded,
                          color: Colors.grey.shade400, size: 20),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  //  Category filter chips
  Widget _buildCategoryChips() {
    final searchState = ref.watch(searchProvider);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // "Available Now" toggle chip
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () {
                  ref.read(searchProvider.notifier).toggleAvailabilityFilter(
                    lat: _lat,
                    lng: _lng,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: searchState.isAvailableOnly ? const Color(0xFFE6F4EA) : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: searchState.isAvailableOnly
                          ? Colors.green.shade600
                          : Colors.grey.shade200,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        searchState.isAvailableOnly ? Icons.circle : Icons.circle_outlined,
                        size: 10,
                        color: searchState.isAvailableOnly ? Colors.green.shade600 : Colors.grey.shade400,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Available Now',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: searchState.isAvailableOnly
                              ? Colors.green.shade800
                              : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Divider
            Container(
              height: 20,
              width: 1,
              color: Colors.grey.shade300,
              margin: const EdgeInsets.only(right: 10),
            ),
            ..._kCategories.map((cat) {
            final isSelected = _selectedCategory == cat.apiValue;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => _onCategoryTap(cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? _primaryOrange : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected
                          ? _primaryOrange
                          : Colors.grey.shade200,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        cat.icon,
                        size: 16,
                        color:
                            isSelected ? Colors.white : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        cat.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
          ],
        ),
      ),
    );
  }

  //  Body — initial / loading / error / results
  Widget _buildBody(SearchState state) {
    if (_focusNode.hasFocus && state.suggestions.isNotEmpty) {
      return _buildSuggestionsList(state.suggestions);
    }

    switch (state.status) {
      case SearchStatus.initial:
        return _buildInitialHint();
      case SearchStatus.loading:
        return _buildLoading();
      case SearchStatus.error:
        return _buildError(state.errorMessage ?? 'Unknown error');
      case SearchStatus.success:
        if (state.isEmpty) return _buildEmpty(state.query, state.selectedCategory);
        return _buildResults(state.results);
    }
  }

  // Autocomplete suggestion list view
  Widget _buildSuggestionsList(List<SearchSuggestion> suggestions) {
    return Container(
      color: Colors.white,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: suggestions.length,
        separatorBuilder: (ctx, idx) => Divider(color: Colors.grey.shade100, height: 1),
        itemBuilder: (context, index) {
          final item = suggestions[index];
          IconData icon;
          Color iconColor;
          
          switch (item.type) {
            case 'CATEGORY':
              icon = Icons.category_rounded;
              iconColor = _primaryOrange;
              break;
            case 'WORKER':
              icon = Icons.person_rounded;
              iconColor = Colors.blue.shade600;
              break;
            case 'SKILL':
              icon = Icons.construction_rounded;
              iconColor = Colors.green.shade600;
              break;
            default:
              icon = Icons.search_rounded;
              iconColor = Colors.grey.shade600;
          }

          return ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            title: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 16, color: Color(0xFF1A1A1A)),
                children: _highlightMatch(item.text, _controller.text),
              ),
            ),
            trailing: Icon(Icons.arrow_outward_rounded, color: Colors.grey.shade400, size: 18),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            onTap: () {
              _controller.text = item.text;
              _focusNode.unfocus();
              
              if (item.type == 'CATEGORY') {
                final mappedValue = _mapDbCategoryToApiValue(item.text);
                final matched = _kCategories.firstWhere(
                  (c) => c.apiValue == mappedValue || c.label.toUpperCase() == item.text.toUpperCase() || c.apiValue == item.text.toUpperCase(),
                  orElse: () => const _CategoryOption('', '', Icons.search),
                );
                if (matched.apiValue.isNotEmpty) {
                  setState(() => _selectedCategory = matched.apiValue);
                  ref.read(searchProvider.notifier).searchByCategory(
                    matched.apiValue,
                    lat: _lat,
                    lng: _lng,
                  );
                  return;
                }
              }
              
              ref.read(searchProvider.notifier).search(
                item.text,
                category: _selectedCategory,
                lat: _lat,
                lng: _lng,
              );
            },
          );
        },
      ),
    );
  }

  List<TextSpan> _highlightMatch(String text, String query) {
    if (query.isEmpty) return [TextSpan(text: text)];
    final lowercaseText = text.toLowerCase();
    final lowercaseQuery = query.toLowerCase();
    final index = lowercaseText.indexOf(lowercaseQuery);
    if (index == -1) return [TextSpan(text: text)];

    return [
      TextSpan(text: text.substring(0, index)),
      TextSpan(
        text: text.substring(index, index + query.length),
        style: const TextStyle(fontWeight: FontWeight.bold, color: _primaryOrange),
      ),
      TextSpan(text: text.substring(index + query.length)),
    ];
  }

  String? _getDistanceString(WorkerSearchResult worker) {
    if (_lat == null || _lng == null || worker.latitude == null || worker.longitude == null) {
      return null;
    }
    final meters = Geolocator.distanceBetween(_lat!, _lng!, worker.latitude!, worker.longitude!);
    final km = meters / 1000.0;
    if (km < 1.0) {
      return '${meters.toStringAsFixed(0)} m';
    }
    return '${km.toStringAsFixed(1)} km';
  }

  String _mapDbCategoryToApiValue(String dbCategoryName) {
    switch (dbCategoryName.toLowerCase()) {
      case 'electrical':
      case 'electrician':
        return 'ELECTRICIAN';
      case 'plumbing':
      case 'plumber':
        return 'PLUMBER';
      case 'carpentry':
      case 'carpenter':
        return 'CARPENTER';
      case 'painting':
      case 'painter':
        return 'PAINTER';
      case 'cleaning':
      case 'cleaner':
        return 'CLEANER';
      case 'mechanic':
        return 'MECHANIC';
      case 'gardener':
        return 'GARDENER';
      case 'technician':
        return 'TECHNICIAN';
      default:
        return dbCategoryName.toUpperCase();
    }
  }

  Widget _buildInitialHint() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0E5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_rounded,
                  size: 48, color: _primaryOrange),
            ),
            const SizedBox(height: 20),
            const Text(
              'Search for a worker',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A)),
            ),
            const SizedBox(height: 8),
            Text(
              'Type a name or skill above, or pick\na category to browse workers.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: Colors.grey.shade500, height: 1.5),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildLoading() {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 4,
      separatorBuilder: (ctx, idx) => const SizedBox(height: 14),
      itemBuilder: (ctx, idx) => _buildSkeletonCard(),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(width: 130, height: 14),
                const SizedBox(height: 8),
                _shimmerBox(width: 90, height: 12),
                const SizedBox(height: 12),
                _shimmerBox(width: 160, height: 10),
                const SizedBox(height: 8),
                _shimmerBox(width: 80, height: 26),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmerBox({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  Widget _buildEmpty(String query, String? category) {
    final label = category != null
        ? 'No $category workers found'
        : 'No results for "$query"';
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A)),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different keyword or category.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text(
              'Search failed',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A)),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => ref
                  .read(searchProvider.notifier)
                  .search(_controller.text, category: _selectedCategory, lat: _lat, lng: _lng),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildBottomSheetDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade500),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
          ],
        ),
      ],
    );
  }

  void _showWorkerDetails(BuildContext context, WorkerSearchResult worker) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: worker.imageUrl != null
                      ? Image.network(
                          worker.imageUrl!,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => _avatarFallback(worker.name),
                        )
                      : _avatarFallback(worker.name),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        worker.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        worker.profession,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 18),
                          const SizedBox(width: 4),
                          Text(
                            worker.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          if (worker.isVerified) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF0E5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.verified_outlined, color: _primaryOrange, size: 12),
                                  SizedBox(width: 4),
                                  Text(
                                    'Verified',
                                    style: TextStyle(
                                      color: _primaryOrange,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            _buildBottomSheetDetailRow(Icons.location_on_outlined, 'Location', worker.location),
            const SizedBox(height: 12),
            _buildBottomSheetDetailRow(Icons.monetization_on_outlined, 'Hourly Rate', 'LKR ${worker.hourlyRate} / hour'),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: const Text('Close', style: TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/client/chat/${worker.id}', extra: {'name': worker.name});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Message', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  //  Result list
  Widget _buildResults(List<WorkerSearchResult> workers) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: workers.length,
      separatorBuilder: (ctx, idx) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final worker = workers[index];
        return GestureDetector(
          onTap: () => _showWorkerDetails(context, worker),
          child: _buildWorkerCard(worker),
        );
      },
    );
  }

  Widget _buildWorkerCard(WorkerSearchResult worker) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: worker.imageUrl != null
                ? Image.network(
                    worker.imageUrl!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => _avatarFallback(worker.name),
                  )
                : _avatarFallback(worker.name),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        worker.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (worker.hourlyRate > 0)
                      Text(
                        'LKR ${worker.hourlyRate}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _primaryOrange,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      worker.profession,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (worker.hourlyRate > 0) ...[
                      Text(
                        'per hour',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade400),
                      ),
                    ],
                  ],
                ),
                if (worker.location.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 13, color: Colors.grey.shade400),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          worker.location,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_getDistanceString(worker) != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEBF5FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.navigation_outlined, size: 10, color: Colors.blue.shade700),
                              const SizedBox(width: 2),
                              Text(
                                _getDistanceString(worker)!,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Star rating
                    Row(
                      children: List.generate(5, (i) {
                        IconData icon;
                        if (i < worker.rating.floor()) {
                          icon = Icons.star_rounded;
                        } else if (i < worker.rating) {
                          icon = Icons.star_half_rounded;
                        } else {
                          icon = Icons.star_outline_rounded;
                        }
                        return Icon(icon,
                            color: const Color(0xFFFFC107), size: 16);
                      }),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      worker.rating.toStringAsFixed(1),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A)),
                    ),
                    const Spacer(),
                    if (worker.isVerified)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0E5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_outlined,
                                color: _primaryOrange, size: 13),
                            SizedBox(width: 4),
                            Text(
                              'Seva Verified',
                              style: TextStyle(
                                color: _primaryOrange,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(String name) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0E5),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: _primaryOrange,
        ),
      ),
    );
  }
}
