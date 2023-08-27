#include <stdio.h>
#include <stdbool.h>

#include <SDL.h>


static int round_up_to_mult_of_eight(int v)
{
        return (v + (8 - 1)) & -8;
}


static void sdl_draw_circle(SDL_Renderer *renderer, int x, int y, int r)
{
        /* 35/49 is slightly biased approx of 1/sqrt(2) */
        const int arr_size = round_up_to_mult_of_eight(r * 8 * 35 / 49); 
        SDL_Point points[arr_size]; 
        int count = 0;

        const int32_t d = r * 2;
        int32_t _x = r - 1;
        int32_t _y = 0;
        int32_t tx = 1;
        int32_t ty = 1;
        int32_t error = (tx - d);

        while (_x >= _y) {
                points[count + 0].x = x + _x; points[count + 0].y = y - _y;
                points[count + 1].x = x + _x; points[count + 1].y = y + _y;
                points[count + 2].x = x - _x; points[count + 2].y = y - _y;
                points[count + 3].x = x - _x; points[count + 3].y = y + _y;
                points[count + 4].x = x + _y; points[count + 4].y = y - _x;
                points[count + 5].x = x + _y; points[count + 5].y = y + _x;
                points[count + 6].x = x - _y; points[count + 6].y = y - _x;
                points[count + 7].x = x - _y; points[count + 7].y = y + _x;

                count += 8;
                
                if (error <= 0) {
                        _y++;
                        error += ty;
                        ty += 2;
                }

                if (error > 0) {
                        _x--;
                        tx += 2;
                        error += tx - d;
                }
        }

        SDL_RenderDrawPoints(renderer, points, count);
}


void sdl_draw_floppy(SDL_Renderer *renderer, int x, int y, int r,
                     int num_tracks, int curr_track, bool write)
{
        int tracks = num_tracks;

        int start_r = r;
        int stop_r = 60;

        double dr = (double)(start_r - stop_r) / (tracks + 1);
        double sr = (double)start_r;
        SDL_SetRenderDrawColor(renderer, 150, 150, 100, 255);
        sdl_draw_circle(renderer, x, y, (int)sr);
        sr -= 3.0*dr;
        while (tracks--) {
                if (tracks == num_tracks - 1 - curr_track) {
                        if (write) {
                                SDL_SetRenderDrawColor(renderer, 255, 127, 127, 255);
                        } else {
                                SDL_SetRenderDrawColor(renderer, 127, 255, 127, 255);
                        }
                } else {
                        SDL_SetRenderDrawColor(renderer, 90, 90, 90, 255);

                }
                sdl_draw_circle(renderer, x, y, (int)sr);
                sr -= dr * 0.75;
        }
        SDL_SetRenderDrawColor(renderer, 150, 150, 100, 255);
        sr -= dr * 6.0;
        sdl_draw_circle(renderer, x, y, (int)sr);
}

