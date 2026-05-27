FROM php:8.3-apache

# -------------------------------------------------------
# System-Abhängigkeiten + Git installieren
# (libsoap-dev existiert nicht separat – soap nutzt libxml2-dev)
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
    git \
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
# Moodle via Git klonen (offizielles Moodle-Repository)
# -------------------------------------------------------
RUN git clone --depth 1 \
        --branch MOODLE_502_STABLE \
        https://github.com/moodle/moodle.git \
        /var/www/html/moodle \
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
