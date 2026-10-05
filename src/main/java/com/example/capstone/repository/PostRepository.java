package com.example.capstone.repository;

import com.example.capstone.domain.post.Post;
import com.example.capstone.domain.post.PostStatus;
import com.example.capstone.domain.post.PostType;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface PostRepository extends JpaRepository<Post, Long> {

    @EntityGraph(attributePaths = {"author", "deliveryDetail", "meetDetail"})
    List<Post> findByStatusOrderByCreatedAtDesc(PostStatus status);

    @Override
    @EntityGraph(attributePaths = {"author", "deliveryDetail", "meetDetail"})
    Optional<Post> findById(Long postId);

    @EntityGraph(attributePaths = {"author", "deliveryDetail", "meetDetail"})
    List<Post> findByAuthor_IdOrderByCreatedAtDesc(Long authorId);

    @EntityGraph(attributePaths = {"author", "deliveryDetail", "meetDetail"})
    List<Post> findByIdIn(List<Long> postIds);

    // 사용자의 모집 중인 특정 타입 게시글 조회
    @EntityGraph(attributePaths = {"author", "deliveryDetail", "meetDetail"})
    @Query("SELECT p FROM Post p WHERE p.author.id = :userId AND p.status = :status AND p.postType = :postType ORDER BY p.createdAt DESC")
    List<Post> findByAuthorIdAndStatusAndPostType(@Param("userId") Long userId, @Param("status") PostStatus status, @Param("postType") PostType postType);

    // 매칭 가능 게시글 검색 (동일 음식점, POI 명칭 일치로 매칭, 본인 제외, 모집 중, 인원 여유)
    @EntityGraph(attributePaths = {"author", "deliveryDetail", "meetDetail"})
    @Query("SELECT p FROM Post p " +
           "JOIN p.deliveryDetail dd " +
           "WHERE p.status = com.example.capstone.domain.post.PostStatus.ACTIVE " +
           "AND p.postType = com.example.capstone.domain.post.PostType.DELIVERY " +
           "AND p.author.id != :userId " +
           "AND dd.restaurantName = :storeName " +
           "AND p.locationName = :locationName " +
           "AND p.currentParticipants < p.maxParticipants " +
           "AND (p.deadline IS NULL OR p.deadline > CURRENT_TIMESTAMP) " +
           "ORDER BY p.createdAt DESC")
    List<Post> findMatchablePostsByLocationName(@Param("storeName") String storeName,
                                                 @Param("locationName") String locationName,
                                                 @Param("userId") Long userId);
}
