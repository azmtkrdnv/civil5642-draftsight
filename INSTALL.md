# Installing Civil 5642 for DraftSight

Civil 5642 is a single AutoLISP file: **`Civil5642.lsp`**.

## Quick load

Type at the DraftSight command line, using **forward slashes** in the path:

```
(load "C:/Tools/Civil5642/Civil5642.lsp")
```

The Civil 5642 stamp appears in the command window:

```
+--------------------------------------------+
|  CIVIL 5642  for DraftSight        v1.3.0  |
|  27 commands  -  type C5642 for the list   |
+--------------------------------------------+
```

## Load with the application dialog

Run **APPLOAD** (also *AddApplication*, or Manage → Load Application), browse to
`Civil5642.lsp` and click **Load**.

## Load automatically on startup

Add the `(load ...)` line above to your DraftSight startup LISP (Tools →
Options → System Options → File Locations). The commands are then available in
every drawing.

## Upgrading from 5642CAD

Civil 5642 replaces the earlier `5642CAD.lsp` and `5642CAD-Civil.lsp`. Remove
their `(load ...)` lines and load `Civil5642.lsp` instead. Command names are
unchanged. New objects go on `C5642-*` layers; objects made by older versions
stay on their `5642-*` / `5642C-*` layers.

## Uninstall

Delete `Civil5642.lsp` and remove any startup/APPLOAD reference to it. The
`C5642-*` layers can be deleted from a drawing if you don't want them.

## Other CAD programs

The same file also loads in ZWCAD and AutoCAD with `(load ...)` or APPLOAD.
