#!/vendor/bin/sh
#
# Start indicated fingerprint HAL service
#
# Copyright (c) 2019 Lenovo
# All rights reserved.
#
# April 15, 2019  chengql2@lenovo.com  Initial version
# December 2, 2019  chengql2  Store fps_id into persist fs

script_name=${0##*/}
script_name=${script_name%.*}
function notice {
    log -t "$scriptname" -p i "$*"
}

persist_fps_id=/mnt/vendor/persist/fps/vendor_id
persist_fps_id2=/mnt/vendor/persist/fps/last_vendor_id
MAX_TIMES=20

if [ ! -f $persist_fps_id ]; then
    notice "warn: no associated persist file found"
    return -1
fi
FPS_VENDOR_NONE=none
FPS_VENDOR_CHIPONE=chipone
FPS_VENDOR_FPC=fpc

prop_fps_status=vendor.hw.fingerprint.status
prop_persist_fps=persist.vendor.hardware.fingerprint

FPS_STATUS_NONE=none
FPS_STATUS_OK=ok

fps_vendor2=$(cat $persist_fps_id2)
if [ -z $fps_vendor2 ]; then
    fps_vendor2=$FPS_VENDOR_NONE
fi
notice "FPS vendor (last): $fps_vendor2"
fps_vendor=$(cat $persist_fps_id)
if [ -z $fps_vendor ]; then
    fps_vendor=$FPS_VENDOR_NONE
fi
notice "FPS vendor: $fps_vendor"

if [ $fps_vendor == $FPS_STATUS_NONE ]; then
    notice "warn: boot as the last FPS"
    fps=$fps_vendor2
else
    fps=$fps_vendor
fi

for i in $(seq 1 2)
do

setprop $prop_fps_status $FPS_STATUS_NONE
if [ $fps == $FPS_VENDOR_FPC ]; then
    notice "start fps_hal"
    start fps_hal
else
    notice "start fpsensor_hal"
    start chipone_fp_hal
fi

notice "wait for HAL finish ..."
fps_status=$(getprop $prop_fps_status)
for ii in $(seq 1 $MAX_TIMES)
do
#    notice "check fps vendor status: $fps_status"
    if [ $fps_status != $FPS_STATUS_NONE ]; then
        break
    fi
    sleep 0.2
    fps_status=$(getprop $prop_fps_status)
done
notice "fingerprint HAL status: $fps_status"

if [ $fps_status == $FPS_STATUS_OK ]; then
    notice "HAL success"
    setprop $prop_persist_fps $fps
    if [ $fps_vendor2 == $fps ]; then
        return 0
    fi
    notice "- update FPS vendor (last)"
    echo $fps > $persist_fps_id2
    notice "- done"
    return 0
fi

if [ $fps == $fps_vendor2 ]; then
    if [ $fps == $FPS_VENDOR_FPC ]; then
        log "remove FPC driver"
        rmmod fpc1020_mmi
        log "- install chipone driver"
        insmod /vendor/lib/modules/fpsensor_spi_tee.ko
        fps=$FPS_VENDOR_CHIPONE
    else
        log "remove chipone driver"
        rmmod fpsensor_spi_tee
        log "- install fpc driver"
        insmod /vendor/lib/modules/fpc1020_mmi.ko
        fps=$FPS_VENDOR_FPC
    fi
    notice "- update FPS vendor"
    echo $fps > $persist_fps_id
    sleep 1
else
    notice "error: HAL fail"
    setprop $prop_persist_fps $FPS_VENDOR_NONE
    echo $FPS_VENDOR_NONE > $persist_fps_id

    notice "- done"
    return 1
fi

done
