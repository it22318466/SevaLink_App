import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/models/job.dart';
import '../../../core/themes/app_theme.dart';
import '../../../providers/auth_provider.dart';

class JobDetailsScreen extends ConsumerStatefulWidget {
  final Job job;
  /// When false the "Send Quote" button is hidden (worker already sent a quote).
  final bool showSendQuote;

  const JobDetailsScreen({super.key, required this.job, this.showSendQuote = true});

  @override
  ConsumerState<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends ConsumerState<JobDetailsScreen> {
  late Job _currentJob;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentJob = widget.job;
    // Fetch details if we have partial information (description is default empty/mocked, or clientId is null)
    if (_currentJob.description.isEmpty || 
        _currentJob.description == 'No description available.' || 
        _currentJob.clientId == null) {
      _fetchDetails();
    }
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioClientProvider).dio;
      final response = await dio.get('/jobs/detail/${widget.job.id}');
      if (mounted && response.statusCode == 200 && response.data != null) {
        setState(() {
          _currentJob = Job.fromJson(response.data);
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load job details');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _openMap(double? lat, double? lng, String location, BuildContext context) async {
    final query = (lat != null && lng != null) ? '$lat,$lng' : Uri.encodeComponent(location);
    final Uri mapUrl = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$query');
    try {
      await launchUrl(mapUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open map: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<SevaLinkColors>() ?? SevaLinkColors.light;
    return Scaffold(
      backgroundColor: colors.bodyBg,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show fetch-error banner when details failed to load
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.fromLTRB(0, 16, 0, 0),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded,
                              color: Colors.red.shade400, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Could not load full details. Showing partial info.',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.red.shade700),
                            ),
                          ),
                          GestureDetector(
                            onTap: _fetchDetails,
                            child: Text('Retry',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  _buildStatusRow(context),
                  const SizedBox(height: 20),
                  _buildBudgetCard(),
                  const SizedBox(height: 20),
                  _buildSection(
                    context: context,
                    title: 'Job Description',
                    icon: Icons.description_outlined,
                    child: _isLoading && _currentJob.description == 'No description available.'
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: CircularProgressIndicator(color: Color(0xFFD3410A)),
                            ),
                          )
                        : Text(
                            _currentJob.description,
                            style: TextStyle(
                              fontSize: 15,
                              color: colors.textSecondary,
                              height: 1.7,
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => _openMap(_currentJob.latitude, _currentJob.longitude, _currentJob.location, context),
                    child: _buildSection(
                      context: context,
                      title: 'Location',
                      icon: Icons.location_on_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5F2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.map_outlined,
                                    color: Color(0xFF006B5E), size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _currentJob.location,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Tap to view on full map',
                                      style: TextStyle(
                                          fontSize: 13, color: Color(0xFF006B5E)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          AbsorbPointer(
                            child: _EmbeddedMap(
                              location: _currentJob.location,
                              latitude: _currentJob.latitude,
                              longitude: _currentJob.longitude,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    context: context,
                    title: 'Job Details',
                    icon: Icons.info_outline_rounded,
                    child: Column(
                      children: [
                        _buildDetailRow(context,
                            Icons.category_outlined, 'Category', _currentJob.category),
                        const SizedBox(height: 12),
                        _buildDetailRow(context,
                            Icons.access_time_rounded, 'Posted', _currentJob.postedAt),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                            context,
                            Icons.new_releases_outlined,
                            'Status',
                            _currentJob.isNew ? 'Newly Posted' : 'Active'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildClientCard(context),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: const Color(0xFFD3410A),
      leading: GestureDetector(
        onTap: () => context.pop(),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.bookmark_border_rounded,
                color: Colors.white, size: 20),
            onPressed: () {},
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFD3410A), Color(0xFFE8520B)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_currentJob.isNew)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C896),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'New',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  Text(
                    _currentJob.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow(BuildContext context) {
    return Row(
      children: [
        _buildChip(context,
            Icons.location_on_outlined, _currentJob.location, const Color(0xFFD3410A)),
        const SizedBox(width: 10),
        _buildChip(context, Icons.access_time_rounded, _currentJob.postedAt,
            const Color(0xFF6B7280)),
      ],
    );
  }

  Widget _buildChip(BuildContext context, IconData icon, String label, Color color) {
    final colors = Theme.of(context).extension<SevaLinkColors>() ?? SevaLinkColors.light;
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: colors.border) : null,
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF006B5E), Color(0xFF00897B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF006B5E).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text(
            'Rs.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Budget Range',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                '${_currentJob.minBudget} - ${_currentJob.maxBudget}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final colors = Theme.of(context).extension<SevaLinkColors>() ?? SevaLinkColors.light;
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: colors.border, width: 1) : null,
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFFD3410A)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: colors.divider),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value) {
    final colors = Theme.of(context).extension<SevaLinkColors>() ?? SevaLinkColors.light;
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? colors.cardBg2 : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: colors.textSecondary),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: colors.textSecondary)),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildClientCard(BuildContext context) {
    final colors = Theme.of(context).extension<SevaLinkColors>() ?? SevaLinkColors.light;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final clientName = _currentJob.clientName ?? 'Client';
    final avatarChar = clientName.isNotEmpty ? clientName[0].toUpperCase() : 'C';
    final isPhoneVerified = _currentJob.clientPhone != null;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: colors.border, width: 1) : null,
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline_rounded,
                  size: 18, color: Color(0xFFD3410A)),
              const SizedBox(width: 8),
              Text(
                'Posted By',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: colors.divider),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFFE8EAF6),
                child: Text(
                  avatarChar,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD3410A),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientName,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          isPhoneVerified ? Icons.verified_outlined : Icons.info_outline,
                          size: 14,
                          color: const Color(0xFF006B5E),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isPhoneVerified ? 'Verified Client' : 'Client Profile',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF006B5E)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_currentJob.clientId != null)
                GestureDetector(
                  onTap: () {
                    context.push('/client/chat/${_currentJob.clientId}', extra: {
                      'name': clientName,
                      'jobTitle': _currentJob.title,
                      'jobBudget': 'Rs. ${_currentJob.minBudget} - ${_currentJob.maxBudget}'
                    });
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF006B5E), width: 1),
                    ),
                    child: const Text(
                      'Message',
                      style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF006B5E),
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final colors = Theme.of(context).extension<SevaLinkColors>() ?? SevaLinkColors.light;
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: colors.cardBg,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Go Back button — always present
          Expanded(
            flex: widget.showSendQuote ? 1 : 2,
            child: OutlinedButton(
              onPressed: () => context.pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD3410A),
                side: const BorderSide(color: Color(0xFFD3410A), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Go Back',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
          // Send Quote button — only shown when worker has not yet sent a quote
          if (widget.showSendQuote) ...[
            const SizedBox(width: 14),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () {
                  context.push('/worker/send-quote', extra: _currentJob);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006B5E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.send_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Send Quote',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmbeddedMap extends StatefulWidget {
  final String location;
  final double? latitude;
  final double? longitude;

  const _EmbeddedMap({
    required this.location,
    this.latitude,
    this.longitude,
  });

  @override
  State<_EmbeddedMap> createState() => _EmbeddedMapState();
}

class _EmbeddedMapState extends State<_EmbeddedMap> {
  LatLng? _target;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCoordinates();
  }

  @override
  void didUpdateWidget(_EmbeddedMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude ||
        oldWidget.location != widget.location) {
      _loadCoordinates();
    }
  }

  Future<void> _loadCoordinates() async {
    if (widget.latitude != null && widget.longitude != null) {
      if (mounted) {
        setState(() {
          _target = LatLng(widget.latitude!, widget.longitude!);
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final locations = await locationFromAddress(widget.location);
      if (locations.isNotEmpty) {
        if (mounted) {
          setState(() {
            _target = LatLng(locations.first.latitude, locations.first.longitude);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 150,
        child: Center(child: CircularProgressIndicator(color: Color(0xFF006B5E))),
      );
    }
    
    if (_target == null) {
      return SizedBox(
        height: 150,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_off_rounded, color: Colors.grey, size: 30),
              const SizedBox(height: 8),
              Text(
                'Could not load map for ${widget.location}',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: _target!, zoom: 14),
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          markers: {
            Marker(
              markerId: const MarkerId('job_location'),
              position: _target!,
            )
          },
        ),
      ),
    );
  }
}
