package com.example.capstone.domain.post;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

@Converter(autoApply = true)
public class ParticipantRoleConverter implements AttributeConverter<ParticipantRole, String> {

    @Override
    public String convertToDatabaseColumn(ParticipantRole attribute) {
        return attribute == null ? null : attribute.toDatabaseValue();
    }

    @Override
    public ParticipantRole convertToEntityAttribute(String dbData) {
        return ParticipantRole.fromDatabaseValue(dbData);
    }
}
