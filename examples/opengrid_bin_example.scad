// opengrid_bin_example.scad -- bins hanging on a board, and one laid out for printing
include <../opengrid.scad>

// Mounted view. The board is stood upright so y points up the wall.
// A 3 column bin (odd) and a 4 column bin (even) sit side by side. Both
// widths put every snap in a cell, so any mix of widths packs flush along a row.
rotate([90, 0, 0]) {
    color("silver") opengrid_tile(8, 3);

    color("steelblue")
        opengrid_bin(cols = 3, depth = 40, height = 56, snap_rows = "ends");

    color("seagreen") translate([og_span(3), 0, 0])
        opengrid_bin(cols = 4, depth = 40, height = 56, divisions_x = 3,
                     snap_rows = "ends");
}

// Print orientation: front face on the bed, snaps pointing up. The snaps need
// no support; the back wall bridges between the side walls and dividers.
color("orangered") translate([og_span(8) + 30, -40, 40]) mirror([0, 0, 1])
    opengrid_bin(cols = 2, depth = 40, height = 28, divisions_y = 2);
