#!/bin/bash -xe

rm -rf iso
mkdir -p iso/LiveOS
cp -v squashfs.img iso/LiveOS
mkisofs -R -J -V frugal-minim-x86_64-201110300111 -o live.iso iso
