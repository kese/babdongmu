package com.example.capstone.exception;

import com.example.capstone.dto.ApiErrorResponse;
import jakarta.persistence.EntityNotFoundException;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.time.LocalDateTime;

import lombok.extern.slf4j.Slf4j;

@RestControllerAdvice(basePackages = "com.example.capstone.api")
@Slf4j
public class GlobalExceptionHandler {

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiErrorResponse> handleValidation(MethodArgumentNotValidException ex, HttpServletRequest request) {
        FieldError fieldError = ex.getBindingResult().getFieldError();
        log.warn("Validation error for field: {}", fieldError != null ? fieldError.getField() : "unknown");
        String message = (fieldError != null) ? fieldError.getDefaultMessage() : "유효성 검증 오류";
        ApiErrorResponse body = ApiErrorResponse.builder()
                .message(message)
                .error("Bad Request")
                .status(HttpStatus.BAD_REQUEST.value())
                .timestamp(LocalDateTime.now())
                .path(request.getRequestURI())
                .build();
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(body);
    }

    @ExceptionHandler(EntityNotFoundException.class)
    public ResponseEntity<ApiErrorResponse> handleNotFound(EntityNotFoundException ex, HttpServletRequest request) {
        log.info("Requested resource was not found");
        ApiErrorResponse body = ApiErrorResponse.builder()
                .message(ex.getMessage())
                .error("Not Found")
                .status(HttpStatus.NOT_FOUND.value())
                .timestamp(LocalDateTime.now())
                .path(request.getRequestURI())
                .build();
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(body);
    }

    @ExceptionHandler(ForbiddenException.class)
    public ResponseEntity<ApiErrorResponse> handleForbidden(ForbiddenException ex, HttpServletRequest request) {
        log.warn("Request was forbidden");
        ApiErrorResponse body = ApiErrorResponse.builder()
                .message(ex.getMessage())
                .error("Forbidden")
                .status(HttpStatus.FORBIDDEN.value())
                .timestamp(LocalDateTime.now())
                .path(request.getRequestURI())
                .build();
        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(body);
    }

    @ExceptionHandler(IllegalStateException.class)
    public ResponseEntity<ApiErrorResponse> handleIllegalState(IllegalStateException ex, HttpServletRequest request) {
        log.warn("Request state was invalid");
        ApiErrorResponse body = ApiErrorResponse.builder()
                .message(ex.getMessage())
                .error("Bad Request")
                .status(HttpStatus.BAD_REQUEST.value())
                .timestamp(LocalDateTime.now())
                .path(request.getRequestURI())
                .build();
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(body);
    }

    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<ApiErrorResponse> handleDuplicate(DataIntegrityViolationException ex, HttpServletRequest request) {
        log.info("Request conflicted with a stored constraint");
        ApiErrorResponse body = ApiErrorResponse.builder()
                .message("요청을 처리할 수 없습니다.")
                .error("Conflict")
                .status(HttpStatus.CONFLICT.value())
                .timestamp(LocalDateTime.now())
                .path(request.getRequestURI())
                .build();
        return ResponseEntity.status(HttpStatus.CONFLICT).body(body);
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<ApiErrorResponse> handleIllegalArg(IllegalArgumentException ex, HttpServletRequest request) {
        log.warn("Request argument was invalid");
        ApiErrorResponse body = ApiErrorResponse.builder()
                .message(ex.getMessage())
                .error("Bad Request")
                .status(HttpStatus.BAD_REQUEST.value())
                .timestamp(LocalDateTime.now())
                .path(request.getRequestURI())
                .build();
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(body);
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ApiErrorResponse> handleUnreadable(HttpMessageNotReadableException ex, HttpServletRequest request) {
        log.warn("Request body could not be parsed");
        ApiErrorResponse body = ApiErrorResponse.builder()
                .message("요청 바디가 잘못되었거나 파싱할 수 없습니다. JSON 형식(Content-Type: application/json)을 확인하세요.")
                .error("Bad Request")
                .status(HttpStatus.BAD_REQUEST.value())
                .timestamp(LocalDateTime.now())
                .path(request.getRequestURI())
                .build();
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(body);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiErrorResponse> handleOthers(Exception ex, HttpServletRequest request) {
        String path = request.getRequestURI();
        
        // Swagger/SpringDoc 관련 경로는 예외 처리하지 않음
        if (path.startsWith("/v3/api-docs") || path.startsWith("/swagger-ui") || path.startsWith("/api-docs")) {
            throw new RuntimeException(ex);
        }
        
        log.error("Unexpected server error at path {} ({})", path, ex.getClass().getSimpleName());
        ApiErrorResponse body = ApiErrorResponse.builder()
                .message("서버 오류가 발생했습니다.")
                .error("Internal Server Error")
                .status(HttpStatus.INTERNAL_SERVER_ERROR.value())
                .timestamp(LocalDateTime.now())
                .path(path)
                .build();
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(body);
    }
}


