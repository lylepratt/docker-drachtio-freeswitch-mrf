#!/bin/bash

# Options for $1 are:
# eipv4 for Public IP
# private-ipv4 for Private IP

curl -s  "http://100.100.100.200/latest/meta-data/$1"
