#! /bin/bash

if [ -z "$@" ];
then
    echo "Welcome to IoT_scan, please input burp packet file and IP"
    # input source file and IP
    echo -n "Burp raw file:"
    read -r burp_raw
else 
    burp_raw=$1 
fi

read -r -p "Do U want to echo out? [Y/n]:" yn
case $yn in 
        [Yy]*) echo $burp_raw;;
        [Nn]*) echo "Okay, then";;
esac