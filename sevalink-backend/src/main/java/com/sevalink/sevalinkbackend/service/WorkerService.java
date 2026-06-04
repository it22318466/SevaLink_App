package com.sevalink.sevalinkbackend.service;

import com.sevalink.sevalinkbackend.model.Worker;
import com.sevalink.sevalinkbackend.model.Category;
import com.sevalink.sevalinkbackend.repository.WorkerRepository;
import com.sevalink.sevalinkbackend.repository.CategoryRepository;
import com.sevalink.sevalinkbackend.dto.UpdateWorkerProfileRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;
import java.util.List;
import java.util.Optional;

@Service
public class WorkerService {

    @Autowired
    private WorkerRepository workerRepository;

    @Autowired
    private CategoryRepository categoryRepository;

    @Autowired
    private com.sevalink.sevalinkbackend.repository.UserRepository userRepository;

    @Autowired
    private FileStorageService fileStorageService;


    // Get all workers
    public List<Worker> getAllWorkers() {
        // Automatically ensure all WORKER users have a Worker profile
        List<com.sevalink.sevalinkbackend.model.User> allUsers = userRepository.findAll();
        for (com.sevalink.sevalinkbackend.model.User u : allUsers) {
            if (com.sevalink.sevalinkbackend.model.UserRole.WORKER.equals(u.getRole())) {
                boolean exists = workerRepository.findByUserId(u.getId()).isPresent();
                if (!exists) {
                    Worker newWorker = new Worker();
                    newWorker.setUser(u);
                    newWorker.setIsAvailable(true);
                    newWorker.setRating(5.0);
                    newWorker.setTotalJobs(0);
                    newWorker.setSkills("Electrician,AC Repair,Wiring");
                    workerRepository.save(newWorker);
                }
            }
        }
        return workerRepository.findAll();
    }

    // Get worker by ID
    public Optional<Worker> getWorkerById(Long id) {
        return workerRepository.findById(id);
    }

    // Get worker profile of the currently authenticated user (by email)
    public Worker getWorkerByEmail(String email) {
        com.sevalink.sevalinkbackend.model.User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found"));

        // Auto-create worker profile if it doesn't exist
        return workerRepository.findByUserId(user.getId()).orElseGet(() -> {
            Worker newWorker = new Worker();
            newWorker.setUser(user);
            newWorker.setIsAvailable(true);
            newWorker.setRating(5.0);
            newWorker.setTotalJobs(0);
            workerRepository.save(newWorker);
            return newWorker;
        });
    }

    // Search workers by keyword (e.g. "plumber", "electrician")
    public List<Worker> searchWorkers(String keyword) {
        return workerRepository.searchWorkers(keyword);
    }

    // Get only available workers
    public List<Worker> getAvailableWorkers() {
        return workerRepository.findByIsAvailableTrue();
    }

    // Update worker availability
    public Worker updateAvailability(Long workerId, Boolean status) {
        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> new RuntimeException("Worker not found"));
        worker.setIsAvailable(status);
        return workerRepository.save(worker);
    }

    // Update worker profile
    @Transactional
    public Worker updateWorkerProfile(Long workerId, UpdateWorkerProfileRequest request) {
        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> new RuntimeException("Worker not found"));

        com.sevalink.sevalinkbackend.model.User user = worker.getUser();
        if (user != null) {
            user.setFullName(request.getFullName());
            user.setPhoneNumber(request.getPhoneNumber());
            user.setLocation(request.getLocation());
            userRepository.save(user);
        }

        worker.setBio(request.getBio());
        worker.setSkills(request.getSkills());
        worker.setHourlyRate(request.getHourlyRate());

        if (request.getCategoryId() != null) {
            Category category = categoryRepository.findById(request.getCategoryId())
                    .orElseThrow(() -> new RuntimeException("Category not found"));
            worker.setCategory(category);
        }

        worker.setLatitude(request.getLatitude());
        worker.setLongitude(request.getLongitude());

        return workerRepository.save(worker);
    }

    // Upload profile image
    @Transactional
    public Worker uploadProfileImage(Long workerId, MultipartFile file) {
        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> new RuntimeException("Worker not found"));

        com.sevalink.sevalinkbackend.model.User user = worker.getUser();
        if (user == null) {
            throw new RuntimeException("User not associated with worker");
        }

        String fileName = fileStorageService.storeFile(file);

        // Build the public URL for the image
        String fileDownloadUri = ServletUriComponentsBuilder.fromCurrentContextPath()
                .path("/api/public/uploads/")
                .path(fileName)
                .toUriString();

        user.setProfileImageUrl(fileDownloadUri);
        userRepository.save(user);

        return worker;
    }
}