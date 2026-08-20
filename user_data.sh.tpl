#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

# Configure the pre-installed DCV engine for zero-authentication testing
mkdir -p /etc/dcv/
cat << 'EOF' > /etc/dcv/dcv.conf
[security]
authentication="none"

[session-management]
create-session = true

[session-management/automatic-console-session]
owner = "dcvuser"

[connectivity]
web-port = 8443
EOF

# Force restart the pre-baked services to load our configuration
systemctl restart dcvserver
sleep 3
sudo dcv create-session --owner dcvuser --type virtual --gl on demo
