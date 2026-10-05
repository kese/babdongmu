package com.example.capstone.domain.chat;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

@Converter(autoApply = true)
public class MessageTypeConverter implements AttributeConverter<MessageType, String> {

    @Override
    public String convertToDatabaseColumn(MessageType attribute) {
        return attribute == null ? null : attribute.getDbValue();
    }

    @Override
    public MessageType convertToEntityAttribute(String dbData) {
        return MessageType.fromDbValue(dbData);
    }
}
