# Block device driver with serial backend

Tested with qemu with MS-DOS 6.22 and IBM DOS 2.0:

```
qemu-system-i386 -boot a -fda dos.img -serial pty
```

Needs dos.img boot disk with

```
DEVICE=COMDSK.SYS
```

in config.sys.

Before accessing drive C then, start the linux backend
(serdev/main.c) with

```
./a.out /dev/pts/4 disk.img
```

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
