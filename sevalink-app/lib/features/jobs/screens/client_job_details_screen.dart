import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/client_jobs_provider.dart';
import '../../../providers/quotation_provider.dart';
import '../../../core/constants/api_endpoints.dart';

class ClientJobDetailsScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> job;

  const ClientJobDetailsScreen({super.key, required this.job});

  @override
  ConsumerState<ClientJobDetailsScreen> createState() => _ClientJobDetailsScreenState();
}

class _ClientJobDetailsScreenState extends ConsumerState<ClientJobDetailsScreen> {
  bool _isLoading = false;
  bool _hasRated = false;

  @override
  void initState() {
    super.initState();
    if (widget.job['status'] == 'COMPLETED') {
      _checkIfRated();
    }
  }

  Future<void> _checkIfRated() async {
    try {
      final user = ref.read(authProvider).user;
      final dio = Dio(BaseOptions(baseUrl: ApiEndpoints.baseUrl));
      final res = await dio.get('/reviews/check?clientId=${user?.id}&jobId=${widget.job['id']}');
      if (mounted) {
        setState(() {
          _hasRated = res.data['hasReviewed'] ?? false;
        });
      }
    } catch (e) {
      // Ignore error for now
    }
  }

  Future<void> _deleteJob() async {
    final reasonController = TextEditingController();
    String selectedReason = 'Found someone else';

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Delete Job'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Are you sure you want to delete this job? Please provide a reason.'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedReason,
                items: const [
                  DropdownMenuItem(value: 'Found someone else', child: Text('Found someone else')),
                  DropdownMenuItem(value: 'No longer needed', child: Text('No longer needed')),
                  DropdownMenuItem(value: 'Created by mistake', child: Text('Created by mistake')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedReason = val);
                },
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              if (selectedReason == 'Other') ...[
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    hintText: 'Please describe your reason',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                final reason = selectedReason == 'Other'
                    ? (reasonController.text.trim().isEmpty ? 'Other' : reasonController.text.trim())
                    : selectedReason;
                Navigator.of(dialogContext).pop(reason);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result is String) {
      setState(() => _isLoading = true);
      try {
        final user = ref.read(authProvider).user;
        final dio = Dio(BaseOptions(baseUrl: ApiEndpoints.baseUrl));
        await dio.put('/jobs/${widget.job['id']}/delete?clientId=${user?.id}', data: {'reason': result});
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Job deleted successfully')));
          ref.invalidate(clientJobsProvider);
          ref.invalidate(clientJobStatsProvider);
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.job['status'] ?? 'OPEN';
    final isCompleted = status == 'COMPLETED';
    final isOpen = status == 'OPEN';

    final quotesAsync = ref.watch(jobQuotationsProvider(widget.job['id']));
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Job Details'),
        backgroundColor: const Color(0xFFE64A19),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.job['title'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Category: ${widget.job['categoryName'] ?? ''}', style: TextStyle(color: Colors.grey.shade600)),
                        const SizedBox(height: 16),
                        const Text('Description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(widget.job['description'] ?? ''),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(status, style: TextStyle(color: status == 'OPEN' ? Colors.blue : (status == 'COMPLETED' ? Colors.green : Colors.orange), fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Budget', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text('Rs. ${widget.job['budgetMin']} - ${widget.job['budgetMax']}', style: const TextStyle(color: Color(0xFFE64A19), fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  if (isCompleted) ...[
                    const SizedBox(height: 24),
                    quotesAsync.when(
                      data: (quotes) {
                        final acceptedQuote = quotes.where((q) => q.status == 'ACCEPTED').firstOrNull;
                        if (acceptedQuote != null) {
                          if (_hasRated) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('Review Submitted', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            );
                          } else {
                            return SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await context.push('/client/rate-worker/${acceptedQuote.workerId}/${widget.job['id']}');
                                  _checkIfRated();
                                },
                                icon: const Icon(Icons.star_outline),
                                label: const Text('Rate Worker', style: TextStyle(fontSize: 16)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            );
                          }
                        }
                        return const SizedBox();
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => const SizedBox(),
                    ),
                  ],
                  
                  if (isOpen) ...[
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _deleteJob,
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        label: const Text('Delete Job', style: TextStyle(color: Colors.red, fontSize: 16)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
