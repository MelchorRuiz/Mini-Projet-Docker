FROM php:7.4-apache

# Install necessary libraries for MySQL and Redis
RUN docker-php-ext-install mysqli && \
    pecl install redis && \
    docker-php-ext-enable redis

# Copy the application code
COPY index.php /var/www/html/index.php

# Set the working directory
WORKDIR /var/www/html

# Expose port 80
EXPOSE 80