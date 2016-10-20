#!/bin/bash
export PATH="/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin/"

IP_REGEX='^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'

while getopts i:p:e:d:a:f:c:w:x:u: option
do	case "$option"  in
        i) ipAddress=$OPTARG;;
	    p) port=$OPTARG;;
        e) entityId=$OPTARG;;
        d) authFqdn=$OPTARG;;
        a) authIp=$OPTARG;;
        f) domainFqdn=$OPTARG;;
        c) sslCert=$OPTARG;;
        w) sslPswd=$OPTARG;;
		x) passwd=$OPTARG;;
        u) iappUrl=$OPTARG;;
    esac 
done
sleep 20
user="admin"
echo "'"$ipAddress"'"
echo "'"$entityId"'"
echo "'"$sslCert"'"
echo "'"$sslPswd"'"
echo "'"$iappUrl"'"
# download and install Certificate
echo "Starting Certificate download"
certificate_location=$sslCert
 curl -k -s -f --retry 5 --retry-delay 10 --retry-max-time 10 -o /config/o365FedCert.pfx $certificate_location
 tmsh install sys crypto pkcs12 o365FedCert from-local-file /config/o365FedCert.pfx passphrase $sslPswd
 echo "Certificate download Completed"
 sleep 10

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
command="create sys application service o365 traffic-group traffic-group-local-only strict-updates disabled device-group none tables replace-all-with {apm__active_directory_servers {column-names { fqdn addr } rows {{row { $authFqdn $authIp }}}}} template f5.microsoft_office_365_idp.v1.1.0 variables replace-all-with {apm__aaa_profile { value \"/\#create_new\#\"} apm__ad_monitor {value ad_icmp} apm__credentials {value no} apm__log_settings {value /Common/default-log-setting} apm__login_domain {value $domainFqdn} apm__saml_entity_id {value $entityId} apm__saml_entity_id_format {value URL} general__assistance_options {value full} general__config_mode {value basic} idp_encryption__cert {value /Common/o365FedCert.crt}idp_encryption__key {value /Common/o365FedCert.key}  webui_virtual__addr {value '$ipAddress'} webui_virtual__cert {value /Common/o365FedCert.crt}webui_virtual__key {value /Common/o365FedCert.key} webui_virtual__port {value $port}}"
tmsh -c "$command"

echo "Deployment complete."
exit
