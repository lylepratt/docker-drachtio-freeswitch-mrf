# SSH Install

These are the notes for using the "ssh" target packer scripts.
These scripts are designed to install jambonz directly to a Generic server via an SSH connection, This could be "Bare metal" or a  Virtual Machine but the key feature is that they are independent of any cloud providers custom management and have their public IP address directly configured on the host itself (no NAT). You can install standard Debain 12 base system on the machine, and have full root access.

## Prerequisites

### DNS

You will require a hostname for the server eg `jambonz.example.com` with an A record pointing to your servers IP address
You will also need a CNAME record for `*.jambonz.example.com` pointing to the A record for subdomain hosts (eg grafana.jambonz.example.com)

### Jambonz Mini
A server with at least 4GB Ram (8GB reccomended) and 40GB of Disk Space (80GB reccomended), 2 CPU cores are a minimum but more are reccomended, 
(Note: On low spec systems the build may take several hours.)

- Install the new system with Debian 12
- login as root
- Create an admin user `adduser admin`
- Add the admin user to the sudo group `usermod -aG sudo admin`
- Edit the `/etc/sudoers` file to allow sudo without a password
    Change the line:
    `%sudo	ALL=(ALL:ALL) ALL`
    to
    `%sudo  ALL=(ALL:ALL) NOPASSWD:ALL`
- Add SSH keys for your laptop to the admin users `~/.ssh/authorized_keys` file

### Firewall
The server as built does not use a built in firewall, (IPTABLES is used for APIBan)
If the hosting provider provides firewall facilities then all incomming connections should be blocked with only the following ports opened
TCP/22 - For SSH
TCP/443 - For Web interfaces
TCP/5060-5061 - For SIP
UDP/5060 - For SIP
TCP/8443 - For WebRTC Signalling
UDP/40000-60000 - For RTP Media

## Building
Once the prerequisites have been met.

- Clone this repositoy to your laptop
- Run the script with the appropriate value for ssh_host  and tee the output to a logfile
    `packer -var 'ssh_host=1.2.3.4' build ssh-debian-template.json | tee ~/packer_install.log`
- Watch the install for any errors, when complete review the logfile

## Post build
 - Run the setup script in `~/admin/setup.sh` as admin with the domain you have created `./setup.sh jambonz.example.com` (if this is an upgrade you can supply the previous JWT Secret as $2)
 - Use certbot to create SSL certs and configure them onto nginx for your domain, you will need to setup the following hostnames in the command
 `sudo certbot --nginx`
 - Edit the API url in the webapp to use the https url
    ```
    cd /home/admin/apps/jambonz-webapp/
    vi .env
    npm run build
    pm2 restart jambonz-webapp
    ```

Restart the server and ensure that everything comes up normally, run the post-install checks.

