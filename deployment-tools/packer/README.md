# packer scripts

Here you will find [packer](https://www.packer.io/) templates to build the various AMIs required for a jambonz system.

Given the variety of deployment scenarios (e.g. a single "all-in-one" jambonz server, versus a cluster) it is possible to build different AMIs, based on the user variable named `variant`:

- 'mini': builds an AMI with the entire jambonz stack to run as a single server (note: this is recommended only for dev/test and small production loads of less than 50 concurrent calls),
- 'fs': builds a feature server AMI
- 'sip-rtp': builds an SBC AMI with both sip and rtp processing
- 'sip': builds an SBC AMI with both sip only
- 'rtp': builds an SBC AMI with both rtp only
- 'web': builds a jambonz webserver AMI
- 'monitoring': builds a jambonz monitoring server AMI
- 'web-monitoring': builds an AMI with both web server and monitoring server

## User variables
There are a number of user variables that can be set.  Please review the packer templates themselves for the full list; here are the most important ones that you are likely to want to tweak; in most cases you may need only to set the `variant` user variable and leave the rest at their default settings.

- variant: Described above.  Defaults to 'mini'.
- distro: `debian-11` or `debian-12` (default) when using [aws-debian-template.json](./aws-debian-template.json); `rhel-8` when using [aws-rhel8-template.json)](./aws-rhel8-template.json).
- jambonz_version: tag for the jambonz version to check out and build.
- drachtio_version: tag for the drachtio version to check out and build.
- rtp_engine_version: tag for the rtpengine to check out and build.
- region: aws region to build the AMI in.
- instance_type: aws instance type to use as the build server.

## Building an AMI
First install packer on your laptop along with the AWS cli.  Then from this folder on your laptop run any of the following exxamples:

To build a jambonz mini on debian-12:
```bash
packer build -color=false aws-debian-template.json
```

To build a jambonz mini on debian-11:
```bash
packer build -color=false -var="distro=debian-11" aws-debian-template.json
```

To build a jambonz mini on RHEL 8
```bash
packer build -color=false aws-rhel8-template.json
```

To build the 3 AMIs needed to deploy a jambonz medium cluster on debian-12
```bash
packer build -color=false -var="variant=sip-rtp" aws-debian-template.json

packer build -color=false -var="variant=fs" aws-debian-template.json

packer build -color=false -var="variant=web-monitoring" aws-debian-template.json

```

To build the 5 AMIs needed to deploy a jambonz large cluster on debian-12
```bash
packer build -color=false -var="variant=sip" aws-debian-template.json

packer build -color=false -var="variant=rtp" aws-debian-template.json

packer build -color=false -var="variant=fs" aws-debian-template.json

packer build -color=false -var="variant=web" aws-debian-template.json

packer build -color=false -var="variant=monitoring" aws-debian-template.json

```
