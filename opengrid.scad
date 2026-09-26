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
 *   opengrid_bin(cols, depth, height)    -- open top bin with snaps on its back wall
 *
 * Public functions:
 *   og_thickness(lite)                   -- board thickness for the variant
 *   og_snap_depth(lite)                  -- how far a snap reaches into the board
 *   og_grid_positions(cols, rows)        -- [x, y] cell centres, patch centred on origin
 *   og_span(n)                           -- outer size of n cells
 *   og_bin_width(cols, clearance)        -- outer width of a bin covering cols cells
 *   og_cols_for(mm), og_cols_for_inner(mm, wall)
 *                                        -- fewest cols for an outer or inner width
 *   og_bin_rows(height)                  -- full grid rows a bin height covers
 *   og_bin_snap_positions(cols, height)  -- [x, y] snap centres on a bin back
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

// ---------------------------------------------------------------------------
// Bin
// ---------------------------------------------------------------------------

OG_BIN_CLEARANCE = 0.5;  // default gap left between neighbouring bins

/*
 * og_bin_width -- outer width of a bin that occupies `cols` grid columns
 */
function og_bin_width(cols, clearance = OG_BIN_CLEARANCE) =
    og_span(cols) - clearance;

/*
 * og_cols_for -- fewest columns whose bin is at least `mm` wide outside
 */
function og_cols_for(mm, clearance = OG_BIN_CLEARANCE) =
    max(1, ceil((mm + clearance) / OG_PITCH));

/*
 * og_cols_for_inner -- fewest columns whose bin is at least `mm` wide inside
 */
function og_cols_for_inner(mm, wall = 2, clearance = OG_BIN_CLEARANCE) =
    og_cols_for(mm + 2 * wall, clearance);

/*
 * og_bin_rows -- how many full grid rows a bin of this height covers.
 * Each snap needs a full row, counted down from the top grid line.
 */
function og_bin_rows(height) = floor(height / OG_PITCH);

/*
 * og_bin_snap_cols -- column indices that carry a snap
 *
 * Spreads snaps at most `spacing` columns apart, always using both end
 * columns, and keeps the pattern mirror symmetric. An even width has no
 * centre column, so it needs an even snap count; when the natural count is
 * odd it drops one snap rather than adding one, since fewer snaps are easier
 * to seat.
 */
function og_bin_snap_cols(cols, spacing = 2) =
    cols == 1 ? [0] :
    let(
        n0 = ceil((cols - 1) / max(1, spacing)) + 1,
        n  = (cols % 2 == 0 && n0 % 2 == 1) ? n0 - 1 : n0,
        f  = (cols - 1) / (n - 1)
    )
    [ for (i = [0 : n - 1])
        i <= (n - 1) / 2 ? round(i * f) : (cols - 1) - round((n - 1 - i) * f) ];

/*
 * og_bin_snap_row_list -- row indices, counted down from the top, that carry snaps
 */
function og_bin_snap_row_list(height, snap_rows = "top") =
    let(r = og_bin_rows(height))
    snap_rows == "all"  ? [ for (k = [0 : r - 1]) k ] :
    snap_rows == "ends" ? (r > 1 ? [0, r - 1] : [0]) :
    [0];

/*
 * og_bin_snap_positions -- [x, y] snap centres in bin coordinates
 *
 * x = 14 + 28 * column from the left grid line, y = 14 + 28 * row down from
 * the top grid line. Both always land on a board cell centre.
 */
function og_bin_snap_positions(cols, height, spacing = 2, snap_rows = "top",
                               snap_cols = undef) =
    let(cs = is_undef(snap_cols) ? og_bin_snap_cols(cols, spacing) : snap_cols)
    [ for (k = og_bin_snap_row_list(height, snap_rows), c = cs)
        [ OG_PITCH / 2 + c * OG_PITCH, height - OG_PITCH / 2 - k * OG_PITCH ] ];

/*
 * og_chamfered_box -- box from [x0, y0, z0] to [x1, y1, z1] with 45 degree
 * chamfers of size c on the four edges at z = z1 that are not on y = y1,
 * plus the three front corners. Hull of two boxes, so no epsilon seams.
 */
module og_chamfered_box(x0, x1, y0, y1, z0, z1, c) {
    hull() {
        translate([x0, y0, z0]) cube([x1 - x0, y1 - y0, z1 - z0 - c]);
        translate([x0 + c, y0 + c, z0]) cube([x1 - x0 - 2 * c, y1 - y0 - c, z1 - z0]);
    }
}

/*
 * opengrid_bin -- an open top bin that hangs on the board
 *
 *   cols            -- grid columns covered, width is og_bin_width(cols)
 *   depth           -- how far the bin stands out from the board face
 *   height          -- grid height, top edge on a grid line. >= 28, use a
 *                      multiple of 28 if you want to stack bins
 *   wall, floor     -- shell thicknesses
 *   divisions_x     -- compartments across the width
 *   divisions_y     -- compartments front to back
 *   divider         -- divider thickness
 *   chamfer         -- outer chamfer on the front and bottom front edges
 *   inner_chamfer   -- chamfer inside along the floor and the inside corners
 *   clearance       -- total gap shared between a bin and its neighbours
 *   snap_spacing    -- largest column step between snaps, 2 = every other cell
 *   snap_rows       -- "top", "ends" (top and bottom full rows) or "all"
 *   snap_cols       -- explicit list of snap columns, overrides snap_spacing
 *   lite, nubs, corner_clearance -- passed to opengrid_snap()
 *
 * Coordinates follow the library convention: z = 0 is the board face and the
 * bin stands out in +z. x runs across the width from the left grid line at
 * x = 0, y runs up the board from y = 0 with the top grid line at y = height.
 * So placing the bin at a board corner puts every snap in a cell.
 */
module opengrid_bin(cols = 3, depth = 40, height = 28,
                    wall = 2, floor = 2,
                    divisions_x = 1, divisions_y = 1, divider = 1.6,
                    chamfer = 3, inner_chamfer = 2,
                    clearance = OG_BIN_CLEARANCE,
                    snap_spacing = 2, snap_rows = "top", snap_cols = undef,
                    lite = false, nubs = true, corner_clearance = 0) {
    assert(cols >= 1, "opengrid_bin: cols must be at least 1");
    assert(height >= OG_PITCH, "opengrid_bin: height must be at least 28 so a snap fits a full cell");
    assert(depth > 2 * wall + 2 * inner_chamfer, "opengrid_bin: depth too small for the walls");

    x0 = clearance / 2;
    x1 = og_span(cols) - clearance / 2;
    y0 = clearance / 2;
    y1 = height - clearance / 2;

    // inner cavity
    ix0 = x0 + wall;
    ix1 = x1 - wall;
    iz0 = wall;
    iz1 = depth - wall;
    iy0 = y0 + floor;

    union() {
        difference() {
            og_chamfered_box(x0, x1, y0, y1, 0, depth, chamfer);

            hull() {
                translate([ix0, iy0 + inner_chamfer, iz0])
                    cube([ix1 - ix0, y1 - iy0, iz1 - iz0]);
                translate([ix0 + inner_chamfer, iy0, iz0 + inner_chamfer])
                    cube([ix1 - ix0 - 2 * inner_chamfer, y1 - iy0 + 1,
                          iz1 - iz0 - 2 * inner_chamfer]);
            }
        }

        // dividers across the width
        if (divisions_x > 1) {
            pitch_x = (ix1 - ix0 + divider) / divisions_x;
            for (k = [1 : divisions_x - 1])
                translate([ix0 + k * pitch_x - divider, iy0 - EPS, iz0 - EPS])
                    cube([divider, y1 - iy0 + EPS, iz1 - iz0 + 2 * EPS]);
        }

        // dividers front to back
        if (divisions_y > 1) {
            pitch_z = (iz1 - iz0 + divider) / divisions_y;
            for (k = [1 : divisions_y - 1])
                translate([ix0 - EPS, iy0 - EPS, iz0 + k * pitch_z - divider])
                    cube([ix1 - ix0 + 2 * EPS, y1 - iy0 + EPS, divider]);
        }

        opengrid_snaps(og_bin_snap_positions(cols, height, snap_spacing,
                                             snap_rows, snap_cols),
                       lite, nubs, corner_clearance);
    }
}
