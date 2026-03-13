#!/bin/bash
VARIANT=$1
DISTRO=$2
DB_USER=$3
DB_PASS=$4

case "$VARIANT" in
  monitoring|web-monitoring|mini)
    ;;
  *)
    echo "skipping postgresql installation"
    exit 0
    ;;
esac


if [[ "$DISTRO" == rhel* ]]; then
  if [ "$EUID" -ne 0 ]; then
    echo "Switching to root user..."
     sudo -E bash "$0" "$@"
    exit
  fi  
fi

if [[ "$DISTRO" == rhel* ]] ; then
  RHEL_RELEASE="${DISTRO:5}"

  sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-${RHEL_RELEASE}-x86_64/pgdg-redhat-repo-latest.noarch.rpm
  dnf -qy module disable postgresql
  sudo dnf install -y postgresql14 postgresql14-server

  sudo /usr/pgsql-14/bin/postgresql-14-setup initdb
  sudo systemctl enable postgresql-14
  sudo systemctl start postgresql-14
else
  wget -q https://www.postgresql.org/media/keys/ACCC4CF8.asc -O- | sudo apt-key add -
  sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/postgresql.list'
  sudo apt-get update
  sudo apt-get install -y postgresql-12
  sudo systemctl daemon-reload
  sudo systemctl enable postgresql
  sudo systemctl restart postgresql
fi

echo "creating database homer_config and homer_data with user ${DB_USER} and password ${DB_PASS}"
cd /tmp
sudo -u postgres psql -c "CREATE DATABASE homer_config;"
sudo -u postgres psql -c "CREATE DATABASE homer_data;"
sudo -u postgres psql -c "CREATE ROLE ${DB_USER} WITH SUPERUSER LOGIN PASSWORD '$DB_PASS';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE homer_config to ${DB_USER};"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE homer_data to ${DB_USER};"


if [[ "$DISTRO" == rhel* ]] ; then
  # change authentication to md5
  sudo sed -i -e 's/^local   all             all                                     peer/local   all             all                                     md5/' -e 's/^host    all             all             127.0.0.1\/32            ident/host    all             all             127.0.0.1\/32            md5/' -e 's/^host    all             all             ::1\/128                 ident/host    all             all             ::1\/128                 md5/' /var/lib/pgsql/14/data/pg_hba.conf
fi
