#!/bin/bash
set -e

#run pres3fs monitor
#/usr/local/bin/monitorPres3fs.sh 2>&1 | tee -a /var/log/monitorPres3fs.log &
/usr/local/bin/monitorPres3fs.sh &

#run rsyslog
if command -v rsyslogd >/dev/null; then
  rsyslogd -n &
fi

CONF_DIR=/usr/local/freeswitch/conf
ACL_FILE="$CONF_DIR/autoload_configs/acl.conf.xml"
EVENT_SOCKET_FILE="$CONF_DIR/autoload_configs/event_socket.conf.xml"
MRF_PROFILE_FILE="$CONF_DIR/sip_profiles/mrf.xml"
SWITCH_CONF_FILE="$CONF_DIR/autoload_configs/switch.conf.xml"
VARS_DIFF_FILE="$CONF_DIR/vars_diff.xml"

# listen on all interfaces, allow connections from anywhere
sed -i -e "s/name=\"listen-ip\" value=\".*\"/name=\"listen-ip\" value=\"0.0.0.0\"/g" "$EVENT_SOCKET_FILE"
sed -i -e "s/<\!--<param name=\"apply-inbound-acl\" value=\"loopback.auto\"\/>-->/<param name=\"apply-inbound-acl\" value=\"socket_acl\"\/>/g" "$EVENT_SOCKET_FILE"
sed -i -e "s/cidr=\"127.0.0.1\/32\"/cidr=\"0.0.0.0\/0\"/g" "$ACL_FILE"

if [ "$1" = 'freeswitch' ]; then
  shift

while :; do
  case $1 in 
  -g|--g711-only)
      sed -i -e "s/global_codec_prefs=.*\"/global_codec_prefs=PCMU,PCMA\"/g" "$VARS_DIFF_FILE"
      sed -i -e "s/outbound_codec_prefs=.*\"/outbound_codec_prefs=PCMU,PCMA\"/g" "$VARS_DIFF_FILE"
    shift
    ;;

  --g711-only-alaw-preferred)
      sed -i -e "s/global_codec_prefs=.*\"/global_codec_prefs=PCMA,PCMU\"/g" "$VARS_DIFF_FILE"
      sed -i -e "s/outbound_codec_prefs=.*\"/outbound_codec_prefs=PCMA,PCMU\"/g" "$VARS_DIFF_FILE"
    shift
    ;;

  -s|--sip-port)
    if [ -n "$2" ]; then
      sed -i -e "s/sip_port=[[:digit:]]\+/sip_port=$2/g" "$VARS_DIFF_FILE"
    fi
    shift
    shift
    ;;

  -t|--tls-port)
    if [ -n "$2" ]; then
      sed -i -e "s/tls_port=[[:digit:]]\+/tls_port=$2/g" "$VARS_DIFF_FILE"
    fi
    shift
    shift
    ;;

  -e|--event-socket-port)
    if [ -n "$2" ]; then
      sed -i -e "s/name=\"listen-port\" value=\"8021\"/name=\"listen-port\" value=\"$2\"/g" "$EVENT_SOCKET_FILE"
    fi
    shift
    shift
    ;;

  -a|--rtp-range-start)
    if [ -n "$2" ]; then
      sed -i -e "s/name=\"rtp-start-port\" value=\".*\"/name=\"rtp-start-port\" value=\"$2\"/g" "$SWITCH_CONF_FILE"
    fi
    shift
    shift
    ;;

  -z|--rtp-range-end)
    if [ -n "$2" ]; then
      sed -i -e "s/name=\"rtp-end-port\" value=\".*\"/name=\"rtp-end-port\" value=\"$2\"/g" "$SWITCH_CONF_FILE"
    fi
    shift
    shift
    ;;

  --ext-rtp-ip)
    if [ -n "$2" ]; then
      sed -i -e "s/ext_rtp_ip=.*\"/ext_rtp_ip=$2\"/g" "$VARS_DIFF_FILE"
    fi
    shift
    shift
    ;;

  --ext-sip-ip)
    if [ -n "$2" ]; then
      sed -i -e "s/ext_sip_ip=.*\"/ext_sip_ip=$2\"/g" "$VARS_DIFF_FILE"
    fi
    shift
    shift
    ;;

  -p|--password)
    if [ -n "$2" ]; then
      sed -i -e "s/name=\"password\" value=\"JambonzR0ck$\"/name=\"password\" value=\"$2\"/g" "$EVENT_SOCKET_FILE"
    fi
    shift
    shift
    ;;

  --codec-answer-generous)
    sed -i -E 's/(name="inbound-codec-negotiation" value=")[^"]*(")/\1generous\2/g' "$MRF_PROFILE_FILE"
    shift
    ;;
  
  --codec-list)
    if [ -n "$2" ]; then
      sed -i -e "s/global_codec_prefs=.*\"/global_codec_prefs=$2\"/g" "$VARS_DIFF_FILE"
      sed -i -e "s/outbound_codec_prefs=.*\"/outbound_codec_prefs=$2\"/g" "$VARS_DIFF_FILE"
    fi
    shift
    shift
    ;;

  --username)
    if [ -n "$2" ]; then
      sed -i -e 's/value="Jambonz-Mediaserver"/value="'$2'-Mediaserver"/g' "$MRF_PROFILE_FILE"
    fi
    shift
    shift
    ;;

  --advertise-external-ip)
    sed -i -e "s/ext-sip-ip\" value=\".*\"/ext-sip-ip\" value=\"\$\${ext_sip_ip}\""/g "$MRF_PROFILE_FILE"
    sed -i -e "s/ext-rtp-ip\" value=\".*\"/ext-rtp-ip\" value=\"\$\${ext_rtp_ip}\""/g "$MRF_PROFILE_FILE"
    shift
    ;;

  -l|--log-level)
    if [ -n "$2" ]; then
      sed -i -e "s/name=\"loglevel\" value=\".*\"/name=\"loglevel\" value=\"$2\"/g" "$SWITCH_CONF_FILE"
    fi
    shift
    shift
    ;;

  --)
    shift
    break
    ;;

  *)
    break
  esac

done
    exec freeswitch "$@"
fi

exec "$@"
