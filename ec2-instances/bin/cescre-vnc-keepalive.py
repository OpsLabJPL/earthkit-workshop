#!/usr/bin/python

import os
import subprocess
import time

# This is a script to keep a vnc server running.  If the server dies, we restart it.
# This should be run as user 'ubuntu'.

def preexec():
    '''This method is passed to the subprocess to cause the child process to
    have a different process group. It keeps the child process from receiving
    signals sent to this (parent) process.'''
    os.setpgrp()

#def get_pid_filename():
#    filenames = os.listdir('/home/ubuntu/.vnc')
#    for filename in filenames:
#        if filename.endswith(':1.pid'):
#           return filename
#    return None

def monitor_vnc():
    while True:
#        filename = get_pid_filename()
#        if filename is None:
        subprocess.call(['/usr/bin/vncserver', ':1'], preexec_fn=preexec)
        time.sleep(5)

if __name__ == '__main__':
    subprocess.call(['/usr/bin/vncserver', '-kill', ':1'], preexec_fn=preexec)
    monitor_vnc()
