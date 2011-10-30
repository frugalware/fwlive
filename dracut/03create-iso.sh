#!/bin/bash -xe

rm -rf iso
mkdir -p iso/LiveOS
cp -v squashfs.img iso/LiveOS
mkisofs -R -J -V fwlive -o fwlive.iso iso
