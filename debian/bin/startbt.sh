#!/bin/bash

get_rdk_type_string() {
  board_id=$(cat /sys/class/socinfo/board_id)
  board_type=$((0x$board_id & 0xfff))
  hex_btype=$(printf "0x%x" $board_type)

  case $hex_btype in
  "0x301")
    echo "x5_rdk"
    ;; 
  "0x302")
    echo "x5_rdk"
    ;;
  *)
    echo "null"
    exit -1
  ;;
  esac

}

board_type_string=$(get_rdk_type_string)

id messagebus >& /dev/null
if [ $? -ne 0 ]; then
	groupadd  messagebus
	useradd -g messagebus messagebus
fi

if [ $board_type_string == "x5_rdk" ]; then
	hciattach -s 1500000 /dev/ttyS5 any 1500000 noflow &
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
