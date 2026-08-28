// opengrid_plate_example.scad -- typical use: a product backplate that carries
// snaps only at its top and bottom rows
include <../opengrid.scad>

plate_w = og_span(2);   // 56
plate_h = 152;
plate_t = 3;

// snap centres must land on the 28 mm grid and keep 14 mm clear of the edges
rows_apart = floor((plate_h - 28) / OG_PITCH) * OG_PITCH;   // 112
y0 = (plate_h - rows_apart) / 2;                            // 20

positions = [ for (x = [-1, 1], y = [y0, plate_h - y0])
                [x * OG_PITCH / 2, y - plate_h / 2] ];

color("steelblue")
    translate([-plate_w / 2, -plate_h / 2, 0]) cube([plate_w, plate_h, plate_t]);
color("orangered") opengrid_snaps(positions);
