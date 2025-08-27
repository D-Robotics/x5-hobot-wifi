#!/bin/bash


id messagebus >& /dev/null
if [ $? -ne 0 ]; then
	groupadd  messagebus
	useradd -g messagebus messagebus
fi

hciattach -s 1500000 /dev/ttyS5 any 1500000 noflow &

echo -n "Waiting for bluetooth initialize..."
wait_hci0=0
while true
do
	[ -d /sys/class/bluetooth/hci0 ] && break
	sleep 1
	let wait_hci0++
	[ $wait_hci0 -eq 30 ] && {
		echo "bring up bluetooth hci0 failed"
		exit 1
	}
	echo -n "."
done

echo "Done"

echo -n "Check Bluetooth State..."
block_state=`rfkill | grep bluetooth | awk '{print $4}'`
echo ${block_state}
if [ x${block_state} == x"blocked" ]; then
	echo "Unblock bluetooth..."
	rfkill unblock bluetooth
fi

# bluetoothd
echo "restart bluetooth..."
systemctl restart bluetooth

# wait bluetoothd
echo -n "Waiting for bluetoothd..."
count=0
while true; do
    hciconfig hci0 >/dev/null 2>&1 && break
    sleep 1
    count=$((count+1))
    [ $count -gt 10 ] && { echo " bluetoothd init timeout!"; exit 1; }
    echo -n "."
done
echo " OK"

echo "Set Bluetooth Up..."
hciconfig hci0 up

hciconfig  | grep PSCAN > /dev/null
if [ $? -ne 0 ]; then
	echo "Set Bluetooth piscan..."
	hciconfig hci0 piscan
fi

hciconfig
