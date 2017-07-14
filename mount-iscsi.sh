#!/bin/bash



mount_iscsi() {
    echo >&2 "Restarting iSCSI"
    service open-iscsi restart
    rc=$?; if [[ $rc != 0 ]]; then return "$rc"; fi

    echo >&2 "Discovering targets"
    iscsiadm -m discovery -t sendtargets -p $IP:$PORT
    rc=$?; if [[ $rc != 0 ]]; then return "$rc"; fi

    echo >&2 "Logging into scsi target"
    iscsiadm -m node --targetname "$TARGETNAME" --portal "$IP:$PORT" --login
    rc=$?; if [[ $rc != 0 ]]; then return "$rc"; fi
    sleep 5

    echo >&2 "Formatting iscsi device"
    local iscsi_device=`lsblk --scsi | grep -F -i 'iscsi' | awk '{print $1}'`
    rc=$?; if [[ $rc != 0 ]]; then return "$rc"; fi

    arr=($iscsi_device)
    mkfs.ext4 -F /dev/${arr[0]}
    rc=$?; if [[ $rc != 0 ]]; then return "$rc"; fi

    mkdir -p /mnt/iscsi
    rc=$?; if [[ $rc != 0 ]]; then return "$rc"; fi

    echo >&2 "Mounting new iSCSI-device"
    mount /dev/${arr[0]} /mnt/iscsi
    rc=$?; if [[ $rc != 0 ]]; then return "$rc"; fi
}

umount_iscsi() {
    echo >&2 "Umounting iSCSI-mount"
    umount /mnt/iscsi

    iscsiadm -m node --targetname "$TARGETNAME" --portal "$IP:$PORT" --logout
}

write_data() {
    echo >&2 "Writing data to mounted device"
    echo $DATA > /mnt/iscsi/file.txt
    rc=$?; if [[ $rc != 0 ]]; then return "$rc"; fi
}

read_compare_data() {
    echo >&2 "Reading file from mounted device"
    out=$(cat /mnt/iscsi/file.txt)
    rc=$?; if [[ $rc != 0 ]]; then return "$rc"; fi

    if [ "$out" != "$DATA" ]; then
        echo >&2 "Failed to read from file on mounted device"
        return 1
    fi
}

cleanup() {
    echo >&2 "Failure Occurred"
    umount_iscsi
    echo >&2 "Exit Code is $rc"
    exit $rc
}

trap cleanup SIGHUP SIGINT SIGQUIT SIGTERM

# Mount
mount_iscsi
rc=$?

if [[ $rc != 0 ]]; then kill -HUP $$; fi


# Read/Write
if [ ! -z "$DATA" ]; then
    write_data
    read_compare_data
fi

# Umount
umount_iscsi

echo "exited $rc"

