# dsa_deploy

A simple deployment script for the django-sample-app (https://github.com/kirpit/django-sample-app). 
Deploys the app and all dependencies to a minimal install of CentOS 7.

To run this script you will need:
 1. A server running CentOS Linux release 7.1.1503 ('minimal' software selection)
 2. sudo access
 3. about 5 minutes

When the script completes you will have:
 1. An instance of django-sample-app running in a dedicated user context. 
 2. nginx serving the static files on <server.ip.addr.here>:80 
 3. uwsgi hosting the app in a python venv
 4. firewalld blocking all traffic except 80,443, and ICMP from anywhere and SSH from local subnets

INSTRUCTIONS:
