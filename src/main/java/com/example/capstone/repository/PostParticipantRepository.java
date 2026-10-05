package com.example.capstone.repository;

import com.example.capstone.domain.post.PostParticipant;
import com.example.capstone.domain.post.PostType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;

public interface PostParticipantRepository extends JpaRepository<PostParticipant, Long> {

    boolean existsByPost_IdAndUser_Id(Long postId, Long userId);

    long countByPost_Id(Long postId);

    @Query("select pp from PostParticipant pp join fetch pp.user where pp.post.id = :postId order by pp.joinedAt asc")
    List<PostParticipant> findByPostIdWithUser(@Param("postId") Long postId);

    @Query("select pp from PostParticipant pp join fetch pp.post p where pp.user.id = :userId and (:excludeRole is null or pp.role <> :excludeRole)")
    List<PostParticipant> findByUserIdWithPost(@Param("userId") Long userId,
                                              @Param("excludeRole") com.example.capstone.domain.post.ParticipantRole excludeRole);

    @Query("select pp.post.id as postId, count(pp.id) as participantCount from PostParticipant pp where pp.post.id in :postIds group by pp.post.id")
    List<PostParticipantCount> countByPostIds(@Param("postIds") Collection<Long> postIds);

    @Query("select distinct pp from PostParticipant pp " +
            "join fetch pp.post p " +
            "join fetch p.deliveryDetail dd " +
            "where pp.user.id = :userId and p.postType = :deliveryType")
    List<PostParticipant> findDeliveryParticipationsWithDetails(@Param("userId") Long userId,
                                                                @Param("deliveryType") PostType deliveryType);

    interface PostParticipantCount {
        Long getPostId();
        Long getParticipantCount();
    }
}
