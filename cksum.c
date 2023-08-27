#include <stdio.h>
#include <stdint.h>

int main(int argc, char **argv)
{
        FILE *f = fopen(argv[1], "r+");


        /* get file size */
        fseek(f, 0, SEEK_END);
        size_t s = ftell(f);

        printf("file has %u bytes\n", s);

        fseek(f, 0, SEEK_SET);

        uint8_t cksum = 0;
        uint8_t byte;
        for (size_t i = 0; i < s - 1; i++) {
                fread(&byte, 1, 1, f);
                cksum += byte;
        }

        cksum = -cksum;
        fseek(f, -1, SEEK_END);
        fwrite(&cksum, 1, 1, f);
        fclose(f);
        return 0;
}
