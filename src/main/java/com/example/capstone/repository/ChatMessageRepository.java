package com.example.capstone.repository;

import com.example.capstone.domain.chat.ChatMessage;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface ChatMessageRepository extends JpaRepository<ChatMessage, Long> {

    Optional<ChatMessage> findTop1ByChatRoom_IdOrderBySentAtDesc(Long chatRoomId);

    long countByChatRoom_Id(Long chatRoomId);

    long countByChatRoom_IdAndIdGreaterThan(Long chatRoomId, Long messageId);

    @Query("select m.chatRoom.id as roomId, count(m.id) as totalCount " +
            "from ChatMessage m where m.chatRoom.id in :roomIds group by m.chatRoom.id")
    List<ChatMessageCount> countMessagesByRoomIds(@Param("roomIds") Collection<Long> roomIds);

    @Query("select m from ChatMessage m where m.id in (" +
        "select max(m2.id) from ChatMessage m2 where m2.chatRoom.id in :roomIds group by m2.chatRoom.id)")
    List<ChatMessage> findLatestMessagesByRoomIds(@Param("roomIds") Collection<Long> roomIds);

    @EntityGraph(attributePaths = "sender")
    Slice<ChatMessage> findByChatRoom_IdOrderByIdDesc(Long chatRoomId, Pageable pageable);

    @EntityGraph(attributePaths = "sender")
    Slice<ChatMessage> findByChatRoom_IdAndIdLessThanOrderByIdDesc(Long chatRoomId, Long messageId, Pageable pageable);

    List<ChatMessage> findByChatRoom_Id(Long chatRoomId);

    interface ChatMessageCount {
        Long getRoomId();
        Long getTotalCount();
    }
}
