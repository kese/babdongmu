package com.example.capstone.domain.chat;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

@Converter(autoApply = true)
public class ChatRoomTypeConverter implements AttributeConverter<ChatRoomType, String> {

    @Override
    public String convertToDatabaseColumn(ChatRoomType attribute) {
        return attribute == null ? null : attribute.getDbValue();
    }

    @Override
    public ChatRoomType convertToEntityAttribute(String dbData) {
        return ChatRoomType.fromDbValue(dbData);
    }
}
