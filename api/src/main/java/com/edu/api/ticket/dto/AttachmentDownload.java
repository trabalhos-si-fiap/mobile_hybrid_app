package com.edu.api.ticket.dto;

import java.io.InputStream;

/** Arquivo pronto para streaming na resposta HTTP. */
public record AttachmentDownload(String fileName, String contentType, long size, InputStream content) {}
