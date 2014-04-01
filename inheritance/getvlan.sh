#!/bin/bash

iface=$1
sudo tcpdump -nn -v -i $iface -s 1500 -c 1 'ether[20:2] == 0x2000'
