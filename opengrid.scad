/*
 * opengrid.scad -- openGrid compatible snap connectors and test tiles
 *
 * Pure OpenSCAD primitives, no external dependencies.
 *
 * Public modules:
 *   opengrid_snap(lite)                  -- one snap plug, front face on z = 0, body in -z
 *   opengrid_snaps(positions, lite)      -- snaps at a list of [x, y] centres
 *   opengrid_snap_grid(cols, rows, lite) -- snaps at every cell of a cols x rows patch
 *   opengrid_tile(cols, rows, lite)      -- test-fit board tile, front face on z = 0
 *   opengrid_cell_void(lite)             -- the negative space of one cell opening
 *
 * Public functions:
 *   og_thickness(lite)                   -- board thickness for the variant
 *   og_snap_depth(lite)                  -- how far a snap reaches into the board
 *   og_grid_positions(cols, rows)        -- [x, y] cell centres, patch centred on origin
 *   og_span(n)                           -- outer size of n cells
 *
 * Coordinate convention: z = 0 is the front face of the board. Product geometry
 * lives at z >= 0, snap geometry at z <= 0. Depth d below is measured from the
 * front face, so a point at depth d sits at z = -d.
 *
 * openGrid is a CC BY 4.0 system by David D:
 *   https://www.printables.com/model/1214361
 * This library is an original implementation of the published interface
 * dimensions. It is openGrid compatible, not official.
 */

$fn = $fn > 0 ? $fn : 64;

// ---------------------------------------------------------------------------
// Interface constants
// ---------------------------------------------------------------------------

OG_PITCH            = 28;    // cell to cell spacing, both axes
OG_FULL_THICKNESS   = 6.8;   // full board
OG_LITE_THICKNESS   = 4.0;   // lite board
OG_LITE_SNAP_DEPTH  = 3.4;   // a lite snap uses 3.4 of the 4.0 lite board

// Cell opening, measured across flats
OG_CELL_FACE_FLAT   = 25.8;  // at the board face
OG_CELL_LAND_FLAT   = 25.0;  // the land the snap body is sized against
OG_CELL_GROOVE_FLAT = 26.4;  // the retaining groove

// Cell opening, depths from the face
OG_CELL_CHAMFER_D   = 0.4;   // face chamfer, 45 degrees
OG_CELL_LAND_END_D  = 1.4;   // land runs from OG_CELL_CHAMFER_D to here
OG_CELL_GROOVE_D    = 2.4;   // groove is full width from here inward

// The opening is an octagon. These are perpendicular distances from the cell
// centre to the 45 degree corner faces. Derived from the openGrid corner block:
// a 2.6 mm square set back 4.2 mm along the diagonal from the cell corner.
OG_CORNER_OFFSET    = 4.2 / sqrt(2) + 2.6;                   // 5.569849
OG_CELL_CORNER      = OG_PITCH / sqrt(2) - OG_CORNER_OFFSET; // 14.229142
OG_CELL_CORNER_LEAD = 1.4;                                   // 45 degree corner lead in
OG_CELL_FACE_CORNER = OG_CELL_CORNER + OG_CELL_CORNER_LEAD;  // 15.629142

// Snap body
OG_SNAP_FLAT        = 24.8;                       // 0.1 clearance per side on the land
OG_SNAP_CORNER      = OG_CELL_CORNER - 0.1;       // 14.129142
OG_SNAP_FACE_D      = 0.4;                        // front plate thickness
OG_SNAP_CAPTURE_D   = 1.5;                        // corner capture taper ends here
// The front plate corners sit where the cell corner lead in has reached 0.4 mm
// of depth, so the capture cone nests conformally.
OG_SNAP_FACE_CORNER = OG_CELL_FACE_CORNER - OG_SNAP_FACE_D;  // 15.229142

// Snap retaining nubs, one per flat face
OG_NUB_PROTRUSION   = 0.4;   // beyond OG_SNAP_FLAT / 2
OG_NUB_TOP_D        = 1.4;   // depth of the nub's leading edge
OG_NUB_BOT_D        = 3.2;   // depth of the nub's trailing edge
OG_NUB_WEDGE        = 0.6;   // length of each ramp, so the tip band is 0.6 long
OG_NUB_ROOT_W       = 11.0;  // width where the nub meets the body
OG_NUB_TIP_W        = 7.1;   // width at full protrusion

// Spring reliefs that turn the outer skin behind each nub into a cantilever
OG_SKIN             = 0.7;   // flexing wall thickness
OG_RELIEF_SLOT_W    = 0.6;   // gap behind the skin
OG_RELIEF_SLOT_LEN  = 12.4;  // how wide the relieved region is
OG_RELIEF_SLIT_W    = 0.4;   // slits down each side of the tab
OG_RELIEF_ANCHOR_D  = 0.6;   // solid depth at the front that anchors the tab

EPS = 0.01;

// ---------------------------------------------------------------------------
// Functions
// ---------------------------------------------------------------------------

function og_thickness(lite = false) =
    lite ? OG_LITE_THICKNESS : OG_FULL_THICKNESS;

function og_snap_depth(lite = false) =
    lite ? OG_LITE_SNAP_DEPTH : OG_FULL_THICKNESS;

function og_span(n) = n * OG_PITCH;

function og_grid_positions(cols = 1, rows = 1) =
    [ for (r = [0 : rows - 1], c = [0 : cols - 1])
        [ (c - (cols - 1) / 2) * OG_PITCH,
          (r - (rows - 1) / 2) * OG_PITCH ] ];

// ---------------------------------------------------------------------------
// Profile helpers
// ---------------------------------------------------------------------------

/*
 * og_octagon -- the openGrid cross section
 *
 *   flat   -- size across the four straight faces
 *   corner -- perpendicular distance from centre to the 45 degree corner faces
 *
 * A square rotated 45 degrees with side 2 * corner has its faces exactly
 * `corner` from the centre, so intersecting the two squares gives the octagon.
 */
module og_octagon(flat, corner) {
    intersection() {
        square([flat, flat], center = true);
        rotate(45) square([corner * 2, corner * 2], center = true);
    }
}

/*
 * og_loft -- straight taper between two octagon profiles
 *
 * Depths are measured from the front face, so d0 must be less than d1 and the
 * result occupies z = -d0 down to z = -d1.
 *
 * Built as the intersection of two independently tapered square prisms, one
 * straight and one turned 45 degrees. At every height the cross section is the
 * intersection of the two interpolated squares, which is exactly the octagon
 * for that depth. No epsilon fudge, so sections butt together cleanly.
 */
module og_loft(d0, flat0, corner0, d1, flat1, corner1) {
    h = d1 - d0;
    translate([0, 0, -d1])
    intersection() {
        linear_extrude(height = h, scale = flat0 / flat1)
            square([flat1, flat1], center = true);
        rotate([0, 0, 45])
            linear_extrude(height = h, scale = corner0 / corner1)
                square([corner1 * 2, corner1 * 2], center = true);
    }
}

// ---------------------------------------------------------------------------
// Board
// ---------------------------------------------------------------------------

/*
 * og_cell_half -- the front half of a cell opening, front face at z = 0
 *
 * Runs from the face down to `to_d`. Flats: 25.8 at the face, 45 degree chamfer
 * to 25.0, a 1.0 mm land, then a 35 degree ramp out to the 26.4 groove.
 * Corners: a 45 degree lead in over the first 1.4 mm, constant after that.
 */
module og_cell_half(to_d) {
    face_c = OG_CELL_FACE_CORNER;
    ch_c   = face_c - OG_CELL_CHAMFER_D;

    og_loft(0, OG_CELL_FACE_FLAT, face_c,
            OG_CELL_CHAMFER_D, OG_CELL_LAND_FLAT, ch_c);

    og_loft(OG_CELL_CHAMFER_D, OG_CELL_LAND_FLAT, ch_c,
            OG_CELL_LAND_END_D, OG_CELL_LAND_FLAT, OG_CELL_CORNER);

    og_loft(OG_CELL_LAND_END_D, OG_CELL_LAND_FLAT, OG_CELL_CORNER,
            OG_CELL_GROOVE_D, OG_CELL_GROOVE_FLAT, OG_CELL_CORNER);

    if (to_d > OG_CELL_GROOVE_D)
        og_loft(OG_CELL_GROOVE_D, OG_CELL_GROOVE_FLAT, OG_CELL_CORNER,
                to_d, OG_CELL_GROOVE_FLAT, OG_CELL_CORNER);
}

/*
 * opengrid_cell_void -- negative space of one cell opening
 *
 * Front face at z = 0, running to z = -thickness. A full board is symmetric
 * front to back, so a full snap can be fitted from either side. A lite board
 * is the front 4.0 mm of that profile, cut off flat at the rear.
 */
module opengrid_cell_void(lite = false) {
    t = og_thickness(lite);

    if (lite) {
        og_cell_half(t);
    } else {
        og_cell_half(t / 2 + EPS);
        translate([0, 0, -t]) mirror([0, 0, 1]) og_cell_half(t / 2 + EPS);
    }
}

/*
 * opengrid_tile -- a cols x rows board patch for test fitting
 *
 * Front face at z = 0. This carries the cell profile only. It is deliberately
 * not a drop in replacement for a printed openGrid board: there are no edge
 * connector cutouts, screw bosses or tile to tile features.
 */
module opengrid_tile(cols = 1, rows = 1, lite = false) {
    t = og_thickness(lite);
    difference() {
        translate([0, 0, -t])
            cube([og_span(cols), og_span(rows), t], center = false);
        for (p = og_grid_positions(cols, rows))
            translate([p[0] + og_span(cols) / 2, p[1] + og_span(rows) / 2, 0])
                opengrid_cell_void(lite);
    }
}

// ---------------------------------------------------------------------------
// Snap
// ---------------------------------------------------------------------------

/*
 * og_nub -- one retaining nub on the +X face
 *
 * A lens shaped bump: full OG_NUB_ROOT_W wide where it leaves the body,
 * narrowing to OG_NUB_TIP_W at full protrusion, with a ramp at each end so it
 * cams in on insertion and wedges against the groove ramp on the way out.
 */
module og_nub(flat) {
    x_root = flat / 2 - EPS;
    x_tip  = flat / 2 + OG_NUB_PROTRUSION - EPS;
    z_mid  = -(OG_NUB_TOP_D + OG_NUB_BOT_D) / 2;
    h_root = OG_NUB_BOT_D - OG_NUB_TOP_D;
    h_tip  = h_root - 2 * OG_NUB_WEDGE;

    hull() {
        translate([x_root, 0, z_mid])
            cube([EPS, OG_NUB_ROOT_W, h_root], center = true);
        translate([x_tip, 0, z_mid])
            cube([EPS, OG_NUB_TIP_W, h_tip], center = true);
    }
}

/*
 * og_nub_relief -- the cuts that let the nub's skin flex inward
 *
 * A slot behind the skin plus a slit down each side leaves a tab that is free
 * on three sides and anchored to the front plate over OG_RELIEF_ANCHOR_D. All
 * three cuts are open at the rear face so they print without bridging.
 */
module og_nub_relief(flat, t) {
    x_in  = flat / 2 - OG_SKIN - OG_RELIEF_SLOT_W;
    depth = t - OG_RELIEF_ANCHOR_D;
    z_mid = -(OG_RELIEF_ANCHOR_D + t) / 2;

    // slot behind the skin
    translate([x_in + OG_RELIEF_SLOT_W / 2, 0, z_mid])
        cube([OG_RELIEF_SLOT_W, OG_RELIEF_SLOT_LEN, depth], center = true);

    // slit down each side of the tab
    slit_len = flat / 2 + OG_NUB_PROTRUSION + EPS - x_in;
    for (s = [-1, 1])
        translate([x_in + slit_len / 2, s * OG_RELIEF_SLOT_LEN / 2, z_mid])
            cube([slit_len, OG_RELIEF_SLIT_W, depth], center = true);
}

/*
 * opengrid_snap -- one snap plug
 *
 *   lite            -- true for a 3.4 mm snap that suits a lite board
 *   nubs            -- fit the flexing retaining nubs (false gives a plain plug)
 *   corner_clearance-- shrink the corner capture cone. 0 is the nominal
 *                      conformal fit; try 0.05 to 0.1 if your printer runs fat
 *
 * The front plate finishes flush with the board face at z = 0 and the body
 * runs to z = -og_snap_depth(lite).
 */
module opengrid_snap(lite = false, nubs = true, corner_clearance = 0) {
    t    = og_snap_depth(lite);
    flat = OG_SNAP_FLAT;
    fc   = OG_SNAP_FACE_CORNER - corner_clearance;
    bc   = OG_SNAP_CORNER - corner_clearance;

    difference() {
        union() {
            // front plate, sits inside the board's face chamfer
            og_loft(0, flat, fc, OG_SNAP_FACE_D, flat, fc);

            // corner capture cone, 45 degrees, nests in the cell corner lead in
            og_loft(OG_SNAP_FACE_D, flat, fc, OG_SNAP_CAPTURE_D, flat, bc);

            // body
            og_loft(OG_SNAP_CAPTURE_D, flat, bc, t, flat, bc);

            if (nubs)
                for (a = [0, 90, 180, 270]) rotate([0, 0, a]) og_nub(flat);
        }
        if (nubs)
            for (a = [0, 90, 180, 270]) rotate([0, 0, a]) og_nub_relief(flat, t);
    }
}

/*
 * opengrid_snaps -- snaps at a list of [x, y] centres
 */
module opengrid_snaps(positions, lite = false, nubs = true, corner_clearance = 0) {
    for (p = positions)
        translate([p[0], p[1], 0])
            opengrid_snap(lite, nubs, corner_clearance);
}

/*
 * opengrid_snap_grid -- a snap in every cell of a cols x rows patch,
 * centred on the origin
 */
module opengrid_snap_grid(cols = 1, rows = 1, lite = false, nubs = true,
                          corner_clearance = 0) {
    opengrid_snaps(og_grid_positions(cols, rows), lite, nubs, corner_clearance);
}
