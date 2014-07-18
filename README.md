EarthKit Workshop
=================

This repository contains a prototype self-paced educational web application. It
is based around sets of self-paced lab tutorials that teach workshop
participants about various earth science data processing tools. Participants
are able to launch a cloud instance pre-loaded with the relevant tools and
access remote desktop sessions with their web browser. In order to gather
real-world user feedback, the system was used to lead a tutorial session at the
UNAVCO 2013 Climate Workshop.


Components
----------

+ **api-server**: API server that controls authentication, client notification,
and EC2 instance management
+ **front-end**: static HTML frontend
+ **ec2-instsances**: tooling that needs to be included in the EC2 AMI


Disclaimer
----------

This project contains alpha-level code not suitable for use in a production
environment. It is being made available under an open source license for
educational purposes only.


License
-------

The software is available under the Apache V2.0 license.

Copyright © 2011-2014 California Institute of Technology. ALL RIGHTS RESERVED.
United States Government Sponsorship Acknowledged. Any commercial use must be
negotiated with with Office of Technology Transfer at the California Institute
of Technology. This software may be subject to U.S. export control laws. By
accepting this software, the user agrees to comply with all applicable U.S.
export laws and regulations. User has the responsibility to obtain export
licenses, or other export authority as may be required before exporting such
information to foreign countries or providing access to foreign persons. Neither
the name of Caltech nor its operating division, the Jet Propulsion Laboratory,
nor the names of its contributors may be used to endorse or promote products
derived from this software without specific prior written permission.
