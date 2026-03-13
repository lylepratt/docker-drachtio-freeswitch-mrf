provider "google" {
  project = var.project
  region = var.region
}

resource "random_string" "uuid" {
  length = 6
  special = false
  upper = false
}

# Create a new VPC
resource "google_compute_network" "jambonz_vpc" {
  name                    = "jambonz-vpc-${random_string.uuid.result}"
  auto_create_subnetworks = false
  description             = "VPC network for Jambonz deployment"
}

# Create a subnet within the VPC
resource "google_compute_subnetwork" "jambonz_subnet" {
  name          = "jambonz-subnet-${random_string.uuid.result}"
  ip_cidr_range = "10.0.0.0/24"
  network       = google_compute_network.jambonz_vpc.id
  region        = var.region
}

# Cloud NAT configuration for instances without external IPs
resource "google_compute_router" "jambonz_router" {
  name    = "jambonz-router-${random_string.uuid.result}"
  region  = var.region
  network = google_compute_network.jambonz_vpc.id
}

resource "google_compute_router_nat" "jambonz_nat" {
  name                               = "jambonz-nat-${random_string.uuid.result}"
  router                             = google_compute_router.jambonz_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_address" "jambonz_static_ip" {
  name = "jambonz-static-ip-${random_string.uuid.result}"
  region = var.region
}

resource "google_compute_firewall" "jambonz_mini_firewall_rule" {
  name = "jambonz-firewall-rule-${random_string.uuid.result}"

  source_ranges = [
    "0.0.0.0/0"
  ]
  target_tags = [
    "jambonz-mini-${random_string.uuid.result}"
  ]
  network = google_compute_network.jambonz_vpc.id
  allow {
    protocol = "tcp"
    ports = ["22", "80", "443", "3020", "5060", "5061", "8443"]
  }
  allow {
    protocol = "udp"
    ports = ["5060", "40000-60000"]
  }
}

# Add internal firewall rule for VPC
resource "google_compute_firewall" "jambonz_internal_firewall_rule" {
  name = "jambonz-internal-rule-${random_string.uuid.result}"
  
  source_ranges = [
    "10.0.0.0/24"  # Allow traffic within the subnet
  ]
  network = google_compute_network.jambonz_vpc.id
  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }
}

resource "google_compute_instance" "jambonz_mini" {
  name = "jambonz-mini-${random_string.uuid.result}"
  zone = var.zone
  machine_type = var.instance_type
  tags = [
    "jambonz-mini-${random_string.uuid.result}"
  ]
  boot_disk {
    device_name = "boot"
    initialize_params {
      image = "https://www.googleapis.com/compute/v1/projects/${var.project}/global/images/${var.image}"
    }
  }
  network_interface {
    network = google_compute_network.jambonz_vpc.id
    subnetwork = google_compute_subnetwork.jambonz_subnet.id
    access_config {
      nat_ip = google_compute_address.jambonz_static_ip.address
    }
  }
  metadata = {
    startup-script = <<-EOT
#!/bin/bash -xe
FLAG_FILE="/var/lib/firstboot_completed"

if [ ! -f "$FLAG_FILE" ]; then
echo "Running first boot setup..."

USER=admin
HOME=/home/admin
URLPortal="${var.dns_name}"
NEW_DB_PASSWD=$(< /dev/urandom tr -dc A-Z | head -c1; < /dev/urandom tr -dc a-z | head -c1; < /dev/urandom tr -dc 0-9 | head -c1; < /dev/urandom tr -dc _ | head -c1; < /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c8; echo;)

systemctl stop jaeger-query
systemctl stop jaeger-collector
systemctl stop telegraf

echo install rtpengine kernel module and iptables rule
if lsmod | grep -q xt_RTPENGINE; then
  echo "xt_RTPENGINE module is already loaded."
else
  echo "loading xt_RTPENGINE module."
  modprobe xt_RTPENGINE
  echo 'add 42' > /proc/rtpengine/control
  iptables -I INPUT -p udp --dport 40000:60000 -j RTPENGINE --id 42
fi
echo "rtpengine module and iptables rule installed. Restarting rtpengine service."
systemctl restart rtpengine

# get instance metadata
PRIVATE_IPV4="$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)" 
PUBLIC_IPV4="$(curl -s -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)" 
INSTANCE_ID="$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/name)"

# change the database password to a random id
NEW_DB_PASSWD=$(< /dev/urandom tr -dc A-Z | head -c1; < /dev/urandom tr -dc a-z | head -c1; < /dev/urandom tr -dc 0-9 | head -c1; < /dev/urandom tr -dc _ | head -c1; < /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c8; echo;)
echo "reset database password for admin user to $NEW_DB_PASSWD"
echo "alter user 'admin'@'%' identified by '$NEW_DB_PASSWD'" | mysql -h 127.0.0.1 -u admin -D jambones -pJambonzR0ck$ 
echo "db password reset"
sudo sed -i -e "s/\(.*\)JAMBONES_MYSQL_PASSWORD.*/\1JAMBONES_MYSQL_PASSWORD: '$NEW_DB_PASSWD',/g" $HOME/apps/ecosystem.config.js 

# replace ip addresses in the ecosystem.config.js file
sudo sed -i -e "s/\(.*\)PRIVATE_IP\(.*\)/\1$PRIVATE_IPV4\2/g" $HOME/apps/ecosystem.config.js 
sudo sed -i -e "s/\(.*\)AWS_REGION_NAME\(.*\)/\1$AWS_REGION_NAME\2/g" $HOME/apps/ecosystem.config.js 
sudo sed -i -e "s/\(.*\)--JAMBONES_API_BASE_URL--\(.*\)/\1http:\/\/$PUBLIC_IPV4\/v1\2/g" $HOME/apps/ecosystem.config.js 

# replace JWT_SECRET
uuid=$(uuidgen)
sudo sed -i -e "s/\(.*\)JWT-SECRET-GOES_HERE\(.*\)/\1$uuid\2/g" $HOME/apps/ecosystem.config.js 

# reset the database
echo "reset database schema and web login password to $INSTANCE_ID"
JAMBONES_ADMIN_INITIAL_PASSWORD=$INSTANCE_ID JAMBONES_MYSQL_USER=admin JAMBONES_MYSQL_PASSWORD=$NEW_DB_PASSWD JAMBONES_MYSQL_DATABASE=jambones JAMBONES_MYSQL_HOST=127.0.0.1 $HOME/apps/jambonz-api-server/db/reset_admin_password.js

# replace ip addresses in the ecosystem.config.js file
sudo sed -i -e "s/\(.*\)PRIVATE_IP\(.*\)/\1$PRIVATE_IPV4\2/g" /home/admin/apps/ecosystem.config.js 
sudo sed -i -e "s/\(.*\)--JAMBONES_API_BASE_URL--\(.*\)/\1http:\/\/$PUBLIC_IPV4\/v1\2/g" /home/admin/apps/ecosystem.config.js 

# replace JWT_SECRET
uuid=$(uuidgen)
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

# get an apiban key and install it
APIBANKEY=$(curl -X POST -u jambonz:1a074994242182a9e0b67eae93978826 -d "{\"client\": \"$INSTANCE_ID\"}" -s https://apiban.org/sponsor/newkey | jq -r '.ApiKey')
sudo sed -i -e "s/API-KEY-HERE/$APIBANKEY/g" /usr/local/bin/apiban/config.json
sudo /usr/local/bin/apiban/apiban-iptables-client FULL

# Create the flag file to indicate first boot has completed
  touch "$FLAG_FILE"
  echo "First boot setup completed."
else
  echo "Not first boot. Skipping setup."
fi


EOT
  }

  depends_on = [
    google_compute_address.jambonz_static_ip,
    google_compute_subnetwork.jambonz_subnet
  ]
}

# Output the external IP address
output "jambonz_ip_address" {
  value = google_compute_address.jambonz_static_ip.address
  description = "The external IP address of the Jambonz instance"
}

# Output the VPC ID
output "jambonz_vpc_id" {
  value = google_compute_network.jambonz_vpc.id
  description = "The ID of the Jambonz VPC"
}

# Output the instance name
output "jambonz_instance_name" {
  value = google_compute_instance.jambonz_mini.name
  description = "The name of the Jambonz instance"
}