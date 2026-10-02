package com.edu.api;

import org.junit.jupiter.api.Test;
import org.springframework.core.io.ClassPathResource;
import org.yaml.snakeyaml.Yaml;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.assertj.core.api.Assertions.assertThat;

/** O openapi.yaml é o contrato dos clientes: todo endpoint documentado e todo $ref resolvível. */
class OpenApiContractTest {

    private static String raw() throws IOException {
        try (InputStream in = new ClassPathResource("static/openapi.yaml").getInputStream()) {
            return new String(in.readAllBytes(), StandardCharsets.UTF_8);
        }
    }

    @Test
    @SuppressWarnings("unchecked")
    void documentsTheTicketEndpointsWithResolvableReferences() throws IOException {
        String raw = raw();
        Map<String, Object> spec = new Yaml().load(raw);
        Map<String, Object> paths = (Map<String, Object>) spec.get("paths");
        Map<String, Object> components = (Map<String, Object>) spec.get("components");

        assertThat(paths).containsKeys(
                "/dashboard/omnichannel",
                "/segments", "/tickets", "/tickets/mine", "/tickets/queue",
                "/tickets/{ticketId}", "/tickets/{ticketId}/messages", "/tickets/{ticketId}/chatbot-conversation",
                "/tickets/{ticketId}/attachments/{attachmentId}",
                "/tickets/{ticketId}/confirm", "/tickets/{ticketId}/reopen", "/tickets/{ticketId}/events",
                "/tickets/{ticketId}/assume", "/tickets/{ticketId}/resolve", "/tickets/{ticketId}/transfer",
                "/tickets/{ticketId}/engineering-alert",
                "/employees/me", "/employees/me/presence",
                "/notifications", "/notifications/{notificationId}/read", "/notifications/read-all",
                "/chatbot/conversations", "/chatbot/conversations/{conversationId}/messages");

        Matcher refs = Pattern.compile("\\$ref: '#/components/(\\w+)/(\\w+)'").matcher(raw);
        while (refs.find()) {
            Map<String, Object> section = (Map<String, Object>) components.get(refs.group(1));
            assertThat(section).as("seção components.%s", refs.group(1)).isNotNull();
            assertThat(section).as("$ref %s/%s", refs.group(1), refs.group(2)).containsKey(refs.group(2));
        }
    }
}
