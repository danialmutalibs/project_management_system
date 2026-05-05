FROM php:8.2-apache

RUN apt-get update && apt-get install -y \
        libpq-dev libzip-dev libpng-dev libjpeg-dev libfreetype6-dev libicu-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install pdo pdo_pgsql pgsql zip gd bcmath intl exif opcache \
    && a2enmod rewrite \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY docker/opcache.ini /usr/local/etc/php/conf.d/opcache.ini

ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf \
    && sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html
COPY . .

RUN cp .env.example .env \
    && mkdir -p bootstrap/cache storage/logs storage/framework/cache storage/framework/sessions storage/framework/views \
    && chmod -R 775 bootstrap/cache storage \
    && composer install --no-interaction --prefer-dist --optimize-autoloader --no-dev --ignore-platform-reqs \
    && chown -R www-data:www-data storage bootstrap/cache public/build

RUN printf '#!/bin/bash\nphp artisan migrate --force || true\nphp artisan config:cache || true\nphp artisan route:cache || true\nphp artisan view:cache || true\nexec php artisan serve --host=0.0.0.0 --port=${PORT:-8080}\n' > /run.sh && chmod +x /run.sh

EXPOSE 8080
CMD ["/run.sh"]
