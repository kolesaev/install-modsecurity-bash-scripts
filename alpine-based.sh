#!/bin/bash

if whoami | grep -qv root
then

    echo "You are not root, so sudo will be used for privileged commands"
    export sudo=sudo

fi

# Get current dir path
cur_dir=$(dirname $(realpath $0))

# Install required packages
apk add --no-cache git jq curl libtool autoconf build-base pcre-dev zlib-dev openssl-dev libxml2-dev geoip-dev lmdb-dev yajl-dev curl-dev pkgconf libxslt-dev gd-dev automake

rm -rf $cur_dir/src
mkdir -p $cur_dir/modsec-build/
mkdir -p $cur_dir/src
# Prepare ModSecurity repo
cd $cur_dir/src
$sudo git clone --depth 1 -b v3/encodejsaudit --single-branch https://github.com/airween/ModSecurity.git
cd ModSecurity
$sudo git submodule init
$sudo git submodule update
$sudo bash build.sh
$sudo sh configure
$sudo make
$sudo make install

# Prepare nginx module
$sudo rm -rf $cur_dir/src/cpg
$sudo mkdir $cur_dir/src/cpg
cd $cur_dir/src/cpg
nginx_ver=$(nginx -v 2>&1 | awk '{print $3}' | awk -F / '{print $2}')
$sudo curl -sSLO "http://nginx.org/download/nginx-${nginx_ver}.tar.gz"
$sudo tar -xvzf nginx-${nginx_ver}.tar.gz
$sudo git clone https://github.com/SpiderLabs/ModSecurity-nginx $cur_dir/src/cpg/ModSecurity-nginx
cd nginx-${nginx_ver}
$sudo sh configure --with-compat --with-openssl=/usr/include/openssl/ --add-dynamic-module=$cur_dir/src/cpg/ModSecurity-nginx
$sudo make modules
$sudo cp $cur_dir/src/cpg/nginx-${nginx_ver}/objs/ngx_http_modsecurity_module.so $cur_dir/modsec-build/
