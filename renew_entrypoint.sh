#!/bin/sh

# Exit immediately if a command exits with a non-zero status.
set -e

# Gracefully handle container shutdown
trap exit TERM;

echo "### Waiting for DNS to propagate for $DOMAIN... ###"
while true; do
  # Get the public IP of the host machine
  # We use a DNS query to an OpenDNS server for reliability
  PUBLIC_IP=$(nslookup myip.opendns.com resolver1.opendns.com | awk -F'Address: ' '/myip.opendns.com/{$1="";print $1;exit}')
  
  # Get the IP the domain resolves to
  DOMAIN_IP=$(nslookup "$DOMAIN" | awk -F': ' '/^Address:/{gsub(" ","",$2); print $2}' | tail -n1)

  echo "Host's Public IP: $PUBLIC_IP"
  echo "$DOMAIN resolves to: $DOMAIN_IP"

  # Compare the IPs
  if [ "$PUBLIC_IP" = "$DOMAIN_IP" ]; then
    echo "### DNS has propagated successfully! ###"
    break
  else
    echo "### DNS not propagated yet. Retrying in 10 seconds... ###"
    sleep 10
  fi
done

# --- Initial Certificate Issuance ---
# Check if a certificate already exists.
# The 'live' directory is the standard place for active certs.
if [ ! -d "/etc/letsencrypt/live/$DOMAIN" ]; then
  echo "### Issuing initial certificate for $DOMAIN... ###"
  
  # Request the certificate using the exact parameters you specified
  certbot certonly \
    --standalone \
    -d "$DOMAIN" \
    --email "test@$DOMAIN" \
    --agree-tos \
    --non-interactive \
    --http-01-port 80 \
    --key-type ecdsa \
    --elliptic-curve secp384r1
    
  echo "### Certificate issued successfully. ###"
else
  echo "### Certificate for $DOMAIN already exists. Skipping issuance. ###"
fi

# --- Automatic Renewal Loop ---
# This loop runs forever, checking for renewal every 12 hours.
# 'certbot renew' will only renew if the cert is close to expiring.
while :; do
  echo "### Checking for certificate renewal... ###"
  certbot renew
  sleep 12h & wait $!
done