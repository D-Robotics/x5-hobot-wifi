#!/bin/bash

SYSFS_BOARDID_PATH="/sys/class/socinfo/board_id"
SYSFS_SOCNAME_PATH="/sys/class/socinfo/soc_name"
SYSFS_SOMNAME_PATH="/sys/class/socinfo/som_name"

get_rdk_type_string() {
  local soc_name=""
  local board_id=""
  local rdk_type="unknown"

  if [ -f "${SYSFS_SOCNAME_PATH}" ]; then
    soc_name=$(cat "${SYSFS_SOCNAME_PATH}" 2>/dev/null | tr -d '[:space:]')
  elif [ -f "${SYSFS_SOMNAME_PATH}" ]; then
    soc_name=$(cat "${SYSFS_SOMNAME_PATH}" 2>/dev/null | tr -d '[:space:]')
  fi
  soc_name=${soc_name:-""}

  if [ -f "${SYSFS_BOARDID_PATH}" ]; then
    board_id=$(cat "${SYSFS_BOARDID_PATH}" 2>/dev/null | tr -d '[:space:]')
  fi
  board_id=${board_id:-""}

  if echo "$soc_name" | grep -qi "x5"; then
    local prefix=""
    local version_num="0"
    
    if [[ "$board_id" == 30* ]]; then
      prefix="x5_rdk"
      version_num=$(echo "$board_id" | grep -o "30[0-9]" | grep -o "[0-9]$" || echo "0")
    elif [[ "$board_id" == 50* ]]; then
      prefix="x5_md"
      version_num=$(echo "$board_id" | grep -o "50[0-9]" | grep -o "[0-9]$" || echo "0")
    fi

    if [ -n "$prefix" ]; then
      rdk_type="${prefix}_v${version_num}"
    else
      rdk_type="x5_unknown"
    fi

  elif [[ "$soc_name" =~ ^[568b]$ ]]; then
    case "$soc_name" in
      "5") rdk_type="x3_rdk_v1"   ;; 
      "6") rdk_type="x3_rdk_v1_2" ;;  
      "8") rdk_type="x3_rdk_v2"   ;;
      "b") rdk_type="x3_md_v1"    ;;
    esac
  fi

  echo "$rdk_type"
}

board_type_string=$(get_rdk_type_string)

# reset bt
case $board_type_string in
  x3_rdk*)
    echo 57 > /sys/class/gpio/export
	echo out > /sys/class/gpio/gpio57/direction
	echo 0 > /sys/class/gpio/gpio57/value
	sleep 0.5
	echo 1 > /sys/class/gpio/gpio57/value
	echo 57 > /sys/class/gpio/unexport
    ;; 
  x3_md*)
    echo 2 > /sys/class/gpio/export
	echo out > /sys/class/gpio/gpio2/direction
	echo 0 > /sys/class/gpio/gpio2/value
	sleep 0.5
	echo 1 > /sys/class/gpio/gpio2/value
	echo 2 > /sys/class/gpio/unexport
    ;;
  *)
    ;;
esac

id messagebus >& /dev/null
if [ $? -ne 0 ]; then
	groupadd  messagebus
	useradd -g messagebus messagebus
fi

case $board_type_string in
  x5*)
    hciattach -s 1500000 /dev/ttyS5 any 1500000 noflow &
    ;; 
  x3_rdk_v1)
    brcm_patchram_plus --enable_hci --no2bytes --tosleep 200000 --baudrate 460800 --patchram /lib/firmware/brcm/BCM4343A1.hcd /dev/ttyS1 &
    ;;
  x3_rdk_v1_2)
    rtk_hciattach -n -s 115200 ttyS1 rtk_h5 &
    ;;
  x3_rdk_v2)
    rtk_hciattach -n -s 115200 ttyS1 rtk_h5 noflow &
    ;;
  x3_md_v1)
    rtk_hciattach -n -s 115200 ttyS1 rtk_h5 noflow &
    ;;
  *)
    ;;
esac

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
