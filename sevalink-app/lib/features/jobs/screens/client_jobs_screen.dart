import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/client_jobs_provider.dart';
import '../../../providers/auth_provider.dart';

class ClientJobsScreen extends ConsumerStatefulWidget {
  const ClientJobsScreen({super.key});

  @override
  ConsumerState<ClientJobsScreen> createState() => _ClientJobsScreenState();
}

class _ClientJobsScreenState extends ConsumerState<ClientJobsScreen> {
  final int _currentNavIndex = 1; // Jobs tab
  int _selectedTabIndex = 0;
  final List<String> _statusFilters = ['OPEN', 'ASSIGNED', 'COMPLETED', 'CANCELLED'];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onNavTapped(int index) {
    if (index == _currentNavIndex) return;
    switch (index) {
      case 0:
        context.go('/client/home');
        break;
      case 1:
        break; // Already here
      case 2:
        context.go('/client/chat');
        break;
      case 3:
        context.go('/client/profile');
        break;
    }
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24) return '${diff.inHours} hours ago';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      return '${(diff.inDays / 7).floor()} weeks ago';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final clientId = user?.id ?? 0;
    final statsAsync = ref.watch(clientJobStatsProvider(clientId));
    final jobsAsync = ref.watch(clientJobsProvider(ClientJobsParams(
      clientId: clientId,
      status: _statusFilters[_selectedTabIndex],
    )));

    return Scaffold(
      backgroundColor: const Color(0xFFE64A19), // Deep orange background for top
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => context.go('/client/home'),
                      ),
                      const Text(
                        'My Jobs',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.add, color: Colors.white),
                          onPressed: () => context.push('/client/jobs/post'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Stats Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: statsAsync.when(
                    data: (stats) => Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatSquare('${stats['total'] ?? 0}', 'Total'),
                        _buildStatSquare('${stats['open'] ?? 0}', 'Open'),
                        _buildStatSquare('${stats['active'] ?? 0}', 'Active'),
                        _buildStatSquare('${stats['done'] ?? 0}', 'Done'),
                      ],
                    ),
                    loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator(color: Colors.white))),
                    error: (err, stack) => Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatSquare('0', 'Total'),
                        _buildStatSquare('0', 'Open'),
                        _buildStatSquare('0', 'Active'),
                        _buildStatSquare('0', 'Done'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          
          // White Overlap Container (Tabs & Jobs)
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8F9FA),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  // Tabs without scrollbar
                  Padding(
                    padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildTabItem(0, 'Open', null),
                          const SizedBox(width: 16),
                          _buildTabItem(1, 'In Progress', null),
                          const SizedBox(width: 16),
                          _buildTabItem(2, 'Completed', Icons.check_circle_outline),
                          const SizedBox(width: 16),
                          _buildTabItem(3, 'Cancelled', Icons.cancel_outlined),
                        ],
                      ),
                    ),
                  ),
                  
                  // Job count + Filter
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        jobsAsync.when(
                          data: (jobs) => Text(
                            '${jobs.length} Jobs',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          loading: () => const Text('Loading...'),
                          error: (err, stack) => const Text('0 Jobs'),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.filter_alt_outlined, size: 18, color: Colors.grey.shade700),
                              const SizedBox(width: 6),
                              Text(
                                'Filter',
                                style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                        style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
                        decoration: InputDecoration(
                          hintText: 'Search jobs by title, description...',
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFE64A19), size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                  child: Icon(Icons.close_rounded, color: Colors.grey.shade400, size: 18),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  
                  // Job list
                  Expanded(
                    child: jobsAsync.when(
                      data: (jobs) {
                        final filteredJobs = jobs.where((job) {
                          if (_searchQuery.isEmpty) return true;
                          final q = _searchQuery.toLowerCase();
                          final title = (job['title'] ?? '').toLowerCase();
                          final desc = (job['description'] ?? '').toLowerCase();
                          final cat = (job['categoryName'] ?? '').toLowerCase();
                          return title.contains(q) || desc.contains(q) || cat.contains(q);
                        }).toList();

                        if (filteredJobs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _searchQuery.isEmpty ? Icons.work_off_outlined : Icons.search_off_rounded,
                                  size: 64,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isEmpty ? 'No jobs found' : 'No matching jobs found',
                                  style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          physics: const BouncingScrollPhysics(),
                          itemCount: filteredJobs.length,
                          itemBuilder: (context, index) => _buildJobCard(filteredJobs[index]),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFD3410A))),
                      error: (e, _) => Center(child: Text('Error loading jobs: $e')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildStatSquare(String value, String label) {
    return Container(
      width: 75,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String title, IconData? icon) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 18,
                color: isSelected ? const Color(0xFF1F2937) : Colors.grey.shade500,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              title,
              style: TextStyle(
                color: isSelected ? const Color(0xFF1F2937) : Colors.grey.shade500,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final status = job['status'] ?? 'OPEN';
    final urgency = job['urgency'] ?? 'FLEXIBLE';
    final budgetMin = job['budgetMin'];
    final budgetMax = job['budgetMax'];
    final quoteCount = job['quoteCount'] ?? 0;
    final createdAt = job['createdAt']?.toString();
    final categoryName = job['categoryName'] ?? 'General';
    final title = job['title'] ?? 'Untitled Job';
    final description = job['description'] ?? 'No description provided';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case 'OPEN':
        statusColor = const Color(0xFF0F9B8E);
        statusLabel = 'Open';
        statusIcon = Icons.search_rounded;
        break;
      case 'ASSIGNED':
        statusColor = const Color(0xFFF59E0B);
        statusLabel = 'Active';
        statusIcon = Icons.play_circle_outline_rounded;
        break;
      case 'COMPLETED':
        statusColor = const Color(0xFF6B7280);
        statusLabel = 'Completed';
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      case 'CANCELLED':
      default:
        statusColor = const Color(0xFFEF4444);
        statusLabel = 'Cancelled';
        statusIcon = Icons.cancel_outlined;
        break;
    }

    return GestureDetector(
      onTap: () {
        if (job['id'] != null) {
          context.push('/client/jobs/${job['id']}/details', extra: job);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isDark ? Border.all(color: const Color(0xFF334155), width: 1) : null,
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category icon
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1F2937),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          categoryName,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: isDark ? const Color(0xFF334155) : Colors.grey.shade100),
              const SizedBox(height: 12),
              
              // Details
              _infoRow(
                Icons.description_outlined,
                description,
                isDark,
                maxLines: 2,
              ),
              const SizedBox(height: 6),
              if (urgency == 'URGENT') ...[
                _infoRow(
                  Icons.warning_amber_rounded,
                  'Urgent Request',
                  isDark,
                  iconColor: const Color(0xFFEF4444),
                  textColor: const Color(0xFFEF4444),
                ),
                const SizedBox(height: 6),
              ],
              _infoRow(
                Icons.calendar_today_outlined,
                createdAt != null ? 'Posted ${_timeAgo(createdAt)}' : 'Recently',
                isDark,
              ),
              
              const SizedBox(height: 14),
              
              // Budget + Quotes Action
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF006B5E).withValues(alpha: 0.2)
                          : const Color(0xFFE8F5F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Rs. ${_formatBudget(budgetMin)} - ${_formatBudget(budgetMax)}',
                      style: const TextStyle(
                        color: Color(0xFF006B5E),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (status == 'OPEN')
                    OutlinedButton.icon(
                      onPressed: () {
                        if (job['id'] != null) {
                          context.push('/client/jobs/${job['id']}/quotes', extra: job);
                        }
                      },
                      icon: const Icon(Icons.request_quote_outlined, size: 15, color: Color(0xFFD3410A)),
                      label: Text(
                        '$quoteCount Quote${quoteCount == 1 ? '' : 's'}',
                        style: const TextStyle(color: Color(0xFFD3410A), fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        side: const BorderSide(color: Color(0xFFD3410A)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () {
                        if (job['id'] != null) {
                          context.push('/client/jobs/${job['id']}/details', extra: job);
                        }
                      },
                      icon: const Icon(Icons.visibility_outlined, size: 15, color: Color(0xFF6B7280)),
                      label: const Text(
                        'View',
                        style: TextStyle(color: Color(0xFF6B7280), fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        side: const BorderSide(color: Color(0xFF6B7280)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

  Widget _infoRow(IconData icon, String text, bool isDark, {int maxLines = 1, Color? iconColor, Color? textColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 14, color: iconColor ?? (isDark ? Colors.grey.shade500 : Colors.grey.shade400)),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: textColor ?? (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              fontSize: 13,
            ),
            maxLines: maxLines,
            overflow: maxLines == 1 ? TextOverflow.ellipsis : null,
          ),
        ),
      ],
    );
  }

  String _formatBudget(dynamic amount) {
    if (amount == null) return '0';
    final num = amount is double ? amount.toInt() : amount as int;
    if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(num % 1000 == 0 ? 0 : 1)}K'.replaceAll('.0K', ',000');
    }
    return num.toString();
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        onTap: _onNavTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 0,
        selectedItemColor: const Color(0xFF006B3D),
        unselectedItemColor: Colors.grey.shade400,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, height: 1.5),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12, height: 1.5),
        items: const [
          BottomNavigationBarItem(
            icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.home_outlined)),
            activeIcon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.home_rounded)),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.work_outline_rounded)),
            activeIcon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.work_rounded)),
            label: 'Jobs',
          ),
          BottomNavigationBarItem(
            icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.chat_bubble_outline_rounded)),
            activeIcon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.chat_bubble_rounded)),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.person_outline_rounded)),
            activeIcon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.person_rounded)),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
