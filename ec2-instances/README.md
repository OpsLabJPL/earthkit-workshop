EarthKit Workshop EC2 Instance Tooling
======================================

This is a collection of scripts and services that should be installed into an
EC2 instance to make an AMI compatible with the EarthKit workshop platform. The
goal of this bundle is to make it easy to generate new
workshop-compatible instances.

## Installation

_NOTE: This has only been tested on Ubuntu 12.04_

Currently the services must be installed into `/usr/local/cescre`.  Also note
that the current installation procedure assumes that the general username is
"ubuntu".  Changing it to a different user involves tweaking the steps below
and updating the references to "ubuntu" in the install script and in
`guacaomle/user-mapping.xml`.

```bash
cd /usr/local
sudo git clone https://github.jpl.nasa.gov/CESCRE/workshop-services.git
# Rename the newly cloned folder to 'cescre'
sudo mv workshop-services cescre
# Make sure the permissions are correct
sudo chown -R ubuntu:ubuntu cescre
cd cescre
sudo ./install
# Now make sure the services are running
sudo start guacd
sudo start tomcat7
sudo start cescre-mounter
sudo start cescre-ttyjs
sudo start cescre-vnc-keepalive
```

After that, the system should be good to go.

## Services

Here is a rundown of all the services installed / used in this project.

* **cescre-mounter** - Provides a remote volume mounter service. This is used by
the workshop API.
* **cescre-ttyjs** - Provides a [tty.js](https://github.com/chjj/tty.js) server.
This is what allows in-browser connections to the instance via the ttyjs
library.
* **cescre-vnc-keepalive** - Provides a simple service to keep at least one VNC
session active at all times.
* **tomcat7** - Servlet host, needed for the Guacamole web client.
* **guacd** - The communication layer between the Guacamole web client and the
VNC server.

## Folder structure

Here's a rundown of the folder structure and how everything is used.

* `bin/` - Location of Python scripts run by cescre-mounter and cescre-vnc-keepalive
* `etc/` - Configuration used by cescre-mounter.py
* `guacamole/` - guacd configuration installed to `/etc/guacamole/`
* `tomcat7/` - configuration for tomcat7, installed to `/etc/tomcat7`
* `upstart/` - upstart scripts for the cescre-* services, installed to `/etc/init`
* `vnc` - VNC configuration that is installed into the user home directory,
e.g. `/home/ubuntu/.vnc`
