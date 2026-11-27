# Civil 5642 for DraftSight — User Manual

Version 1.3.0 · MIT licensed

Type `C5642` in DraftSight at any time to see the Civil 5642 stamp and the full
command list.

**Good to know for every command**

- Everything Civil 5642 draws goes on its own `C5642-*` layer, so it's easy to
  isolate, freeze or delete.
- Labels use your **current text style**, and the text-height prompt defaults
  to your drawing's current text size — just press Enter to accept it.
- Numbers always show the decimals you asked for, even in metric templates that
  normally strip trailing zeros.

**Contents:** Part 1 — Drafting tools · Part 2 — Survey & civil tools

---

# Part 1 — Drafting tools

## Measure

### TOTALLEN — total length
Select lines, polylines, arcs and circles; prints the combined length. Polyline
arc segments are measured exactly; circles count their circumference.

### TOTALAREA — total area
Select closed polylines and/or circles; prints the combined area (arc segments
included). Open polylines count as zero.

### AREATAG — tag each area
Enter a text height, select closed polylines. Writes `A=… P=…` (area /
perimeter) at the centre of each one on layer `C5642-AREA`. Open polylines are
skipped and counted in the summary.

---

## Text

### TXTSUM — sum numeric text
Select text/mtext; prints how many items were numeric and their SUM, then offers
to place the total as a new text. Numbers with stray spaces around them are
counted; non-numeric text is ignored.

### TXTMATH — arithmetic on text
Choose Add / Subtract / Multiply / Divide, enter the value and decimal places,
then select numeric text. Each item is recalculated in place. Dividing by zero
is refused up front, and items on locked layers are reported as not updated.

### TXTCASE — change case
Choose Upper or Lower, select text/mtext.

### TXTPRE — prefix / suffix
Enter a prefix and/or suffix (spaces allowed; Enter to skip either), then select
text. If you skip both, the command simply exits.

---

## Layers

### MOVLAY — move to a layer
Pick an object on the target layer, then select objects to move. Objects on
locked layers can't be moved; the summary tells you how many were skipped.

### LAYOFF — turn layers off
Select objects; the layers they sit on are turned off. Your **current layer is
always left on** (turning it off would hide everything you draw next) — the
summary says when that happened.

### LAYON — turn layers on
Turns every layer that is off back on, and tells you how many.

---

## Blocks

### BCOUNT — count blocks
Select block inserts (or press Enter for all); prints an **alphabetical** tally
by block name and the total. Dynamic blocks that have been edited may appear
under an anonymous name such as `*U12`.

### ATTOUT — export attributes
Select attributed blocks (or Enter for all), choose a CSV filename. Output:
`Block, Tag, Value, X, Y` — one row per attribute; commas and quotes inside
values are escaped. If the file can't be created (for example it's open in
Excel), you'll be told.

---

## COGO / Grid

### BDIST — bearing & distance
Pick two points; prints the plan distance, azimuth (decimal and D°M'S") and
quadrant bearing (e.g. `N 45d0'0.0" E`). Optionally draws the line and a label
on layer `C5642-COGO`.

### GRIDGEN — coordinate grid
Pick two corners, then the spacing, label height and decimals. Draws a labelled
grid on layer `C5642-GRID`. If the spacing would produce more than about 2,000
lines, it asks before drawing.

---

## Limits

- `TXTMATH`, `TXTCASE`, `TXTPRE` work on TEXT and MTEXT; MTEXT with rich inline
  formatting may not transform perfectly.
- Area commands work on lightweight polylines and circles (not old-style heavy
  2D polylines, ellipses or splines).

---

# Part 2 — Survey & civil tools

## What this is — and is not

Civil 5642 is a **2D civil/survey drafting and calculation toolkit**. It
speeds up traverses, stationing, contour labelling and earthwork takeoffs.

It is **not** a replacement for Autodesk Civil 3D. Civil 3D is built on dynamic
objects (alignments, surfaces, corridors, pipe networks) that recompute when you
edit them. DraftSight's AutoLISP API can't create those, so this
toolkit produces **static** output: accurate when you run a command, but it does
not update when the geometry changes.

All objects go on `C5642-*` layers. Text height defaults to your current text
size; labels use your current text style.

**Bearings** are shown as `N45d30'0.0"E` (degrees `d`, minutes `'`, seconds `"`).
**Azimuths** are decimal degrees measured clockwise from North (N = 0, E = 90).

---

## Survey / COGO

### TRAVERSE — traverse by bearing & distance
1. Pick a start point.
2. For each leg: type a quadrant (`NE`, `SE`, `SW`, `NW`), then degrees,
   minutes, seconds and a distance. Each line is drawn as you go.
3. Type **Finish** to stop, or **Close** to also draw the closing leg back to
   the start.

When you finish, it reports the total length, the **misclosure** back to the
start (with dE / dN) and the **precision ratio** (e.g. `1:3999`). Invalid
input (more than 90°, minutes over 59, seconds of 60 or more, a zero or negative
distance) is rejected and that leg is skipped — nothing wrong is drawn.

### INVERSE — inverse between points
Pick points in sequence; each leg's bearing and distance is reported, plus the
running total. Enter to finish.

### BRGINT — bearing–bearing intersection
Pick point 1 and an azimuth, then point 2 and an azimuth. Places a point where
the two bearings meet. If the intersection lies **behind** either start point
(usually a sign that a bearing was entered the wrong way round) you're warned.

### LEGAL — metes-and-bounds description
Select the boundary polyline and choose where to save the text file. The
description starts with *"Beginning at a point having coordinates N…, E…"*,
lists each course (bearing and distance, or radius / arc / delta / chord for
curves), and the last course of a closed boundary ends *"to the point of
beginning."* The area is included for closed boundaries; an open polyline is
described with a note that it does not close.

---

## Stationing / annotation

### STALABEL — station labels along an alignment
Select an alignment polyline, then the interval, text height, start station and
format:

| Format | Example |
|---|---|
| Feet | `1+05.00` |
| Metric | `1+005.00` |
| Raw | `105.00` |

Ticks and labels are placed at every interval **and at the end of the
alignment**. If the interval would create more than 2,000 labels you're asked
first. *(Arcs in the alignment are treated as straight chords.)*

### STAOFF — station & offset of a point
Select the alignment, text height and station format, then pick points. Each is
labelled and reported as e.g. `STA 0+50.00  OFF 10.00L` (L = left, R = right of
the direction the alignment was drawn).

### GRADE — slope label
Enter a text height, pick two points and their elevations. Labels the grade as
a percentage and an H:V ratio (e.g. `G=2.00%  (50.0:1)`) and draws the line.

### CURVELBL — label arcs
Select arcs; each is labelled `R=… L=… D=…` (radius, arc length, delta), and the
chord length and chord bearing are reported.

---

## Contours / spot elevations

### CONTLBL — contour elevation
Select a contour polyline, type its elevation, pick where the label goes. The
elevation is also stored on the polyline itself. Repeats until Enter.

### SPOT — spot elevation
Pick points; type an elevation or press Enter to use the point's Z. Drops a node
and a label. Repeats until Enter.

### INTERP — interpolate elevation
Pick two known points and their elevations, then pick points to interpolate.
Points beyond the two known points are flagged as **extrapolated**.

---

## Earthwork

### SECTAREA — cut & fill area of a cross-section
Select the **ground** (existing) line, then the **design** (proposed) line. You
get **cut**, **fill** and **net** area, plus a `CUT=… FILL=…` label.

- Lines can be drawn in either direction and may cross each other — crossings
  are found and the area is split exactly into cut and fill.
- Draw sections with **x = offset, y = elevation**. Each line must run steadily
  left-to-right (no folding back on itself).
- Only the offset range where both lines exist is measured.

### EAVOL — earthwork volume (average-end-area)
Select a CSV file in either form (a header row is fine):

```
Station,Area            Station,Cut,Fill
0,12.5                  0,10.0,0.0
50,18.0                 50,14.0,2.5
```

Stations can be in any order (they're sorted for you). Choose **Units** (same
units as the CSV) or **CY** to convert cubic feet to cubic yards (÷27). With two
columns you get a total volume; with three you get cut, fill and net.

Try it on the files in the `examples` folder — the answers are
`sections_area.csv` → **3327.500**, and `sections_cut_fill.csv` → cut
**1250.000**, fill **825.000**.

---

## How this was checked

Every command was run end-to-end against a test harness that emulates
AutoLISP, with known-answer cases: traverse closure, bearing intersections,
station formatting (including boundaries such as 199.996 → `2+00.00` and
negative stations), station/offset, crossing cut/fill sections, unsorted and
cut/fill CSVs, extrapolation, and Esc/cancel at every file dialog (no file is
left open).
