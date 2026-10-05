package com.example.capstone.dto.sharedcart;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;

public record SharedCartItemRequestDto(
        @NotBlank(message = "메뉴명을 입력하세요.") String name,
        @Min(value = 0, message = "가격은 0 이상이어야 합니다.") int price
) {
}
