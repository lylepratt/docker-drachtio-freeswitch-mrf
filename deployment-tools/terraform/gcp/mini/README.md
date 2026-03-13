# Deploying a jambonz-mini on Google Cloud Platform (GCP)

## Prerequisites
In order to follow these instructions, you will need:
- a google cloud account, with necessary permissions
- a google machine image, which you can build using [this packer script](../../../packer/gcp-debian-template.json).
- terraform installed on your laptop

## Installation

### Create or identify the google cloud project to use
In order to run packer and terraform locally on your laptop and create resources on Google Cloud Platform you'll need to download some credentials to your laptop. So login into the [GCP console](https://console.cloud.google.com), create a project (or select an existing one) and then from the main menu select IAM & Admin / Service Accounts. Click "Create Service Account", fill in the details and click "Create and Continue".

Add the following roles to the service account that you created and then click "Continue":

- Compute Admin
- Compute Instance Admin (v1)
- Compute Network Admin
- Service Account Admin
- Service Account User

Now find the service account you just created in the list, select it and then click Add Key / Create Key and select JSON. Download the json key file to your laptop.

Finally, set the environment variable `GOOGLE_APPLICATION_CREDENTIALS` to point to the JSON service key file 

```bash
export GOOGLE_APPLICATION_CREDENTIALS=<path-to-json-key-file>
```

### Set terraform variables

Create a file named `deployment.tfvars` in this folder and copy in the following content, editing as needed for your selections.

```
image = "<your-packer-image-name>"
region = "us-central1"
zone = "us-central1-a"
project = "<your-project>"
dns_name = "yourdomain.com"
instance_type = "e2-medium"
```

Notes:
- `image` refers to the VM image that you built previously using google
- `region`, `zone` set according to your preference
- `dns_name` will be the domain name that the jambonz portal will be served from; this must be a domain that you control and are able to create DNS records for

### Run terraform

First, verify your settings and configuration:

```bash
terraform plan -var-file="deployment.tfvars"
```

If all goes, deploy your instance:

```bash
terraform apply -var-file="deployment.tfvars"
```

This should run successfully with output like the following:

```bash
random_string.uuid: Creating...
random_string.uuid: Creation complete after 0s [id=ntzsiu]
google_compute_address.jambonz_static_ip: Creating...
google_compute_firewall.jambonz_mini_firewall_rule: Creating...
google_compute_address.jambonz_static_ip: Still creating... [10s elapsed]
google_compute_firewall.jambonz_mini_firewall_rule: Still creating... [10s elapsed]
google_compute_address.jambonz_static_ip: Creation complete after 11s [id=projects/drachtio-cpaas/regions/us-central1/addresses/jambonz-static-ip-ntzsiu]
google_compute_instance.jambonz_mini: Creating...
google_compute_firewall.jambonz_mini_firewall_rule: Creation complete after 11s [id=projects/drachtio-cpaas/global/firewalls/jambonz-firewall-rule-ntzsiu]
google_compute_instance.jambonz_mini: Still creating... [10s elapsed]
google_compute_instance.jambonz_mini: Still creating... [20s elapsed]
google_compute_instance.jambonz_mini: Still creating... [30s elapsed]
google_compute_instance.jambonz_mini: Still creating... [40s elapsed]
google_compute_instance.jambonz_mini: Creation complete after 42s [id=projects/drachtio-cpaas/zones/us-central1-a/instances/jambonz-mini-ntzsiu]

Apply complete! Resources: 4 added, 0 changed, 0 destroyed.
```

### Create DNS records

Now you should be able to log into the GCP console and see the running instance. Make note of the external (static) IP because in the final step you will add DNS A records pointing to this IP.

Now create DNS A records for the following names that point to the external IP:
- yourdomain
- api.yourdomain
- grafana.yourdomain
- homer.yourdomain
- sip.yourdomain

### Log in and change portal password

Now you should be able to log in at http://yourdomain with user 'admin' and initial password equal to the instance name that was created.  You will be prompted to change the password.

### Secure the web portal

Optionally, you can secure the web portal so it is available using https.  To do so using letsencrypt as the cert provider is simple:

As root user, generate a TLS cert
```bash
certbot --nginx
```

Then, as admin user, edit ~/apps/jambonz-webapp/.env and change "http" to "https", then save the file.  Next, rebuild the webapp

```bash
cd /home/admin/apps/jambonz-webapp
npm run build
pm2 restart jambonz-webapp
```

The web portal should now be available at https://yourdomain