package com.edu.api.storage;

import java.io.InputStream;

/** Onde os bytes dos anexos ficam; o banco guarda só a chave. */
public interface AttachmentStorage {

    void put(String objectKey, InputStream content, long size, String contentType);

    InputStream get(String objectKey);
}
