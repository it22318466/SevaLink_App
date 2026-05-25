package com.sevalink.sevalinkbackend.service;

import com.sevalink.sevalinkbackend.model.JobPost;
import com.sevalink.sevalinkbackend.model.JobTimeline;
import com.sevalink.sevalinkbackend.repository.JobPostRepository;
import com.sevalink.sevalinkbackend.repository.JobTimelineRepository;
import com.sevalink.sevalinkbackend.repository.QuotationRepository;
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

    // Client posts a new job
    public JobPost createJob(JobPost jobPost) {
        JobPost saved = jobPostRepository.save(jobPost);

        // Auto create first timeline entry
        JobTimeline timeline = new JobTimeline();
        timeline.setJobPost(saved);
        timeline.setStatus("JOB_POSTED");
        timeline.setNote("Job posted by client");
        jobTimelineRepository.save(timeline);

        return saved;
    }

    // Get all open jobs (worker feed)
    public List<JobPost> getAllOpenJobs() {
        return jobPostRepository.findByStatusOrderByCreatedAtDesc("OPEN");
    }

    // Worker sees nearby jobs
    public List<JobPost> getNearbyJobs(Double lat, Double lng, Double radius) {
        double r = (radius != null) ? radius : 10.0;
        return jobPostRepository.findNearbyJobs(lat, lng, r);
    }

    // Worker sees nearby jobs by category
    public List<JobPost> getNearbyJobsByCategory(Double lat, Double lng,
                                                 Double radius, Long categoryId) {
        double r = (radius != null) ? radius : 10.0;
        return jobPostRepository.findNearbyJobsByCategory(lat, lng, r, categoryId);
    }

    // Get job by ID
    public Optional<JobPost> getJobById(Long id) {
        return jobPostRepository.findById(id);
    }

    // Client sees their own jobs
    public List<JobPost> getClientJobs(Long clientId) {
        return jobPostRepository.findByClientIdOrderByCreatedAtDesc(clientId);
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
        JobTimeline timeline = new JobTimeline();
        timeline.setJobPost(job);
        timeline.setStatus(status);
        timeline.setNote(note);
        return jobTimelineRepository.save(timeline);
    }

    // Client job statistics
    public ClientJobStatsDto getClientJobStats(Long clientId) {
        return ClientJobStatsDto.builder()
                .total(jobPostRepository.countByClientId(clientId))
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
            jobs = jobPostRepository.findByClientIdOrderByCreatedAtDesc(clientId);
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
