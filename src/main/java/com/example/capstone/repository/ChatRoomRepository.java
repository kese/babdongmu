package com.example.capstone.repository;

import com.example.capstone.domain.chat.ChatRoom;
import com.example.capstone.domain.chat.ChatRoomStatus;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface ChatRoomRepository extends JpaRepository<ChatRoom, Long> {

	Optional<ChatRoom> findByPost_Id(Long postId);

    List<ChatRoom> findByRoomStatusAndUpdatedAtBefore(ChatRoomStatus status, LocalDateTime threshold);
}
