#!/bin/bash
echo "$(tput setaf 2)Starting deployment of django_sample...$(tput setaf 7)"
cd /srv
# Create a dedicated user
# with a random password
userpws=$(tr -dc [:alnum:] < /dev/urandom | head -c 16)
useradd -U django -p $(openssl passwd -1 $userpws) 

# Create system folders
mkdir -p /etc/uwsgi/vassals
mkdir -p /var/log/uwsgi

# Create application folders
# Set permissions
mkdir -p /srv/python/projects
chgrp -hR django /srv/python 
chmod -R g+w /srv/python/

# Add the EPEL repo 
yum -y install epel-release

# Install, start and init postgres
# set postgres to autostart
# Create user and sample database
yum -y install postgresql postgresql-server
postgresql-setup initdb
systemctl start postgresql
systemctl enable postgresql
sudo -u postgres createuser django --createdb
sudo -u django createdb django_sample

# Install development packages 
# required by the sample app
yum -y install postgresql-devel
yum -y install python-devel
yum -y install gcc
yum -y install git

# Install project files
# clone the repo from git
# Rename the projectname default folder
cd /srv/python/projects
sudo -u django git clone https://github.com/kirpit/django-sample-app.git /srv/python/projects/dsa
mv /srv/python/projects/dsa/projectname /srv/python/projects/dsa/django_sample

# Install global python components
easy_install pip
pip install virtualenv
pip install virtualenvwrapper
pip install uwsgi

# Create the python venv
# and install requirements
source /usr/bin/virtualenvwrapper.sh
export WORKON_HOME=/srv/python
cd /srv/python
mkvirtualenv --clear dsa
pip install -r /srv/python/projects/dsa/requirements.txt
export PYTHONPATH=/srv/python/projects/dsa:$PYTHONPATH


# Customize the sample app
sed -i s/'{{ project_name }}'/django_sample/g /srv/python/projects/dsa/django_sample/wsgi.py
sed -i s/'{{ project_name }}'/django_sample/g /srv/python/projects/dsa/django_sample/settings/default.py
sed -i s/'{{ db_name }}'/django_sample/g /srv/python/projects/dsa/django_sample/settings/default.py
sed -i s/'{{ db_user }}'/django/g /srv/python/projects/dsa/django_sample/settings/default.py
sed -i s/'{{ db_p@ssword }}'/''/g /srv/python/projects/dsa/django_sample/settings/default.py
sed -i s/'localhost'/''/g /srv/python/projects/dsa/django_sample/settings/default.py
sed -i s/'projectname.home'/django_sample.home/g /srv/python/projects/dsa/django_sample/urls.py
secret_key="nwz=djtu3@zhdlkin6ib=l#tu)gtu10%1y2#qmb@cyhkat8mez"
sed -i s/'!!! paste your own secret key here !!!'/$secret_key/g /srv/python/projects/dsa/django_sample/settings/default.py
sed -i s/'ALLOWED_HOSTS = ('/'ALLOWED_HOSTS = ( "*"'/g /srv/python/projects/dsa/django_sample/settings/default.py

# Initialize the sample app database and collect static files
sudo -u django /srv/python/dsa/bin/python /srv/python/projects/dsa/django_sample/manage.py collectstatic --noinput
sudo -u django /srv/python/dsa/bin/python /srv/python/projects/dsa/django_sample/manage.py migrate

# Install nginx
yum -y install nginx
echo "$(tput setaf 2)Configuring nginx...$(tput setaf 7)"
# SELinux modifications for nginx
# Allow nginx to connect over network sockets
# Allow nginx to serve content from the project folder
sudo setsebool -P httpd_can_network_connect 1
sudo chcon -Rt httpd_sys_content_t /srv/python/projects/dsa

# Create an nginx conf file for the site
echo 'upstream django { server 127.0.0.1:8001;}' >> /etc/nginx/conf.d/django.conf
echo 'server {' >> /etc/nginx/conf.d/django.conf
echo '        listen 80;' >> /etc/nginx/conf.d/django.conf
echo '        location /media {' >> /etc/nginx/conf.d/django.conf
echo '               alias /srv/python/projects/dsa/media;}' >> /etc/nginx/conf.d/django.conf
echo '        location /static {' >> /etc/nginx/conf.d/django.conf
echo '               alias /srv/python/projects/dsa/static;}' >> /etc/nginx/conf.d/django.conf
echo '        location / {' >> /etc/nginx/conf.d/django.conf
echo '               uwsgi_pass  django;' >> /etc/nginx/conf.d/django.conf
echo '               include /etc/nginx/uwsgi_params; }}' >> /etc/nginx/conf.d/django.conf

# Stop the default server from listening on port 80
# restart nginx and enable autostart
sed -i '36,37 s:^:#:' /etc/nginx/nginx.conf
systemctl restart nginx
systemctl enable nginx  

# Create a uwsgi ini file for the django_sample project
echo '[uwsgi]' >> /etc/uwsgi/vassals/django_uwsgi.ini
echo 'chdir=/srv/python/projects/dsa' >> /etc/uwsgi/vassals/django_uwsgi.ini
echo 'module=django_sample.wsgi' >> /etc/uwsgi/vassals/django_uwsgi.ini
echo 'socket=127.0.0.1:8001' >> /etc/uwsgi/vassals/django_uwsgi.ini
echo 'master=True' >> /etc/uwsgi/vassals/django_uwsgi.ini
echo 'pidfile=/tmp/project-master.pid' >> /etc/uwsgi/vassals/django_uwsgi.ini
echo 'vacuum=True' >> /etc/uwsgi/vassals/django_uwsgi.ini
echo 'max-requests=5000' >> /etc/uwsgi/vassals/django_uwsgi.ini
echo 'daemonize=/var/log/uwsgi/django.log' >> /etc/uwsgi/vassals/django_uwsgi.ini
echo 'home=/srv/python/dsa' >> /etc/uwsgi/vassals/django_uwsgi.ini
echo 'uid=django' >> /etc/uwsgi/vassals/django_uwsgi.ini
echo 'gid=django' >> /etc/uwsgi/vassals/django_uwsgi.ini

# Create an ini file for the uwsgi emperor
echo '[uwsgi]' >> /etc/uwsgi/emperor.ini
echo 'emperor = /etc/uwsgi/vassals'>> /etc/uwsgi/emperor.ini

# Create a systemd service for the uwsgi emperor
echo '[Unit]'>> /etc/systemd/system/uwsgi.emperor.service
echo 'Description=uWSGI Emperor'>> /etc/systemd/system/uwsgi.emperor.service
echo 'After=syslog.target'>> /etc/systemd/system/uwsgi.emperor.service
echo '[Service]'>> /etc/systemd/system/uwsgi.emperor.service
echo 'ExecStart=/usr/bin/uwsgi --ini /etc/uwsgi/emperor.ini'>> /etc/systemd/system/uwsgi.emperor.service
echo 'Restart=always'>> /etc/systemd/system/uwsgi.emperor.service
echo 'KillSignal=SIGQUIT'>> /etc/systemd/system/uwsgi.emperor.service
echo 'Type=notify'>> /etc/systemd/system/uwsgi.emperor.service
echo 'StandardError=syslog'>> /etc/systemd/system/uwsgi.emperor.service
echo 'NotifyAccess=all'>> /etc/systemd/system/uwsgi.emperor.service
echo '[Install]'>> /etc/systemd/system/uwsgi.emperor.service
echo 'WantedBy=multi-user.target'>> /etc/systemd/system/uwsgi.emperor.service

echo "$(tput setaf 2)Configuring uwsgi...$(tput setaf 7)"
# Start and enable autostart of the uwsgi emperor
systemctl start uwsgi.emperor.service
systemctl enable uwsgi.emperor.service
echo "$(tput setaf 2)Configuring firewall...$(tput setaf 7)"
# Allow SSH traffic from private subnets
firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -s 192.168.0/16 -p tcp --dport 22 -j ACCEPT
firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -s 10.0.0/8 -p tcp --dport 22 -j ACCEPT
firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -s 172.0.0/8 -p tcp --dport 22 -j ACCEPT
# Remove SSH service from public zone
firewall-cmd --zone=public --remove-service ssh
# Allow HTTP,HTTPS, and ICMP from everywhere
firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -p tcp --dport 80 -j ACCEPT
firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -p tcp --dport 443 -j ACCEPT
firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -p icmp  -j ACCEPT
# Drop all other traffic
firewall-cmd --set-default-zone=drop
# Reload all rules
firewall-cmd --complete-reload
echo "$(tput setaf 2)Deployment Complete!$(tput setaf 7)"
