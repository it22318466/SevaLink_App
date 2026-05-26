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
  int _currentNavIndex = 1; // Jobs tab
  int _selectedTabIndex = 0;
  final List<String> _tabs = ['All', 'Open', 'In Progress'];
  final List<String> _statusFilters = ['ALL', 'OPEN', 'ASSIGNED'];

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
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // Orange header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFD3410A), Color(0xFFE8520B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => context.go('/client/home'),
                    ),
                    const Expanded(
                      child: Text(
                        'My Jobs',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.white),
                      onPressed: () {
                        context.push('/client/jobs/post');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Stats row
          Container(
            color: const Color(0xFFE8520B),
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: statsAsync.when(
              data: (stats) => Row(
                children: [
                  _buildStatPill('${stats['total'] ?? 0}', 'Total', const Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  _buildStatPill('${stats['open'] ?? 0}', 'Open', const Color(0xFF22C55E)),
                  const SizedBox(width: 8),
                  _buildStatPill('${stats['active'] ?? 0}', 'Active', const Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  _buildStatPill('${stats['done'] ?? 0}', 'Done', const Color(0xFF22C55E)),
                ],
              ),
              loading: () => const Center(
                child: SizedBox(
                  height: 50,
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
              error: (_, __) => Row(
                children: [
                  _buildStatPill('0', 'Total', const Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  _buildStatPill('0', 'Open', const Color(0xFF22C55E)),
                  const SizedBox(width: 8),
                  _buildStatPill('0', 'Active', const Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  _buildStatPill('0', 'Done', const Color(0xFF22C55E)),
                ],
              ),
            ),
          ),

          // Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: List.generate(_tabs.length, (index) {
                  final isSelected = _selectedTabIndex == index;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTabIndex = index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFD3410A) : Colors.transparent,
                          borderRadius: BorderRadius.circular(25),
                          border: isSelected
                              ? null
                              : Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            if (index == 0 || index == 2)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Icon(
                                  Icons.show_chart,
                                  size: 16,
                                  color: isSelected ? Colors.white : Colors.grey.shade600,
                                ),
                              ),
                            if (index == 1)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: isSelected ? Colors.white : Colors.grey.shade600,
                                ),
                              ),
                            Text(
                              _tabs[index],
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey.shade700,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          // Job count + Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                jobsAsync.when(
                  data: (jobs) => Text(
                    '${jobs.length} Jobs',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  loading: () => const Text('Loading...'),
                  error: (_, __) => const Text('0 Jobs'),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.filter_list, size: 18, color: Colors.grey.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Filter',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Job list
          Expanded(
            child: jobsAsync.when(
              data: (jobs) => jobs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.work_off_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'No jobs found',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: jobs.length,
                      itemBuilder: (context, index) => _buildJobCard(jobs[index]),
                    ),
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFD3410A))),
              error: (e, _) => Center(
                child: Text('Error loading jobs: $e'),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildStatPill(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
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

    Color statusColor;
    switch (status) {
      case 'OPEN':
        statusColor = const Color(0xFF22C55E);
        break;
      case 'ASSIGNED':
        statusColor = const Color(0xFFF59E0B);
        break;
      case 'COMPLETED':
        statusColor = const Color(0xFF3B82F6);
        break;
      default:
        statusColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + Status badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  job['title'] ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status == 'ASSIGNED' ? 'Active' : status[0] + status.substring(1).toLowerCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Category
          Text(
            job['categoryName'] ?? 'General',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),

          // Description
          if (job['description'] != null && job['description'].toString().isNotEmpty)
            Text(
              job['description'],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          const SizedBox(height: 10),

          // Urgency badge
          if (urgency == 'URGENT')
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                'Urgent',
                style: TextStyle(
                  color: Colors.red.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          // Budget + Time + Quotes
          Row(
            children: [
              if (budgetMin != null && budgetMax != null)
                Text(
                  'Rs. ${_formatBudget(budgetMin)} - Rs. ${_formatBudget(budgetMax)}',
                  style: const TextStyle(
                    color: Color(0xFFD3410A),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const Spacer(),
              if (createdAt != null)
                Text(
                  _timeAgo(createdAt),
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              if (quoteCount > 0) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('•', style: TextStyle(color: Colors.grey.shade400)),
                ),
                Text(
                  '$quoteCount\nQuotes',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF22C55E),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
        selectedItemColor: const Color(0xFF22C55E), // user requested Jobs icon should be green
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
