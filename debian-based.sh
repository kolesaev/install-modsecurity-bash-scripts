#!/bin/bash

# Sourced from https://www.webhi.com/how-to/how-to-install-modsecurity-in-nginx-on-ubuntu-18-04-20-4-22-04-debian/

if whoami | grep -qv root
then

    echo "You are not root, so sudo will be used for privileged commands"
    export sudo=sudo

fi

# Get current dir path
cur_dir=$(pwd)

# Install required packages
$sudo apt-get update
$sudo apt-get install -y git jq curl libtool autoconf build-essential libpcre3-dev zlib1g-dev libssl-dev libxml2-dev libgeoip-dev liblmdb-dev libyajl-dev libcurl4-openssl-dev libpcre++-dev pkgconf libxslt1-dev libgd-dev nginx automake
$sudo mkdir -p /opt/modsecurity

# Prepare ModSecurity repo
cd /usr/local/src
$sudo git clone --depth 1 -b v3/master --single-branch https://github.com/SpiderLabs/ModSecurity
cd ModSecurity
$sudo git submodule init
$sudo git submodule update
$sudo bash build.sh
$sudo ./configure
$sudo make
$sudo make install

# Prepare nginx module
$sudo mkdir /usr/local/src/cpg
cd /usr/local/src/cpg
nginx_ver=$(nginx -v 2>&1 | awk '{print $3}' | awk -F / '{print $2}')
$sudo curl -sSLO "http://nginx.org/download/nginx-${nginx_ver}.tar.gz"
$sudo tar -xvzf nginx-${nginx_ver}.tar.gz
$sudo git clone https://github.com/SpiderLabs/ModSecurity-nginx
cd nginx-${nginx_ver}
$sudo ./configure --with-compat --with-openssl=/usr/include/openssl/ --add-dynamic-module=/usr/local/src/cpg/ModSecurity-nginx
$sudo make modules
$sudo cp objs/ngx_http_modsecurity_module.so /usr/share/nginx/modules/

# Configure ModSecurity
cd /opt/modsecurity
$sudo cp /usr/local/src/ModSecurity/unicode.mapping ./
$sudo rm -rf /usr/local/src/cpg /usr/local/src/ModSecurity
crs_ver=$(curl -sSL https://api.github.com/repos/coreruleset/coreruleset/releases/latest | jq -r .tag_name)
$sudo rm -rf crs
$sudo git clone -b $crs_ver https://github.com/coreruleset/coreruleset.git crs
$sudo cp $cur_dir/modsecurity.conf /opt/modsecurity/modsecurity.conf
$sudo chown -R root:root /opt/modsecurity 

# Configure nginx
echo 'load_module /usr/share/nginx/modules/ngx_http_modsecurity_module.so;' | $sudo tee /etc/nginx/modules-enabled/50-mod-http-modsecurity.conf
$sudo sed -i "s|modsecurity on;||g; s|modsecurity_rules_file.*||g;" /etc/nginx/nginx.conf
$sudo sed -i "/http {/a #\n        modsecurity on;\n        modsecurity_rules_file /opt/modsecurity/modsecurity.conf;" /etc/nginx/nginx.conf

$sudo nginx -t && $sudo nginx -s reload || echo "Error"
