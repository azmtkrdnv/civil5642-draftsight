;;; ==========================================================================
;;;  CIVIL 5642 for DraftSight
;;;  Drafting, survey and civil tools for DraftSight - one file, 27 commands.
;;;  Core AutoLISP only (also loads in ZWCAD and AutoCAD).
;;;
;;;  Version : 1.3.0
;;;  Author  : Civil 5642
;;;  License : MIT (see LICENSE)
;;;  Type C5642 in DraftSight for the command list.
;;;
;;;  IMPORTANT: the civil tools are 2D drafting/calculation aids, not a dynamic
;;;  Civil 3D-style model - results do not update when geometry changes.
;;;
;;;  MEASURE     TOTALLEN  TOTALAREA  AREATAG
;;;  TEXT        TXTSUM  TXTMATH  TXTCASE  TXTPRE
;;;  LAYERS      MOVLAY  LAYOFF  LAYON
;;;  BLOCKS      BCOUNT  ATTOUT
;;;  COGO/GRID   BDIST  GRIDGEN
;;;  SURVEY      TRAVERSE  INVERSE  BRGINT  LEGAL
;;;  STATIONING  STALABEL  STAOFF  GRADE  CURVELBL
;;;  CONTOURS    CONTLBL  SPOT  INTERP
;;;  EARTHWORK   SECTAREA  EAVOL
;;;
;;;  Load:  (load "C:/path/to/Civil5642.lsp")   or the APPLOAD dialog.
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;;  Helpers
;;; --------------------------------------------------------------------------

;; Decimal string with exactly PREC decimals. rtos normally follows the
;; drawing's DIMZIN (metric templates strip trailing zeros), so it is set to 0
;; for the call and restored straight away.
(defun c56:rtos (v prec / dz s)
  (setq dz (getvar "DIMZIN"))
  (if dz (setvar "DIMZIN" 0))
  (setq s (rtos v 2 prec))
  (if dz (setvar "DIMZIN" dz))
  s)

;; Trim spaces, tabs, CR, LF from both ends.
(defun c56:trim (s)
  (while (and (> (strlen s) 0) (member (ascii (substr s 1 1)) '(32 9 13 10)))
    (setq s (substr s 2)))
  (while (and (> (strlen s) 0) (member (ascii (substr s (strlen s) 1)) '(32 9 13 10)))
    (setq s (substr s 1 (1- (strlen s)))))
  s)

;; Number from a string (decimal), or nil. Tolerates surrounding spaces.
(defun c56:num (s)
  (if (= (type s) 'STR) (distof (c56:trim s) 2)))

(defun c56:layer (name col)
  (if (not (tblsearch "LAYER" name))
    (entmake (list (cons 0 "LAYER")
                   (cons 100 "AcDbSymbolTableRecord")
                   (cons 100 "AcDbLayerTableRecord")
                   (cons 2 name) (cons 70 0) (cons 62 col) (cons 6 "Continuous"))))
  name)

;; Single-line text in the current text style.
(defun c56:text (pt h str lay / st)
  (setq st (getvar "TEXTSTYLE"))
  (entmake (append (list (cons 0 "TEXT") (cons 8 lay) (cons 10 pt) (cons 40 h) (cons 1 str))
                   (if (and st (tblsearch "STYLE" st)) (list (cons 7 st))))))

(defun c56:line (p1 p2 lay)
  (entmake (list (cons 0 "LINE") (cons 8 lay) (cons 10 p1) (cons 11 p2))))

(defun c56:getreal (msg default / v)
  (setq v (getreal (strcat msg " <" (c56:rtos default 2) ">: ")))
  (if v v default))

;; Default text height = the drawing's TEXTSIZE.
(defun c56:deftxt ( / d)
  (setq d (getvar "TEXTSIZE"))
  (if (and d (> d 0.0)) d 2.5))

(defun c56:th ( ) (c56:getreal "\nText height" (c56:deftxt)))

;; Yes/No prompt; returns T for Yes.
(defun c56:yes (msg default / k)
  (initget "Yes No")
  (setq k (getkword (strcat msg " [Yes/No] <" default ">: ")))
  (= (if k k default) "Yes"))

(defun c56:csv (s / out i ch)
  (if (null s) (setq s ""))
  (setq out "\"" i 1)
  (while (<= i (strlen s))
    (setq ch (substr s i 1)
          out (strcat out (if (= ch "\"") "\"\"" ch))
          i (1+ i)))
  (strcat out "\""))

;; Replace an entity's text string. Returns nil if the change was refused
;; (for example, the object is on a locked layer).
(defun c56:setstr (en newstr / el r)
  (setq el (entget en))
  (if (assoc 1 el)
    (progn
      (setq r (entmod (subst (cons 1 newstr) (assoc 1 el) el)))
      (if r (entupd en))
      r)))

(defun c56:arcang (a b / d)
  (setq d (- b a))
  (while (< d 0.0) (setq d (+ d (* 2.0 pi))))
  (while (>= d (* 2.0 pi)) (setq d (- d (* 2.0 pi))))
  d)

(defun c56:lwverts (el / cur out pr)
  (setq out '() cur nil)
  (foreach pr el
    (cond
      ((= 10 (car pr))
       (if cur (setq out (cons cur out)))
       (setq cur (list (cadr pr) (caddr pr) 0.0)))
      ((= 42 (car pr))
       (if cur (setq cur (list (car cur) (cadr cur) (cdr pr)))))))
  (if cur (setq out (cons cur out)))
  (reverse out))

(defun c56:lwlen (verts closed / n lim i p1 p2 b chord ang r tot)
  (setq n (length verts) tot 0.0 i 0 lim (if closed n (1- n)))
  (while (< i lim)
    (setq p1 (nth i verts) p2 (nth (rem (1+ i) n) verts) b (caddr p1)
          chord (distance (list (car p1) (cadr p1)) (list (car p2) (cadr p2))))
    (if (equal b 0.0 1e-12)
      (setq tot (+ tot chord))
      (progn
        (setq ang (* 4.0 (atan b)) r (/ chord (* 2.0 (sin (/ ang 2.0)))))
        (setq tot (+ tot (abs (* r ang))))))
    (setq i (1+ i)))
  tot)

(defun c56:lwarea (verts / n i p1 p2 b sh seg chord ang r)
  (setq n (length verts) sh 0.0 seg 0.0 i 0)
  (while (< i n)
    (setq p1 (nth i verts) p2 (nth (rem (1+ i) n) verts) b (caddr p1))
    (setq sh (+ sh (- (* (car p1) (cadr p2)) (* (car p2) (cadr p1)))))
    (if (not (equal b 0.0 1e-12))
      (progn
        (setq chord (distance (list (car p1) (cadr p1)) (list (car p2) (cadr p2)))
              ang (* 4.0 (atan b)) r (/ chord (* 2.0 (sin (/ ang 2.0)))))
        (setq seg (+ seg (* 0.5 r r (- ang (sin ang)))))))
    (setq i (1+ i)))
  (abs (+ (/ sh 2.0) seg)))

(defun c56:entlen (en / el ty)
  (setq el (entget en) ty (cdr (assoc 0 el)))
  (cond
    ((= ty "LINE")   (distance (cdr (assoc 10 el)) (cdr (assoc 11 el))))
    ((= ty "CIRCLE") (* 2.0 pi (cdr (assoc 40 el))))
    ((= ty "ARC")    (* (cdr (assoc 40 el))
                        (c56:arcang (cdr (assoc 50 el)) (cdr (assoc 51 el)))))
    ((= ty "LWPOLYLINE")
     (c56:lwlen (c56:lwverts el) (= 1 (logand 1 (cdr (assoc 70 el))))))
    (T 0.0)))

(defun c56:entarea (en / el ty r)
  (setq el (entget en) ty (cdr (assoc 0 el)))
  (cond
    ((= ty "CIRCLE") (setq r (cdr (assoc 40 el))) (* pi r r))
    ((and (= ty "LWPOLYLINE") (= 1 (logand 1 (cdr (assoc 70 el)))))
     (c56:lwarea (c56:lwverts el)))
    (T 0.0)))

(defun c56:azimuth (dx dy / a)
  (setq a (/ (* 180.0 (atan dx dy)) pi))
  (while (< a 0.0)    (setq a (+ a 360.0)))
  (while (>= a 360.0) (setq a (- a 360.0)))
  a)

;; Decimal degrees -> dd m' ss.s" . Rounded once, in whole tenths of a second,
;; using integer maths, so it can never print 60.0" or 60'.
(defun c56:dms (dd / k d m tn)
  (setq k  (fix (+ (* (abs dd) 36000.0) 0.5))
        d  (/ k 36000)
        m  (/ (- k (* d 36000)) 600)
        tn (- k (* d 36000) (* m 600)))
  (strcat (itoa d) "d" (itoa m) "'" (itoa (/ tn 10)) "." (itoa (rem tn 10)) "\""))

(defun c56:bearing (az / ns ew ang)
  (cond
    ((<= az 90.0)  (setq ns "N" ew "E" ang az))
    ((<= az 180.0) (setq ns "S" ew "E" ang (- 180.0 az)))
    ((<= az 270.0) (setq ns "S" ew "W" ang (- az 180.0)))
    (T             (setq ns "N" ew "W" ang (- 360.0 az))))
  (strcat ns " " (c56:dms ang) " " ew))

;; Smallest multiple of sp that is >= mn (tolerant of floating-point noise).
(defun c56:ceilmult (mn sp / k)
  (setq k (fix (/ mn sp)))
  (if (< (* k sp) (- mn (* (abs sp) 1e-9))) (setq k (1+ k)))
  (* k sp))

;; Insert (name . count) into a list kept in alphabetical order.
(defun c56:insort (p lst)
  (cond ((null lst) (list p))
        ((< (strcase (car p)) (strcase (car (car lst)))) (cons p lst))
        (T (cons (car lst) (c56:insort p (cdr lst))))))

(defun c56:laystate (name on / en el col)
  (setq en (tblobjname "LAYER" name))
  (if en
    (progn
      (setq el (entget en) col (abs (cdr (assoc 62 el))))
      (if (null on) (setq col (- col)))
      (entmod (subst (cons 62 col) (assoc 62 el) el)))))


;;; --------------------------------------------------------------------------
;;;  MEASURE
;;; --------------------------------------------------------------------------
(defun c:TOTALLEN ( / ss i n tot)
  (princ "\nSelect lines / polylines / arcs / circles: ")
  (setq ss (ssget '((0 . "LINE,LWPOLYLINE,ARC,CIRCLE"))))
  (if ss
    (progn
      (setq i 0 n (sslength ss) tot 0.0)
      (while (< i n)
        (setq tot (+ tot (c56:entlen (ssname ss i))) i (1+ i)))
      (princ (strcat "\nObjects: " (itoa n) "   Total length = " (c56:rtos tot 4))))
    (princ "\nNothing selected."))
  (princ))

(defun c:TOTALAREA ( / ss i n tot)
  (princ "\nSelect closed polylines / circles: ")
  (setq ss (ssget '((0 . "LWPOLYLINE,CIRCLE"))))
  (if ss
    (progn
      (setq i 0 n (sslength ss) tot 0.0)
      (while (< i n)
        (setq tot (+ tot (c56:entarea (ssname ss i))) i (1+ i)))
      (princ (strcat "\nObjects: " (itoa n) "   Total area = " (c56:rtos tot 3)
                     "   (open polylines count as 0)")))
    (princ "\nNothing selected."))
  (princ))

(defun c:AREATAG ( / th lay ss i n el verts ar pe cx cy vv m cnt)
  (setq th (c56:th) lay (c56:layer "C5642-AREA" 4))
  (princ "\nSelect closed polylines to tag: ")
  (setq ss (ssget '((0 . "LWPOLYLINE"))))
  (if ss
    (progn
      (setq i 0 n (sslength ss) cnt 0)
      (while (< i n)
        (setq el (entget (ssname ss i)) verts (c56:lwverts el))
        (if (and (>= (length verts) 3) (= 1 (logand 1 (cdr (assoc 70 el)))))
          (progn
            (setq ar (c56:lwarea verts) pe (c56:lwlen verts T)
                  m (length verts) cx 0.0 cy 0.0)
            (foreach vv verts (setq cx (+ cx (car vv)) cy (+ cy (cadr vv))))
            (c56:text (list (/ cx m) (/ cy m) 0.0) th
                      (strcat "A=" (c56:rtos ar 2) "  P=" (c56:rtos pe 2)) lay)
            (setq cnt (1+ cnt))))
        (setq i (1+ i)))
      (princ (strcat "\nTagged " (itoa cnt) " closed polyline(s)."
                     (if (< cnt n) (strcat "  " (itoa (- n cnt)) " open polyline(s) skipped.") ""))))
    (princ "\nNothing selected."))
  (princ))


;;; --------------------------------------------------------------------------
;;;  TEXT
;;; --------------------------------------------------------------------------
(defun c:TXTSUM ( / ss i n v tot cnt th lay pt)
  (princ "\nSelect text/mtext to sum: ")
  (setq ss (ssget '((0 . "TEXT,MTEXT"))))
  (if ss
    (progn
      (setq i 0 n (sslength ss) tot 0.0 cnt 0)
      (while (< i n)
        (setq v (c56:num (cdr (assoc 1 (entget (ssname ss i))))))
        (if v (setq tot (+ tot v) cnt (1+ cnt)))
        (setq i (1+ i)))
      (princ (strcat "\nNumeric items: " (itoa cnt) " of " (itoa n)
                     "    SUM = " (c56:rtos tot 4)))
      (if (c56:yes "\nPlace the total as text?" "No")
        (progn
          (setq th (c56:th) lay (c56:layer "C5642-TEXT" 3)
                pt (getpoint "\nPick location for total: "))
          (if pt (c56:text (list (car pt) (cadr pt) 0.0) th (c56:rtos tot 4) lay)))))
    (princ "\nNothing selected."))
  (princ))

(defun c:TXTMATH ( / op val prec ss i n en v nv cnt)
  (initget 1 "Add Subtract Multiply Divide")
  (setq op (getkword "\nOperation [Add/Subtract/Multiply/Divide]: "))
  (initget 1)
  (setq val (getreal "\nValue: "))
  (if (and (= op "Divide") (equal val 0.0 1e-12))
    (princ "\nCannot divide by zero - nothing changed.")
    (progn
      (setq prec (fix (c56:getreal "\nDecimal places" 2.0)))
      (if (< prec 0) (setq prec 0))
      (princ "\nSelect numeric text/mtext to change: ")
      (setq ss (ssget '((0 . "TEXT,MTEXT"))))
      (if ss
        (progn
          (setq i 0 n (sslength ss) cnt 0)
          (while (< i n)
            (setq en (ssname ss i) v (c56:num (cdr (assoc 1 (entget en)))))
            (if v
              (progn
                (setq nv (cond ((= op "Add") (+ v val))
                               ((= op "Subtract") (- v val))
                               ((= op "Multiply") (* v val))
                               (T (/ v val))))
                (if (c56:setstr en (c56:rtos nv prec)) (setq cnt (1+ cnt)))))
            (setq i (1+ i)))
          (princ (strcat "\nUpdated " (itoa cnt) " of " (itoa n) " item(s)."
                         (if (< cnt n) "  Non-numeric or locked items were left alone." ""))))
        (princ "\nNothing selected."))))
  (princ))

(defun c:TXTCASE ( / mode ss i n en v cnt)
  (initget 1 "Upper Lower")
  (setq mode (getkword "\nChange case to [Upper/Lower]: "))
  (princ "\nSelect text/mtext: ")
  (setq ss (ssget '((0 . "TEXT,MTEXT"))))
  (if ss
    (progn
      (setq i 0 n (sslength ss) cnt 0)
      (while (< i n)
        (setq en (ssname ss i) v (cdr (assoc 1 (entget en))))
        (if (and v (c56:setstr en (if (= mode "Upper") (strcase v) (strcase v T))))
          (setq cnt (1+ cnt)))
        (setq i (1+ i)))
      (princ (strcat "\nUpdated " (itoa cnt) " of " (itoa n) " item(s).")))
    (princ "\nNothing selected."))
  (princ))

(defun c:TXTPRE ( / pre suf ss i n en v cnt)
  (setq pre (getstring T "\nPrefix to add (Enter for none): "))
  (setq suf (getstring T "\nSuffix to add (Enter for none): "))
  (if (and (= pre "") (= suf ""))
    (princ "\nNo prefix or suffix given - nothing to do.")
    (progn
      (princ "\nSelect text/mtext: ")
      (setq ss (ssget '((0 . "TEXT,MTEXT"))))
      (if ss
        (progn
          (setq i 0 n (sslength ss) cnt 0)
          (while (< i n)
            (setq en (ssname ss i) v (cdr (assoc 1 (entget en))))
            (if (and v (c56:setstr en (strcat pre v suf))) (setq cnt (1+ cnt)))
            (setq i (1+ i)))
          (princ (strcat "\nUpdated " (itoa cnt) " of " (itoa n) " item(s).")))
        (princ "\nNothing selected."))))
  (princ))


;;; --------------------------------------------------------------------------
;;;  LAYERS
;;; --------------------------------------------------------------------------
(defun c:MOVLAY ( / pick tgt ss i n el moved)
  (setq pick (entsel "\nPick object on the TARGET layer: "))
  (if pick
    (progn
      (setq tgt (cdr (assoc 8 (entget (car pick)))))
      (princ (strcat "\nTarget layer: " tgt))
      (princ "\nSelect objects to move: ")
      (setq ss (ssget))
      (if ss
        (progn
          (setq i 0 n (sslength ss) moved 0)
          (while (< i n)
            (setq el (entget (ssname ss i)))
            (if (entmod (subst (cons 8 tgt) (assoc 8 el) el)) (setq moved (1+ moved)))
            (setq i (1+ i)))
          (princ (strcat "\nMoved " (itoa moved) " object(s) to layer " tgt "."
                         (if (< moved n)
                           (strcat "  " (itoa (- n moved)) " could not be moved (locked layer).")
                           ""))))
        (princ "\nNothing selected."))))
  (princ))

(defun c:LAYOFF ( / ss i n names nm cur cnt kept)
  (princ "\nSelect objects whose layers to turn OFF: ")
  (setq ss (ssget))
  (if ss
    (progn
      (setq i 0 n (sslength ss) names '() cnt 0 kept nil
            cur (strcase (getvar "CLAYER")))
      (while (< i n)
        (setq nm (cdr (assoc 8 (entget (ssname ss i)))))
        (if (not (member nm names)) (setq names (cons nm names)))
        (setq i (1+ i)))
      (foreach nm names
        (if (= (strcase nm) cur)
          (setq kept nm)
          (progn (c56:laystate nm nil) (setq cnt (1+ cnt)))))
      (princ (strcat "\nTurned off " (itoa cnt) " layer(s)."
                     (if kept (strcat "  The current layer \"" kept "\" was left on.") "")))
      (command "._REGEN"))
    (princ "\nNothing selected."))
  (princ))

(defun c:LAYON ( / ld cnt)
  (setq ld (tblnext "LAYER" T) cnt 0)
  (while ld
    (if (< (cdr (assoc 62 ld)) 0)
      (progn (c56:laystate (cdr (assoc 2 ld)) T) (setq cnt (1+ cnt))))
    (setq ld (tblnext "LAYER")))
  (command "._REGEN")
  (princ (strcat "\nTurned on " (itoa cnt) " layer(s)."))
  (princ))


;;; --------------------------------------------------------------------------
;;;  BLOCKS
;;; --------------------------------------------------------------------------
(defun c:BCOUNT ( / ss i n nm lst pair out p)
  (princ "\nSelect blocks (Enter = all): ")
  (setq ss (ssget '((0 . "INSERT"))))
  (if (null ss) (setq ss (ssget "_X" '((0 . "INSERT")))))
  (if ss
    (progn
      (setq i 0 n (sslength ss) lst '())
      (while (< i n)
        (setq nm (cdr (assoc 2 (entget (ssname ss i)))) pair (assoc nm lst))
        (if pair
          (setq lst (subst (cons nm (1+ (cdr pair))) pair lst))
          (setq lst (cons (cons nm 1) lst)))
        (setq i (1+ i)))
      (setq out '())
      (foreach p lst (setq out (c56:insort p out)))
      (princ "\n--- Block counts ---")
      (foreach p out (princ (strcat "\n  " (car p) " : " (itoa (cdr p)))))
      (princ (strcat "\n  TOTAL : " (itoa n) "   (" (itoa (length out)) " block name(s))")))
    (princ "\nNo blocks found."))
  (princ))

(defun c:ATTOUT ( / *error* ss path f i n el nm ip sub sel rows)
  (defun *error* (msg)
    (if f (close f))
    (if (not (member msg '("Function cancelled" "quit / exit abort")))
      (princ (strcat "\nError: " msg)))
    (princ))
  (princ "\nSelect blocks with attributes (Enter = all): ")
  (setq ss (ssget '((0 . "INSERT") (66 . 1))))
  (if (null ss) (setq ss (ssget "_X" '((0 . "INSERT") (66 . 1)))))
  (if (null ss)
    (princ "\nNo attributed blocks found.")
    (progn
      (setq path (getfiled "Save attributes CSV as" "attributes" "csv" 1))
      (if (null path)
        (princ "\nCancelled.")
        (progn
          (setq f (open path "w"))
          (if (null f)
            (princ "\nCould not create the file (is it open in Excel?).")
            (progn
              (write-line "Block,Tag,Value,X,Y" f)
              (setq i 0 n (sslength ss) rows 0)
              (while (< i n)
                (setq el (entget (ssname ss i))
                      nm (cdr (assoc 2 el)) ip (cdr (assoc 10 el))
                      sub (entnext (ssname ss i)))
                (while (and sub (setq sel (entget sub))
                            (= "ATTRIB" (cdr (assoc 0 sel))))
                  (write-line (strcat (c56:csv nm) "," (c56:csv (cdr (assoc 2 sel))) ","
                                      (c56:csv (cdr (assoc 1 sel))) ","
                                      (c56:rtos (car ip) 4) "," (c56:rtos (cadr ip) 4)) f)
                  (setq rows (1+ rows) sub (entnext sub)))
                (setq i (1+ i)))
              (close f) (setq f nil)
              (princ (strcat "\nWrote " (itoa rows) " attribute row(s) from " (itoa n)
                             " block(s) to " path "."))))))))
  (princ))


;;; --------------------------------------------------------------------------
;;;  COGO / GRID
;;; --------------------------------------------------------------------------
(defun c:BDIST ( / p1 p2 dx dy dist az brg th lay)
  (setq p1 (getpoint "\nFirst point (from): "))
  (if p1 (setq p2 (getpoint p1 "\nSecond point (to): ")))
  (if (and p1 p2)
    (progn
      (setq dx (- (car p2) (car p1)) dy (- (cadr p2) (cadr p1))
            dist (distance (list (car p1) (cadr p1)) (list (car p2) (cadr p2)))
            az (c56:azimuth dx dy) brg (c56:bearing az))
      (princ (strcat "\nDistance = " (c56:rtos dist 4)
                     "\nAzimuth  = " (c56:dms az) "  (" (c56:rtos az 4) " deg)"
                     "\nBearing  = " brg))
      (if (c56:yes "\nLabel it on the drawing?" "No")
        (progn
          (setq th (c56:th) lay (c56:layer "C5642-COGO" 6))
          (c56:line p1 p2 lay)
          (c56:text (list (/ (+ (car p1) (car p2)) 2.0) (/ (+ (cadr p1) (cadr p2)) 2.0) 0.0)
                    th (strcat brg "  " (c56:rtos dist 3)) lay))))
    (princ "\nNeed two points."))
  (princ))

(defun c:GRIDGEN ( / p1 p2 sp minx miny maxx maxy lay th dec x0 y0 k x y n est)
  (setq p1 (getpoint "\nFirst corner of grid area: "))
  (if p1 (setq p2 (getcorner p1 "\nOpposite corner: ")))
  (if (and p1 p2)
    (progn
      (setq sp  (c56:getreal "\nGrid spacing" 10.0)
            th  (c56:getreal "\nLabel text height" (c56:deftxt))
            dec (fix (c56:getreal "\nLabel decimals" 2.0))
            minx (min (car p1) (car p2)) maxx (max (car p1) (car p2))
            miny (min (cadr p1) (cadr p2)) maxy (max (cadr p1) (cadr p2)) n 0)
      (if (< dec 0) (setq dec 0))
      (cond
        ((<= sp 0.0) (princ "\nSpacing must be positive."))
        ((and (> (setq est (+ (/ (- maxx minx) sp) (/ (- maxy miny) sp))) 2000.0)
              (not (c56:yes (strcat "\nThat is about " (c56:rtos est 0) " lines. Continue?") "No")))
         (princ "\nCancelled - try a larger spacing."))
        (T
          (setq lay (c56:layer "C5642-GRID" 8)
                x0 (c56:ceilmult minx sp) y0 (c56:ceilmult miny sp))
          ;; step by index (x0 + k*sp) so rounding never drops the last line
          (setq k 0)
          (while (<= (setq x (+ x0 (* k sp))) (+ maxx (* sp 1e-6)))
            (c56:line (list x miny 0.0) (list x maxy 0.0) lay)
            (c56:text (list x (- miny (* 1.5 th)) 0.0) th (c56:rtos x dec) lay)
            (setq k (1+ k) n (1+ n)))
          (setq k 0)
          (while (<= (setq y (+ y0 (* k sp))) (+ maxy (* sp 1e-6)))
            (c56:line (list minx y 0.0) (list maxx y 0.0) lay)
            (c56:text (list (- minx (* 4.0 th)) y 0.0) th (c56:rtos y dec) lay)
            (setq k (1+ k) n (1+ n)))
          (princ (strcat "\nDrew " (itoa n) " grid line(s) at spacing " (c56:rtos sp 2) ".")))))
    (princ "\nNeed two corners."))
  (princ))


;;; --------------------------------------------------------------------------
;;;  Civil helpers
;;; --------------------------------------------------------------------------

(defun c56:point (pt lay)
  (entmake (list (cons 0 "POINT") (cons 8 lay) (cons 10 pt))))

(defun c56:getint (msg default / v)
  (setq v (getint (strcat msg " <" (itoa default) ">: ")))
  (if v v default))

(defun c56:d2r (d) (/ (* d pi) 180.0))

(defun c56:dd (d m s) (+ d (/ m 60.0) (/ s 3600.0)))

(defun c56:az2brg (az / ns ew ang)
  (cond ((<= az 90.0)  (setq ns "N" ew "E" ang az))
        ((<= az 180.0) (setq ns "S" ew "E" ang (- 180.0 az)))
        ((<= az 270.0) (setq ns "S" ew "W" ang (- az 180.0)))
        (T             (setq ns "N" ew "W" ang (- 360.0 az))))
  (strcat ns (c56:dms ang) ew))

(defun c56:brg2az (quad a)
  (cond ((= quad "NE") a)
        ((= quad "SE") (- 180.0 a))
        ((= quad "SW") (+ 180.0 a))
        ((= quad "NW") (- 360.0 a))))

(defun c56:polypts (el / out pr)
  (setq out '())
  (foreach pr el
    (if (= 10 (car pr)) (setq out (cons (list (cadr pr) (caddr pr)) out))))
  (reverse out))

;; pick an LWPOLYLINE; returns its entity list or nil (with a message)
(defun c56:pickpoly (msg / pick el)
  (setq pick (entsel msg))
  (cond ((null pick) (princ "\nNothing selected.") nil)
        ((/= (cdr (assoc 0 (setq el (entget (car pick))))) "LWPOLYLINE")
         (princ "\nThat is not a lightweight polyline.") nil)
        (T el)))

(defun c56:len2d (verts / i tot)
  (setq i 0 tot 0.0)
  (while (< i (1- (length verts)))
    (setq tot (+ tot (distance (nth i verts) (nth (1+ i) verts))) i (1+ i)))
  tot)

;; point + unit direction at distance d along a straight 2D polyline
(defun c56:ptdir (verts d / n i a b seg res acc tt)
  (setq n (length verts) i 0 acc 0.0 res nil)
  (while (and (null res) (< i (1- n)))
    (setq a (nth i verts) b (nth (1+ i) verts) seg (distance a b))
    (if (and (> seg 1e-12) (<= d (+ acc seg 1e-9)))
      (progn
        (setq tt (/ (- d acc) seg))
        (if (< tt 0.0) (setq tt 0.0))
        (if (> tt 1.0) (setq tt 1.0))
        (setq res (list (list (+ (car a) (* tt (- (car b) (car a))))
                              (+ (cadr a) (* tt (- (cadr b) (cadr a)))) 0.0)
                        (/ (- (car b) (car a)) seg)
                        (/ (- (cadr b) (cadr a)) seg))))
      (setq acc (+ acc seg)))
    (setq i (1+ i)))
  (if res res
    (progn
      (setq a (nth (- n 2) verts) b (nth (1- n) verts) seg (distance a b))
      (list (list (car b) (cadr b) 0.0)
            (/ (- (car b) (car a)) seg) (/ (- (cadr b) (cadr a)) seg)))))

;; station & signed offset (+left) of point p from a straight 2D polyline
(defun c56:staoff (verts p / n i a b abx aby L2 tt fx fy dist seg sta
                     cross side acc best bsta boff)
  (setq n (length verts) i 0 acc 0.0 best nil bsta 0.0 boff 0.0)
  (while (< i (1- n))
    (setq a (nth i verts) b (nth (1+ i) verts)
          abx (- (car b) (car a)) aby (- (cadr b) (cadr a))
          L2 (+ (* abx abx) (* aby aby)))
    (setq tt (if (equal L2 0.0 1e-12) 0.0
               (/ (+ (* (- (car p) (car a)) abx) (* (- (cadr p) (cadr a)) aby)) L2)))
    (if (< tt 0.0) (setq tt 0.0))
    (if (> tt 1.0) (setq tt 1.0))
    (setq fx (+ (car a) (* tt abx)) fy (+ (cadr a) (* tt aby))
          dist (distance (list (car p) (cadr p)) (list fx fy)) seg (sqrt L2)
          sta (+ acc (* tt seg))
          cross (- (* abx (- (cadr p) (cadr a))) (* aby (- (car p) (car a))))
          side (if (> cross 0.0) 1.0 -1.0))
    (if (or (null best) (< dist best))
      (setq best dist bsta sta boff (* dist side)))
    (setq acc (+ acc seg) i (1+ i)))
  (list bsta boff))

;; left-pad an integer with zeros to width w
(defun c56:pad (n w / s)
  (setq s (itoa n))
  (while (< (strlen s) w) (setq s (strcat "0" s)))
  s)

;; Station string. "Feet" 1+05.00 / "Metric" 1+005.00 / "Raw" 105.00.
;; Rounded once to hundredths in integer maths, so 199.996 -> 2+00.00 and
;; negative stations read -0+50.00.
(defun c56:stafmt (v mode / base k h rr)
  (cond ((= mode "Metric") (setq base 1000))
        ((= mode "Raw")    (setq base nil))
        (T                 (setq base 100)))
  (if (null base)
    (c56:rtos v 2)
    (progn
      (setq k  (fix (+ (* (abs v) 100.0) 0.5))
            h  (/ k (* base 100))
            rr (- k (* h base 100)))
      (strcat (if (and (< v 0.0) (> k 0)) "-" "")
              (itoa h) "+" (c56:pad (/ rr 100) (if (= base 100) 2 3))
              "." (c56:pad (rem rr 100) 2)))))

(defun c56:stamode ( / m)
  (initget "Feet Metric Raw")
  (setq m (getkword "\nStation format [Feet/Metric/Raw] <Feet>: "))
  (if m m "Feet"))

(defun c56:split (str delim / lst cur i n ch)
  (setq lst '() cur "" i 1 n (strlen str))
  (while (<= i n)
    (setq ch (substr str i 1))
    (if (= ch delim) (setq lst (cons cur lst) cur "")
      (setq cur (strcat cur ch)))
    (setq i (1+ i)))
  (reverse (cons cur lst)))

;; bulge-aware signed area of a vertex loop
(defun c56:signed-area (verts / n i p1 p2 b sh seg chord ang r)
  (setq n (length verts) sh 0.0 seg 0.0 i 0)
  (while (< i n)
    (setq p1 (nth i verts) p2 (nth (rem (1+ i) n) verts) b (caddr p1))
    (setq sh (+ sh (- (* (car p1) (cadr p2)) (* (car p2) (cadr p1)))))
    (if (not (equal b 0.0 1e-12))
      (progn
        (setq chord (distance (list (car p1) (cadr p1)) (list (car p2) (cadr p2)))
              ang (* 4.0 (atan b)) r (/ chord (* 2.0 (sin (/ ang 2.0)))))
        (setq seg (+ seg (* 0.5 r r (- ang (sin ang)))))))
    (setq i (1+ i)))
  (+ (/ sh 2.0) seg))

;; --- section helpers (x = offset, y = elevation) ---
(defun c56:ascx (pts)
  (if (> (car (car pts)) (car (nth (1- (length pts)) pts))) (reverse pts) pts))

(defun c56:monox (pts / ok i)
  (setq ok T i 0)
  (while (and ok (< i (1- (length pts))))
    (if (< (car (nth (1+ i) pts)) (- (car (nth i pts)) 1e-9)) (setq ok nil))
    (setq i (1+ i)))
  ok)

;; elevation of an x-ascending section at offset x (linear), nil if outside
(defun c56:yat (pts x / i n a b res)
  (setq i 0 n (length pts) res nil)
  (while (and (null res) (< i (1- n)))
    (setq a (nth i pts) b (nth (1+ i) pts))
    (if (and (<= (car a) (+ x 1e-9)) (>= (car b) (- x 1e-9)))
      (setq res (if (equal (car a) (car b) 1e-12)
                  (cadr a)
                  (+ (cadr a) (* (- x (car a)) (/ (- (cadr b) (cadr a)) (- (car b) (car a))))))))
    (setq i (1+ i)))
  res)

;; insert x into an ascending list of distinct numbers
(defun c56:insnum (x lst)
  (cond ((null lst) (list x))
        ((equal x (car lst) 1e-9) lst)
        ((< x (car lst)) (cons x lst))
        (T (cons (car lst) (c56:insnum x (cdr lst))))))

;; insert a row (station ...) into a list sorted by station (iterative)
(defun c56:insrow (r lst / head done)
  (setq head nil done nil)
  (while (and lst (not done))
    (if (< (car r) (car (car lst)))
      (setq done T)
      (setq head (cons (car lst) head) lst (cdr lst))))
  (append (reverse head) (cons r lst)))

;; one station tick + label
(defun c56:stamark (verts d st0 mode tick th lay / pd pt px py)
  (setq pd (c56:ptdir verts d) pt (car pd)
        px (- (caddr pd)) py (cadr pd))
  (c56:line (list (- (car pt) (* px tick)) (- (cadr pt) (* py tick)) 0.0)
             (list (+ (car pt) (* px tick)) (+ (cadr pt) (* py tick)) 0.0) lay)
  (c56:text (list (+ (car pt) (* px tick 1.3)) (+ (cadr pt) (* py tick 1.3)) 0.0)
             th (c56:stafmt (+ st0 d) mode) lay))

;; standard error handler that closes an open file held in variable F
(defun c56:errclose (msg)
  (if f (close f))
  (if (not (member msg '("Function cancelled" "quit / exit abort")))
    (princ (strcat "\nError: " msg)))
  (princ))


;;; --------------------------------------------------------------------------
;;;  SURVEY / COGO
;;; --------------------------------------------------------------------------
(defun c:TRAVERSE ( / lay p0 p quad dg mn sc dist a az azr np legs tot dx dy mis)
  (setq lay (c56:layer "C5642-TRAV" 3))
  (setq p0 (getpoint "\nStart point: "))
  (if (null p0)
    (princ "\nNo start point.")
    (progn
      (setq p p0 legs 0 tot 0.0)
      (while
        (progn
          (initget "NE SE SW NW Close Finish")
          (setq quad (getkword "\nLeg quadrant [NE/SE/SW/NW/Close/Finish] <Finish>: "))
          (and quad (/= quad "Finish") (/= quad "Close")))
        (setq dg (c56:getint  "  degrees (0-90)" 0)
              mn (c56:getint  "  minutes (0-59)" 0)
              sc (c56:getreal "  seconds (0-59.9)" 0.0)
              a  (c56:dd dg mn sc))
        (if (or (< dg 0) (< mn 0) (> mn 59) (< sc 0.0) (>= sc 60.0) (> a 90.0))
          (princ "\n  Invalid bearing (degrees 0-90, minutes 0-59, seconds under 60) - leg skipped.")
          (progn
            (setq dist (getdist p "  distance: "))
            (if (and dist (> dist 0.0))
              (progn
                (setq az (c56:brg2az quad a) azr (c56:d2r az)
                      np (list (+ (car p) (* dist (sin azr))) (+ (cadr p) (* dist (cos azr))) 0.0))
                (c56:line p np lay)
                (setq p np legs (1+ legs) tot (+ tot dist))
                (princ (strcat "   -> at " (c56:rtos (car np) 3) ", " (c56:rtos (cadr np) 3))))
              (princ "\n  Distance must be positive - leg skipped.")))))
      (setq dx (- (car p0) (car p)) dy (- (cadr p0) (cadr p))
            mis (sqrt (+ (* dx dx) (* dy dy))))
      (princ (strcat "\nTraverse: " (itoa legs) " leg(s), length " (c56:rtos tot 3)
                     ".  End at " (c56:rtos (car p) 3) ", " (c56:rtos (cadr p) 3)))
      (if (>= legs 2)
        (princ (strcat "\nMisclosure back to start: " (c56:rtos mis 4)
                       "  (dE " (c56:rtos dx 4) ", dN " (c56:rtos dy 4) ")"
                       (cond ((<= mis 1e-9) "  - closes exactly")
                             ((> (/ tot mis) 1e9) "  precision better than 1:1000000000")
                             (T (strcat "  precision 1:" (itoa (fix (/ tot mis)))))))))
      (if (and (= quad "Close") (> legs 0) (> mis 1e-9))
        (progn
          (c56:line p (list (car p0) (cadr p0) 0.0) lay)
          (princ (strcat "\nClosing leg drawn: " (c56:az2brg (c56:azimuth dx dy))
                         ", " (c56:rtos mis 3)))))))
  (princ))

(defun c:INVERSE ( / p0 p1 dx dy az dist total n)
  (setq p0 (getpoint "\nFirst point: ") total 0.0 n 0)
  (if (null p0)
    (princ "\nNo point.")
    (progn
      (princ "\nPick next points (Enter to finish):")
      (while (setq p1 (getpoint p0 "\nNext point: "))
        (setq dx (- (car p1) (car p0)) dy (- (cadr p1) (cadr p0))
              az (c56:azimuth dx dy)
              dist (distance (list (car p0) (cadr p0)) (list (car p1) (cadr p1)))
              total (+ total dist) n (1+ n))
        (princ (strcat "\n  Leg " (itoa n) ":  " (c56:az2brg az)
                       "   dist " (c56:rtos dist 3)))
        (setq p0 p1))
      (princ (strcat "\n  Total distance: " (c56:rtos total 3)
                     "   (" (itoa n) " leg(s))"))))
  (princ))

(defun c:BRGINT ( / lay p1 az1 p2 az2 d1x d1y d2x d2y den bx by tt uu ix iy)
  (setq lay (c56:layer "C5642-COGO" 4))
  (setq p1 (getpoint "\nPoint 1: "))
  (if p1 (setq az1 (getreal "\nAzimuth from point 1 (decimal degrees, N=0 clockwise): ")))
  (if (and p1 az1) (setq p2 (getpoint "\nPoint 2: ")))
  (if p2 (setq az2 (getreal "\nAzimuth from point 2 (decimal degrees, N=0 clockwise): ")))
  (if (and p1 az1 p2 az2)
    (progn
      (setq d1x (sin (c56:d2r az1)) d1y (cos (c56:d2r az1))
            d2x (sin (c56:d2r az2)) d2y (cos (c56:d2r az2))
            den (- (* d1x (- d2y)) (* (- d2x) d1y)))
      (if (equal den 0.0 1e-12)
        (princ "\nBearings are parallel - no intersection.")
        (progn
          (setq bx (- (car p2) (car p1)) by (- (cadr p2) (cadr p1))
                tt (/ (- (* bx (- d2y)) (* (- d2x) by)) den)
                uu (/ (- (* d1x by) (* d1y bx)) den)
                ix (+ (car p1) (* tt d1x)) iy (+ (cadr p1) (* tt d1y)))
          (c56:point (list ix iy 0.0) lay)
          (princ (strcat "\nIntersection: " (c56:rtos ix 4) ", " (c56:rtos iy 4)))
          (if (or (< tt 0.0) (< uu 0.0))
            (princ "\n  Note: the point lies BEHIND one of the start points (check the bearings).")))))
    (princ "\nNeed two points and two azimuths."))
  (princ))

(defun c:LEGAL ( / *error* el verts closed n i lim p1 p2 b path f ln dx dy dist ang r
                   arclen delta dir)
  (setq *error* c56:errclose)
  (setq el (c56:pickpoly "\nSelect the boundary polyline: "))
  (if el
    (progn
      (setq verts (c56:lwverts el)
            closed (= 1 (logand 1 (cdr (assoc 70 el))))
            n (length verts) lim (if closed n (1- n)))
      (setq path (getfiled "Save legal description as" "legal" "txt" 1))
      (if (null path)
        (princ "\nCancelled.")
        (progn
          (setq f (open path "w"))
          (if (null f)
            (princ "\nCould not create the file.")
            (progn
              (setq ln (strcat "LEGAL DESCRIPTION  (" (itoa lim) " courses"
                               (if closed (strcat ", area " (c56:rtos (abs (c56:signed-area verts)) 2)) "")
                               ")"))
              (princ (strcat "\n" ln)) (write-line ln f)
              (setq ln (strcat "Beginning at a point having coordinates N "
                               (c56:rtos (cadr (car verts)) 3) ", E "
                               (c56:rtos (car (car verts)) 3) ";"))
              (princ (strcat "\n" ln)) (write-line ln f)
              (setq i 0)
              (while (< i lim)
                (setq p1 (nth i verts) p2 (nth (rem (1+ i) n) verts) b (caddr p1)
                      dx (- (car p2) (car p1)) dy (- (cadr p2) (cadr p1))
                      dist (distance (list (car p1) (cadr p1)) (list (car p2) (cadr p2))))
                (if (equal b 0.0 1e-9)
                  (setq ln (strcat "  Course " (itoa (1+ i)) ": thence "
                                   (c56:az2brg (c56:azimuth dx dy)) ", " (c56:rtos dist 2)))
                  (progn
                    (setq ang (* 4.0 (atan b)) r (/ dist (* 2.0 (sin (/ ang 2.0))))
                          arclen (abs (* r ang)) delta (abs (/ (* ang 180.0) pi))
                          dir (if (> b 0.0) "left" "right"))
                    (setq ln (strcat "  Course " (itoa (1+ i))
                                     ": thence along a curve to the " dir
                                     ", radius " (c56:rtos (abs r) 2)
                                     ", arc length " (c56:rtos arclen 2)
                                     ", delta " (c56:dms delta)
                                     ", chord " (c56:az2brg (c56:azimuth dx dy))
                                     " " (c56:rtos dist 2)))))
                (setq ln (strcat ln (if (and closed (= i (1- lim)))
                                      " to the point of beginning."
                                      " to a point;")))
                (princ (strcat "\n" ln)) (write-line ln f)
                (setq i (1+ i)))
              (if (not closed)
                (progn (setq ln "(Note: the polyline is open - the description does not close.)")
                       (princ (strcat "\n" ln)) (write-line ln f)))
              (close f) (setq f nil)
              (princ (strcat "\nSaved to " path))))))))
  (princ))


;;; --------------------------------------------------------------------------
;;;  STATIONING / ANNOTATION
;;; --------------------------------------------------------------------------
(defun c:STALABEL ( / el verts total iv th st0 mode lay tick k d cnt go)
  (setq el (c56:pickpoly "\nSelect alignment polyline: "))
  (if el
    (progn
      (setq verts (c56:polypts el) total (c56:len2d verts))
      (setq iv  (c56:getreal "\nStation interval" 100.0)
            th  (c56:th)
            st0 (c56:getreal "\nStart station" 0.0)
            mode (c56:stamode))
      (cond
        ((<= iv 0.0) (princ "\nInterval must be positive."))
        ((and (> (/ total iv) 2000.0)
              (not (c56:yes (strcat "\nThat is " (itoa (fix (/ total iv))) " stations. Continue?") "No")))
         (princ "\nCancelled - try a larger interval."))
        (T
          (setq lay (c56:layer "C5642-STA" 5) tick (* 2.0 th) k 0 cnt 0)
          ;; step by index so floating-point rounding never drops a station
          (while (<= (setq d (* k iv)) (+ total (* iv 1e-6)))
            (c56:stamark verts (if (> d total) total d) st0 mode tick th lay)
            (setq k (1+ k) cnt (1+ cnt)))
          ;; label the end of the alignment if it isn't on an interval
          (if (> (- total (* (1- k) iv)) (* iv 1e-6))
            (progn (c56:stamark verts total st0 mode tick th lay) (setq cnt (1+ cnt))))
          (princ (strcat "\nPlaced " (itoa cnt) " station label(s) along "
                         (c56:rtos total 2) " of alignment ("
                         (c56:stafmt st0 mode) " to " (c56:stafmt (+ st0 total) mode) ")."))))))
  (princ))

(defun c:STAOFF ( / el verts th mode lay p so off s)
  (setq el (c56:pickpoly "\nSelect alignment polyline: "))
  (if el
    (progn
      (setq verts (c56:polypts el)
            th (c56:th) mode (c56:stamode)
            lay (c56:layer "C5642-STA" 5))
      (princ "\nPick points to report (Enter to finish):")
      (while (setq p (getpoint "\nPoint: "))
        (setq so (c56:staoff verts p) off (cadr so)
              s (strcat "STA " (c56:stafmt (car so) mode)
                        "  OFF " (c56:rtos (abs off) 2) (if (>= off 0.0) "L" "R")))
        (c56:text (list (+ (car p) th) (cadr p) 0.0) th s lay)
        (princ (strcat "\n  " s)))))
  (princ))

(defun c:GRADE ( / th lay p1 e1 p2 e2 horiz dz slope ratio s)
  (setq th (c56:th) lay (c56:layer "C5642-GRADE" 6))
  (setq p1 (getpoint "\nFirst point: "))
  (if p1 (setq e1 (getreal "\nElevation at first point: ")))
  (if (and p1 e1) (setq p2 (getpoint p1 "\nSecond point: ")))
  (if p2 (setq e2 (getreal "\nElevation at second point: ")))
  (if (and p1 e1 p2 e2)
    (progn
      (setq horiz (distance (list (car p1) (cadr p1)) (list (car p2) (cadr p2)))
            dz (- e2 e1))
      (if (equal horiz 0.0 1e-9)
        (princ "\nThe points are on top of each other in plan.")
        (progn
          (setq slope (* (/ dz horiz) 100.0)
                ratio (if (equal dz 0.0 1e-9) 0.0 (/ horiz (abs dz)))
                s (strcat "G=" (c56:rtos slope 2) "%"
                          (if (> ratio 0.0) (strcat "  (" (c56:rtos ratio 1) ":1)") "")))
          (c56:line p1 p2 lay)
          (c56:text (list (/ (+ (car p1) (car p2)) 2.0) (/ (+ (cadr p1) (cadr p2)) 2.0) 0.0)
                     th s lay)
          (princ (strcat "\n  " s "   rise " (c56:rtos dz 3) " over " (c56:rtos horiz 3))))))
    (princ "\nNeed two points and two elevations."))
  (princ))

(defun c:CURVELBL ( / ss i n el lay th cen r a0 a1 delta arclen chord sp ep mida s)
  (princ "\nSelect arcs to label: ")
  (setq ss (ssget '((0 . "ARC"))))
  (if (null ss)
    (princ "\nNo arcs selected.")
    (progn
      (setq th (c56:th) lay (c56:layer "C5642-CURVE" 4) i 0 n (sslength ss))
      (while (< i n)
        (setq el (entget (ssname ss i))
              cen (cdr (assoc 10 el)) r (cdr (assoc 40 el))
              a0 (cdr (assoc 50 el)) a1 (cdr (assoc 51 el))
              delta (- a1 a0))
        (while (<= delta 0.0) (setq delta (+ delta (* 2.0 pi))))
        (setq arclen (* r delta)
              chord (* 2.0 r (sin (/ delta 2.0)))
              sp (list (+ (car cen) (* r (cos a0))) (+ (cadr cen) (* r (sin a0))))
              ep (list (+ (car cen) (* r (cos a1))) (+ (cadr cen) (* r (sin a1))))
              mida (+ a0 (/ delta 2.0))
              s (strcat "R=" (c56:rtos r 2) "  L=" (c56:rtos arclen 2)
                        "  D=" (c56:dms (/ (* delta 180.0) pi))))
        (c56:text (list (+ (car cen) (* r (cos mida))) (+ (cadr cen) (* r (sin mida))) 0.0)
                   th s lay)
        (princ (strcat "\n  " s "  chord " (c56:rtos chord 2) " "
                       (c56:az2brg (c56:azimuth (- (car ep) (car sp)) (- (cadr ep) (cadr sp))))))
        (setq i (1+ i)))
      (princ (strcat "\nLabelled " (itoa n) " curve(s)."))))
  (princ))


;;; --------------------------------------------------------------------------
;;;  CONTOURS / SPOT ELEVATIONS
;;; --------------------------------------------------------------------------
(defun c:CONTLBL ( / th lay pick en el ev pt)
  (setq th (c56:th) lay (c56:layer "C5642-CONT" 3))
  (princ "\nSelect contour polylines (Enter to finish):")
  (while (setq pick (entsel "\nSelect contour: "))
    (setq en (car pick) el (entget en))
    (if (= (cdr (assoc 0 el)) "LWPOLYLINE")
      (progn
        (setq ev (getreal "\n  Elevation for this contour: "))
        (if ev
          (progn
            (if (assoc 38 el)
              (setq el (subst (cons 38 ev) (assoc 38 el) el))
              (setq el (append el (list (cons 38 ev)))))
            (if (entmod el)
              (entupd en)
              (princ "\n  (could not store the elevation - locked layer?)"))
            (setq pt (getpoint "\n  Pick label location: "))
            (if pt (c56:text (list (car pt) (cadr pt) 0.0) th (c56:rtos ev 2) lay)))))
      (princ "\n  Not a lightweight polyline - skipped.")))
  (princ))

(defun c:SPOT ( / th lay p ev)
  (setq th (c56:th) lay (c56:layer "C5642-SPOT" 2))
  (princ "\nPick points for spot elevations (Enter to finish):")
  (while (setq p (getpoint "\nPoint: "))
    (setq ev (getreal (strcat "\n  Elevation <" (c56:rtos (caddr p) 2) ">: ")))
    (if (null ev) (setq ev (caddr p)))
    (c56:point (list (car p) (cadr p) 0.0) lay)
    (c56:text (list (+ (car p) (* 0.4 th)) (cadr p) 0.0) th (c56:rtos ev 2) lay))
  (princ))

(defun c:INTERP ( / th lay p1 e1 p2 e2 p3 abx aby L2 tt ev)
  (setq th (c56:th) lay (c56:layer "C5642-SPOT" 2))
  (setq p1 (getpoint "\nFirst known point: "))
  (if p1 (setq e1 (getreal "\n  Elevation at first point: ")))
  (if (and p1 e1) (setq p2 (getpoint p1 "\nSecond known point: ")))
  (if p2 (setq e2 (getreal "\n  Elevation at second point: ")))
  (if (and p1 e1 p2 e2)
    (progn
      (setq abx (- (car p2) (car p1)) aby (- (cadr p2) (cadr p1))
            L2 (+ (* abx abx) (* aby aby)))
      (if (equal L2 0.0 1e-12)
        (princ "\nThe two points are coincident.")
        (progn
          (princ "\nPick points to interpolate (Enter to finish):")
          (while (setq p3 (getpoint "\n  Point: "))
            (setq tt (/ (+ (* (- (car p3) (car p1)) abx) (* (- (cadr p3) (cadr p1)) aby)) L2)
                  ev (+ e1 (* tt (- e2 e1))))
            (c56:point (list (car p3) (cadr p3) 0.0) lay)
            (c56:text (list (+ (car p3) (* 0.4 th)) (cadr p3) 0.0) th (c56:rtos ev 2) lay)
            (princ (strcat "\n    elev = " (c56:rtos ev 3)
                           (if (or (< tt 0.0) (> tt 1.0)) "   (outside the two points - extrapolated)" "")))))))
    (princ "\nNeed two points and two elevations."))
  (princ))


;;; --------------------------------------------------------------------------
;;;  EARTHWORK
;;; --------------------------------------------------------------------------
;;; SECTAREA: exact cut and fill between a ground line and a design line in a
;;; cross-section (x = offset, y = elevation). Lines may be drawn in either
;;; direction and may cross; each must run one way in x (no fold-backs).
(defun c:SECTAREA ( / lay th g d gv dv x0 x1 xs p i xa xb w fa fb xz cut fill xm)
  (setq lay (c56:layer "C5642-SECT" 1) th (c56:th))
  (setq g (c56:pickpoly "\nSelect GROUND (existing) section line: "))
  (if g (setq d (c56:pickpoly "\nSelect DESIGN (proposed) section line: ")))
  (if (and g d)
    (progn
      (setq gv (c56:ascx (c56:polypts g)) dv (c56:ascx (c56:polypts d))
            x0 (max (car (car gv)) (car (car dv)))
            x1 (min (car (nth (1- (length gv)) gv)) (car (nth (1- (length dv)) dv))))
      (cond
        ((not (and (c56:monox gv) (c56:monox dv)))
         (princ "\nEach section line must run steadily left-to-right (no fold-backs)."))
        ((>= x0 x1)
         (princ "\nThe two section lines do not overlap in offset."))
        (T
          ;; breakpoints = every vertex offset inside the overlap, plus its ends
          (setq xs (c56:insnum x1 (list x0)))
          (foreach p (append gv dv)
            (if (and (> (car p) x0) (< (car p) x1)) (setq xs (c56:insnum (car p) xs))))
          (setq cut 0.0 fill 0.0 i 0)
          (while (< i (1- (length xs)))
            (setq xa (nth i xs) xb (nth (1+ i) xs) w (- xb xa)
                  fa (- (c56:yat dv xa) (c56:yat gv xa))
                  fb (- (c56:yat dv xb) (c56:yat gv xb)))
            (if (>= (* fa fb) 0.0)
              (if (>= (+ fa fb) 0.0)
                (setq fill (+ fill (* 0.5 (+ fa fb) w)))
                (setq cut  (- cut  (* 0.5 (+ fa fb) w))))
              (progn                                   ; lines cross inside this strip
                (setq xz (* w (/ fa (- fa fb))))
                (if (> fa 0.0)
                  (setq fill (+ fill (* 0.5 fa xz))  cut (- cut (* 0.5 fb (- w xz))))
                  (setq cut  (- cut (* 0.5 fa xz))   fill (+ fill (* 0.5 fb (- w xz)))))))
            (setq i (1+ i)))
          (setq xm (/ (+ x0 x1) 2.0))
          (c56:text (list xm (+ (c56:yat gv xm) th) 0.0) th
                     (strcat "CUT=" (c56:rtos cut 2) "  FILL=" (c56:rtos fill 2)) lay)
          (princ (strcat "\nCut area  = " (c56:rtos cut 3)
                         "\nFill area = " (c56:rtos fill 3)
                         "\nNet (fill - cut) = " (c56:rtos (- fill cut) 3)
                         "\n(over offsets " (c56:rtos x0 2) " to " (c56:rtos x1 2) ")"))))))
  (princ))

;;; EAVOL: CSV rows of  station,area   or   station,cut,fill
;;; Header rows / blank lines are skipped; rows may be in any order.
(defun c:EAVOL ( / *error* path f ln flds s a b rows mode sorted prev v1 v2 r0 r1 len units k)
  (setq *error* c56:errclose)
  (setq path (getfiled "Select sections CSV (station,area or station,cut,fill)" "" "csv" 8))
  (if (null path)
    (princ "\nCancelled.")
    (progn
      (setq f (open path "r") rows '() mode 3)
      (if (null f)
        (princ "\nCould not open the file.")
        (progn
          (while (setq ln (read-line f))
            (setq flds (c56:split ln ",")
                  s (c56:num (nth 0 flds))
                  a (if (nth 1 flds) (c56:num (nth 1 flds)))
                  b (if (nth 2 flds) (c56:num (nth 2 flds))))
            (if (and s a)
              (progn
                (if (null b) (setq mode 2))
                (setq rows (cons (list s a (if b b 0.0)) rows)))))
          (close f) (setq f nil)
          (setq rows (reverse rows))
          (if (< (length rows) 2)
            (princ "\nNeed at least two station rows with numbers.")
            (progn
              ;; sort by station only if needed
              (setq sorted T prev nil)
              (foreach r0 rows
                (if (and prev (< (car r0) (car prev))) (setq sorted nil))
                (setq prev r0))
              (if (not sorted)
                (progn
                  (setq k rows rows '())
                  (foreach r0 k (setq rows (c56:insrow r0 rows)))
                  (princ "\n(Stations were out of order - sorted before calculating.)")))
              (initget "Units CY")
              (setq units (getkword "\nReport volume in [Units/CY (cubic yards from feet)] <Units>: "))
              (if (null units) (setq units "Units"))
              (setq v1 0.0 v2 0.0 r0 (car rows))
              (foreach r1 (cdr rows)
                (setq len (- (car r1) (car r0))
                      v1 (+ v1 (* (/ (+ (cadr r0) (cadr r1)) 2.0) len))
                      v2 (+ v2 (* (/ (+ (caddr r0) (caddr r1)) 2.0) len))
                      r0 r1))
              (if (= units "CY") (setq v1 (/ v1 27.0) v2 (/ v2 27.0)))
              (princ (strcat "\nStations: " (itoa (length rows)) "  from "
                             (c56:rtos (car (car rows)) 2) " to "
                             (c56:rtos (car (nth (1- (length rows)) rows)) 2)))
              (if (= mode 3)
                (princ (strcat "\nCut volume  = " (c56:rtos v1 3) (if (= units "CY") " CY" "")
                               "\nFill volume = " (c56:rtos v2 3) (if (= units "CY") " CY" "")
                               "\nNet (fill - cut) = " (c56:rtos (- v2 v1) 3)))
                (princ (strcat "\nTotal volume (average-end-area) = " (c56:rtos v1 3)
                               (if (= units "CY") " CY" ""))))))))))
  (princ))


;;; --------------------------------------------------------------------------
;;;  STAMP / HELP
;;; --------------------------------------------------------------------------
;; The Civil 5642 stamp shown in the command window on load and in C5642.
(defun c56:stamp ( )
  (princ "\n+--------------------------------------------+")
  (princ "\n|  CIVIL 5642  for DraftSight        v1.3.0  |")
  (princ "\n|  27 commands  -  type C5642 for the list   |")
  (princ "\n+--------------------------------------------+")
  (princ))

(defun c:C5642 ( )
  (c56:stamp)
  (princ "\n  Measure    : TOTALLEN  TOTALAREA  AREATAG")
  (princ "\n  Text       : TXTSUM  TXTMATH  TXTCASE  TXTPRE")
  (princ "\n  Layers     : MOVLAY  LAYOFF  LAYON")
  (princ "\n  Blocks     : BCOUNT  ATTOUT")
  (princ "\n  COGO/Grid  : BDIST  GRIDGEN")
  (princ "\n  Survey     : TRAVERSE  INVERSE  BRGINT  LEGAL")
  (princ "\n  Stationing : STALABEL  STAOFF  GRADE  CURVELBL")
  (princ "\n  Contours   : CONTLBL  SPOT  INTERP")
  (princ "\n  Earthwork  : SECTAREA  EAVOL")
  (princ "\n  Civil tools are 2D drafting aids, not a dynamic Civil 3D model.")
  (princ "\n  MIT licensed.  Type any command name to run it.")
  (princ))

;; CIVIL also opens the command list (the name used in earlier versions)
(defun c:CIVIL ( ) (c:C5642))

(c56:stamp)
(princ)
