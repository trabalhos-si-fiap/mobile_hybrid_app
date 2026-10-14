package com.edu.api.support;

import org.springframework.test.context.DynamicPropertyRegistry;
import org.testcontainers.containers.MinIOContainer;
import org.testcontainers.utility.DockerImageName;

/** MinIO efêmero, iniciado uma vez por JVM, como o Oracle dos testes. */
public final class MinioTestContainer {

    // A imagem oficial saiu do Docker Hub; esta é uma cópia idêntica no GHCR.
    private static final DockerImageName IMAGE = DockerImageName
            .parse("ghcr.io/trabalhos-si-fiap/minio:RELEASE.2025-09-07T16-13-09Z")
            .asCompatibleSubstituteFor("minio/minio");

    public static final MinIOContainer MINIO = new MinIOContainer(IMAGE);

    static {
        MINIO.start();
    }

    private MinioTestContainer() {
    }

    public static void register(DynamicPropertyRegistry registry) {
        registry.add("app.storage.minio.url", MINIO::getS3URL);
        registry.add("app.storage.minio.access-key", MINIO::getUserName);
        registry.add("app.storage.minio.secret-key", MINIO::getPassword);
        registry.add("app.storage.minio.bucket", () -> "ticket-attachments-test");
    }
}
