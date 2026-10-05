package com.example.capstone.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.media.StringSchema;
import io.swagger.v3.oas.models.parameters.Parameter;
import io.swagger.v3.oas.models.security.SecurityScheme;
import io.swagger.v3.oas.models.servers.Server;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.List;

@Configuration
public class SwaggerConfig {

    private static final String BEARER_SCHEME = "bearerAuth";

    @Bean
    public OpenAPI capstoneOpenAPI() {
        Server server = new Server();
        server.setUrl(resolveServerUrl());
        server.setDescription("로컬 개발 서버");

        Contact contact = new Contact();
        contact.setName("Capstone 팀");
        contact.setEmail("support@capstone.example.com");

    Info info = new Info()
        .title("Capstone Server API")
        .version("1.0.0")
        .description("""
            Capstone 프로젝트 REST API 문서입니다.

            ### 인증 가이드
            - JWT 액세스 토큰을 발급받은 후 Swagger UI의 `Authorize` 버튼에서 등록합니다.
            - `Authorization` 헤더는 `Bearer {발급받은 토큰}` 형태를 따릅니다.

            ### 요청/응답 기본 규칙
            - 모든 요청 본문은 `application/json` UTF-8 인코딩을 사용합니다.
            - 시간 정보는 ISO-8601 (`yyyy-MM-dd'T'HH:mm:ss`) 형식의 문자열을 사용합니다.
            - 응답은 snake-case 대신 camelCase 필드를 사용합니다.
            """)
        .contact(contact);

    Components components = new Components()
        .addSecuritySchemes(BEARER_SCHEME, new SecurityScheme()
            .name("Authorization")
            .type(SecurityScheme.Type.HTTP)
            .scheme("bearer")
            .bearerFormat("JWT")
            .in(SecurityScheme.In.HEADER))
        .addParameters("AuthorizationHeader", new Parameter()
            .name("Authorization")
            .in("header")
            .required(true)
            .description("JWT 액세스 토큰. `Bearer {토큰값}` 형식을 따라야 합니다.")
            .schema(new StringSchema()
                .example("Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...")));

        return new OpenAPI()
                .info(info)
        .servers(List.of(server))
        .components(components);
    }

    private String resolveServerUrl() {
        String envUrl = System.getenv("SWAGGER_SERVER_URL");
        if (envUrl != null && !envUrl.isBlank()) {
            return envUrl;
        }

        String sysPropUrl = System.getProperty("swagger.server.url");
        if (sysPropUrl != null && !sysPropUrl.isBlank()) {
            return sysPropUrl;
        }

        return "http://localhost:8080";
    }
}

