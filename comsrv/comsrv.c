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

#include <SDL.h>
#include <SDL_mixer.h>

#include "ui_floppy.h"


int floppy_old_track = 0;


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
        tty.c_cc[VTIME] = 5;
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
        tty.c_cc[VTIME] = 5;

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

int init_header(FILE *diskfile)
{
        fseek(diskfile, 0, SEEK_END);
        uint32_t pos = ftell(diskfile) - 6;
        if (pos != 1024*160 && pos != 1024*180 &&
            pos != 1024*320 && pos != 1024*360 &&
            pos != 1024*720 && pos != 1024*1200 &
            pos != 1024*1440) {
                printf("Invalid floppy image format\n");
                return -1;
        }
        fseek(diskfile, 0, SEEK_SET);

        fread(&h, sizeof(h), 1, diskfile);
        printf("------------------------------------\n");
        printf("Floppy image:\n");
        printf("cylinders:         %d\n", h.cylinders);
        printf("heads:             %d\n", h.heads);
        printf("sectors per track: %d\n", h.sectors_per_track);
        printf("capacity:          %d bytes\n", h.sectors * 512);
        printf("------------------------------------\n");
        printf("\n");

        return 0;
}

Mix_Chunk *floppy_sound = NULL;

void floppy_seek(int cyl)
{
        if (cyl == floppy_old_track) {
                return; 
        }

        int chan = Mix_PlayChannel(-1, floppy_sound,
                        (int)fabs((double)(floppy_old_track - cyl)*0.2));
     //   while (Mix_Playing(chan));
        floppy_old_track = cyl;
}


int write_sectors(int fd, FILE *diskfile, SDL_Renderer *renderer)
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

        printf("FDD: Write %d sectors from: CYL=%d, HEAD=%d, SEC=%d\n",
               num, cyl, head, sector);

        int lsector = (cyl * h.heads + head) * h.sectors_per_track +
                      sector - 1;
        fseek(diskfile, lsector * 512 + sizeof(h), SEEK_SET);
        floppy_seek(cyl);
        sdl_draw_floppy(renderer, 400, 300, 280, h.cylinders, cyl, true);
        SDL_RenderPresent(renderer);
        for (int j = 0; j < num; j++) {
                for (int i = 0; i < 512; i++) {
                        int wl;
                        do {
                                wl = read(fd, &buffer[i], 1);
                        } while (wl != 1);
                }
                fwrite(buffer, 512, 1, diskfile);
        }
}


int read_sectors(int fd, FILE *diskfile, SDL_Renderer *renderer)
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

        printf("FDD: Read %d sectors from: CYL=%d, HEAD=%d, SEC=%d\n",
               num, cyl, head, sector);

        int lsector = (cyl * h.heads + head) * h.sectors_per_track +
                      sector - 1;
        fseek(diskfile, lsector * 512 + sizeof(h), SEEK_SET);
        floppy_seek(cyl);
        sdl_draw_floppy(renderer, 400, 300, 280, h.cylinders, cyl, false);
        SDL_RenderPresent(renderer);
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
}


void read_hdd(int fd, FILE *hddfile)
{
        uint16_t sector;
        uint16_t count;
        uint32_t pos;
        uint8_t sector_low, sector_high, count_low, count_high;
        int rlen;

        char buffer[512];

        do {
                rlen = read(fd, &sector_low, 1);
        } while (rlen == 0);
        do {
                rlen = read(fd, &sector_high, 1);
        } while (rlen == 0);
        do {
                rlen = read(fd, &count_low, 1);
        } while (rlen == 0);
        do {
                rlen = read(fd, &count_high, 1);
        } while (rlen == 0);
        sector = ((uint16_t)sector_high << 8) | sector_low;
        count = ((uint16_t)count_high << 8) | count_low;
        printf("HDD: read %d sectors, start = %u\n", count, sector);
        pos = sector * 512;
        uint8_t byte;
     
        byte = 'K';
        write(fd, &byte, 1);

        fseek(hddfile, pos, SEEK_SET);

        do {
                fread(buffer, 512, 1, hddfile);
                /* transmit 512 bytes */
                for (int i = 0; i < 512; i++) {
                        while (write(fd, &buffer[i], 1)== 0);
                }
                count -= 1;
        } while(count);

}


void write_hdd(int fd, FILE *hddfile)
{
        uint16_t sector;
        uint16_t count;
        uint32_t pos;
        uint8_t sector_low, sector_high, count_low, count_high;
        int rlen;

        char buffer[512];
        do {
                rlen = read(fd, &sector_low, 1);
        } while (rlen == 0);
        do {
                rlen = read(fd, &sector_high, 1);
        } while (rlen == 0);
        do {
                rlen = read(fd, &count_low, 1);
        } while (rlen == 0);
        do {
                rlen = read(fd, &count_high, 1);
        } while (rlen == 0);
        sector = ((uint16_t)sector_high << 8) | sector_low;
        count = ((uint16_t)count_high << 8) | count_low;
        printf("HDD: write %d sectors, start = %u\n", count, sector);
        pos = sector * 512;
        uint8_t byte;

        byte = 'K';
        write(fd, &byte, 1);

        fseek(hddfile, pos, SEEK_SET);

        do {
                /* transmit 512 bytes */
                for (int i = 0; i < 512; i++) {
                        // usleep(500);
                        while (read(fd, &buffer[i], 1) == 0);
                }

                fwrite(buffer, 512, 1, hddfile);

                count -= 1;
        } while(count);
}


int main(int argc, char **argv)
{
        printf("COMSRV - Serial FDD and HDD emulator\n");
        printf(" For COMDRV option ROM and COMDRV.SYS DOS driver\n");
        printf(" v0.1 Beta, (C)2023 Andreas. J. Reichel\n");
        printf(" MIT License\n\n");

        int fd;

        fd = open(argv[1], O_RDWR | O_NOCTTY | O_SYNC);
        if (fd < 0) {
                perror("error opening serial");
                return -1;
        }

        /* if pseudo console is used, unlock the slave */
        if (strcmp(argv[1], "/dev/ptmx") == 0) { 
                grantpt(fd);
                unlockpt(fd);

                char *slavename = ptsname(fd);
                printf("pts slave: %s\n", slavename);
        }
//        set_iface_attribs(fd, B19200, 0);
        set_iface_attribs(fd, B115200, 0);
//        set_iface_attribs(fd, B38400, 0);

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

        FILE *diskfile = NULL;

        if (strcmp(argv[2], "-") != 0) {
                diskfile = fopen(argv[2], "r+");
                if (!diskfile) {
                        printf("Error, could not load floppy image\n");
                } else {
                        if (init_header(diskfile) != 0) {
                                fclose(diskfile);
                                diskfile = NULL;
                        }
                }
        }
        FILE *hddfile = fopen(argv[3], "r+");

        if (!diskfile) {
                goto no_floppy_ui;
        }

        if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) != 0) {
                return 1;
        }

        Mix_OpenAudio(44100, MIX_DEFAULT_FORMAT, 2, 2048);
        floppy_sound = Mix_LoadWAV("servo3.wav");

        SDL_Window *screen = SDL_CreateWindow("My App",
                0, 0, 800, 600, SDL_WINDOW_SHOWN);
        if (!screen) {
                return 2;
        }
        SDL_Renderer *renderer = SDL_CreateRenderer(screen, -1,
                SDL_RENDERER_ACCELERATED);
        if (!renderer) {
                return 3;
        }
        atexit(SDL_Quit);

        SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
        SDL_RenderClear(renderer);

no_floppy_ui:
        bool quit = false;

        while (!quit) {
                if (diskfile) {
                        SDL_RenderPresent(renderer);
                        SDL_Event event;
                        while (SDL_PollEvent(&event)) {
                                switch (event.type) {
                                case SDL_QUIT:
                                        quit = true;
                                        break;
                                default:
                                        break;
                                }
                        }
                }
                cmd = 0;
                rlen = read(fd, &cmd, 1);
                if (rlen <= 0) {
                        continue;
                }
                switch (cmd) {
                case 'r': read_sectors(fd, diskfile, renderer); 
                        break;
                case 'w': write_sectors(fd, diskfile, renderer);
                        break;
                case 'R': read_hdd(fd, hddfile);
                        break;
                case 'W': write_hdd(fd, hddfile);
                        break;
                default:
                        printf("command: %c\n", (uint8_t)cmd);
                        break;
                }
        }
        fclose(hddfile);
        if (diskfile) {
                fclose(diskfile);
                Mix_FreeChunk(floppy_sound);
                SDL_DestroyWindow(screen);
                SDL_Quit();
        }
        close(fd);
        return 0;
}
