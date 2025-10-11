#!/bin/sh

source ../.env

# obtain instance external IP
PUBLIC_IP=$(curl https://compute.googleapis.com/compute/v1/projects/${PROJECT_ID}/zones/${ZONE}/instances/${INSTANCE_NAME} -H "Authorization: Bearer $(gcloud auth print-access-token)" | jq '.networkInterfaces[0].accessConfigs[0].natIP')

# update DNS record
curl -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${DNS_ID}" \
	-H "Authorization: Bearer ${API_TOKEN}" \
	-H "Content-Type: application/json" \
	-d '{"content": '$PUBLIC_IP'}'

# update frpc endpoint
sed 's/serverAddr = "[^"]+"/serverAddr = "${PUBLIC_IP}"/' ../frp/frpc.toml

# update systemd service
sudo systemctl daemon-reload
sudo systemctl restart frp
