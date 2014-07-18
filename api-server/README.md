EarthKit Workshop API Server
============================

The EarthKit Lab web application was used to lead an interactive session at the
UNAVCO 2013 Climate Workshop. CESCRE Launcher API is the server-side component
of that system responsible for user authentication and the provisioning of cloud
instance on Amazon EC2.

TODO
====
+ source AWS script in runme.sh
+ add SSL certs and enable/disable to config.rb
+ go through source and remove unnecessary comments

Installation & Usage
====================

Language Pre-Reqs
-----------------
+ ruby
+ redis-server

Build Instructions
------------------
```
$ gem install bundler
$ bundle install
```

Configuration -- AWS
--------------------

An Amazon IAM API key pair is required for the server to manage EC2 instances.
These keys are read from environment variables. As an example, settings these
variables in bash would look like the following. Remember to use an IAM key with
EC2 permissions!
```
export AWS_REGION='us-west-1'
export AWS_ACCESS_KEY='your key'
export AWS_SECRET_KEY='your secret'
```

Configuration -- config.rb
--------------------------

General server configuration can be found in `config.rb`. Field descriptions are
as follows.

+ `:workshop` -- workshop identifier string
+ `:ec2` `:key_pair` -- the EC2 SSH keypair name to use with instances
+ `:ec2` `:security_group` -- the EC2 security group to apply to instances
+ `:ec2` `:subnet` -- the EC2 VPC subnet to launch instances into
+ `:redis` `:host` -- the IP or hostname of the redis server
+ `:redis` `:port` -- the port number of the redis server
+ `:ssl` `:enabled` -- enables or disables SSL (boolean)
+ `:ssl` `:certificate` -- path to the SSL certificate chain file (relpath ok)
+ `:ssl` `:key` -- path to the SSL private key file (relpath ok)

Run Instructions
----------------
The following command launches the API server using Thin on port 4567.
```
$ ruby lib/server.rb
```
