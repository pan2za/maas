#!/bin/bash

LSUB=$1
DOMAIN=$2

ip2int() {
    local a b c d
    { IFS=. read a b c d; } <<< $1
    echo $(((((((a << 8) | b) << 8) | c) << 8) | d))
}

int2ip() {
    local ui32=$1; shift
    local ip n
    for n in 1 2 3 4; do
        ip=$((ui32 & 0xff))${ip:+.}$ip
        ui32=$((ui32 >> 8))
    done
    echo $ip
}

netmask() {
    local mask=$((0xffffffff << (32 - $1))); shift
    int2ip $mask
}


broadcast() {
    local addr=$(ip2int $1); shift
    local mask=$((0xffffffff << (32 -$1))); shift
    int2ip $((addr | ~mask))
}

network() {
    local addr=$(ip2int $1); shift
    local mask=$((0xffffffff << (32 -$1))); shift
    int2ip $((addr & mask))
}

first() {
    local addr=$(ip2int $1)
    addr=`expr $addr + 1`
    int2ip $addr
}

LBITS=`echo "$LSUB" | cut -d/ -f2`
LNETW=` echo "$LSUB" | cut -d/ -f1`
LMASK=`netmask $LBITS`
LHOST=`first $LNETW`

DEST=/etc/maas/templates/dns/zone.template
OUT=$(mktemp -u)
cat /tmp/zone.template | awk '/; CORD - DO NOT EDIT BELOW THIS LINE/{exit};1' | awk "/^auto / { if (\$2 == \"${IFACE_MGMT}\") { IN=1 } else {IN=0} } /^iface / { if (\$2 == \"${IFACE_MGMT}\") { IN=1 } else {IN=0}}  /^#/ || /^\s*\$/ { IN=0 } IN==0 {print} IN==1 { print \"#\" \$0 }" > $OUT

cat <<EOT >> $OUT
; CORD - DO NOT EDIT BELOW THIS LINE
{{if domain == '$DOMAIN'}}
\$INCLUDE "/etc/bind/maas/dhcp_harvest.inc"
$HOSTNAME IN A $LHOST
xos CNAME $HOSTNAME
xos-core CNAME $HOSTNAME
xos-chameleon CNAME $HOSTNAME
xos-spa-gui CNAME $HOSTNAME
xos-rest-gw CNAME $HOSTNAME
onos-cord CNAME $HOSTNAME
onos-fabric CNAME $HOSTNAME
docker-registry CNAME $HOSTNAME
apt-cache CNAME $HOSTNAME
mavenrepo CNAME $HOSTNAME
juju-head-node CNAME $HOSTNAME
\$INCLUDE "/etc/bind/maas/cnames.inc"
{{endif}}
EOT

diff $DEST $OUT 2>&1 > /dev/null
if [ $? -ne 0 ]; then
    cp $DEST $DEST.last
    cp $OUT $DEST
    echo -n "true"
else
    echo -n "false"
fi

rm $OUT
