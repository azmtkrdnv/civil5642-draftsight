# Civil 5642 for DraftSight — Quick Start

New here? This gets you working in about five minutes. Every command is
explained in [MANUAL.md](MANUAL.md).

---

## 1. Put the file somewhere you'll keep it

Unzip the download to a folder such as `C:\Tools\Civil5642\`. The file that
matters is **`Civil5642.lsp`** — it holds all 27 commands.

## 2. Load it into DraftSight

**Quick way** — click in the command line (the box at the bottom showing
`Command:`), type this and press Enter (note the **forward slashes**):

```
(load "C:/Tools/Civil5642/Civil5642.lsp")
```

**Menu way** — run **APPLOAD** (type `APPLOAD`, Enter), browse to
`Civil5642.lsp` and click **Load**.

When it loads you'll see the Civil 5642 stamp:

```
+--------------------------------------------+
|  CIVIL 5642  for DraftSight        v1.3.0  |
|  27 commands  -  type C5642 for the list   |
+--------------------------------------------+
```

## 3. See the commands

Type **`C5642`** and press Enter. You get the stamp again plus every command,
grouped by job (Measure, Text, Layers, Blocks, COGO, Survey, Stationing,
Contours, Earthwork).

## 4. Run a command

Type the command name, press Enter, and follow the prompts. Three examples:

**Add up lengths** — type `TOTALLEN`, select some lines/polylines, press Enter.
The combined length prints in the command window.

**Draw a traverse** — type `TRAVERSE`, click a start point, then for each leg
type a quadrant (`NE`, Enter), degrees / minutes / seconds and a distance. Type
`Finish` (or `Close` to draw the closing leg). You'll see the misclosure and
precision.

**Export block attributes** — type `ATTOUT`, press Enter to take all attributed
blocks, choose where to save. You get a clean CSV.

Everything Civil 5642 draws goes on its own `C5642-*` layer, so you can isolate,
freeze or delete it easily.

**Check it's working** — type `EAVOL`, pick `examples/sections_area.csv`, and
press Enter at the units prompt. You should see
`Total volume (average-end-area) = 3327.500`.

---

## 5. (Optional) Load it automatically every time

Add the `(load ...)` line from step 2 to your DraftSight startup LISP:

> Tools → Options → System Options → File Locations → (startup/LISP location)

The stamp then appears and the commands are ready in every drawing.

---

## Common questions

**"Unknown command" when I type a command name.**
The file isn't loaded in this session — repeat step 2 (or set up step 5).

**Nothing happens / it can't find the file.**
Check the path in the `(load ...)` line matches where you unzipped, and use
forward slashes `/`.

**I used 5642CAD before.**
Civil 5642 replaces both 5642CAD files — see "Upgrading" in
[INSTALL.md](INSTALL.md). Command names haven't changed.
