CESCRE Launcher API Restlet
===========================

For now, we are only using region "us-west-1".
Make sure you have the environment variables set for AWS credentials before doing anything.  To do this, you need to set the variables below.  You can also set them in the `aws_creds.sh` script and run `source aws_creds.sh`.

    export AWS_REGION='us-west-1'
    export AWS_ACCESS_KEY='your key'
    export AWS_SECRET_KEY='your secret'

The server now depends on redis being installed.  So you must launch redis-server before starting the server.
To launch the server, run from project root:

  ruby ./lib/server.rb -p 4567

### Example to launch an instance

  curl -XPOST -d '{"ami":"ami-d47b5691","instance_type":"t1.micro","name":"foo1","volume_snapshots":[]}' http://localhost:4567/users/bgeorge/instances

### Example to create a volume

  curl -XPOST -d '{"snapshot_id":"snap-4ff9fc60"}' http://localhost:4567/users/bgeorge/instances/i-db79d183/volumes

Notes
-----
The self-signed SSL certificates provided in this repo are for development purposes only. Actual trusted certificates should be used in production.
