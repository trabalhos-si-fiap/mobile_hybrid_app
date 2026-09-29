package com.edu.api.ticket.dto;

import java.util.Locale;

public enum QueueScope {
    MINE,
    SKILLS,
    ALL;

    public static QueueScope parse(String value) {
        try {
            return valueOf(value.trim().toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException("scope: use mine, skills ou all");
        }
    }
}
