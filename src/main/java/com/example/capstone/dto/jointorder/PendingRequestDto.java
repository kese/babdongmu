package com.example.capstone.dto.jointorder;

import java.time.LocalDateTime;
import java.util.List;

public record PendingRequestDto(
    Long id,
    String requesterName,
    Long requesterPostId,
    List<Long> targetPostIds,
    LocalDateTime requestTime,
    String status
) {
}
