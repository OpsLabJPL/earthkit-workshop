#!/bin/bash

HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cd $HERE
source aws-creds.sh
ruby lib/server.rb &>> /home/ubuntu/log/api.log &
