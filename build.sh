#!/bin/sh

nasm -f bin ${1}_source -o ${1}_image && dd if=${1}_image of=bootdisk_image conv=notrunc && qemu -fda bootdisk_image -boot a
