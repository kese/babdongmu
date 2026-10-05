package com.example.capstone.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

@Getter
@Builder
@AllArgsConstructor
public class RequestLogEntry {
    private String timestamp;
    private String method;
    private String path;
    private String clientIp;
    private String requestBody;
    private Integer responseStatus;
    private String responseBody;
    private Long duration; // milliseconds
    
    public static RequestLogEntry create(String method, String path, String clientIp, String requestBody) {
        return RequestLogEntry.builder()
                .timestamp(LocalDateTime.now().toString())
                .method(method)
                .path(path)
                .clientIp(clientIp)
                .requestBody(requestBody)
                .build();
    }
}

