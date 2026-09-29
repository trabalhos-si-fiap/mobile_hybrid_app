package com.edu.api.storage;

import com.edu.api.support.MinioTestContainer;
import io.minio.BucketExistsArgs;
import io.minio.MinioClient;
import org.junit.jupiter.api.Test;

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.util.UUID;

import static com.edu.api.support.MinioTestContainer.MINIO;
import static org.assertj.core.api.Assertions.assertThat;

class MinioAttachmentStorageIT {

    private final MinioClient client = MinioClient.builder()
            .endpoint(MINIO.getS3URL())
            .credentials(MINIO.getUserName(), MINIO.getPassword())
            .build();

    private MinioAttachmentStorage storage(String bucket) {
        return new MinioAttachmentStorage(client,
                new MinioProperties(MINIO.getS3URL(), MINIO.getUserName(), MINIO.getPassword(), bucket));
    }

    @Test
    void storesAndReadsBackAnObject() throws Exception {
        MinioAttachmentStorage storage = storage("it-" + UUID.randomUUID());
        byte[] content = "evidência".getBytes();

        storage.put("tickets/1/abc", new ByteArrayInputStream(content), content.length, "text/plain");

        try (InputStream read = storage.get("tickets/1/abc")) {
            assertThat(read.readAllBytes()).isEqualTo(content);
        }
    }

    @Test
    void createsTheBucketOnFirstUse() throws Exception {
        String bucket = "it-" + UUID.randomUUID();

        storage(bucket).put("k", new ByteArrayInputStream(new byte[] {1}), 1, "image/png");

        assertThat(client.bucketExists(BucketExistsArgs.builder().bucket(bucket).build())).isTrue();
    }
}
