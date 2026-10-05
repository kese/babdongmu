package com.example.capstone.dto;

import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

@Getter
@Builder
public class ApiErrorResponse {
    private final String message;
    private final String error;
    private final int status;
    private final LocalDateTime timestamp;
    private final String path;
}


