#ifndef UI_FLOPPY_H
#define UI_FLOPPY_H

#include <stdio.h>
#include <stdbool.h>

#include <SDL.h>


void sdl_draw_floppy(SDL_Renderer *renderer, int x, int y, int r,
                     int num_tracks, int curr_track);


#endif
