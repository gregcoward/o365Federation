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
command="create sys application service o365 traffic-group traffic-group-local-only strict-updates disabled device-group none tables replace-all-with {apm__active_directory_servers {column-names { fqdn addr } rows {{row { $authFqdn $authIp }}}}} template f5.microsoft_office_365_idp.v1.1.0 variables replace-all-with {apm__aaa_profile { value \"/\#create_new\#\"} apm__ad_monitor {value ad_icmp} apm__credentials {value no} apm__log_settings {value /Common/default-log-setting} apm__login_domain {value $domainFqdn} apm__saml_entity_id {value $entityId} apm__saml_entity_id_format {value URL} general__assistance_options {value full} general__config_mode {value basic} idp_encryption__cert {value /Common/default.crt}idp_encryption__key {value /Common/default.key}  webui_virtual__addr {value '$ipAddress'} webui_virtual__cert {value /Common/default.crt}webui_virtual__key {value /Common/default.key} webui_virtual__port {value $port}}"
tmsh -c "$command"

echo "Deployment complete."
exit