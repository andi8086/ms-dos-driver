#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#pragma pack(1)

typedef struct {
        uint16_t sector_size;        
        uint8_t sectors_per_cluster;
        uint16_t reserved_sectors;
        uint8_t num_fats;
        uint16_t max_root_entries;
        uint16_t total_num_sectors;
        uint8_t mediadesc;
        uint16_t sectors_per_fat;
} bpb_t;

typedef struct {
        uint8_t jump[3];
        char oem_name[8];
        bpb_t bpb;
} start_area_t;


start_area_t start;

int main(int argc, char **argv)
{
        FILE *disk = fopen(argv[1], "r");
        fread(&start, sizeof(start), 1, disk);
        fclose(disk);

        printf("BPB:\n");
        
        printf(" sector size: %u\n", start.bpb.sector_size);
        printf(" sectors per cluster: %u\n", start.bpb.sectors_per_cluster);
        printf(" reserved sectors: %u\n", start.bpb.reserved_sectors);
        printf(" num fats: %u\n", start.bpb.num_fats);
        printf(" max root entries: %u\n", start.bpb.max_root_entries);
        printf(" total sector count: %u\n", start.bpb.total_num_sectors);
        printf(" media descriptor byte: %02x\n", start.bpb.mediadesc);
        printf(" sectors per FAT: %u\n", start.bpb.sectors_per_fat);

        return 0;
}

