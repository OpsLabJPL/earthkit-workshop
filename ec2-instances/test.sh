# Runs a command as it would be run via upstart
user=root
cmd="/usr/bin/python /usr/local/cescre/bin/cescre-vnc-keepalive.py"
su -c 'nohup env -i $cmd </dev/null >/dev/null 2>&1 &' $user
