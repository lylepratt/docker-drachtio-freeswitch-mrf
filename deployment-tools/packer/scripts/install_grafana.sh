#!/bin/bash
VARIANT=$1
DISTRO=$2

case "$VARIANT" in
  monitoring|web-monitoring|mini)
    ;;
  *)
    echo "skipping grafana installation"
    exit 0
    ;;
esac


if [[ "$DISTRO" == rhel* ]] ; then
  echo "installing grafana on rhel"
  sudo tee /etc/yum.repos.d/grafana.repo <<EOF
[grafana]
name=grafana
baseurl=https://packages.grafana.com/oss/rpm
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packages.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF
  sudo dnf install -y grafana
else
  echo "installing grafana on debian"
  cd /tmp
  sudo apt-get install -y adduser libfontconfig1 musl
  wget https://dl.grafana.com/oss/release/grafana_10.4.1_amd64.deb
  sudo dpkg -i grafana_10.4.1_amd64.deb
fi

sudo mkdir /var/lib/grafana/dashboards
sudo mv /tmp/grafana-dashboard-default.yaml /etc/grafana/provisioning/dashboards/default.yaml
sudo mv /tmp/grafana-datasource.yml /etc/grafana/provisioning/datasources/datasource.yml

sudo mv /tmp/grafana-dashboard-heplify.json /var/lib/grafana/dashboards
sudo mv /tmp/grafana-dashboard-servers.json /var/lib/grafana/dashboards

sudo chown -R grafana:grafana /var/lib/grafana/dashboards
sudo chown -R grafana:grafana /etc/grafana/provisioning/dashboards

sudo sed -i -e "s/;http_port = 3000/http_port = 3010/g" /etc/grafana/grafana.ini

if [ "$VARIANT" = "mini" ]; then
  echo "installing jambonz mini dashboard"
  sudo mv /tmp/grafana-dashboard-jambonz-mini.json /var/lib/grafana/dashboards
elif [ "$VARIANT" = "web+monitoring" ]; then
  echo "installing jambonz medium dashboard"
  sudo mv /tmp/grafana-dashboard-jambonz-medium.json /var/lib/grafana/dashboards
else
  echo "installing jambonz cluster dashboard"
  sudo mv /tmp/grafana-dashboard-jambonz-cluster.json /var/lib/grafana/dashboards
fi

sudo chown -R grafana:grafana /etc/grafana/provisioning/datasources

sudo systemctl enable grafana-server
sudo systemctl start grafana-server
