FROM mysql:8.2

ENV MYSQL_USER=petclinic \
    MYSQL_PASSWORD=petclinic \
    MYSQL_ROOT_PASSWORD=root \
    MYSQL_DATABASE=petclinic

EXPOSE 3306





