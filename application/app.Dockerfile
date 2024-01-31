FROM openjdk:17-bullseye
COPY target/myapp.jar app.jar
CMD [ "java", "-jar", "app.jar" ]