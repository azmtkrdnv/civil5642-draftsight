# Civil 5642 for DraftSight

**Drafting, survey and civil tools for DraftSight — one file, 27 commands.**

Version 1.3.0 · Pure AutoLISP · MIT licensed

```
+--------------------------------------------+
|  CIVIL 5642  for DraftSight        v1.3.0  |
|  27 commands  -  type C5642 for the list   |
+--------------------------------------------+
```

Civil 5642 adds everyday drafting tools and a 2D survey/civil toolkit to
DraftSight in a single `.lsp` file — no installer, no dependencies. Load it and
the stamp above appears in the command window; type `C5642` any time for the
command list.

> **New here? Start with [QUICKSTART.md](QUICKSTART.md)** — running in about
> five minutes.

---

## Features

| Group | Commands |
|---|---|
| Measure | `TOTALLEN` · `TOTALAREA` · `AREATAG` |
| Text | `TXTSUM` · `TXTMATH` · `TXTCASE` · `TXTPRE` |
| Layers | `MOVLAY` · `LAYOFF` · `LAYON` |
| Blocks | `BCOUNT` · `ATTOUT` |
| COGO / Grid | `BDIST` · `GRIDGEN` |
| Survey | `TRAVERSE` · `INVERSE` · `BRGINT` · `LEGAL` |
| Stationing | `STALABEL` · `STAOFF` · `GRADE` · `CURVELBL` |
| Contours / spot | `CONTLBL` · `SPOT` · `INTERP` |
| Earthwork | `SECTAREA` · `EAVOL` |

Highlights: bulge-aware polyline lengths and areas · exact cut/fill split for
cross-sections, even where lines cross · average-end-area volumes from CSV
(area or cut/fill, any station order, optional cubic yards) · traverse
misclosure and precision · metes-and-bounds descriptions · quote-safe CSV export.

## Install

Type at the DraftSight command line:

```
(load "C:/Tools/Civil5642/Civil5642.lsp")
```

…or load `Civil5642.lsp` through the **APPLOAD** dialog. Details in
[INSTALL.md](INSTALL.md).

## Documentation

- [QUICKSTART.md](QUICKSTART.md) — 5-minute get-started guide
- [MANUAL.md](MANUAL.md) — every command (Part 1 drafting, Part 2 survey & civil)
- `examples/` — sample section CSVs with known answers

## Quality

Every command is run end-to-end in an AutoLISP test harness with known-answer
cases (73 checks), plus static checks for undefined functions, wrong argument
counts and leaked variables. See [CHANGELOG.md](CHANGELOG.md).

## A note on Civil 3D

Civil 5642 is a **2D drafting and calculation toolkit**, not a dynamic model,
and **does not replace Autodesk Civil 3D**. DraftSight's API can't create the
self-updating alignment/surface/corridor objects Civil 3D is built on, so
results are static. See the manual for details.

## Compatibility

Built for **DraftSight** (editions with LISP support). Because it uses only core
AutoLISP, the same file also loads in ZWCAD 2017+ and AutoCAD.

## License

[MIT](LICENSE) © 2026 Civil 5642.

## Contents

```
Civil5642.lsp            the plugin (all 27 commands)
README.md                this file
QUICKSTART.md            5-minute get-started guide
INSTALL.md               install / load guide
MANUAL.md                full command reference
CHANGELOG.md             version history
LICENSE                  MIT license
examples/
  sections_area.csv      Station,Area     -> EAVOL total 3327.500
  sections_cut_fill.csv  Station,Cut,Fill -> cut 1250.000, fill 825.000
```
