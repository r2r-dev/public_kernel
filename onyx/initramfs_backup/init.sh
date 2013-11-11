#!/bin/sh

PASSWORD=Mx*98Ndqx01@Jc
PASSWORD_ARTA=ARTAMx*98Ndqx01@Jctech
# do not add line above  !!!
init=/sbin/init

rescue_shell()
{
# Create shell
mknod /dev/ttyGS0 c 252 0
insmod /lib/modules/arcotg_udc.ko
insmod /lib/modules/g_serial.ko use_acm=1

# Spawn login
getty -t 10 -L 115200 ttyGS0 -l /bin/login
getty -t 60 -L 115200 ttyGS0 -l /bin/login
}

check_update()
{
  update_pkg=""

  for i in $(ls /mnt/mmc|grep "update-[0-9]\{8\}.zip")
  do
	  continue
  done

  echo $i

  if [ ! -z $i ]; then
    # Extracting files.
    echo "Extracting files..."
    
    update_pkg=/mnt/mmc/$i

    /bin/unzip -o -P $PASSWORD $update_pkg boot/boot-splash -d /tmp/
    if [ $? -eq "0" ]; then
       echo "Password is DEFAULT." 
    else
       /bin/unzip -o -P $PASSWORD_ARTA $update_pkg boot/boot-splash -d /tmp/
       if [ $? -eq "0" ]; then
           echo "Password is ARTA."
           PASSWORD=$PASSWORD_ARTA
       else
           echo "Password is error !!!"
           umount /mnt/mmc
           reboot
           sleep 60
       fi
    fi

    mkdir -p /mnt/rootfs

    /bin/unzip -o -P $PASSWORD $update_pkg usr/bin/mke2fs -d /tmp/
    RET=$?
    if [ $RET == 0 ]; then
        chmod 777 /tmp/usr/bin/mke2fs
        /tmp/usr/bin/mke2fs -T ext4 -m0 /dev/mmcblk0p1
        mount -t ext4 /dev/mmcblk0p1 /mnt/rootfs
        cd /mnt/rootfs
    else
        mount -t ext4 /dev/mmcblk0p1 /mnt/rootfs
        cd /mnt/rootfs
        rm -rf *
    fi
    # Do update.

    sync 
    # Decrypt & extract the update package
    /bin/unzip -P $PASSWORD $update_pkg -d /mnt/rootfs
    
    if [ -f "boot/post_update.sh" ]; then
        cp boot/post_update.sh /tmp
        rm boot/post_update.sh
    fi

    # Update bootloader
    #if [ -f "boot/u-boot.bin" ]; then
    #    echo 1 > /sys/devices/platform/mxsdhci.2/mmc_host/mmc0/mmc0:0001/boot_config
    #    dd if=boot/u-boot.bin of=/dev/mmcblk0 skip=2 seek=2
    #    echo 8 > /sys/devices/platform/mxsdhci.2/mmc_host/mmc0/mmc0:0001/boot_config
    #    echo 2 > /sys/devices/platform/mxsdhci.2/mmc_host/mmc0/mmc0:0001/boot_bus_config
    #fi

    # Update boot splash
    if [ -f "boot/boot-splash" ]; then
       dd if=boot/boot-splash of=/dev/mmcblk0 bs=512 seek=2048
    fi

    # Update uImage
    if [ -f "boot/uImage" ]; then
        dd if=boot/uImage of=/dev/mmcblk0 bs=512 seek=8192
    fi

    # Update initramfs
    #if [ -f "boot/uImage-initramfs" ]; then
    #    dd if=boot/uImage-initramfs of=/dev/mmcblk0 bs=512 seek=12288
    #fi

    # Copy custom fonts
    if [ -d "/mnt/mmc/fonts" ]; then
        cp  /mnt/mmc/fonts/*.ttf /mnt/rootfs/opt/onyx/arm/lib/fonts/
    fi

    #Delete the boot directory.
    rm -rf boot

    mknod dev/console  c 5 1
    mknod dev/null     c 1 3
    sync
 
	cd /
    umount /mnt/rootfs

    echo "Update complete."
    # Update complete, change display

    if [ -f "/tmp/post_update.sh" ]; then
        sh /tmp/post_update.sh
        rm /tmp/post_update.sh
    fi

    # Restart device
    reboot
  else
    echo "No update found."
  fi
}

sd_boot()
{
   # Mount real rootfs
   mount -t ext3 /dev/mmcblk1p2 /newroot
   
   if [ $? != 0 ]; then
      rescue_shell
   fi

   # Switch to the new root and execute init
   mount -n -o move /sys /newroot/sys
   mount -n -o move /proc /newroot/proc

   exec /bin/run-init /newroot /sbin/init.exe 2
}

# Mount things needed by this script
busybox mount -t proc proc /proc
busybox mount -t sysfs sysfs /sys
busybox mount -t devtmpfs none /dev

# Create all the symlinks to /bin/busybox
busybox --install -s

# Main entry for initramfs
echo "Entering initramfs... V1.1"

# Load code page modules.
insmod /lib/modules/nls_iso8859-1.ko
insmod /lib/modules/nls_cp437.ko

retry_count=0
while [ $retry_count -lt 5 ]
do
  if [ -b "/dev/mmcblk1p1" ]; then
    mount -t vfat /dev/mmcblk1p1 /mnt/mmc
    if [ $? = 0 ]; then
      break
    fi
  fi
  sleep 1
  retry_count=`expr $retry_count + 1`
done

if [ $retry_count -lt 5 ]; then
  check_update
  umount /mnt/mmc
fi

# Start sd boot process.
sd_boot

# Impossible to reach.
rescue_shell
exec sh
