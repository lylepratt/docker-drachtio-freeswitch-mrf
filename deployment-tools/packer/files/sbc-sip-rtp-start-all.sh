#!/bin/bash
echo starting drachtio
sudo systemctl restart drachtio
sudo systemctl status drachtio --no-pager
echo starting rtpengine
sudo systemctl restart rtpengine
sudo systemctl status rtpengine --no-pager
echo starting apps
pm2 restart ~/apps/ecosystem.config.js
echo done