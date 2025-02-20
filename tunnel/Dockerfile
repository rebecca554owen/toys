FROM nginx:alpine-slim

WORKDIR /etc/nginx

COPY ./tunnel /etc/nginx
COPY ./tunnel/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

CMD ["nginx", "-g", "daemon off;"]
