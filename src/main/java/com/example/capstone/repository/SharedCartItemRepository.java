package com.example.capstone.repository;

import com.example.capstone.domain.cart.SharedCartItem;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface SharedCartItemRepository extends JpaRepository<SharedCartItem, Long> {

    List<SharedCartItem> findByCart_IdOrderByCreatedAtAsc(Long cartId);

    Optional<SharedCartItem> findByIdAndCart_ChatRoom_Id(Long itemId, Long roomId);
}
