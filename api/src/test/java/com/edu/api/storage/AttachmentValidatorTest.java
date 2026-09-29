package com.edu.api.storage;

import com.edu.api.shared.exception.ValidationException;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.web.multipart.MultipartFile;

import java.util.ArrayList;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class AttachmentValidatorTest {

    private final AttachmentValidator validator = new AttachmentValidator();

    private static MultipartFile file(String name, String type, int size) {
        return new MockMultipartFile("files", name, type, new byte[size]);
    }

    @Test
    void acceptsImagesAndPdfsAndIgnoresMissingParts() {
        assertThat(validator.validate(null)).isEmpty();
        assertThat(validator.validate(List.of(file("a.png", "image/png", 10), file("b.pdf", "application/pdf", 10))))
                .hasSize(2);
    }

    @Test
    void rejectsOtherFileTypes() {
        assertThatThrownBy(() -> validator.validate(List.of(file("virus.exe", "application/octet-stream", 10))))
                .isInstanceOf(ValidationException.class)
                .hasMessageContaining("virus.exe");
    }

    @Test
    void rejectsFilesOverFiveMegabytes() {
        assertThatThrownBy(() -> validator.validate(List.of(file("big.jpg", "image/jpeg", 5 * 1024 * 1024 + 1))))
                .isInstanceOf(ValidationException.class)
                .hasMessageContaining("5 MB");
    }

    @Test
    void rejectsMoreThanFiveFiles() {
        List<MultipartFile> six = new ArrayList<>();
        for (int i = 0; i < 6; i++) {
            six.add(file(i + ".png", "image/png", 10));
        }

        assertThatThrownBy(() -> validator.validate(six)).isInstanceOf(ValidationException.class);
    }

    @Test
    void rejectsEmptyFiles() {
        assertThatThrownBy(() -> validator.validate(List.of(file("vazio.png", "image/png", 0))))
                .isInstanceOf(ValidationException.class)
                .hasMessageContaining("vazio.png");
    }
}
