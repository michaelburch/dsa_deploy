# Get WebPI from MS
$webpi_url = "http://download.microsoft.com/download/C/F/F/CFF3A0B8-99D4-41A2-AE1A-496C08BEB904/WebPlatformInstaller_amd64_en-US.msi"
$webpi_msi = "C:\users\Administrator\Documents\webpi.msi"
$wc = New-Object System.Net.WebClient
$wc.DownloadFile($webpi_url, $webpi_msi)

# Install WebPI and wait for it to finish
msiexec /i $webpi_msi /quiet | out-null
$env:path += ";C:\Program Files\Microsoft\Web Platform Installer"

# Use WebPI to install python, pip,git and wfcgi
WebpiCmd-x64.exe /install /products:"PythonPip27,msysgitVS,PythonVirtualEnv27,WFastCGI_21_279" /AcceptEULA

# set environment variables
$env:Path += ";C:\python27;C:\python27\scripts;C:\Program Files (x86)\Git\bin"
$env:WORKON_HOME="C:\python27\virtualenvs"
[Environment]::SetEnvironmentVariable("Path", $env:Path, "machine")
[Environment]::SetEnvironmentVariable("WORKON_HOME", $env:WORKON_HOME, "machine")

# Use pip to add virtualenv and the powershell extensions
pip install virtualenvwrapper
pip install virtualenvwrapper-powershell
# create virtualenv
mkdir c:\python27\virtualenvs
mkvirtualenv dsa

# Get project files
mkdir c:\projects
cd \projects
git clone https://github.com/kirpit/django-sample-app.git
cd django-sample-app
mv projectname django_sample
copy c:\python27\scripts\wfastcgi.py c:\projects\django-sample-app\django_sample

# install requirements
# after commenting out line 6 to skip the postgres packages
# since this will use sqlite
sed -i '6 s:^:#:' requirements.txt
pip install -r requirements.txt

# Customize the sample app
sed -i s/'{{ project_name }}'/django_sample/g c:\projects\django-sample-app\django_sample\wsgi.py
sed -i s/'{{ project_name }}'/django_sample/g c:\projects\django-sample-app\django_sample\settings\default.py

sed -i '61,65 s:^:#:' c:\projects\django-sample-app\django_sample\settings\default.py
sed -i s/'django.db.backends.postgresql_psycopg2'/django.db.backends.sqlite3/g c:\projects\django-sample-app\django_sample\settings\default.py
sed -i s/'{{ db_name }}'/sample_db.sqlite3/g c:\projects\django-sample-app\django_sample\settings\default.py


sed -i s/'localhost'/''/g c:\projects\django-sample-app\django_sample\settings\default.py
sed -i s/'projectname.home'/django_sample.home/g c:\projects\django-sample-app\django_sample\urls.py
$secret_key="nwz=djtu3@zhdlkin6ib=l#tu)gtu10%1y2#qmb@cyhkat8mez"
sed -i s/'$secret_key'/$secret_key/g c:\projects\django-sample-app\django_sample\settings\default.py
sed -i s/'ALLOWED_HOSTS = ('/'ALLOWED_HOSTS = ( ""*""'/g c:\projects\django-sample-app\django_sample\settings\default.py
sed -i '22 a\import django' c:\projects\django-sample-app\django_sample\wfastcgi.py
sed -i '373 a\    django.setup()' c:\projects\django-sample-app\django_sample\wfastcgi.py

# Init the database
python c:\projects\django-sample-app\django_sample\manage.py migrate
python c:\projects\django-sample-app\django_sample\manage.py collectstatic --noinput

# Add Windows features for IIS
Add-WindowsFeature Web-Server
Add-WindowsFeature Web-Static-Content
Add-WindowsFeature Web-CGI
Add-WindowsFeature Web-Mgmt-Console
Add-WindowsFeature Web-Scripting-Tools

# Setup the IIS website
C:\windows\system32\inetsrv\appcmd delete site "Default Web Site"
C:\windows\system32\inetsrv\appcmd set config -section:system.webServer/fastCgi /+"[fullPath='c:\python27\virtualenvs\dsa\scripts\python.exe',arguments='c:\projects\django-sample-app\django_sample\wfastcgi.py',maxInstances='4',idleTimeout='1800',activityTimeout='30',requestTimeout='90',instanceMaxRequests='100000',protocol='NamedPipe',flushNamedPipe='False',monitorChangesTo='c:\projects\django-sample-app\django_sample\settings\default.py']" /commit:apphost
C:\windows\system32\inetsrv\appcmd.exe set config -section:system.webServer/fastCgi /+"[fullPath='c:\python27\virtualenvs\dsa\scripts\python.exe'].environmentVariables.[name='DJANGO_SETTINGS_MODULE',value='django_sample.settings']" /commit:apphost
C:\windows\system32\inetsrv\appcmd.exe set config -section:system.webServer/fastCgi /+"[fullPath='c:\python27\virtualenvs\dsa\scripts\python.exe'].environmentVariables.[name='PYTHONPATH',value='c:\projects\django-sample-app\django_sample']" /commit:apphost
C:\windows\system32\inetsrv\appcmd.exe set config -section:system.webServer/fastCgi /+"[fullPath='c:\python27\virtualenvs\dsa\scripts\python.exe'].environmentVariables.[name='WSGI_HANDLER',value='django.core.handlers.wsgi.WSGIHandler()']" /commit:apphost
C:\windows\system32\inetsrv\appcmd add apppool /name:dsa
C:\windows\system32\inetsrv\appcmd add site /name:dsa /bindings:http://*:80 /physicalPath:c:\projects\django-sample-app\
C:\windows\system32\inetsrv\appcmd set app "dsa/" /applicationPool:dsa
C:\windows\system32\inetsrv\appcmd.exe set config -section:system.webServer/handlers /+"[name='django_fcgi',path='*',verb='*',modules='FastCgiModule',scriptProcessor='C:\python27\virtualenvs\dsa\scripts\python.exe|C:\projects\django-sample-app\django_sample\wfastcgi.py',resourceType='Either']" /commit:apphost
curl http://localhost | out-null

# Remove the fastcgi handler from the static and media folders
C:\windows\system32\inetsrv\appcmd.exe set config "dsa/static" -section:handlers /-"[name='django_fcgi',path='*',verb='*',modules='FastCgiModule',scriptProcessor='C:\python27\virtualenvs\dsa\scripts\python.exe|C:\projects\django-sample-app\django_sample\wfastcgi.py',resourceType='Either']" /commit:apphost
C:\windows\system32\inetsrv\appcmd.exe set config "dsa/media" -section:handlers /-"[name='django_fcgi',path='*',verb='*',modules='FastCgiModule',scriptProcessor='C:\python27\virtualenvs\dsa\scripts\python.exe|C:\projects\django-sample-app\django_sample\wfastcgi.py',resourceType='Either']" /commit:apphost


# Allow ping, HTTP and HTTPS from everywhere
New-NetFirewallRule -Name Allow_Ping -DisplayName "Allow Ping" -Protocol ICMPv4 -IcmpType 8 -Enabled True -Profile Any -Action Allow 
New-NetFirewallRule -DisplayName Allow_HTTP_In -Direction Inbound -LocalPort 80 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName Allow_HTTPS_In -Direction Inbound -LocalPort 443 -Protocol TCP -Action Allow

# Allow RDP from local subnets
New-NetFirewallRule -DisplayName Allow_RDP_In_192 -Direction Inbound -LocalPort 3389 -Protocol TCP -RemoteAddress 192.168.0.0/16 -Action Allow
New-NetFirewallRule -DisplayName Allow_RDP_In_172 -Direction Inbound -LocalPort 3389 -Protocol TCP -RemoteAddress 172.0.0.0/8 -Action Allow
New-NetFirewallRule -DisplayName Allow_RDP_In_010 -Direction Inbound -LocalPort 3389 -Protocol TCP -RemoteAddress 10.0.0.0/8 -Action Allow

# Set Default action to block and disable all preconfigured rule groups
Set-NetFirewallProfile -name * -DefaultInboundAction Block 
Set-NetFirewallRule -DisplayGroup * -Enabled False



