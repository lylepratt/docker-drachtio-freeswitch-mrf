#!/bin/bash -xe

USER=admin
HOME=/home/admin
URLPortal=$1
NEW_DB_PASSWD=$(< /dev/urandom tr -dc A-Z | head -c1; < /dev/urandom tr -dc a-z | head -c1; < /dev/urandom tr -dc 0-9 | head -c1; < /dev/urandom tr -dc _ | head -c1; < /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c8; echo;)
uuid==${2:-$(uuidgen)}

sudo systemctl stop jaeger-query
sudo systemctl stop jaeger-collector
sudo systemctl stop telegraf


echo "Restarting rtpengine service."
sudo systemctl restart rtpengine

# get instance metadata
PRIVATE_IPV4="$(curl -s https://api.ipify.org/)" 
PUBLIC_IPV4="$(curl -s https://api.ipify.org/)" 
INSTANCE_ID="$(< /dev/urandom tr -dc A-Z | head -c1; < /dev/urandom tr -dc a-z | head -c1; < /dev/urandom tr -dc 0-9 | head -c6)"
echo $INSTANCE_ID > /home/admin/instanceid

# change the database password to a random id
NEW_DB_PASSWD=$(< /dev/urandom tr -dc A-Z | head -c1; < /dev/urandom tr -dc a-z | head -c1; < /dev/urandom tr -dc 0-9 | head -c1; < /dev/urandom tr -dc _ | head -c1; < /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c8; echo;)
echo "reset database password for admin user to $NEW_DB_PASSWD"
echo "alter user 'admin'@'%' identified by '$NEW_DB_PASSWD'" | mysql -h 127.0.0.1 -u admin -D jambones -pJambonzR0ck$ 
echo "db password reset"
sudo sed -i -e "s/\(.*\)JAMBONES_MYSQL_PASSWORD.*/\1JAMBONES_MYSQL_PASSWORD: '$NEW_DB_PASSWD',/g" $HOME/apps/ecosystem.config.js 

# replace ip addresses in the ecosystem.config.js file
sudo sed -i -e "s/\(.*\)PRIVATE_IP\(.*\)/\1$PRIVATE_IPV4\2/g" $HOME/apps/ecosystem.config.js 
#sudo sed -i -e "s/\(.*\)AWS_REGION_NAME\(.*\)/\1$AWS_REGION_NAME\2/g" $HOME/apps/ecosystem.config.js 
sudo sed -i -e "s/\(.*\)--JAMBONES_API_BASE_URL--\(.*\)/\1http:\/\/$PUBLIC_IPV4\/v1\2/g" $HOME/apps/ecosystem.config.js 

# replace JWT_SECRET
sudo sed -i -e "s/\(.*\)JWT-SECRET-GOES_HERE\(.*\)/\1$uuid\2/g" $HOME/apps/ecosystem.config.js 

# reset the database
echo "reset database schema and web login password to $INSTANCE_ID"
JAMBONES_ADMIN_INITIAL_PASSWORD=$INSTANCE_ID JAMBONES_MYSQL_USER=admin JAMBONES_MYSQL_PASSWORD=$NEW_DB_PASSWD JAMBONES_MYSQL_DATABASE=jambones JAMBONES_MYSQL_HOST=127.0.0.1 $HOME/apps/jambonz-api-server/db/reset_admin_password.js

# replace ip addresses in the ecosystem.config.js file
sudo sed -i -e "s/\(.*\)PRIVATE_IP\(.*\)/\1$PRIVATE_IPV4\2/g" /home/admin/apps/ecosystem.config.js 
sudo sed -i -e "s/\(.*\)--JAMBONES_API_BASE_URL--\(.*\)/\1http:\/\/$PUBLIC_IPV4\/v1\2/g" /home/admin/apps/ecosystem.config.js 

# replace JWT_SECRET
sudo sed -i -e "s/\(.*\)JWT-SECRET-GOES_HERE\(.*\)/\1$uuid\2/g" /home/admin/apps/ecosystem.config.js 

# configure webapp
if [[ -z "$URLPortal" ]]; then
  # portals will be accessed by IP address of server
  echo "VITE_API_BASE_URL=http://$PUBLIC_IPV4/api/v1" > /home/admin/apps/jambonz-webapp/.env 
  API_BASE_URL=http://$PUBLIC_IPV4/api/v1 TAG="<script>window.JAMBONZ = { API_BASE_URL: '$API_BASE_URL'};</script>"
  sed -i -e "\@</head>@i\ $TAG" /home/admin/apps/jambonz-webapp/dist/index.html
else
  # portals will be accessed by DNS name
  echo "VITE_API_BASE_URL=http://$URLPortal/api/v1" > /home/admin/apps/jambonz-webapp/.env 
  API_BASE_URL=http://$URLPortal/api/v1 TAG="<script>window.JAMBONZ = { API_BASE_URL: '$API_BASE_URL'};</script>"
  sed -i -e "\@</head>@i\ $TAG" /home/admin/apps/jambonz-webapp/dist/index.html

  # add row to system information table 
  mysql -h 127.0.0.1 -u admin -D jambones -p$NEW_DB_PASSWD -e $'insert into system_information (domain_name, sip_domain_name, monitoring_domain_name) values ('\'''"$URLPortal"''\'', '\''sip.'"$URLPortal"''\'', '\''grafana.'"$URLPortal"''\'')'

  sudo cat << EOF > /etc/nginx/sites-available/default 
  server {
      listen 80;
      server_name $URLPortal;
      location /api/ {
          rewrite ^/api/(.*)$ /\$1 break;
          proxy_pass http://localhost:3002;
          proxy_set_header Host \$host;
      }
      location / {
          proxy_pass http://localhost:3001;
          proxy_set_header Host \$host;
      }
  }
  server {
    listen 80;
    server_name api.$URLPortal; 
    location / {
      proxy_pass http://localhost:3002; 
      proxy_set_header Host \$host;
    }
  }
  server {
    listen 80;
    server_name grafana.$URLPortal; 
    location / {
      proxy_pass http://localhost:3010; 
      proxy_http_version 1.1;
      proxy_set_header Upgrade \$http_upgrade;
      proxy_set_header Connection 'upgrade';
      proxy_set_header Host \$host;
      proxy_cache_bypass \$http_upgrade;
    }
  }
  server {
    listen 80;
    server_name homer.$URLPortal; 
    location / {
      proxy_pass http://localhost:9080; 
      proxy_http_version 1.1;
      proxy_set_header Upgrade \$http_upgrade;
      proxy_set_header Connection 'upgrade';
      proxy_set_header Host \$host;
      proxy_cache_bypass \$http_upgrade;
    }
  }
EOF
  sudo systemctl restart nginx
fi

# restart heplify-server
sudo systemctl restart heplify-server

sudo systemctl restart cassandra.service        
echo "waiting 60 secs for cassandra to start.."
sleep 60
echo "now start jaeger"

# restart jaeger 
sudo systemctl restart jaeger-collector.service
sudo systemctl restart jaeger-query.service

# configure telegraf to send to local influxdb
sudo sed -i -e "s/influxdb:8086/127.0.0.1:8086/g"  /etc/telegraf/telegraf.conf
sudo systemctl restart telegraf

sudo -u $USER bash -c "pm2 restart $HOME/apps/ecosystem.config.js" 
sudo -u $USER bash -c "pm2 save"
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u $USER --hp $HOME

# get an apiban key and install it
APIBANKEY=$(curl -X POST -u jambonz:1a074994242182a9e0b67eae93978826 -d "{\"client\": \"$INSTANCE_ID\"}" -s https://apiban.org/sponsor/newkey | jq -r '.ApiKey')
sudo sed -i -e "s/API-KEY-HERE/$APIBANKEY/g" /usr/local/bin/apiban/config.json
sudo /usr/local/bin/apiban/apiban-iptables-client FULL

# configure upload_recordings service
sudo sed -i -e "s/MYSQL_HOST=/MYSQL_HOST=127.0.0.1/g" /etc/systemd/system/upload_recordings.service
sudo sed -i -e "s/MYSQL_USER=/MYSQL_USER=admin/g" /etc/systemd/system/upload_recordings.service
sudo sed -i -e "s/MYSQL_PASSWORD=/MYSQL_PASSWORD=$NEW_DB_PASSWD/g" /etc/systemd/system/upload_recordings.service
sudo sed -i -e "s/MYSQL_DATABASE=/MYSQL_DATABASE=jambones/g" /etc/systemd/system/upload_recordings.service
sudo sed -i -e "s/BASIC_AUTH_USERNAME=/BASIC_AUTH_USERNAME=jambonz/g" /etc/systemd/system/upload_recordings.service
sudo sed -i -e "s/BASIC_AUTH_PASSWORD=/BASIC_AUTH_PASSWORD=$uuid/g" /etc/systemd/system/upload_recordings.service
sudo sed -i -e "s/ENCRYPTION_SECRET=/ENCRYPTION_SECRET=$uuid/g" /etc/systemd/system/upload_recordings.service

sudo systemctl daemon-reload
sudo systemctl enable upload_recordings
sudo systemctl start upload_recordings