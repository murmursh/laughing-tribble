#!/bin/sh

# Exit immediately if a command exits with a non-zero status.
set -e

# Gracefully handle container shutdown
trap exit TERM;

echo "### Waiting for DNS to propagate for $DOMAIN... ###"

PUBLIC_IP=""

# --- Attempt 1: Get public IP from OpenDNS (IPv4 only) ---
echo "--> Trying to get public IP from OpenDNS..."
# The "-query=A" flag ensures we only look for an IPv4 address.
IP_FROM_OPENDNS=$(nslookup -query=A myip.opendns.com resolver1.opendns.com 2>/dev/null | awk -F': ' '/^Address:/{print $2}' | tail -n1)

if [ -n "$IP_FROM_OPENDNS" ]; then
    PUBLIC_IP="$IP_FROM_OPENDNS"
fi

# --- Attempt 2: If the first method failed, try Akamai's service (IPv4 only) ---
if [ -z "$PUBLIC_IP" ]; then
    echo "    OpenDNS failed. Trying Akamai's DNS service..."
    # Akamai's 'whoami.akamai.net' service returns the requester's IP as an A record.
    # We explicitly ask for the A record to guarantee an IPv4 address.
    IP_FROM_AKAMAI=$(nslookup -query=A whoami.akamai.net ns1-1.akamaitech.net 2>/dev/null | awk -F': ' '/^Address:/{print $2}' | tail -n1)
    
    if [ -n "$IP_FROM_AKAMAI" ]; then
        PUBLIC_IP="$IP_FROM_AKAMAI"
    fi
fi

# --- Final Check: See if we got an IP from any method ---
if [ -z "$PUBLIC_IP" ]; then
    echo "❌ Error: Could not determine public IPv4 after trying multiple methods."
    echo "    This strongly suggests a network issue within your container is blocking outbound DNS queries to public servers."
    exit 1
fi

echo "✅ Successfully found public IPv4: $PUBLIC_IP"

# --- Loop to check for propagation ---
while true; do
  # Get the domain's public IPv4 from a reliable public resolver.
  DOMAIN_IP=$(nslookup -query=A "$DOMAIN" 1.1.1.1 | awk '/^Address: / { print $2 }' | tail -n1)

  echo "Host's Public IPv4: $PUBLIC_IP"
  echo "$DOMAIN's Public IPv4: $DOMAIN_IP"

  if [ "$PUBLIC_IP" = "$DOMAIN_IP" ]; then
    echo "✅ DNS for IPv4 has propagated successfully!"
    break
  else
    echo "⏳ DNS not propagated yet. Retrying in 10 seconds..."
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