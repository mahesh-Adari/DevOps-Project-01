FROM eclipse-temurin:21-jre

WORKDIR /app

COPY target/dptweb-1.0.war app.war

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.war"]