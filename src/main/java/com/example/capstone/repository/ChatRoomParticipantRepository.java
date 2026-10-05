package com.example.capstone.repository;

import com.example.capstone.domain.chat.ChatRoomParticipant;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface ChatRoomParticipantRepository extends JpaRepository<ChatRoomParticipant, Long> {

    @Query("select crp from ChatRoomParticipant crp " +
            "join fetch crp.chatRoom cr " +
            "left join fetch cr.post " +
            "where crp.user.id = :userId and cr.active = true")
    List<ChatRoomParticipant> findByUserIdWithRoom(@Param("userId") Long userId);

    @Query("select crp.chatRoom.id as roomId, count(crp.id) as memberCount " +
            "from ChatRoomParticipant crp " +
            "where crp.chatRoom.id in :roomIds " +
            "group by crp.chatRoom.id")
    List<ChatRoomMemberCount> countMembersByRoomIds(@Param("roomIds") Collection<Long> roomIds);

    Optional<ChatRoomParticipant> findByChatRoom_IdAndUser_Id(Long roomId, Long userId);

        List<ChatRoomParticipant> findByChatRoom_Id(Long roomId);

    @Query("select crp.user.id from ChatRoomParticipant crp where crp.chatRoom.id = :roomId")
    List<Long> findUserIdsByChatRoomId(@Param("roomId") Long roomId);

    @Query("select crp from ChatRoomParticipant crp where crp.chatRoom.id = :roomId and crp.target = true")
    List<ChatRoomParticipant> findTargetsByRoomId(@Param("roomId") Long roomId);

    @Query("select count(crp) from ChatRoomParticipant crp where crp.chatRoom.id = :roomId and crp.target = true")
    long countTargets(@Param("roomId") Long roomId);

    @Query("select count(crp) from ChatRoomParticipant crp where crp.chatRoom.id = :roomId and crp.target = true and crp.confirmedReception = false")
    long countTargetsPendingReception(@Param("roomId") Long roomId);

    @Query("select case when count(crp) > 0 then true else false end from ChatRoomParticipant crp where crp.chatRoom.id = :roomId and crp.target = true and crp.reportedIssue = true")
    boolean existsReportedIssue(@Param("roomId") Long roomId);

    @Query("select crp from ChatRoomParticipant crp where crp.chatRoom.id = :roomId and crp.target = true and crp.confirmedReception = false")
    List<ChatRoomParticipant> findPendingReceptionTargets(@Param("roomId") Long roomId);

    @Query("select case when count(crp) > 0 then true else false end from ChatRoomParticipant crp where crp.chatRoom.id = :roomId and crp.user.id = :userId and crp.target = true")
    boolean existsByChatRoom_IdAndUser_IdAndHostTrue(@Param("roomId") Long roomId, @Param("userId") Long userId);

    interface ChatRoomMemberCount {
        Long getRoomId();
        Long getMemberCount();
    }
}
