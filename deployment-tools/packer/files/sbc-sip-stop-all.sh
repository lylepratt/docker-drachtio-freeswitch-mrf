#!/bin/bash
echo stopping apps
pm2 delete ~/apps/ecosystem.config.js
echo stopping drachtio
sudo systemctl stop drachtio
echo all done

