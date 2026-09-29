package com.edu.api.storage;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app.storage.minio")
public record MinioProperties(String url, String accessKey, String secretKey, String bucket) {}
