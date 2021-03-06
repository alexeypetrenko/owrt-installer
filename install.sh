#!/bin/bash

VERSION=${VERSION:-minimal-20201026}

SYSUP_URL=https://github.com/openlumi/openwrt/releases/download/$VERSION/openwrt-imx6-lumi-ubifs-sysupgrade.tar
DTB_URL=https://github.com/openlumi/openwrt/releases/download/$VERSION/openwrt-imx6-imx6ull-xiaomi-lumi.dtb
UTILS_HOST=raw.githubusercontent.com
UTILS_URL=/openlumi/owrt-installer/main/curl
UPDATE_URL=/openlumi/owrt-installer/main/update.sh
PKG=/tmp/m.tar
KERNEL=kernel
DTB=lumi.dtb
UBIFS=rootfs.ubifs

w_get() {
    echo -e "GET $2 HTTP/1.0\nHost: $1\n" | openssl s_client -quiet -connect $1:443 2>/dev/null | sed '1,/^\r$/d' > $3
}

echo =================================================================
echo OpenWRT automatic installer
echo =================================================================

# Sanity checks first
if [ ! -d "/lumi" ]; then
    echo
    echo Only STOCK firmware supported. Please try another upgrade path.
    exit -1
fi

if lsmod | grep 8189es >/dev/null; then
    echo
    echo WiFi module 8189es is not supported by OpenWRT yet.
    exit -1
fi

echo
echo Updating time...
ntpdate pool.ntp.org

echo
echo Downloading curl...
WORKDIR=$(mktemp -d)
w_get $UTILS_HOST $UTILS_URL $WORKDIR/curl
chmod +x $WORKDIR/curl

echo
echo Downloading DTB...
$WORKDIR/curl -L -o $WORKDIR/$DTB $DTB_URL
if [ ! -s $WORKDIR/$DTB ]; then
    echo Download failed, please check available space and try again.
    exit -1
fi

echo
echo Downloading SysUpgrade package...
$WORKDIR/curl -L -o $PKG $SYSUP_URL
if ! tar -xvf $PKG -C $WORKDIR; then
    echo Unpacking failed, please check available space and try again.
    exit -1
fi
rm $PKG
mv $WORKDIR/sysupgrade-*/kernel $WORKDIR/$KERNEL
mv $WORKDIR/sysupgrade-*/root $WORKDIR/$UBIFS
rm -rf $WORKDIR/sysupgrade-*

echo
echo Downloading upgrade script...
$WORKDIR/curl -L -o $WORKDIR/update.sh https://$UTILS_HOST$UPDATE_URL
if [ ! -s $WORKDIR/update.sh ]; then
    echo Download failed, please check available space and try again.
    exit -1
fi
chmod +x $WORKDIR/update.sh

echo
echo =================================================================
echo Last chance!!! Stock OS would be replaced with OpenWRT. 
echo You have 15 seconds. Press Ctrl+C to cancel.
echo =================================================================
sleep 15

setsid $WORKDIR/update.sh $WORKDIR/$DTB $WORKDIR/$KERNEL $WORKDIR/$UBIFS >/dev/ttymxc0 2>&1 < /dev/null &
