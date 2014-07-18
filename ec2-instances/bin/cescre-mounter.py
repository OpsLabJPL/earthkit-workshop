#!/usr/bin/python

import json
import os
import os.path
import SocketServer
import subprocess
import traceback

AUTH_TOKEN = ''

class MyTCPHandler(SocketServer.StreamRequestHandler):

    def get_paths(self, dev):
        dev = os.path.basename(dev)
        dev_path = os.path.join('/dev', dev)
        if not os.path.exists(dev_path):
            # Try doing the xvd <-> sd conversion
            if dev.startswith('sd'):
                dev = dev.replace('sd', 'xvd')
            elif dev.startswith('xvd'):
                dev = dev.replace('xvd', 'sd')
            dev_path = os.path.join('/dev', dev)
            if not os.path.exists(dev_path):
                # Panic ?
                raise Exception("could not mount device: %s" % dev)
        return dev_path, os.path.join('/mnt', dev)

    def get_vol_path(self, dev):
        return os.path.join('/mnt', os.path.basename(dev))

    def mount(self, dev):
        # Generate the volume path
        #vol_path = self.get_vol_path(dev)
        dev_path, mnt_path = self.get_paths(dev)
        if os.path.ismount(mnt_path):
            # Already mounted
            return
        if not os.path.exists(mnt_path):
            os.mkdir(mnt_path)
        subprocess.check_call(['mount', dev_path, mnt_path])

    def umount(self, dev):
        dev_path, mnt_path = self.get_paths(dev)
        self._umount(mnt_path)

    def _umount(self, mnt_path):
        if not os.path.ismount(mnt_path):
            # Not mounted
            return
        subprocess.check_call(['umount', mnt_path])
        os.rmdir(mnt_path)

    def ok(self):
        if not self.wfile.closed:
            self.wfile.write('OK\\n')

    def error(self, msg):
        if not self.wfile.closed:
            self.wfile.write('ERROR\\n' + msg)

    def handle(self):
        try:
            self.__handle()
        except Exception, e:
            self.error(traceback.format_exc())
        finally:
            self.ok()

    def __handle(self):
        global AUTH_TOKEN
        data = self.rfile.readline().strip()
        if len(data) == 0:
            return
        args = data.split(':', 2)
        auth_key = args[0]
        action = args[1]
        if len(args) > 2:
            args = args[2].split(':')
        if auth_key != AUTH_TOKEN:
            raise Exception('invalid authorization key')
        if action == 'MOUNT':
            self.mount(*args)
        elif action == 'UMOUNT':
            self.umount(*args)
        else:
            raise Exception('invalid command: %s' % action)

class ThreadingTCPServer(SocketServer.ThreadingMixIn, SocketServer.TCPServer): pass

if __name__ == "__main__":
    f = open('/usr/local/cescre/etc/remote-mounter.json')
    jsonObj = json.loads(f.read())
    f.close()
    AUTH_TOKEN = jsonObj.get('auth_token', '')
    HOST, PORT = '', 57775
    server = ThreadingTCPServer((HOST, PORT), MyTCPHandler)
    try:
        server.serve_forever()
    finally:
        server.socket.close()
