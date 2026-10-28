# Build: dependências numa camada própria, para reaproveitar o cache entre builds.
# No CI este estágio é trocado pelo jar que passou nos testes
# (build-contexts: build=..., em .github/workflows/ci-cd.yml).
FROM maven:3.9.16-eclipse-temurin-21@sha256:99e61abcff91a9b1333463bd8451fb18495d6eba9250ac66a338b518f8278320 AS build
WORKDIR /build
COPY pom.xml .
RUN mvn -B -q dependency:go-offline
COPY src ./src
RUN mvn -B -q package -DskipTests

# Runtime: só a JRE e o jar, com usuário sem privilégios.
FROM eclipse-temurin:21.0.12.1_1-jre@sha256:dc9cf8ce05fab93643ec058491c3f0ab3cf65de8e11e7a8a999570364399f4a3
RUN useradd --system --uid 10001 app
WORKDIR /app
COPY --from=build /build/target/*.jar app.jar
USER app
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
