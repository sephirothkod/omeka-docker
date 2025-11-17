FROM php:5.6-apache

MAINTAINER Braydon Justice <braydon.justice@1268456bcltd.ca>

# Fix Debian Stretch repositories (moved to archive)
RUN sed -i 's/deb.debian.org/archive.debian.org/g' /etc/apt/sources.list \
    && sed -i 's|security.debian.org|archive.debian.org|g' /etc/apt/sources.list \
    && sed -i '/stretch-updates/d' /etc/apt/sources.list

RUN a2enmod rewrite

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get -qq update && apt-get -qq -y --allow-unauthenticated upgrade
RUN apt-get -qq update && apt-get -qq -y --no-install-recommends install \
    unzip \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libmcrypt-dev \
    ffmpeg \
    libpng-dev \
    libjpeg-dev \
    libmemcached-dev \
    zlib1g-dev \
    imagemagick \
    libmagickwand-dev \
    vim \
    wget

# Install the PHP extensions for PHP 5.6
# Note: mcrypt is built-in for PHP 5.6, different gd configuration syntax
RUN docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/
RUN docker-php-ext-install -j$(nproc) iconv pdo pdo_mysql mysqli gd exif mcrypt
RUN pecl install imagick \
&& docker-php-ext-enable imagick

# Install Ghostscript
RUN mkdir -p /installs
ADD https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs926/ghostscript-9.26-linux-x86_64.tgz /installs/
RUN cd /installs && tar -xvf ghostscript-9.26-linux-x86_64.tgz

ENV PATH /installs/ghostscript-9.26-linux-x86_64:$PATH

RUN apt-get -y install build-essential
ADD https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs926/ghostpdl-9.26.tar.gz /installs/
RUN cd /installs && tar -xvf ghostpdl-9.26.tar.gz
RUN apt-get -y install autoconf autogen
RUN cd /installs/ghostpdl-9.26 && ./autogen.sh && ./configure && make -j 5 && make install


ARG version="2.2.2"
ENV version $version

# Add the Omeka Classic 2.2.2 code
ADD https://github.com/omeka/Omeka/releases/download/v$version/omeka-$version.zip /installs/
RUN unzip -q /installs/omeka-$version.zip -d /var/www/ \
&&  rm /installs/omeka-$version.zip \
&&  rm -rf /var/www/html/ \
&&  mv /var/www/omeka-$version/ /var/www/html \
&&  rm /var/www/html/db.ini \
&&  ln -s /var/www/html/volume/config/db.ini /var/www/html/db.ini \
&&  rm /etc/ImageMagick-6/policy.xml \
&&  ln -s /var/www/html/volume/config/policy.xml /etc/ImageMagick-6/policy.xml \
&&  rm /var/www/html/application/config/config.ini \
&&  ln -s /var/www/html/volume/config/config.ini /var/www/html/application/config/config.ini \
&&  rm /var/www/html/.htaccess \
&&  ln -s /var/www/html/volume/config/.htaccess /var/www/html/.htaccess \
&&  rm /usr/local/etc/php/php.ini-production

COPY php.ini-production /usr/local/etc/php/php.ini-production

# Add in a fix for assets being sent insecurely on old versions
COPY https-fix.txt /tmp
RUN sed -i '1r /tmp/https-fix.txt' /var/www/html/bootstrap.php && \
    rm /tmp/https-fix.txt

# Create one volume for files and set permissions
RUN rm -rf /var/www/html/files/ \
&&  rm -rf /var/www/html/themes/ \
&&  rm -rf /var/www/html/plugins/ \
&&  rm -rf /var/www/html/application/logs \
&&  ln -s /var/www/html/volume/files/ /var/www/html/files \
&&  ln -s /var/www/html/volume/themes/ /var/www/html/themes \
&&  ln -s /var/www/html/volume/plugins/ /var/www/html/plugins \
&&  ln -s /var/www/html/volume/logs/ /var/www/html/application/logs \
&&  ln -s /var/www/html/volume/config/ /var/www/html/config \
&&  chown -R www-data:www-data /var/www/html/

COPY ./startup-script.sh /var/www/startup-script.sh
RUN chmod +x /var/www/startup-script.sh
ENTRYPOINT ["/var/www/startup-script.sh"]