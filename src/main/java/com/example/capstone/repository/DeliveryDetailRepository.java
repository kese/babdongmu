package com.example.capstone.repository;

import com.example.capstone.domain.post.DeliveryDetail;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface DeliveryDetailRepository extends JpaRepository<DeliveryDetail, Long> {

    Optional<DeliveryDetail> findByPost_Id(Long postId);

    List<DeliveryDetail> findByPost_IdIn(Collection<Long> postIds);
}
