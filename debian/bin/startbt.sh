#!/bin/bash

som_name=$(cat /sys/class/socinfo/som_name)

# reset bt
if [ ${som_name} == '5' ] || [ ${som_name} == '6' ] || [ ${som_name} == '8' ];then
	# X3 PI
	echo 57 > /sys/class/gpio/export
	echo out > /sys/class/gpio/gpio57/direction
	echo 0 > /sys/class/gpio/gpio57/value
	sleep 0.5
	echo 1 > /sys/class/gpio/gpio57/value
	echo 57 > /sys/class/gpio/unexport
elif [ ${som_name} == 'b' ]; then
	# X3 CM
	echo 2 > /sys/class/gpio/export
	echo out > /sys/class/gpio/gpio2/direction
	echo 0 > /sys/class/gpio/gpio2/value
	sleep 0.5
	echo 1 > /sys/class/gpio/gpio2/value
	echo 2 > /sys/class/gpio/unexport
elif [ ${som_name} == '3' ]  || [ ${som_name} == '4' ]; then
	# X3 SDB
	echo 23 > /sys/class/gpio/export
	echo out > /sys/class/gpio/gpio23/direction
	echo 0 > /sys/class/gpio/gpio23/value
	sleep 0.5
	echo 1 > /sys/class/gpio/gpio23/value
	echo 23 > /sys/class/gpio/unexport
fi

id messagebus >& /dev/null
if [ $? -ne 0 ]; then
	groupadd  messagebus
	useradd -g messagebus messagebus
fi

if [ ${som_name} == '5' ];then
	brcm_patchram_plus --enable_hci --no2bytes --tosleep 200000 --baudrate 460800 --patchram /lib/firmware/brcm/BCM4343A1.hcd /dev/ttyS1 &
elif [ ${som_name} == '6' ];then
	rtk_hciattach -n -s 115200 ttyS1 rtk_h5 &
elif [ ${som_name} == 'b' ] || [ ${som_name} == '8' ];then
	rtk_hciattach -n -s 115200 ttyS1 rtk_h5 noflow &
fi

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

sleep 0.3
echo "Set Bluetooth Up..."
hciconfig hci0 up

hciconfig  | grep PSCAN > /dev/null
if [ $? -ne 0 ]; then
	echo "Set Bluetooth piscan..."
	hciconfig hci0 piscan
fi

hciconfig
