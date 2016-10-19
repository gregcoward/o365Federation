#!/bin/bash
export PATH="/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin/"

IP_REGEX='^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'

while getopts m:d:n:h:s:t:l:a:c:u:p: option
do	case "$option"  in
        i) ipAddress=$OPTARG;;
	    p) port=$OPTARG;;
        e) entityId=$OPTARG;;
        d) authFqdn=$OPTARG;;
        a) authIp=$OPTARG;;
        f) domainFqdn=$OPTARG;;
        c) sslCert=$OPTARG;;
        w) sslPswd=$OPTARG;;
        m) dnsFqdn=$OPTARG;;
        u) iappUrl=$OPTARG;;
		x) passwd=$OPTARG;;
		h) hostname=$OPTARG;;
		
    esac 
done

user="admin"
vs_https_port="8445"

# check for existence of device-group
response_code=$(curl -sku $user:$passwd -w "%{http_code}" -X GET -H "Content-Type: application/json" https://localhost/mgmt/tm/cm/device-group/~Common~Sync  -o /dev/null)

if [[ $response_code != 200 ]]; then
     echo "We are one, set device group to none"
     device_group="none"
else
     echo "We are two, set device group to Sync"
     device_group="/Common/Sync"
fi

 curl -sk -u $user:$passwd -X POST -H "Content-Type: application/json" https://localhost/mgmt/tm/asm/tasks/update-signatures -d '{ }'

sleep 120

# download iApp templates
template_location=$iappUrl

for template in f5.microsoft_office_365_idp.v1.1.0.tmpl
do
     curl -k -s -f --retry 5 --retry-delay 10 --retry-max-time 10 -o /config/$template $template_location
     response_code=$(curl -sku $user:$passwd -w "%{http_code}" -X POST -H "Content-Type: application/json" https://localhost/mgmt/tm/sys/config -d '{"command": "load","name": "merge","options": [ { "file": "/config/'"$template"'" } ] }' -o /dev/null)
     if [[ $response_code != 200  ]]; then
          echo "Failed to install iApp template; exiting with response code '"$response_code"'"
          exit
     fi
     sleep 10
done

# deploy application

## Construct the blackbox.conf file using the arrays.

response_code=$(curl -sku $user:$passwd -w "%{http_code}" -X POST -H "Content-Type: application/json" https://localhost/mgmt/tm/sys/application/service/ -d '{"name":"o365Fed","partition":"Common","deviceGroup":"'"$device_group"'","strictUpdates":"disabled","template":"/Common/f5.microsoft_office_365_idp.v1.1.0.tmpl","traffic-group": "traffic-group-local-only","tables": [{"apm__active_directory_servers","column-names":["fqdn","addr"],"rows":["'$hostname'","'$ipAddress'"]}],"variables replace-all-with":[{"name":"apm__aaa_profile","encrypted":"no","value":"/#create_new#"},{"name":"apm__login_domain","encrypted":"no","value":"'$domainFqdn'"},{"name":"apm__credentials","encrypted":"no","value":"no"},{"name":"apm__log_settings","encrypted":"no","value":"/Common/default-log-setting"},{"name":"apm__ad_monitor","encrypted":"no","value":"ad_icmp"},{"name":"apm__saml_entity_id","encrypted":"no","value":"'$entityId'"},{"name":"apm__saml_entity_id_format","encrypted":"no","value":"URL"},{"name":"general__config_mode","encrypted":"no","value":"basic"},{"name":"idp_encryption__cert","encrypted":"no","value":"/Common/default.crt"},{"name":"idp_encryption__key","encrypted":"no","value":"/Common/default.key"},{"name":"webui_virtual__addr","encrypted":"no","value":"'$ipAddress'"},{"name":"webui_virtual__cert","encrypted":"no","value":"/Common/default.crt"},{"name":"webui_virtual__key","encrypted":"no","value":"/Common/default.key"},{"name":"webui_virtual__port","encrypted":"no","value":"'$port'"}]}' -o /dev/null)

     if [[ $response_code != 200  ]]; then
          echo "Failed to deploy unencrypted application; exiting with response code '"$response_code"'"
          exit
     fi

echo "Deployment complete."
exit