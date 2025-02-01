FROM php:8.1-apache AS app

RUN apt-get update && apt-get install -y \
    libpq-dev \
    libzip-dev \
    zip \
    unzip \
    redis \
    && docker-php-ext-install pdo_mysql \
    && pecl install redis \
    && docker-php-ext-enable redis

RUN a2enmod rewrite

COPY . /var/www/html/

EXPOSE 80

WORKDIR /var/www/html/