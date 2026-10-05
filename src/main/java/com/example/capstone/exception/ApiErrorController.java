package com.example.capstone.exception;

import com.example.capstone.dto.ApiErrorResponse;
import jakarta.servlet.RequestDispatcher;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.boot.web.servlet.error.ErrorController;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDateTime;

@RestController
public class ApiErrorController implements ErrorController {

    @RequestMapping("/error")
    public ResponseEntity<ApiErrorResponse> handleError(HttpServletRequest request) {
        Object statusAttr = request.getAttribute(RequestDispatcher.ERROR_STATUS_CODE);
        int status = (statusAttr instanceof Integer) ? (Integer) statusAttr : HttpStatus.INTERNAL_SERVER_ERROR.value();
        HttpStatus httpStatus = HttpStatus.resolve(status);
        if (httpStatus == null) httpStatus = HttpStatus.INTERNAL_SERVER_ERROR;

        ApiErrorResponse body = ApiErrorResponse.builder()
                .message("서버 오류가 발생했습니다.")
                .error(httpStatus.getReasonPhrase())
                .status(httpStatus.value())
                .timestamp(LocalDateTime.now())
                .path((String) request.getAttribute(RequestDispatcher.ERROR_REQUEST_URI))
                .build();

        return ResponseEntity.status(httpStatus).body(body);
    }
}


