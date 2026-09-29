package com.edu.api.storage;

import com.edu.api.shared.exception.ValidationException;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.Objects;
import java.util.Set;

/** Regras de anexo: PNG/JPEG/WEBP/PDF, até 5 MB cada, até 5 por envio. */
@Component
public class AttachmentValidator {

    static final Set<String> ALLOWED_TYPES = Set.of("image/png", "image/jpeg", "image/webp", "application/pdf");
    static final long MAX_BYTES = 5L * 1024 * 1024;
    static final int MAX_FILES = 5;

    public List<MultipartFile> validate(List<MultipartFile> files) {
        List<MultipartFile> present = files == null ? List.of() : files.stream().filter(Objects::nonNull).toList();

        if (present.size() > MAX_FILES) {
            throw new ValidationException("Envie no máximo " + MAX_FILES + " arquivos por vez");
        }
        for (MultipartFile file : present) {
            String name = file.getOriginalFilename();
            if (file.isEmpty()) {
                throw new ValidationException("Arquivo vazio: " + name);
            }
            if (!ALLOWED_TYPES.contains(file.getContentType())) {
                throw new ValidationException("Tipo de arquivo não permitido: " + name
                        + " (" + file.getContentType() + "). Use PNG, JPEG, WEBP ou PDF");
            }
            if (file.getSize() > MAX_BYTES) {
                throw new ValidationException("Arquivo maior que 5 MB: " + name);
            }
        }
        return present;
    }
}
