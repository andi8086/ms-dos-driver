#include <stdio.h>
#include <stdint.h>

typedef struct {
        uint16_t sectors;
        uint16_t cylinders;
        uint8_t heads;
        uint8_t sectors_per_track;
} fheader_t;


void print_options(char **argv)
{
        printf("Syntax: %s headerfile id\n\n", argv[0]);
        printf("id list:\n");
        printf("1: (5.25\") 160K\n");
        printf("2: (5.25\") 320K\n");
        printf("3: (5.25\") 180K\n");
        printf("4: (5.25\") 360K\n");
        printf("5: (5.25\") 1200K\n");
        printf("6: (3.5\")  720K\n");
        printf("7: (3.5\")  1440K\n");
        printf("\n");

}


int main(int argc, char **argv)
{
        fheader_t h;

        if (argc < 2) {
                print_options(argv);
                return 0;
        }


        switch (*argv[2]) {
        case '1': // 160k
                h.cylinders = 40;
                h.heads = 1;
                h.sectors_per_track = 8;
                break;
        case '2': // 320k
                h.cylinders = 40;
                h.heads = 2;
                h.sectors_per_track = 8;
                break;
        case '3': // 180k
                h.cylinders = 40;
                h.heads = 1;
                h.sectors_per_track = 9;
                break;
        case '4': // 360k
                h.cylinders = 40;
                h.heads = 2;
                h.sectors_per_track = 9;
                break;
        case '5': // 1200k
                h.cylinders = 80;
                h.heads = 2;
                h.sectors_per_track = 15;
                break;
        case '6': // 720k
                h.cylinders = 80;
                h.heads = 2;
                h.sectors_per_track = 9;
                break;
        case '7': // 1440k
                h.cylinders = 80;
                h.heads = 2;
                h.sectors_per_track = 18;
                break;
        default:
                print_options(argv);
                return 0;
        }

        FILE *f = fopen(argv[1], "w");
        h.sectors = h.cylinders * h.heads * h.sectors_per_track;
        printf("cylinders:      %d\n", h.cylinders);
        printf("heads:          %d\n", h.heads);
        printf("sectors per track: %d\n", h.sectors_per_track);
        printf("capacity:       %d bytes\n", h.sectors * 512);

        fwrite(&h, sizeof(h), 1, f);
        fclose(f);
        return 0;
}
