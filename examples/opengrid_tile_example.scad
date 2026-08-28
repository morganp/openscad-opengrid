// opengrid_tile_example.scad -- a snap fitted into a test tile and sectioned
// through the middle, so the retaining nub and the groove it sits in show up.
// Each part is cut separately so the section keeps its own colour.
include <../opengrid.scad>

module front_half_cut() {
    translate([-20, -20, -20]) cube([40, 20, 40]);
}

color("silver")
    difference() {
        translate([-14, -14, 0]) opengrid_tile(1, 1);
        front_half_cut();
    }

color("orangered")
    difference() {
        opengrid_snap();
        front_half_cut();
    }
