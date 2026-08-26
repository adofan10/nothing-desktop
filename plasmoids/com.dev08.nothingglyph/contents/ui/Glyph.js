.pragma library

// The character, as dot patterns on a 16x16 grid.
//
// Everything is a small pattern plus an origin rather than sixteen full-width
// rows, so a pose is assembled from parts: head, torso, eyes, mouth, arms, props.
// That is what lets five states share one character instead of being five
// drawings that drift apart.
//
// Two things learned by rendering it rather than reasoning about it:
//
//   - An OUTLINED head reads as a face at this size. A filled blob with the eyes
//     punched out of it reads as three vertical bars.
//   - The head and the torso need a blank row between them. Joined by a neck they
//     merge into one mass and the whole thing stops reading as a figure.

var W = 16, H = 16;

var HEAD = [[
    "...######...",
    ".##......##.",
    "#..........#",
    "#..........#",
    "#..........#",
    "#..........#",
    ".##......##.",
    "...######..."], 2, 1];

var TORSO = [["######",
              "######",
              "######",
              "##..##"], 5, 10];        // row 13 is the legs

var ARMS_DOWN = [["#......#",
                  "#......#"], 4, 10];
var ARMS_UP   = [["#......#",
                  "#......#"], 4,  9];

var EYES_OPEN  = [[".##..##."], 4, 3];
var EYES_BLINK = [["#.....#"],  5, 4];
var EYES_HAPPY = [[".#.##.#."], 4, 3];
var EYES_SAD   = [[".##..##."], 4, 4];   // sat a row lower: looking down

var MOUTH_SMILE = [["#....#",
                    ".####."], 5, 5];
var MOUTH_LINE  = [["####"], 6, 6];
var MOUTH_OPEN  = [[".##.",
                    "####",
                    ".##."], 6, 5];

var HP_BAND  = [["..########..",
                 ".#........#."], 2, 0];
var HP_CUP_L = [["##", "##", "##"], 0,  3];
var HP_CUP_R = [["##", "##", "##"], 14, 3];
var NOTE     = [[".#", ".#", "##"], 14, 0];

// Beside the head, not punched into the chest: the torso is only six dots wide,
// and taking four of them out reads as damage rather than as a charge mark.
var BOLT = [[".#", "##", "#.", "##", ".#"], 14, 3];

var ZED_BIG   = [["###", "..#", "###"], 13, 0];
var ZED_SMALL = [["##", ".#"], 10, 0];

function stamp(lit, spec, dx, dy, on) {
    var pat = spec[0], ox = spec[1] + (dx || 0), oy = spec[2] + (dy || 0);
    for (var y = 0; y < pat.length; ++y) {
        var row = pat[y];
        for (var x = 0; x < row.length; ++x) {
            if (row.charAt(x) !== "#") continue;
            var gx = ox + x, gy = oy + y;
            if (gx < 0 || gx >= W || gy < 0 || gy >= H) continue;
            lit[gy * W + gx] = (on !== false);
        }
    }
}

// Returns a flat array of 256 booleans for the given state and frame counter.
function build(state, t) {
    var lit = new Array(W * H);
    for (var i = 0; i < lit.length; ++i) lit[i] = false;

    var bob   = (state === "music" && (t % 2)) ? 1 : 0;
    var droop = (state === "low" || state === "sleep") ? 1 : 0;
    var dy    = bob + droop;

    stamp(lit, HEAD,  0, dy);
    stamp(lit, TORSO, 0, droop);

    var arms = (state === "music") ? ((t % 2) ? ARMS_UP : ARMS_DOWN)
             : (state === "charge") ? ARMS_UP
             : ARMS_DOWN;
    stamp(lit, arms, 0, droop);

    var eyes = state === "music"  ? EYES_HAPPY
             : state === "charge" ? EYES_HAPPY
             : state === "low"    ? EYES_SAD
             : state === "sleep"  ? EYES_BLINK
             : (t % 8 === 3)      ? EYES_BLINK      // idle blinks now and then
             : EYES_OPEN;

    var mouth = state === "music"  ? MOUTH_OPEN
              : state === "charge" ? MOUTH_SMILE
              : state === "low"    ? MOUTH_LINE
              : state === "sleep"  ? MOUTH_LINE
              : MOUTH_SMILE;

    stamp(lit, eyes,  0, dy);
    stamp(lit, mouth, 0, dy);

    if (state === "music") {
        stamp(lit, HP_BAND,  0, dy);
        stamp(lit, HP_CUP_L, 0, dy);
        stamp(lit, HP_CUP_R, 0, dy);
        stamp(lit, NOTE, 0, (t % 2) ? 1 : 0);
    } else if (state === "charge") {
        // Static on purpose. Drifting it a row per frame meant the dot fade never
        // settled and the bolt read as scattered grey specks rather than a shape.
        stamp(lit, BOLT);
    } else if (state === "sleep") {
        stamp(lit, ZED_BIG);
        if (t % 2) stamp(lit, ZED_SMALL);
    }

    return lit;
}
