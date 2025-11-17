#!/bin/bash

# Sourced from https://www.webhi.com/how-to/how-to-install-modsecurity-in-nginx-on-ubuntu-18-04-20-4-22-04-debian/

if whoami | grep -qv root
then

    echo "You are not root, so sudo will be used for privileged commands"
    export sudo=sudo

fi

# Get current dir path
cur_dir=$(dirname $(realpath $0))

# Install required packages
$sudo apt-get update
$sudo apt-get install -y git jq curl libtool autoconf build-essential libpcre3-dev zlib1g-dev libssl-dev libxml2-dev libgeoip-dev liblmdb-dev libyajl-dev libcurl4-openssl-dev pkgconf libxslt1-dev libgd-dev nginx-full automake libmodsecurity3

if apt search "libpcre\+\+-dev" | grep -q libpcre\+\+-dev
then

    $sudo apt-get install -y libpcre++-dev

else

    curl -o /tmp/libpcre1.deb -sSL "http://launchpadlibrarian.net/564387724/libpcre++0v5_0.9.5-7_amd64.deb"
    curl -o /tmp/libpcre2.deb -sSL "http://launchpadlibrarian.net/564387721/libpcre++-dev_0.9.5-7_amd64.deb"
    $sudo dpkg -i /tmp/libpcre1.deb
    $sudo dpkg -i /tmp/libpcre2.deb

fi


# Prepare ModSecurity repo
$sudo rm -rf $cur_dir/src
$sudo mkdir -p $cur_dir/modsec-build/ $cur_dir/src /opt/modsecurity
# Prepare ModSecurity repo
cd $cur_dir/src
$sudo git clone --depth 1 -b v3/encodejsaudit --single-branch https://github.com/airween/ModSecurity.git
cd $cur_dir/src/ModSecurity
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
cd $cur_dir/src/cpg/nginx-${nginx_ver}
$sudo sh configure --with-compat --with-openssl=/usr/include/openssl/ --add-dynamic-module=$cur_dir/src/cpg/ModSecurity-nginx
$sudo make modules
$sudo cp $cur_dir/src/cpg/nginx-${nginx_ver}/objs/ngx_http_modsecurity_module.so /usr/share/nginx/modules/

# Configure ModSecurity
cd /opt/modsecurity
$sudo cp $cur_dir/src/ModSecurity/unicode.mapping ./
$sudo rm -rf $cur_dir/src
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
