package com.sevalink.sevalinkbackend.service;

import com.sevalink.sevalinkbackend.model.Worker;
import com.sevalink.sevalinkbackend.repository.SearchRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import java.util.List;
import java.util.Map;

@Service
public class SearchService {

    @Autowired
    private SearchRepository searchRepository;

    // Maps frontend uppercase category values → DB canonical names
    private static final Map<String, String> CATEGORY_ALIAS = Map.of(
            "electrician",  "Electrical",
            "electrical",   "Electrical",
            "plumber",      "Plumbing",
            "plumbing",     "Plumbing",
            "carpenter",    "Carpentry",
            "carpentry",    "Carpentry",
            "painter",      "Painting",
            "painting",     "Painting",
            "cleaner",      "Cleaning",
            "cleaning",     "Cleaning"
    );

    /** Normalise a raw category value sent from the client app to the DB name. */
    private String normalizeCategory(String raw) {
        if (raw == null) return null;
        String normalized = CATEGORY_ALIAS.get(raw.trim().toLowerCase());
        // Fall back to the original value if no alias found (e.g. "General", "Mechanic")
        return (normalized != null) ? normalized : capitalize(raw.trim());
    }

    private String capitalize(String s) {
        if (s == null || s.isEmpty()) return s;
        return Character.toUpperCase(s.charAt(0)) + s.substring(1).toLowerCase();
    }

    // Basic keyword search
    public List<Worker> search(String keyword) {
        if (keyword == null || keyword.trim().isEmpty()) {
            return searchRepository.findAll();
        }
        return searchRepository.searchByKeyword(keyword.trim());
    }

    // Category filter
    public List<Worker> searchByCategory(String categoryName) {
        return searchRepository.searchByCategory(normalizeCategory(categoryName));
    }

    // Availability filter
    public List<Worker> searchByAvailability(Boolean available) {
        return searchRepository.findByIsAvailableOrderByRatingDesc(available);
    }

    // Location based search
    public List<Worker> searchByLocation(Double lat, Double lng, Double radiusKm) {
        // Default radius 10km if not provided
        double radius = (radiusKm != null) ? radiusKm : 10.0;
        return searchRepository.searchByLocation(lat, lng, radius);
    }

    // Full search — all filters combined, sorted nearest first when coords provided
    public List<Worker> fullSearch(String keyword,
                                   String categoryName,
                                   Boolean available,
                                   Double lat,
                                   Double lng,
                                   Double radiusKm) {

        String kw = (keyword == null || keyword.trim().isEmpty()) ? "" : keyword.trim();
        String normalizedCategory = normalizeCategory(categoryName);
        double radius = (radiusKm != null) ? radiusKm : 15.0;

        if (lat == null || lng == null) {
            return searchRepository.searchWithoutLocation(kw, normalizedCategory, available);
        }

        return searchRepository.fullSearch(kw, normalizedCategory, available, lat, lng, radius);
    }
}