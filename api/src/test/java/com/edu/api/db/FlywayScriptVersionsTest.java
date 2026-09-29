package com.edu.api.db;

import org.flywaydb.core.api.MigrationVersion;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.Resource;
import org.springframework.core.io.support.PathMatchingResourcePatternResolver;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * O Flyway numera as versões globalmente entre as pastas. Os testes de
 * integração não leem {@code db/seed}, então uma colisão entre
 * {@code db/migration} e {@code db/seed} passaria no {@code verify} e só
 * quebraria na subida da aplicação. Este teste lê apenas nomes de arquivo.
 */
class FlywayScriptVersionsTest {

    private static final List<String> LOCATIONS = List.of("db/migration", "db/plsql", "db/seed");
    private static final Pattern VERSIONED = Pattern.compile("V([0-9._]+)__.+\\.sql");

    @Test
    void versionedScriptsHaveUniqueVersionsAcrossLocations() throws IOException {
        var resolver = new PathMatchingResourcePatternResolver();
        Map<MigrationVersion, List<String>> scriptsByVersion = new TreeMap<>();

        for (String location : LOCATIONS) {
            for (Resource script : resolver.getResources("classpath*:" + location + "/V*__*.sql")) {
                Matcher name = VERSIONED.matcher(script.getFilename());
                assertThat(name.matches()).as("nome de migration inválido: %s", script.getFilename()).isTrue();
                scriptsByVersion
                        .computeIfAbsent(MigrationVersion.fromVersion(name.group(1)), v -> new ArrayList<>())
                        .add(location + "/" + script.getFilename());
            }
        }

        assertThat(scriptsByVersion).isNotEmpty();
        assertThat(scriptsByVersion.values())
                .as("versões repetidas entre %s", LOCATIONS)
                .allSatisfy(scripts -> assertThat(scripts).hasSize(1));
    }
}
