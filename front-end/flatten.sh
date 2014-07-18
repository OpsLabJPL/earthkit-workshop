#!/bin/bash

HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOG_DIR=/home/ubuntu/log
WWW_DIR=/home/ubuntu/www

cd $HERE

### Clean
rm -rf /home/ubuntu/www
mkdir $LOG_DIR

### Build
grunt clean
grunt handlebars
grunt build
grunt cssmin
cp -r ./app $WWW_DIR

### fire ze missiles
sudo nginx -c $HERE/nginx.conf
