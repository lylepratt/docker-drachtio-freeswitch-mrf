`pm2 status`   
Check for running processes:

- jambonz-api-server  
- jambonz-feature-server   
- jambonz-smpp-esme  
- jambonz-webapp   
- sbc-call-router  
- sbc-inbound  
- sbc-rtpengine-sidecar  
- sbc-sip-sidecar	

All should be running with decent uptime 

`pm2 logs`  
Look for errors

`systemctl status freeswitch.service`  
Running, no errors  
`sudo cat /usr/local/freeswitch/log/freeswitch.log`  
Check for errors

`systemctl status drachtio.service`  
Running, no errors  
`sudo journalctl -f -u drachtio.service`  
no errors

`systemctl status drachtio-5070.service`  
Running, no errors  
`sudo journalctl -f -u drachtio-5070.service`  
no errors

`systemctl status rtpengine.service`  
Running, no errors  
`sudo journalctl -f -u rtpengine.service`  
no errors

`systemctl status rtpengine-recording.service`  
Running, no errors  
`sudo journalctl -f -u rtpengine-recording.service`  
no errors


`systemctl status heplify-server.service`  
Running, no errors  
`sudo journalctl -f -u heplify-server.service`  
no errors

 
`systemctl status telegraf.service`  
Running, no errors  
`sudo journalctl -f -u telegraf.service`  
no errors

  
`systemctl status postgresql.service`  
Running, no errors  
`sudo journalctl -f -u postgresql.service`  
no errors

`systemctl status grafana-server.service`  
Running, no errors  
`sudo journalctl -f -u grafana-server.service`  
no errors

  
`systemctl status cassandra.service`  
Running, no errors  
`sudo journalctl -f -u cassandra.service`  
no errors

  
`systemctl status jaeger-query.service`  
Running, no errors  
`sudo journalctl -f -u jaeger-query.service`  
no errors

`systemctl status jaeger-collector.service`  
Running, no errors  
`sudo journalctl -f -u jaeger-collector.service`  
no errors

`systemctl status homer-app.service`  
Running, no errors  
`sudo journalctl -f -u homer-app.service`  
no errors

Check iptables rules  
`iptables -S`
Should show a list of IPs being blocked by API Ban

Check crontab  
`cat /etc/crontab`
Should show
```
0 * * * * root fsw-clear-old-calls --password JambonzR0ck$ >> /var/log/fsw-clear-old-calls.log 2>&1
0 1 * * * root find /tmp -name "*.mp3" -mtime +2 -exec rm {} \; > /dev/null 2>&1
0 */12 * * * root find /usr/local/freeswitch/storage/http_file_cache -mmin +720 -exec rm {} \; > /dev/null 2>&1
0 2 * * * root find /tmp/tts-cache-files -mtime +3 -exec rm {} \; > /dev/null 2>&1
0 3 * * * root /usr/local/freeswitch/bin/fs_cli -p JambonzR0ck$ -x fsctl send_sighup > /dev/null 2>&1
5 3 * * * root /usr/bin/find /usr/local/freeswitch/log -name "freeswitch.log.*" -mtime +1 -delete > /dev/null 2>&1
*/4 * * * * root cd /usr/local/bin/apiban && ./apiban-iptables-client >/dev/null 2>&1
```