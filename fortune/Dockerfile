# Stage 1: Convert images
FROM alpine:latest AS converter

COPY images /images
COPY convert.sh /convert.sh

RUN apk add --no-cache imagemagick libjpeg && \
    chmod +x /convert.sh && /convert.sh && \
    apk del imagemagick libjpeg && \
    rm -rf /var/cache/apk/* /tmp/*

# Stage 2: Build the final image
FROM nginx:stable-alpine AS fortune

RUN apk update && apk add --no-cache php82 php82-fpm fortune && \
    rm -rf /var/cache/apk/*

COPY nginx.conf /etc/nginx/nginx.conf
COPY php-fpm.conf /etc/php81/php-fpm.d/www.conf
COPY --from=converter /images /var/www/html/images
COPY index.php /var/www/html/

RUN adduser -D -u 1000 -G www-data www-data && \
    chown -R www-data:www-data /var/www/html && \
    rm -rf /tmp/*

EXPOSE 80

CMD ["sh", "-c", "php-fpm82 --daemonize && nginx -g 'daemon off;'"]