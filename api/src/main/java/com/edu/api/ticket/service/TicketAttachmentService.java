package com.edu.api.ticket.service;

import com.edu.api.shared.exception.NotFoundException;
import com.edu.api.shared.exception.ValidationException;
import com.edu.api.storage.AttachmentStorage;
import com.edu.api.storage.AttachmentValidator;
import com.edu.api.ticket.dto.AttachmentDownload;
import com.edu.api.ticket.entity.Ticket;
import com.edu.api.ticket.entity.TicketAttachment;
import com.edu.api.ticket.entity.TicketMessage;
import com.edu.api.ticket.repository.TicketAttachmentRepository;
import com.edu.api.user.entity.AdminUser;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStream;
import java.time.Clock;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
public class TicketAttachmentService {

    private final AttachmentStorage storage;
    private final AttachmentValidator validator;
    private final TicketAttachmentRepository attachments;
    private final Clock clock;

    public TicketAttachmentService(AttachmentStorage storage, AttachmentValidator validator,
                                   TicketAttachmentRepository attachments, Clock clock) {
        this.storage = storage;
        this.validator = validator;
        this.attachments = attachments;
        this.clock = clock;
    }

    /** Chamar antes de criar qualquer registro: um arquivo inválido não deixa nada pela metade. */
    public List<MultipartFile> validate(List<MultipartFile> files) {
        return validator.validate(files);
    }

    /** Grava arquivos já validados no MinIO e registra cada um no banco. */
    public List<TicketAttachment> store(Ticket ticket, TicketMessage message, AdminUser uploader,
                                        List<MultipartFile> files) {
        List<TicketAttachment> stored = new ArrayList<>();
        for (MultipartFile file : files) {
            String key = "tickets/" + ticket.getId() + "/" + UUID.randomUUID();
            try (InputStream content = file.getInputStream()) {
                storage.put(key, content, file.getSize(), file.getContentType());
            } catch (IOException e) {
                throw new ValidationException("Não foi possível ler o arquivo " + file.getOriginalFilename());
            }
            stored.add(attachments.save(new TicketAttachment(ticket, message, key, fileName(file),
                    file.getContentType(), file.getSize(), uploader, clock.instant())));
        }
        return stored;
    }

    public AttachmentDownload download(Ticket ticket, long attachmentId) {
        TicketAttachment attachment = attachments.findInTicket(attachmentId, ticket.getId())
                .orElseThrow(() -> new NotFoundException("Anexo " + attachmentId + " não encontrado"));
        return new AttachmentDownload(attachment.getFileName(), attachment.getContentType(),
                attachment.getSizeBytes(), storage.get(attachment.getObjectKey()));
    }

    private static String fileName(MultipartFile file) {
        String original = file.getOriginalFilename();
        if (original == null || original.isBlank()) {
            return "arquivo";
        }
        String name = original.replace('\\', '/');
        name = name.substring(name.lastIndexOf('/') + 1);
        return name.length() > 255 ? name.substring(name.length() - 255) : name;
    }
}
