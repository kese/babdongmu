package com.example.capstone.domain;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

@Converter(autoApply = true)
public class AuthEventTypeConverter implements AttributeConverter<AuthEventType, String> {

    @Override
    public String convertToDatabaseColumn(AuthEventType attribute) {
        return attribute == null ? null : attribute.getDbValue();
    }

    @Override
    public AuthEventType convertToEntityAttribute(String dbData) {
        return AuthEventType.fromDbValue(dbData);
    }
}
