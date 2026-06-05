import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../data/models/job.dart';
import 'auth_provider.dart';

// ─── Worker Stats (from GET /api/workers/{id}) ───────────────────────────────

class WorkerStats {
  final int totalJobs;
  final double rating;
  final int? workerId; // backend worker row ID (different from user ID)
  final String fullName;
  final String phoneNumber;
  final String location;
  final String bio;
  final List<String> skills;
  final String hourlyRate;
  final String? profileImageUrl;
  final int? categoryId;
  final String? categoryName;
  final double? latitude;
  final double? longitude;

  const WorkerStats({
    this.totalJobs = 0,
    this.rating = 0.0,
    this.workerId,
    this.fullName = '',
    this.phoneNumber = '',
    this.location = '',
    this.bio = '',
    this.skills = const [],
    this.hourlyRate = '',
    this.profileImageUrl,
    this.categoryId,
    this.categoryName,
    this.latitude,
    this.longitude,
  });

  WorkerStats copyWith({
    int? totalJobs,
    double? rating,
    int? workerId,
    String? fullName,
    String? phoneNumber,
    String? location,
    String? bio,
    List<String>? skills,
    String? hourlyRate,
    String? profileImageUrl,
    int? categoryId,
    String? categoryName,
    double? latitude,
    double? longitude,
    bool clearProfileImageUrl = false,
  }) {
    return WorkerStats(
      totalJobs: totalJobs ?? this.totalJobs,
      rating: rating ?? this.rating,
      workerId: workerId ?? this.workerId,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      location: location ?? this.location,
      bio: bio ?? this.bio,
      skills: skills ?? this.skills,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      profileImageUrl: clearProfileImageUrl ? null : (profileImageUrl ?? this.profileImageUrl),
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

// ─── Feed State ───────────────────────────────────────────────────────────────

class WorkerFeedState {
  final List<Job> jobs;
  final bool isLoading;
  final String? error;
  final WorkerStats stats;

  const WorkerFeedState({
    this.jobs = const [],
    this.isLoading = false,
    this.error,
    this.stats = const WorkerStats(),
  });

  WorkerFeedState copyWith({
    List<Job>? jobs,
    bool? isLoading,
    String? error,
    WorkerStats? stats,
  }) {
    return WorkerFeedState(
      jobs: jobs ?? this.jobs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      stats: stats ?? this.stats,
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class WorkerFeedNotifier extends Notifier<WorkerFeedState> {
  @override
  WorkerFeedState build() {
    // Watch authProvider so we rebuild/reload whenever auth state changes (login/logout)
    final authState = ref.watch(authProvider);

    if (authState.user == null) {
      return const WorkerFeedState();
    }

    // Automatically load feed when provider is first read or auth changes
    Future.microtask(() => loadFeed());
    return const WorkerFeedState(isLoading: true);
  }

  Future<void> loadFeed() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dio = ref.read(dioClientProvider).dio;

      // ── Step 1: Fetch worker profile to get category + GPS coords ─────────
      WorkerStats stats = state.stats; // keep existing stats if refresh
      final user = ref.read(authProvider).user;

      if (user != null) {
        try {
          debugPrint('loadFeed: current user: id=${user.id}, name=${user.fullName}, role=${user.role}');
          final workersResponse = await dio.get('/workers');
          final List<dynamic> workersData = workersResponse.data;
          debugPrint('loadFeed: fetched ${workersData.length} workers');

          final workerEntry = workersData.firstWhere(
            (w) => w['user'] != null && w['user']['id'].toString() == user.id.toString(),
            orElse: () => null,
          );
          debugPrint('loadFeed: matched worker entry: $workerEntry');

          if (workerEntry != null) {
            final userEntry = workerEntry['user'] ?? {};
            final String skillsString = workerEntry['skills'] as String? ?? '';
            final List<String> parsedSkills = skillsString
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();

            stats = WorkerStats(
              totalJobs: workerEntry['totalJobs'] ?? 0,
              rating: (workerEntry['rating'] ?? 0.0).toDouble(),
              workerId: workerEntry['id'],
              fullName: userEntry['fullName'] ?? '',
              phoneNumber: userEntry['phoneNumber'] ?? '',
              location: userEntry['location'] ?? '',
              bio: workerEntry['bio'] ?? '',
              skills: parsedSkills,
              hourlyRate: workerEntry['hourlyRate']?.toString() ?? '',
              profileImageUrl: userEntry['profileImageUrl'],
              categoryId: workerEntry['category']?['id'],
              categoryName: workerEntry['category']?['name'],
              latitude: workerEntry['latitude'] != null ? (workerEntry['latitude'] as num).toDouble() : null,
              longitude: workerEntry['longitude'] != null ? (workerEntry['longitude'] as num).toDouble() : null,
            );
          }
        } catch (e, stack) {
          debugPrint('Error fetching worker profile: $e');
          debugPrint(stack.toString());
        }
      }

      // ── Step 2: Build query params from worker profile ────────────────────
      final queryParams = <String, dynamic>{};

      // Filter by the worker's category so they see relevant jobs
      if (stats.categoryId != null) {
        queryParams['categoryId'] = stats.categoryId;
      }

      // Include worker's GPS coords so nearby jobs appear first
      if (stats.latitude != null && stats.longitude != null) {
        queryParams['lat'] = stats.latitude;
        queryParams['lng'] = stats.longitude;
        queryParams['radius'] = 25.0; // 25 km feed radius
      }

      // ── Step 3: Fetch job feed with smart filters ─────────────────────────
      final jobsResponse = await dio.get('/jobs/feed', queryParameters: queryParams);
      final List<dynamic> jobsData = jobsResponse.data;
      final jobs = jobsData.map((json) => Job.fromJson(json)).toList();

      state = state.copyWith(
        jobs: jobs,
        isLoading: false,
        stats: stats,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> updateWorkerProfile({
    required String fullName,
    required String phoneNumber,
    required String location,
    required String bio,
    required List<String> skills,
    required String hourlyRate,
    int? categoryId,
    double? latitude,
    double? longitude,
  }) async {
    final workerId = state.stats.workerId;
    if (workerId == null) throw Exception('Worker ID not found');

    final dio = ref.read(dioClientProvider).dio;
    final rateDouble = double.tryParse(hourlyRate.replaceAll(',', '')) ?? 0.0;

    final response = await dio.put(
      '/workers/$workerId/profile',
      data: {
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'location': location,
        'bio': bio,
        'skills': skills.join(','),
        'hourlyRate': rateDouble,
        'categoryId': categoryId,
        'latitude': latitude,
        'longitude': longitude,
      },
    );

    if (response.statusCode == 200) {
      final updatedWorker = response.data;
      final userEntry = updatedWorker['user'] ?? {};
      final String skillsString = updatedWorker['skills'] as String? ?? '';
      final List<String> parsedSkills = skillsString
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      state = state.copyWith(
        stats: state.stats.copyWith(
          fullName: userEntry['fullName'] ?? '',
          phoneNumber: userEntry['phoneNumber'] ?? '',
          location: userEntry['location'] ?? '',
          bio: updatedWorker['bio'] ?? '',
          skills: parsedSkills,
          hourlyRate: updatedWorker['hourlyRate']?.toString() ?? '',
          profileImageUrl: userEntry['profileImageUrl'],
          categoryId: updatedWorker['category']?['id'],
          categoryName: updatedWorker['category']?['name'],
          latitude: updatedWorker['latitude'] != null ? (updatedWorker['latitude'] as num).toDouble() : null,
          longitude: updatedWorker['longitude'] != null ? (updatedWorker['longitude'] as num).toDouble() : null,
        ),
      );
    } else {
      throw Exception('Failed to update worker profile');
    }
  }

  Future<void> uploadWorkerProfileImage(String filePath, String fileName, List<int> bytes) async {
    final workerId = state.stats.workerId;
    if (workerId == null) throw Exception('Worker ID not found');

    final dio = ref.read(dioClientProvider).dio;

    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });

    final response = await dio.post(
      '/workers/$workerId/profile/image',
      data: formData,
    );

    if (response.statusCode == 200) {
      final updatedWorker = response.data;
      final userEntry = updatedWorker['user'] ?? {};

      state = state.copyWith(
        stats: state.stats.copyWith(
          profileImageUrl: userEntry['profileImageUrl'],
        ),
      );
    } else {
      throw Exception('Failed to upload profile image');
    }
  }

  /// Pull-to-refresh
  Future<void> refresh() => loadFeed();
}

final workerFeedProvider =
    NotifierProvider<WorkerFeedNotifier, WorkerFeedState>(
  WorkerFeedNotifier.new,
);
