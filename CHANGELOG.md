# Changelog — Civil 5642 for DraftSight

All notable changes are documented here. This project follows
[Semantic Versioning](https://semver.org/). Versions before 1.3.0 were released
as **5642CAD**.

## [1.3.0] - 2026-11-27

### Changed
- **Renamed to Civil 5642 for DraftSight.**
- **One file:** `5642CAD.lsp` and `5642CAD-Civil.lsp` are merged into
  `Civil5642.lsp` (27 commands). Shared helper code is now defined once.
- Layers created by the tools are now named `C5642-*` (previously `5642-*` and
  `5642C-*`).
- Help command is now **`C5642`** (`CIVIL` still works).
- Documentation merged into a single MANUAL.md.

### Added
- **Civil 5642 stamp** — a compact boxed banner in the command window when the
  file loads and at the top of `C5642`.

### Verified
- Full regression on the merged file: 73 end-to-end checks (the 67 from 1.2.0
  plus stamp, help list, alias and layer-name checks), all passing; bulge
  reference shapes unchanged.

## [1.2.0] - 2026-11-27

Quality release. Every command was run end-to-end in an AutoLISP test harness
(67 checks); the bugs below were found that way and fixed.

### Fixed — wrong results
- **SECTAREA** returned 0 when the design line was drawn in the opposite
  direction to the ground line.
- **EAVOL** returned a negative volume when stations in the CSV were out of
  order.
- **Bearings/angles** could print `59'60.0"` instead of rolling over to the next
  minute/degree (BDIST, TRAVERSE, INVERSE, LEGAL, CURVELBL).
- **Station labels** at interval boundaries could print `1+100.00` instead of
  `2+00.00`; negative stations printed as `0+0-50.00`.
- **GRIDGEN** and **STALABEL** could silently drop the last line/station with
  decimal spacings (e.g. 0.1) due to floating-point accumulation.
- In drawings that suppress trailing zeros (DIMZIN 8, common in metric
  templates) labels and CSV values lost their decimals (`10` instead of
  `10.00`). Numbers now always show the requested decimals; DIMZIN is restored.

### Fixed — misleading behaviour
- **MOVLAY** reported objects on locked layers as moved; it now counts them.
- **LAYOFF** could turn off the current layer; it now leaves it on and says so.
- **TXTMATH** reported success when dividing by zero; it now refuses up front.
  Locked text is reported as not updated.
- **TRAVERSE** accepted quadrant angles over 90°, 60 seconds, and zero/negative
  distances; these are now rejected with a message.
- **GRADE** sized its label at 2% of the line length; it now asks for a text
  height.
- **TXTSUM/TXTMATH** ignored numbers with leading/trailing spaces.
- Files are always closed if you press Esc during ATTOUT, LEGAL or EAVOL.

### Improved
- **SECTAREA** now reports **cut, fill and net** separately, exactly, even
  when the lines cross.
- **EAVOL** accepts `station,cut,fill` files, sorts stations automatically, and
  can report in cubic yards (CY).
- **TRAVERSE** reports misclosure and precision ratio, and has a **Close**
  option that draws the closing leg.
- **LEGAL** now starts at the point of beginning (with coordinates) and ends
  "to the point of beginning"; open boundaries are noted.
- **STALABEL** labels the end of the alignment; **STAOFF** offers Feet /
  Metric / Raw formats.
- **BRGINT** warns when the intersection lies behind a start point; **INTERP**
  flags extrapolated values.
- **BCOUNT** lists blocks alphabetically; **AREATAG** reports skipped open
  polylines; **GRIDGEN/STALABEL** ask before creating thousands of objects.
- Labels use the current text style; text height defaults to the drawing's
  current text size.
- `examples/` folder with sample section CSVs and their known answers.

## [1.1.0] - 2026-11-27

### Added
- **5642CAD Civil** module (`5642CAD-Civil.lsp`), 13 commands: TRAVERSE,
  INVERSE, BRGINT, LEGAL, STALABEL, STAOFF, GRADE, CURVELBL, CONTLBL, SPOT,
  INTERP, SECTAREA, EAVOL. Type `CIVIL` for the list.
- Civil manual and QUICKSTART guide.

## [1.0.0] - 2026-08-25

### Added
- Initial release of the core pack: TOTALLEN, TOTALAREA, AREATAG, TXTSUM,
  TXTMATH, TXTCASE, TXTPRE, MOVLAY, LAYOFF, LAYON, BCOUNT, ATTOUT, BDIST,
  GRIDGEN, CAD5642. MIT license, manual, install guide.
