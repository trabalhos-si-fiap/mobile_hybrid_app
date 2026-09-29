package com.edu.api.ticket.service;

import com.edu.api.shared.exception.ValidationException;

/** Validação dos textos livres vindos de multipart (sem Bean Validation). */
final class TicketTexts {

    static final int MAX_LENGTH = 2000;

    private TicketTexts() {
    }

    static String require(String value, String field) {
        if (value == null || value.isBlank()) {
            throw new ValidationException(field + ": não pode ficar em branco");
        }
        String text = value.strip();
        if (text.length() > MAX_LENGTH) {
            throw new ValidationException(field + ": máximo de " + MAX_LENGTH + " caracteres");
        }
        return text;
    }
}
