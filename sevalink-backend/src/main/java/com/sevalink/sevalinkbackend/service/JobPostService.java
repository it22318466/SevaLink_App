package com.sevalink.sevalinkbackend.service;

import com.sevalink.sevalinkbackend.model.JobPost;
import com.sevalink.sevalinkbackend.model.JobTimeline;
import com.sevalink.sevalinkbackend.repository.JobPostRepository;
import com.sevalink.sevalinkbackend.repository.JobTimelineRepository;
import com.sevalink.sevalinkbackend.repository.QuotationRepository;
import com.sevalink.sevalinkbackend.repository.WorkerRepository;
import com.sevalink.sevalinkbackend.repository.NotificationRepository;
import com.sevalink.sevalinkbackend.model.Notification;
import com.sevalink.sevalinkbackend.model.Worker;
import com.sevalink.sevalinkbackend.dto.ClientJobStatsDto;
import com.sevalink.sevalinkbackend.dto.ClientJobDto;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
public class JobPostService {

    @Autowired
    private JobPostRepository jobPostRepository;

    @Autowired
    private JobTimelineRepository jobTimelineRepository;

    @Autowired
    private QuotationRepository quotationRepository;

    @Autowired
    private WorkerRepository workerRepository;

    @Autowired
    private NotificationRepository notificationRepository;

    // Client posts a new job
    public JobPost createJob(JobPost jobPost) {
        JobPost saved = jobPostRepository.save(jobPost);

        // Auto create first timeline entry
        JobTimeline timeline = new JobTimeline();
        timeline.setJobPost(saved);
        timeline.setStatus("JOB_POSTED");
        timeline.setNote("Job posted by client");
        jobTimelineRepository.save(timeline);

        // Notify relevant nearby workers (within 15 km, matching job category)
        if (saved.getLatitude() != null && saved.getLongitude() != null) {
            List<Worker> targetWorkers;

            if (saved.getCategory() != null) {
                // Category-aware: only notify workers in the same trade within 15 km
                targetWorkers = workerRepository.findNearbyWorkersByCategory(
                        saved.getLatitude(), saved.getLongitude(), 15.0,
                        saved.getCategory().getId());
            } else {
                // No category on job — fall back to proximity-only
                targetWorkers = workerRepository.findNearbyWorkers(
                        saved.getLatitude(), saved.getLongitude(), 15.0);
            }

            for (Worker worker : targetWorkers) {
                if (worker.getUser() != null) {
                    Notification notification = new Notification();
                    notification.setUser(worker.getUser());
                    notification.setJobPost(saved);
                    notification.setTitle("New Job Nearby");
                    notification.setMessage("A new job '" + saved.getTitle() + "' was posted near you.");
                    notificationRepository.save(notification);
                }
            }
        }

        return saved;
    }

    // Get all open jobs (worker feed — unfiltered, or filtered by worker)
    public List<JobPost> getAllOpenJobs() {
        return jobPostRepository.findByStatusOrderByCreatedAtDesc("OPEN");
    }

    // Get all open jobs excluding those the worker already quoted
    public List<JobPost> getAllOpenJobsForWorker(Long workerId) {
        return jobPostRepository.findOpenJobsExcludingWorkerQuotes(workerId);
    }

    // Get open jobs for a specific category — worker category-targeted feed
    public List<JobPost> getOpenJobsByCategory(Long categoryId) {
        return jobPostRepository.findByStatusAndCategoryIdOrderByCreatedAtDesc("OPEN", categoryId);
    }

    // Get open jobs for a category, excluding those the worker already quoted
    public List<JobPost> getOpenJobsByCategoryForWorker(Long categoryId, Long workerId) {
        return jobPostRepository.findOpenJobsByCategoryExcludingWorkerQuotes(categoryId, workerId);
    }

    // Worker sees nearby jobs
    public List<JobPost> getNearbyJobs(Double lat, Double lng, Double radius) {
        double r = (radius != null) ? radius : 10.0;
        return jobPostRepository.findNearbyJobs(lat, lng, r);
    }

    // Worker sees nearby jobs, excluding those they already quoted
    public List<JobPost> getNearbyJobsForWorker(Double lat, Double lng, Double radius, Long workerId) {
        double r = (radius != null) ? radius : 10.0;
        return jobPostRepository.findNearbyJobsExcludingWorkerQuotes(lat, lng, r, workerId);
    }

    // Worker sees nearby jobs by category
    public List<JobPost> getNearbyJobsByCategory(Double lat, Double lng,
                                                 Double radius, Long categoryId) {
        double r = (radius != null) ? radius : 10.0;
        return jobPostRepository.findNearbyJobsByCategory(lat, lng, r, categoryId);
    }

    // Worker sees nearby jobs by category, excluding those they already quoted
    public List<JobPost> getNearbyJobsByCategoryForWorker(Double lat, Double lng,
                                                          Double radius, Long categoryId, Long workerId) {
        double r = (radius != null) ? radius : 10.0;
        return jobPostRepository.findNearbyJobsByCategoryExcludingWorkerQuotes(lat, lng, r, categoryId, workerId);
    }

    // Get job by ID
    public Optional<JobPost> getJobById(Long id) {
        return jobPostRepository.findById(id);
    }

    // Client sees their own jobs
    public List<JobPost> getClientJobs(Long clientId) {
        return jobPostRepository.findByClientIdAndStatusNotOrderByCreatedAtDesc(clientId, "DELETED");
    }

    // Delete a job
    public JobPost deleteJob(Long jobId, String reason, Long clientId) {
        JobPost job = jobPostRepository.findById(jobId)
                .orElseThrow(() -> new RuntimeException("Job not found"));
        if (job.getClient() == null || job.getClient().getId() != clientId.longValue()) {
            throw new RuntimeException("Unauthorized to delete this job");
        }
        if ("COMPLETED".equals(job.getStatus())) {
            throw new RuntimeException("Cannot delete a completed job");
        }
        
        // Notify any workers who have submitted quotes or are assigned
        List<com.sevalink.sevalinkbackend.model.Quotation> quotes = quotationRepository.findByJobPostIdOrderByProposedPriceAsc(jobId);
        for (com.sevalink.sevalinkbackend.model.Quotation quote : quotes) {
            if ("ACCEPTED".equals(quote.getStatus()) || "OPEN".equals(quote.getStatus())) {
                Worker worker = quote.getWorker();
                if (worker != null && worker.getUser() != null) {
                    Notification notification = new Notification();
                    notification.setUser(worker.getUser());
                    notification.setJobPost(job);
                    notification.setTitle("Job Cancelled");
                    notification.setMessage("The client has cancelled the job '" + job.getTitle() + "'. Reason: " + reason);
                    notificationRepository.save(notification);
                }
            }
        }

        job.setStatus("CANCELLED");
        job.setDeletionReason(reason);
        return jobPostRepository.save(job);
    }

    // Cancel a job
    public JobPost cancelJob(Long jobId) {
        JobPost job = jobPostRepository.findById(jobId)
                .orElseThrow(() -> new RuntimeException("Job not found"));
        job.setStatus("CANCELLED");
        return jobPostRepository.save(job);
    }

    // Get job timeline
    public List<JobTimeline> getJobTimeline(Long jobId) {
        return jobTimelineRepository.findByJobPostIdOrderByUpdatedAtAsc(jobId);
    }

    // Update job timeline
    public JobTimeline updateTimeline(Long jobId, String status, String note) {
        JobPost job = jobPostRepository.findById(jobId)
                .orElseThrow(() -> new RuntimeException("Job not found"));
        if ("COMPLETED".equals(status)) {
            job.setStatus("COMPLETED");
            jobPostRepository.save(job);

            // Increment the worker's total job count and experience
            quotationRepository.findByJobPostIdAndStatus(jobId, "ACCEPTED")
                    .ifPresent(acceptedQuote -> {
                        Worker worker = acceptedQuote.getWorker();
                        int current = worker.getTotalJobs() != null ? worker.getTotalJobs() : 0;
                        worker.setTotalJobs(current + 1);
                        workerRepository.save(worker);
                        
                        // Notify Client
                        Notification notification = new Notification();
                        notification.setUser(job.getClient());
                        notification.setJobPost(job);
                        notification.setTitle("Job Completed");
                        notification.setMessage("Your job '" + job.getTitle() + "' has been marked as completed by " + worker.getUser().getFullName() + ". Please review and rate the worker.");
                        notificationRepository.save(notification);
                    });
        }
        JobTimeline timeline = new JobTimeline();
        timeline.setJobPost(job);
        timeline.setStatus(status);
        timeline.setNote(note);
        return jobTimelineRepository.save(timeline);
    }

    // Client job statistics
    public ClientJobStatsDto getClientJobStats(Long clientId) {
        return ClientJobStatsDto.builder()
                .total(jobPostRepository.countByClientIdAndStatusNot(clientId, "DELETED"))
                .open(jobPostRepository.countByClientIdAndStatus(clientId, "OPEN"))
                .active(jobPostRepository.countByClientIdAndStatus(clientId, "ASSIGNED"))
                .done(jobPostRepository.countByClientIdAndStatus(clientId, "COMPLETED"))
                .build();
    }

    // Client jobs with quote counts
    public List<ClientJobDto> getClientJobsWithQuotes(Long clientId, String statusFilter) {
        List<JobPost> jobs;
        if (statusFilter != null && !statusFilter.equalsIgnoreCase("ALL")) {
            jobs = jobPostRepository.findByClientIdAndStatusInOrderByCreatedAtDesc(
                    clientId, List.of(statusFilter.toUpperCase()));
        } else {
            jobs = jobPostRepository.findByClientIdAndStatusNotOrderByCreatedAtDesc(clientId, "DELETED");
        }

        return jobs.stream().map(job -> {
            long quoteCount = quotationRepository.findByJobPostIdOrderByProposedPriceAsc(job.getId()).size();
            return ClientJobDto.builder()
                    .id(job.getId())
                    .title(job.getTitle())
                    .description(job.getDescription())
                    .categoryName(job.getCategory() != null ? job.getCategory().getName() : "General")
                    .locationName(job.getLocationName())
                    .budgetMin(job.getBudgetMin())
                    .budgetMax(job.getBudgetMax())
                    .urgency(job.getUrgency())
                    .status(job.getStatus())
                    .createdAt(job.getCreatedAt())
                    .quoteCount(quoteCount)
                    .build();
        }).collect(Collectors.toList());
    }
}
