#!/bin/bash
echo starting freeswitch
sudo systemctl restart freeswitch
sudo systemctl status freeswitch --no-pager
echo starting drachtio
sudo systemctl restart drachtio
sudo systemctl status drachtio --no-pager
echo starting apps
pm2 restart ~/apps/ecosystem.config.js
echo done