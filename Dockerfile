FROM debian:stable-20240904-slim

ENV DEBIAN_FRONTEND=noninteractive

# 必要なパッケージのインストール
RUN apt update && apt install -y \
    build-essential \
    libxml2-dev \
    libssl-dev \
    libbz2-dev \
    libcurl4-openssl-dev \
    libjpeg-dev \
    libpng-dev \
    libfreetype6-dev \
    libkrb5-dev \
    libmcrypt-dev \
    libreadline-dev \
    libtidy-dev \
    libxslt1-dev \
    libltdl-dev \
    libgmp-dev \
    wget \
    unzip \
    tzdata

RUN apt install -y lsb-release gnupg && wget https://dev.mysql.com/get/mysql-apt-config_0.8.17-1_all.deb --no-check-certificate && dpkg -i mysql-apt-config_0.8.17-1_all.deb
RUN apt install -y pkg-config

RUN wget https://curl.haxx.se/download/curl-7.68.0.tar.bz2 && \
    tar -xjf curl-7.68.0.tar.bz2 && \
    cd curl-7.68.0 && \
    ./configure --prefix=/usr/local/curl --with-openssl=/usr/local/openssl && \
    make && make install && \
    cd .. && \
    rm -rf curl-7.68.0 curl-7.68.0.tar.bz2

RUN ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime && echo "Asia/Tokyo" > /etc/timezone


# OpenSSL 1.0.2 のダウンロードとインストール
RUN wget https://www.openssl.org/source/openssl-1.0.2u.tar.gz && \
    tar -xzf openssl-1.0.2u.tar.gz && \
    cd openssl-1.0.2u && \
    ./config --prefix=/usr/local/openssl --openssldir=/usr/local/openssl shared zlib && \
    make && make install && \
    cd .. && rm -rf openssl-1.0.2u*

# OpenSSL 1.0.2 を使うように環境変数を設定
ENV LD_LIBRARY_PATH="/usr/local/openssl/lib:/usr/local/icu/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
ENV OPENSSL_INCLUDE_DIR="/usr/local/openssl/include"
ENV OPENSSL_LIB_DIR="/usr/local/openssl/lib"
ENV PATH="/usr/local/php/sbin:/usr/local/openssl/bin:$PATH"

# icu-configのインストール
RUN wget https://github.com/unicode-org/icu/releases/download/release-58-2/icu4c-58_2-src.tgz
RUN tar -xzf icu4c-58_2-src.tgz
WORKDIR icu/source

RUN ./configure --prefix=/usr/local/icu
RUN touch ./i18n/xlocale.h
RUN make && make install

WORKDIR /

# PHP 5.3.29 のダウンロード
RUN wget https://museum.php.net/php5/php-5.3.29.tar.bz2

# # PHP 5.3.29 の解凍
RUN tar -xjf php-5.3.29.tar.bz2
# 
# # 最新の config.guess と config.sub のダウンロード
RUN wget -O php-5.3.29/config.guess https://git.savannah.gnu.org/cgit/config.git/plain/config.guess
RUN wget -O php-5.3.29/config.sub https://git.savannah.gnu.org/cgit/config.git/plain/config.sub

# # ディレクトリを移動
WORKDIR php-5.3.29
ENV LDFLAGS="-L/usr/local/icu/lib -L/usr/local/openssl/lib -lstdc++"

RUN apt install -y libldap2-dev libldb-dev libsasl2-dev
RUN ln -s /usr/lib/x86_64-linux-gnu/libldap.so /usr/lib/libldap.so
RUN ln -s /usr/lib/x86_64-linux-gnu/liblber.so /usr/lib/liblber.so
RUN ln -s /usr/include/x86_64-linux-gnu/gmp.h /usr/include/gmp.h

# 設定を構成
RUN ./configure --prefix=/usr/local/php \
                --sysconfdir=/etc/php \
                --with-config-file-path=/etc/php \
                --with-jpeg-dir=yes \
                --with-png-dir=yes \
                --with-freetype-dir=/usr \
                --with-openssl=/usr/local/openssl \
                --with-icu-dir=/usr/local/icu \
                --with-curl=/usr/local/curl \
                --with-mysqli=mysqlnd \
                --with-mysql=mysqlnd \
                --with-pdo-mysql=mysqlnd \
                --enable-mbstring \
                --with-zlib \
                --with-gd \
                --enable-soap \
                --enable-intl \
                --enable-fpm \
                --with-readline \
                --enable-sockets \
                --enable-sysvsem \
                --enable-sysvshm \
                --enable-pcntl \
                --enable-mbregex \
                --with-mcrypt \
                --enable-shmop \
                --enable-wddx \
                --with-xsl \
                --enable-bcmath \
                --enable-calendar \
                --enable-exif \
                --enable-ftp \
                --with-gettext \
                --enable-mysqlnd \
                --disable-rpath \
                --enable-gd-native-ttf \
                --enable-magic-quotes \
                --enable-xml \
                --enable-dba \
                --enable-xmlreader \
                --enable-xmlwriter \
                --enable-json \
                -enable-zip \
                --enable-sysvmsg \
                --enable-posix \
                --without-gdbm \
                --without-sqlite \
                --with-pear \
                --with-mhash \
                --with-bz2 \
                --with-iconv \
                --with-kerberos \
                --with-layout=GNU \
                --with-xmlrpc \
                --with-gmp=/usr/include \
                --with-ldap \
                --with-ldap-sasl \
                --enable-mysqlnd \
                --with-mysql=mysqlnd \
                --with-mysqli=mysqlnd \
                --with-fpm-user=www-data \
                --with-fpm-group=www-data

# コンパイルとインストール
RUN make && make install
ENV PATH="$PATH:/usr/local/php/bin"


WORKDIR /
RUN apt install -y apache2
RUN apachectl start

RUN groupadd php-fpm && \
    useradd -m -s /bin/bash -g php-fpm php-fpm

COPY config/php-fpm.conf /etc/php

RUN mkdir -p /run/php
RUN chown www-data:www-data /run/php
RUN chmod 770 /run/php

RUN mkdir -p /usr/local/var/log/php-fpm
RUN a2enmod proxy_fcgi setenvif
RUN echo '<?php phpinfo(); ?>' > /var/www/html/info.php

RUN apt install -y vim
