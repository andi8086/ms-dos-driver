#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>



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
        tty.c_cflag &= ~CRTSCTS;

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

int main(int argc, char **argv)
{
        int fd;

        fd = open(argv[1], O_RDWR | O_NOCTTY | O_SYNC);
        if (fd < 0) {
                perror("error opening serial");
                return -1;
        }

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

        FILE *f = fopen(argv[2], "r+");
        uint32_t pos = 0;

        char buffer[512];

        do {

                rlen = read(fd, &cmd, 1);
                if (rlen == 0) {
                        /* timeout */
                        continue;
                }
                if (rlen < 0) {
                        printf("error reading from serial\n");
                        break;
                }

                if (cmd == 'R') {
                        printf("read cmd\n");
                        do {
                                rlen = read(fd, &sector_low, 1);
                        } while (rlen == 0);
                        if (rlen < 0) {
                                printf("error SL\n");
                                continue;
                        }
                        do {
                                rlen = read(fd, &sector_high, 1);
                        } while (rlen == 0);
                        if (rlen < 0) {
                                printf("error SH\n");
                                continue;
                        }
                        do {
                                rlen = read(fd, &count_low, 1);
                        } while (rlen == 0);
                        if (rlen < 0) {
                                printf("error CL\n");
                                continue;
                        }
                        do {
                                rlen = read(fd, &count_high, 1);
                        } while (rlen == 0);
                        if (rlen < 0) {
                                printf("error CH\n");
                                continue;
                        }
                        sector = ((uint16_t)sector_high << 8) | sector_low;
                        count = ((uint16_t)count_high << 8) | count_low;
                        printf("read %d sectors, start = %u\n", count, sector);
                        pos = sector * 512;
                        uint8_t byte;
     
                        byte = 'K';
                        write(fd, &byte, 1);

                        fseek(f, pos, SEEK_SET);

                        do {
                                fread(buffer, 512, 1, f);


                                /* transmit 512 bytes */
                                for (int i = 0; i < 512; i++) {
                                        // usleep(500);
                                        while (write(fd, &buffer[i], 1)== 0);
                                }
                                count -= 1;
                        } while(count);
                }
                else if (cmd == 'W') {
                        printf("write cmd\n");
                        do {
                                rlen = read(fd, &sector_low, 1);
                        } while (rlen == 0);
                        if (rlen < 0) {
                                printf("error SL\n");
                                continue;
                        }
                        do {
                                rlen = read(fd, &sector_high, 1);
                        } while (rlen == 0);
                        if (rlen < 0) {
                                printf("error SH\n");
                                continue;
                        }
                        do {
                                rlen = read(fd, &count_low, 1);
                        } while (rlen == 0);
                        if (rlen < 0) {
                                printf("error CL\n");
                                continue;
                        }
                        do {
                                rlen = read(fd, &count_high, 1);
                        } while (rlen == 0);
                        if (rlen < 0) {
                                printf("error CH\n");
                                continue;
                        }
                        sector = ((uint16_t)sector_high << 8) | sector_low;
                        count = ((uint16_t)count_high << 8) | count_low;
                        printf("write %d sectors, start = %u\n", count, sector);
                        pos = sector * 512;
                        uint8_t byte;
     
                        byte = 'K';
                        write(fd, &byte, 1);

                        fseek(f, pos, SEEK_SET);

                        do {
                                /* transmit 512 bytes */
                                for (int i = 0; i < 512; i++) {
                                        // usleep(500);
                                        while (read(fd, &buffer[i], 1) == 0);
                                }

                                fwrite(buffer, 512, 1, f);

                                count -= 1;
                        } while(count);
                }
        } while (true);

        close(fd);
        return 0;
}
