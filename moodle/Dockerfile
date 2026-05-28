FROM php:8.3-apache

# -------------------------------------------------------
# System-Abhängigkeiten installieren
# -------------------------------------------------------
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    libxml2-dev \
    libcurl4-openssl-dev \
    libonig-dev \
    libicu-dev \
    unzip \
    curl \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install \
        gd \
        intl \
        mysqli \
        pdo_mysql \
        zip \
        xml \
        curl \
        mbstring \
        soap \
        opcache \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# -------------------------------------------------------
# Moodle als ZIP herunterladen
# -------------------------------------------------------
RUN curl -fsSL "https://packaging.moodle.org/stable500/moodle-latest-500.tgz" \
        -o /tmp/moodle.tgz \
    && tar -xzf /tmp/moodle.tgz -C /var/www/html/ \
    && rm /tmp/moodle.tgz \
    && chown -R www-data:www-data /var/www/html/moodle

# -------------------------------------------------------
# moodledata-Verzeichnis
# -------------------------------------------------------
RUN mkdir -p /var/moodledata \
    && chown -R www-data:www-data /var/moodledata \
    && chmod 0777 /var/moodledata

# -------------------------------------------------------
# Apache konfigurieren
# -------------------------------------------------------
RUN a2enmod rewrite
COPY moodle.conf /etc/apache2/sites-available/000-default.conf

# -------------------------------------------------------
# PHP-Konfiguration
# -------------------------------------------------------
RUN echo "max_input_vars = 5000"         >> /usr/local/etc/php/conf.d/moodle.ini \
    && echo "upload_max_filesize = 512M" >> /usr/local/etc/php/conf.d/moodle.ini \
    && echo "post_max_size = 512M"       >> /usr/local/etc/php/conf.d/moodle.ini \
    && echo "opcache.enable = 1"         >> /usr/local/etc/php/conf.d/moodle.ini

# -------------------------------------------------------
# Moodle config.php einkopieren
# -------------------------------------------------------
COPY config.php /var/www/html/moodle/config.php
RUN chown www-data:www-data /var/www/html/moodle/config.php

EXPOSE 80
