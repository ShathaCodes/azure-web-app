#!/bin/bash
sudo apt-get update
sudo apt install docker.io -y
sudo systemctl start docker
sudo systemctl enable docker

sudo docker pull shatha20/bookshopback:cloud

sudo docker run -d -t -i \
-e SPRING_DATASOURCE_URL='jdbc:postgresql://the-book-boutique-server.privatelink.postgres.database.azure.com.:5432/the-book-boutique-db?sslmode=require' \
-e SPRING_DATASOURCE_PASSWORD='H@Sh1CoR3!' \
-e SPRING_DATASOURCE_USERNAME='shatha@the-book-boutique-server' \
-p 8080:8080 \
--name back shatha20/bookshopback:cloud 