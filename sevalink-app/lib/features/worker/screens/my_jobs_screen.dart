import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'job_details_screen.dart';
import '../../../data/models/job.dart';
import '../../../core/themes/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/worker_feed_provider.dart';

// ─── Enums & Model ────────────────────────────────────────────────────────────

enum JobStatus { active, pending, completed }

class WorkerJob {
  final String id;
  final String title;
  final String clientName;
  final String location;
  final String date;
  final String budget;
  final JobStatus status;
  final String? category;

  const WorkerJob({
    required this.id,
    required this.title,
    required this.clientName,
    required this.location,
    required this.date,
    required this.budget,
    required this.status,
    this.category,
  });

  WorkerJob copyWith({JobStatus? status}) {
    return WorkerJob(
      id: id,
      title: title,
      clientName: clientName,
      location: location,
      date: date,
      budget: budget,
      status: status ?? this.status,
      category: category,
    );
  }
}

// ─── Jobs State Notifier ──────────────────────────────────────────────────────

class WorkerJobsListState {
  final List<WorkerJob> jobs;
  final bool isLoading;
  final String? error;

  const WorkerJobsListState({
    this.jobs = const [],
    this.isLoading = false,
    this.error,
  });

  WorkerJobsListState copyWith({
    List<WorkerJob>? jobs,
    bool? isLoading,
    String? error,
  }) {
    return WorkerJobsListState(
      jobs: jobs ?? this.jobs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class _WorkerJobsNotifier extends Notifier<WorkerJobsListState> {
  @override
  WorkerJobsListState build() {
    // Load jobs automatically when provider is read
    Future.microtask(() => loadJobs());
    return const WorkerJobsListState(isLoading: true);
  }

  Future<void> loadJobs() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dioClient = ref.read(dioClientProvider);
      final user = ref.read(authProvider).user;

      if (user == null) throw Exception('Not logged in');

      // Find worker profile by user id (from workerFeedProvider stats or workers API)
      int? workerId = ref.read(workerFeedProvider).stats.workerId;
      if (workerId == null || workerId == 0) {
        final workersResponse = await dioClient.dio.get('/workers');
        final List<dynamic> workersData = workersResponse.data;
        final workerEntry = workersData.firstWhere(
          (w) => w['user'] != null && w['user']['id'] == user.id,
          orElse: () => null,
        );
        if (workerEntry != null) {
          workerId = workerEntry['id'];
        }
      }

      if (workerId == null || workerId == 0) {
        throw Exception('Worker profile not found');
      }

      // Fetch worker quotations
      final response = await dioClient.dio.get('/quotations/worker/$workerId');
      final List<dynamic> data = response.data;

      final List<WorkerJob> jobsList = [];
      for (final item in data) {
        final statusStr = item['status'] ?? 'PENDING';
        if (statusStr == 'REJECTED') continue; // Skip rejected ones

        final jobPost = item['jobPost'];
        if (jobPost == null) continue;

        final jobPostId = jobPost['id']?.toString() ?? '0';
        final title = jobPost['title'] ?? '';
        final location = jobPost['locationName'] ?? jobPost['location'] ?? '';

        // Safely extract client name
        final clientMap = jobPost['client'];
        final clientName = clientMap != null ? (clientMap['fullName'] ?? 'Client') : 'Client';

        // Proposed price or budget
        final proposedPrice = item['proposedPrice'] ?? 0.0;
        final budgetStr = 'Rs. ${proposedPrice.toInt()}';

        final date = jobPost['createdAt'] != null
            ? jobPost['createdAt'].toString().split('T').first
            : '';

        final jobStatusStr = jobPost['status'] ?? 'OPEN';
        JobStatus status;
        if (statusStr == 'ACCEPTED') {
          if (jobStatusStr == 'COMPLETED') {
            status = JobStatus.completed;
          } else {
            status = JobStatus.active;
          }
        } else {
          status = JobStatus.pending;
        }

        final categoryMap = jobPost['category'];
        final categoryName = categoryMap is Map ? (categoryMap['name'] ?? '') : (categoryMap ?? '');

        jobsList.add(WorkerJob(
          id: jobPostId,
          title: title,
          clientName: clientName,
          location: location,
          date: date,
          budget: budgetStr,
          status: status,
          category: categoryName.isNotEmpty ? categoryName : null,
        ));
      }

      state = state.copyWith(jobs: jobsList, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Mark a job as completed (moves it to Done tab)
  Future<void> markDone(String id) async {
    try {
      final dioClient = ref.read(dioClientProvider);
      
      // Update job timeline to COMPLETED
      await dioClient.dio.put(
        '/jobs/detail/$id/timeline',
        queryParameters: {
          'status': 'COMPLETED',
          'note': 'Job completed by worker',
        },
      );

      // Refresh the local job list and the worker home feed stats
      await loadJobs();
      ref.read(workerFeedProvider.notifier).refresh();
    } catch (e) {
      // Propagation of error can be handled in UI or log
    }
  }
}

// Public so the home screen can watch the live active count
final workerJobsListProvider =
    NotifierProvider<_WorkerJobsNotifier, WorkerJobsListState>(
  _WorkerJobsNotifier.new,
);

// ─── Screen ───────────────────────────────────────────────────────────────────

class MyJobsScreen extends ConsumerStatefulWidget {
  final bool showBackButton;
  const MyJobsScreen({super.key, this.showBackButton = false});

  @override
  ConsumerState<MyJobsScreen> createState() => _MyJobsScreenState();
}

class _MyJobsScreenState extends ConsumerState<MyJobsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<WorkerJob> _byStatus(List<WorkerJob> all, JobStatus s) =>
      all.where((j) => j.status == s).toList();

  void _handleMarkDone(String id) {
    ref.read(workerJobsListProvider.notifier).markDone(id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Job marked as done!',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: const Color(0xFF0F9B8E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );

    // Animate to Done tab after short delay
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _tabController.animateTo(2);
    });
  }

  Widget _buildErrorView(String errorMsg) {
    final colors = Theme.of(context).extension<SevaLinkColors>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 54, color: Colors.redAccent.shade200),
            const SizedBox(height: 16),
            Text(
              'Failed to load jobs',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMsg.replaceAll('Exception: ', ''),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: colors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.read(workerJobsListProvider.notifier).loadJobs(),
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text('Try Again', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F9B8E),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobsState = ref.watch(workerJobsListProvider);
    final jobs      = jobsState.jobs;
    final isLoading = jobsState.isLoading;
    final error     = jobsState.error;

    final active    = _byStatus(jobs, JobStatus.active);
    final pending   = _byStatus(jobs, JobStatus.pending);
    final completed = _byStatus(jobs, JobStatus.completed);
    final colors    = Theme.of(context).extension<SevaLinkColors>()!;

    return Scaffold(
      backgroundColor: colors.bodyBg,
      body: Column(
        children: [
          // Header
          _buildHeader(active.length, pending.length, completed.length),

          // Tab content
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF0F9B8E)),
                  )
                : error != null
                    ? _buildErrorView(error)
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          // Active tab
                          _JobList(
                            jobs: active,
                            emptyLabel: 'No active jobs right now',
                            onMarkDone: (id) => _handleMarkDone(id),
                          ),
                          // Pending tab
                          _JobList(
                            jobs: pending,
                            emptyLabel: 'No upcoming jobs scheduled',
                            onViewDetails: (job) => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => JobDetailsScreen(
                                  job: Job(
                                    id: int.tryParse(job.id) ?? 0,
                                    title: job.title,
                                    description: 'No description available.',
                                    location: job.location,
                                    postedAt: job.date,
                                    minBudget: 0,
                                    maxBudget: 0,
                                    isNew: false,
                                    category: job.category ?? '',
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Done tab
                          _JobList(jobs: completed, emptyLabel: 'No completed jobs yet'),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int active, int pending, int completed) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFD3410A), Color(0xFFE8520B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Title row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  if (widget.showBackButton)
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  if (widget.showBackButton) const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'My Jobs',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Summary chips
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  _summaryChip('$active',    'Active', const Color(0xFF0F9B8E)),
                  const SizedBox(width: 10),
                  _summaryChip('$pending',   'To-Do',  const Color(0xFFF59E0B)),
                  const SizedBox(width: 10),
                  _summaryChip('$completed', 'Done',   Colors.white54),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Tabs
            TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              tabs: [
                Tab(text: 'Active ($active)'),
                Tab(text: 'To-Do ($pending)'),
                Tab(text: 'Done ($completed)'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(String count, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(count,
                style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ─── Job List ─────────────────────────────────────────────────────────────────

class _JobList extends StatelessWidget {
  final List<WorkerJob> jobs;
  final String emptyLabel;
  final void Function(String id)? onMarkDone;
  final void Function(WorkerJob job)? onViewDetails;

  const _JobList({
    required this.jobs,
    required this.emptyLabel,
    this.onMarkDone,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<SevaLinkColors>()!;

    if (jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_off_outlined,
                size: 64, color: colors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(emptyLabel,
                style: TextStyle(color: colors.textSecondary, fontSize: 15)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      itemCount: jobs.length,
      itemBuilder: (_, i) => _JobCard(
        job: jobs[i],
        onMarkDone:
            onMarkDone == null ? null : () => onMarkDone!(jobs[i].id),
        onViewDetails:
            onViewDetails == null ? null : () => onViewDetails!(jobs[i]),
      ),
    );
  }
}

// ─── Job Card ─────────────────────────────────────────────────────────────────

class _JobCard extends StatelessWidget {
  final WorkerJob job;
  final VoidCallback? onMarkDone;
  final VoidCallback? onViewDetails;
  const _JobCard({required this.job, this.onMarkDone, this.onViewDetails});

  Color get _statusColor {
    switch (job.status) {
      case JobStatus.active:    return const Color(0xFF0F9B8E);
      case JobStatus.pending:   return const Color(0xFFF59E0B);
      case JobStatus.completed: return const Color(0xFF6B7280);
    }
  }

  String get _statusLabel {
    switch (job.status) {
      case JobStatus.active:    return 'Active';
      case JobStatus.pending:   return 'To-Do';
      case JobStatus.completed: return 'Completed';
    }
  }

  IconData get _statusIcon {
    switch (job.status) {
      case JobStatus.active:    return Icons.play_circle_outline_rounded;
      case JobStatus.pending:   return Icons.schedule_rounded;
      case JobStatus.completed: return Icons.check_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<SevaLinkColors>()!;
    final isDark  = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: isDark
            ? Border.all(color: colors.border, width: 1)
            : null,
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
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_statusIcon, color: _statusColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job.title,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary)),
                      if (job.category != null) ...[
                        const SizedBox(height: 2),
                        Text(job.category!,
                            style: TextStyle(
                                fontSize: 12,
                                color: colors.textSecondary)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(
                        color: _statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            Divider(height: 1, color: colors.divider),
            const SizedBox(height: 12),

            // Details
            _infoRow(Icons.person_outline_rounded, job.clientName, colors),
            const SizedBox(height: 6),
            _infoRow(Icons.location_on_outlined, job.location, colors),
            const SizedBox(height: 6),
            _infoRow(Icons.calendar_today_outlined, job.date, colors),

            const SizedBox(height: 14),

            // Budget + action button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF006B5E).withValues(alpha: 0.2)
                        : const Color(0xFFE8F5F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    job.budget,
                    style: const TextStyle(
                        color: Color(0xFF006B5E),
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                ),
                const Spacer(),
                _actionButton(context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, SevaLinkColors colors) {
    return Row(
      children: [
        Icon(icon, size: 14, color: colors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: TextStyle(color: colors.textSecondary, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _actionButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (job.status) {
      case JobStatus.active:
        return ElevatedButton.icon(
          onPressed: onMarkDone,
          icon: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
          label: const Text('Mark Done',
              style: TextStyle(color: Colors.white, fontSize: 13)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F9B8E),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        );

      case JobStatus.pending:
        return OutlinedButton.icon(
          onPressed: onViewDetails,
          icon: const Icon(Icons.visibility_outlined,
              size: 15, color: Color(0xFFF59E0B)),
          label: const Text('View',
              style: TextStyle(color: Color(0xFFF59E0B), fontSize: 13)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            side: const BorderSide(color: Color(0xFFF59E0B)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        );

      case JobStatus.completed:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF2E3347)
                : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  size: 14,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF6B7280)),
              const SizedBox(width: 4),
              Text('Completed',
                  style: TextStyle(
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        );
    }
  }
}