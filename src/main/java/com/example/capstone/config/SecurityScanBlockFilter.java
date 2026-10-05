package com.example.capstone.config;

import jakarta.servlet.*;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.util.Arrays;
import java.util.List;

/**
 * 보안 스캔/봇 요청을 조기에 차단하는 필터
 * 의심스러운 경로 패턴을 빠르게 거부하여 불필요한 로그를 줄입니다.
 */
@Slf4j
@Component
@Order(1)
public class SecurityScanBlockFilter implements Filter {

    // 차단할 의심스러운 경로 패턴
    private static final List<String> BLOCKED_PATTERNS = Arrays.asList(
        // 설정 파일 스캔
        ".env", "sftp-config.json", "sftp.json", "wp-config", 
        ".aws", ".ssh", ".vscode", ".remote", ".local", ".production",
        
        // PHP 관련
        "phpinfo", ".php", "index.php",
        
        // 프레임워크 특정 경로
        "wordpress", "wp-admin", "wp-content", "wp-includes",
        "laravel", "symfony", "prevlaravel",
        
        // 기타 일반적인 스캔 대상
        ".git", ".svn", ".hg", "config.json", 
        ".bak", ".old", ".swp", ".sql", ".zip", ".tar", ".gz",
        "backup", "dump", "database",
        
        // 일반적인 로그인 경로 (Spring Boot는 /api/auth를 사용)
        "/admin", "/login", "/signin", "/user/login"
    );

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain) 
            throws IOException, ServletException {
        
        HttpServletRequest httpRequest = (HttpServletRequest) request;
        HttpServletResponse httpResponse = (HttpServletResponse) response;
        
        String path = httpRequest.getRequestURI().toLowerCase();
        String method = httpRequest.getMethod();
        
        // 의심스러운 패턴 검사
        if (isSuspiciousPath(path)) {
            log.warn("Blocked suspicious request: {} {}", method, path);
            
            httpResponse.setStatus(HttpServletResponse.SC_FORBIDDEN);
            httpResponse.setContentType("application/json");
            httpResponse.getWriter().write("{\"error\":\"Forbidden\",\"message\":\"Access denied\"}");
            return;
        }
        
        // 정상 요청은 다음 필터로 전달
        chain.doFilter(request, response);
    }

    /**
     * 의심스러운 경로인지 검사
     */
    private boolean isSuspiciousPath(String path) {
        // 정상적인 API 경로는 허용
        if (path.startsWith("/api/") || 
            path.startsWith("/swagger-") || 
            path.startsWith("/v3/api-docs") ||
            path.equals("/") ||
            path.startsWith("/index.html")) {
            return false;
        }
        
        // 차단 패턴 검사
        for (String pattern : BLOCKED_PATTERNS) {
            if (path.contains(pattern)) {
                return true;
            }
        }
        
        return false;
    }

}
