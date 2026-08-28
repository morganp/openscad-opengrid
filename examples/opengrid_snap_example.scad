// opengrid_snap_example.scad -- the snap on its own, and fitted to a tile
include <../opengrid.scad>

// left: full snap, viewed from the front
translate([-45, 0, 0]) opengrid_snap(lite = false);

// centre: lite snap, 3.4 mm deep
translate([0, 0, 0]) opengrid_snap(lite = true);

// right: full snap, flipped so the flexing tabs and reliefs face the viewer
translate([45, 0, 0]) rotate([180, 0, 0]) opengrid_snap(lite = false);
