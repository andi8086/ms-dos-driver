# IBM PC Block device emulation via serial

This software package consists of

* `OPTROM.BIN` - 512 Byte ROM Image to hook into int13h to boot from serial
* `comsrv`     - Linux program to emulate fdd and hdd emulation
* `COMDSK.SYS` - DOS device driver (DOS 2.0+) that installs drive C: via serial
* `COMDSKI.SYS` - same as `COMDSK.SYS`, but will initialize serial port, if
                no Option ROM used.

and some helper tools.

# Boot drive via serial

Install the option ROM into address space C800 to F600 wherever
it fits.

If you boot using this option BIOS, the block device driver
MUST NOT reinitialize the serial port. Therefore, load

`COMDSK.SYS`, instead of `COMDSKI.SYS`.

First start the server:

```
./comsrv /dev/ttyXX fdd.sfi hdd.img
```

where hdd.img is a 32 Megabyte harddrive, created with `create_hdd.sh`.
Floppy images are in `sfi` format, i.e. are prefixed by a 6 byte header.
You can convert a raw floppy image `.img` by using

```
./img2sfi.sh floppy.img
```

which will detect the format by the size, call `cfh` to create the floppy header,
and prefix the image file by it.

## How it works

The option ROM replaces int13 and calls the old int13 if the target drive number
is not 0. In case of 0, read calls are feed through the serial line.

The floppy image with DOS can load the `DSKDRV.SYS` block driver which will
then install a drive `C:`, that will also be emulated by the serial server.


# Block device driver with serial backend WITHOUT option rom

Use driver `COMDSKI.SYS`.


Tested with qemu with MS-DOS 6.22 and IBM DOS 2.0:

```
qemu-system-i386 -boot a -fda dos.img -serial pty
```

Needs dos.img boot disk with

```
DEVICE=COMDSKI.SYS
```

in config.sys.

Before accessing drive C then, start the linux backend
(serdev/main.c) with

```
./comsrv /dev/pts/4 - hdd.img
```

The dash means, that no floppy image is emulated. This is because
the system did not boot from serial in this case.


See comdsk.s for further disk format details.

Please note that DOS 2 does not display the used drive letter correctly.
This is only available wth DOS 3+. Functionality is the same however.


# Simple Character Device Driver

Needs a DOS boot disk with

DEVICE=SKEL.SYS

in config.sys.

This will install the driver 'SKELETON'.

The program 'readdev.com' can then be executed to read from
the device driver.
