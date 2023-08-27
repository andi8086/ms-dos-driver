#define _XOPEN_SOURCE 1500
#define _DEFAULT_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>


int set_iface_attribs(int fd, int speed, int parity)
{
        struct termios tty;

        if (tcgetattr(fd, &tty) != 0) {
                perror("error from tcgetattr");
                return -1;
        }

        cfsetospeed(&tty, speed);
        cfsetispeed(&tty, speed);

        tty.c_cflag = (tty.c_cflag & ~CSIZE) | CS8;
        tty.c_iflag &= ~IGNBRK;
        tty.c_lflag = 0;
        tty.c_oflag = 0;
        tty.c_cc[VMIN] = 0;
        tty.c_cc[VTIME] = 50;
        tty.c_iflag &= ~(IXON | IXOFF | IXANY);
        tty.c_cflag |= (CLOCAL | CREAD);
        tty.c_cflag &= ~(PARENB | PARODD);
        tty.c_cflag |= parity;
        tty.c_cflag &= ~CSTOPB;
//        tty.c_cflag &= ~CRTSCTS;

        tty.c_iflag &= ~(IGNBRK | BRKINT | PARMRK | ISTRIP |
                         INLCR | IGNCR | ICRNL);
        tty.c_lflag &= ~(ECHO | ECHONL | ICANON | ISIG | IEXTEN);
        tty.c_oflag &= ~OPOST;

        if (tcsetattr(fd, TCSANOW, &tty) != 0) {
                perror("error %d from tcsetattr");
                return -1;
        }
        return 0;
}

void set_blocking(int fd, int should_block)
{
        struct termios tty;
        memset(&tty, 0, sizeof(tty));
        if (tcgetattr(fd, &tty) != 0) {
                perror("error from tcgetattr");
                return;
        }

        tty.c_cc[VMIN] = should_block ? 1 : 0;
        tty.c_cc[VTIME] = 50;

        if (tcsetattr(fd, TCSANOW, &tty) != 0) {
                perror("error from tcsetattr");
        }
}


typedef struct {
        uint16_t sectors;
        uint16_t cylinders;
        uint8_t heads;
        uint8_t sectors_per_track;
} fheader_t;

fheader_t h;

void init_header(FILE *diskfile)
{
        fread(&h, sizeof(h), 1, diskfile);
        printf("cylinders:      %d\n", h.cylinders);
        printf("heads:          %d\n", h.heads);
        printf("sectors per track: %d\n", h.sectors_per_track);
        printf("capacity:       %d bytes\n", h.sectors * 512);
        printf("\n");
}

int read_sectors(int fd, FILE *diskfile)
{

        uint8_t value;
        int rl;
        do {
                rl = read(fd, &value, 1);
        } while (rl != 1);

        int num = value;

        do {
                rl = read(fd, &value, 1);
        } while (rl != 1);

        int cyl = value;

        do {
                rl = read(fd, &value, 1);
        } while (rl != 1);

        int head = value;

        do {
                rl = read(fd, &value, 1);
        } while (rl != 1);

        int sector = value;


        char buffer[512];

        printf("Read %d sectors from: CYL=%d, HEAD=%d, SEC=%d\n",
               num, cyl, head, sector);

        int lsector = (cyl * h.heads + head) * h.sectors_per_track +
                      sector - 1;
        fseek(diskfile, lsector * 512 + sizeof(h), SEEK_SET);

        for (int j = 0; j < num; j++) {
                fread(buffer, 512, 1, diskfile);
                for (int i = 0; i < 512; i++) {
                        int wl;
                        do {
                                wl = write(fd, &buffer[i], 1);
                                // usleep(500);
                        } while (wl != 1);
                }
        }
        printf("%u sectors sent\n", num);
}


int main(int argc, char **argv)
{
        int fd;

        fd = open(argv[1], O_RDWR | O_NOCTTY | O_SYNC);
        if (fd < 0) {
                perror("error opening serial");
                return -1;
        }

        grantpt(fd);
        unlockpt(fd);

        char *slavename = ptsname(fd);
        printf("pts slave: %s\n", slavename);

        set_iface_attribs(fd, B19200, 0);
        set_blocking(fd, 1);

        int rlen;
        char cmd;
        uint8_t sector_low;
        uint8_t sector_high;
        uint8_t count_low;
        uint8_t count_high;
        uint16_t sector;
        uint16_t count;

        uint32_t pos = 0;

        FILE *diskfile = fopen(argv[2], "r+");

        init_header(diskfile);

        do {
                cmd = 0;
                rlen = read(fd, &cmd, 1);
                if (rlen <= 0) {
                        continue;
                }
                switch (cmd) {
                case 'R': read_sectors(fd, diskfile); 
                        break;
                default:
                        printf("command: %c\n", (uint8_t)cmd);
                        break;
                }
        } while (true);

        fclose(diskfile);
        close(fd);
        return 0;
}
