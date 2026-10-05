package com.example.capstone.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jws;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.util.Assert;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Date;

/**
 * JWT 토큰 발급 및 검증을 담당하는 유틸리티 컴포넌트.
 */
@Component
public class JwtTokenProvider {

    private final String secret;
    private final long validityInMillis;
    private SecretKey secretKey;

    public JwtTokenProvider(
            @Value("${jwt.secret}") String secret,
            @Value("${jwt.expiration-minutes:120}") long expirationMinutes
    ) {
        this.secret = secret;
        this.validityInMillis = Duration.ofMinutes(expirationMinutes).toMillis();
    }

    @PostConstruct
    void init() {
        Assert.hasText(secret, "JWT secret must not be empty");
        byte[] keyBytes = secret.getBytes(StandardCharsets.UTF_8);
        Assert.isTrue(keyBytes.length >= 32, "JWT secret must be at least 256 bits long");
        this.secretKey = Keys.hmacShaKeyFor(keyBytes);
    }

    public String generateToken(Long userId) {
        Date now = new Date();
        Date expiry = new Date(now.getTime() + validityInMillis);
        return Jwts.builder()
                .subject(String.valueOf(userId))
                .issuedAt(now)
                .expiration(expiry)
                .signWith(secretKey)
                .compact();
    }

    public boolean validateToken(String token) {
        try {
            parseClaims(token);
            return true;
        } catch (Exception ex) {
            return false;
        }
    }

    public Long getUserIdFromToken(String token) {
        Jws<Claims> claims = parseClaims(token);
        return Long.parseLong(claims.getPayload().getSubject());
    }

    private Jws<Claims> parseClaims(String token) {
        return Jwts.parser()
                .verifyWith(secretKey)
                .build()
                .parseSignedClaims(token);
    }
}
