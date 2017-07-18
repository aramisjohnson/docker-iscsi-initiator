#!/bin/bash

rc=0


mount_iscsi() {
    echo "Restarting iSCSI"
    service open-iscsi restart

    echo "Discovering targets $IP:$PORT"
    iscsiadm -m discovery -t st -p "$IP:$PORT"
    rc=$?; if [[ $rc != 0 ]]; then return "$rc"; fi

    echo "Logging into scsi target $TARGETNAME"
    iscsiadm -m node -T "$TARGETNAME" -l -p "$IP:$PORT"
    rc=$?; if [[ $rc != 0 ]]; then return "$rc"; fi
    sleep 10

    echo "Formatting iscsi device"
    iscsi_device=`lsblk --scsi | grep -F -i 'iscsi' | awk '{print $1}'`

    echo $iscsi_device
    arr=($iscsi_device)
    mkfs.ext4 -F /dev/${arr[0]}

    mkdir -p /mnt/iscsi

    echo "Mounting new iSCSI-device"
    mount /dev/${arr[0]} /mnt/iscsi

}

umount_iscsi() {
    echo "Umounting iSCSI-mount"
    umount /mnt/iscsi

    iscsiadm -m node --targetname "$TARGETNAME" --portal "$IP:$PORT" --logout
}

write_data() {
    echo "Writing the data '$DATA' to mounted device"
    echo $DATA > /mnt/iscsi/file.txt
    rc=$?; if [[ $rc != 0 ]]; then return "$rc"; fi
}

read_compare_data() {
    echo "Reading file from mounted device"
    out=$(cat /mnt/iscsi/file.txt)
    rc=$?; if [[ $rc != 0 ]]; then return "$rc"; fi

    echo "Found the data '$out' in the file and comparing to expected '$DATA'"
    if [ "$out" != "$DATA" ]; then
        echo "Failed to read from file on mounted device"
        return 1
    fi
}

cleanup() {
    echo "Failure occurred..."
    umount_iscsi
    echo "Exit Code is $rc"
    exit $rc
}

trap cleanup SIGHUP SIGINT SIGQUIT SIGTERM

# Mount
mount_iscsi
rc=$?

if [[ "$rc" != 0 ]]; then kill -HUP $$; fi


# Read/Write
if [ ! -z "$DATA" ]; then
    write_data
    read_compare_data
fi

# Umount
umount_iscsi

echo "exited $rc"

