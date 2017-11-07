#!/usr/bin/env bash

sudo apt-get -y update && sudo apt-get install -y fio ioping

fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 --name=test --filename=test \
    --bs=4k --iodepth=64 --size=4G --readwrite=randrw --rwmixread=75
ioping -c 10 .
