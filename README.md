# dsa_deploy

A simple deployment script for the django-sample-app (https://github.com/kirpit/django-sample-app). 
Deploys the app and all dependencies to a basic install of Windows Server 2012 R2 Update.

To run this script you will need:
 1. A server running a clean install of Windows Server 2012 R2 Update
 2. Administrator access
 3. about 8 minutes

When the script completes you will have:
 1. An instance of django-sample-app running in a dedicated user context (dedicated AppPoolIdentity). 
 2. IIS serving the static files on server.ip.addr.here:80 
 3. WFastCGI hosting the app in a python venv
 4. Windows Firewall blocking all traffic except 80,443, and ICMP from anywhere and RDP from local subnets

INSTRUCTIONS:

1. Copy the content of the script and paste into a new file using notepad, save it as django_sample_deploy.ps1 

2. Open a powershell prompt and enter: powershell ./django_sample_deploy.ps1 -executionpolicy unrestricted 

3. When the script completes browse to the site to test it (http://server.ip.addr.here)


