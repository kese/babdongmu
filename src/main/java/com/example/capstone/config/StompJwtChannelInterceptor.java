package com.example.capstone.config;

import com.example.capstone.security.JwtTokenProvider;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.SimpMessageType;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.AuthorityUtils;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;

@Slf4j
@Component
@RequiredArgsConstructor
public class StompJwtChannelInterceptor implements ChannelInterceptor {

    private static final String BEARER_PREFIX = "Bearer ";
    private static final String AUTHORIZATION_HEADER = "Authorization";
    private static final String ACCESS_TOKEN_HEADER = "accessToken";

    private final JwtTokenProvider jwtTokenProvider;

    @Override
    public Message<?> preSend(Message<?> message, MessageChannel channel) {
        StompHeaderAccessor accessor = MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);
        if (accessor == null) {
            return message;
        }

        StompCommand command = accessor.getCommand();
        if (command == null) {
            return message;
        }

        if (StompCommand.CONNECT.equals(command)) {
            authenticate(accessor);
        }
        return message;
    }

    private void authenticate(StompHeaderAccessor accessor) {
        String token = resolveToken(accessor);
        if (!StringUtils.hasText(token) || !jwtTokenProvider.validateToken(token)) {
            throw new IllegalArgumentException("유효하지 않은 STOMP 연결 요청입니다.");
        }

        Long userId = jwtTokenProvider.getUserIdFromToken(token);
        Authentication authentication = new UsernamePasswordAuthenticationToken(
            userId,
            null,
            AuthorityUtils.NO_AUTHORITIES
        );
        accessor.setUser(authentication);
        accessor.setLeaveMutable(true);
        accessor.setMessageTypeIfNotSet(SimpMessageType.CONNECT);
    }

    private String resolveToken(StompHeaderAccessor accessor) {
        String authorization = accessor.getFirstNativeHeader(AUTHORIZATION_HEADER);
        if (StringUtils.hasText(authorization) && authorization.startsWith(BEARER_PREFIX)) {
            return authorization.substring(BEARER_PREFIX.length());
        }
        String accessToken = accessor.getFirstNativeHeader(ACCESS_TOKEN_HEADER);
        if (StringUtils.hasText(accessToken)) {
            return accessToken;
        }
        return null;
    }
}
