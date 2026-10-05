package com.example.capstone.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.nio.file.Path;
import java.nio.file.Paths;

@Configuration
public class WebConfig implements WebMvcConfigurer {

    @Value("${file.upload-dir:uploads}")
    private String uploadDir;

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/**")
                .allowedOrigins("http://localhost:8080", "http://127.0.0.1:8080")
                .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
                .allowedHeaders("Content-Type", "Authorization");
    }

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        // 절대 경로로 변환하여 리소스 매핑 (Double Slash 방지)
        Path absolutePath = Paths.get(uploadDir).toAbsolutePath().normalize();
        String resourceLocation = "file:///" + absolutePath.toString().replace("\\", "/") + "/";
        
        // /uploads/** URL 패턴을 실제 파일 경로에 매핑
        registry.addResourceHandler("/uploads/**")
                .addResourceLocations(resourceLocation);
    }
}
