package com.sevalink.sevalinkbackend.repository;

import com.sevalink.sevalinkbackend.model.Worker;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface FeedRepository extends JpaRepository<Worker, Long> {

    //  Get all available workers (default feed)
    List<Worker> findByIsAvailableTrueOrderByRatingDesc();

    //  Paginated feed
    Page<Worker> findByIsAvailableTrue(Pageable pageable);

    //  Sort by rating
    Page<Worker> findByIsAvailableTrueOrderByRatingDesc(Pageable pageable);

    //  Sort by hourly rate (lowest first)
    Page<Worker> findByIsAvailableTrueOrderByHourlyRateAsc(Pageable pageable);

    //  Sort by nearest location
    @Query("SELECT w FROM Worker w WHERE w.isAvailable = true " +
            "ORDER BY (6371 * acos(cos(radians(:lat)) * cos(radians(w.latitude)) * " +
            "cos(radians(w.longitude) - radians(:lng)) + " +
            "sin(radians(:lat)) * sin(radians(w.latitude)))) ASC")
    Page<Worker> findNearestWorkers(
            @Param("lat") Double lat,
            @Param("lng") Double lng,
            Pageable pageable);

    // 6. Get single worker full profile
    @Query("SELECT w FROM Worker w " +
            "LEFT JOIN FETCH w.user " +
            "LEFT JOIN FETCH w.category " +
            "WHERE w.id = :id")
    Worker findWorkerWithFullProfile(@Param("id") Long id);
}