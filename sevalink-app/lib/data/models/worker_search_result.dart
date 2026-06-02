class WorkerSearchResult {
  final int id;
  final String name;
  final String profession;
  final double rating;
  final int hourlyRate;
  final String location;
  final bool isVerified;
  final String? imageUrl;

  const WorkerSearchResult({
    required this.id,
    required this.name,
    required this.profession,
    required this.rating,
    required this.hourlyRate,
    required this.location,
    required this.isVerified,
    this.imageUrl,
  });

  factory WorkerSearchResult.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? {};
    final category = json['category'] as Map<String, dynamic>? ?? {};

    return WorkerSearchResult(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: user['fullName'] as String? ?? 'Unknown',
      profession: category['name'] as String? ?? 'Unknown',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      hourlyRate: (json['hourlyRate'] as num?)?.toInt() ?? 0,
      location: user['location'] as String? ?? 'Unknown Location',
      isVerified: user['isPhoneVerified'] as bool? ?? false,
      imageUrl: user['profileImageUrl'] as String?,
    );
  }
}
