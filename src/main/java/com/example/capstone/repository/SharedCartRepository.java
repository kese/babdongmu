package com.example.capstone.repository;

import com.example.capstone.domain.cart.SharedCart;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface SharedCartRepository extends JpaRepository<SharedCart, Long> {

    @EntityGraph(attributePaths = {"chatRoom", "chatRoom.post", "host"})
    Optional<SharedCart> findTopByChatRoom_IdOrderByCreatedAtDesc(Long roomId);

    @EntityGraph(attributePaths = {"items", "items.user", "chatRoom", "chatRoom.post", "host"})
    Optional<SharedCart> findByChatRoom_IdAndActiveTrue(Long roomId);

    @EntityGraph(attributePaths = {"items", "items.user", "chatRoom", "chatRoom.post", "host"})
    Optional<SharedCart> findByIdAndChatRoom_Id(Long cartId, Long roomId);
}
