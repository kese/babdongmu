package com.example.capstone;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class CapstoneServerApplication {

    public static void main(String[] args) {
        SpringApplication.run(CapstoneServerApplication.class, args);
    }

}
