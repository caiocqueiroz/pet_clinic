FROM openjdk:17-bullseye
COPY target/myapp.jar app.jar
ENV SPRING_PROFILES_ACTIVE=mysql
CMD [ "java", "-jar", "app.jar" ]