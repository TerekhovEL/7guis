Red [author: "Gregg Irwin"]

; This version keeps history as complete a drawing state.
; How the FP folks would do it.

draw-blk: copy []	; Current state
history:  copy []	; History of all states

DEF_RADIUS: 25
MIN_RADIUS: 10.0
MAX_RADIUS: 200.0
DEF_FCOLOR: white	; Default fill color
SEL_FCOLOR: gray	; Selected circle fill color

selected-circle: none
circle-selected?: does [not none? selected-circle]

distance: func [a [pair!] b [pair!]][
	square-root add ((a/x - b/x) ** 2) ((a/y - b/y) ** 2)
]

in-circle?: func [c [block!] "Circle draw cmd block" pos [pair!]][
	c/:C_RADIUS >= distance pos c/:C_CENTER
]

; Because of undo/redo, clear any possible selection. If we wanted
; to remember selections, we could do that as well, but we don't
; for this small example.
clear-selection: does [
	foreach cmd draw-blk [set-circle-color cmd DEF_FCOLOR]
	selected-circle: none
]
select-circle: func [pos [pair!] "mouse position"][
	cmds: reverse copy draw-blk						; Check in reverse, for z-order; don't deep copy
	clear-selection
	foreach cmd cmds [
		if in-circle? cmd pos [
			set-circle-color cmd SEL_FCOLOR			; Mods cmd in draw-blk
			return selected-circle: cmd				; Set new selection
		]
	]
]

update-viz: does [
	viz-draw/text: mold new-line/all draw-blk on
	viz-redo/text: mold new-line/all history on
	viz-cmds/text: mold new-line/all head history on
]
update-history: func [state][
	; Move back to point of insertion, so we're at the 
	; current state we just added. That means when we
	; clear the future history (undone ops), we need to
	; use `next` so we don't clear the current state.
	history: back insert/only clear next history copy/deep state
]
add-circle: func [c] [
	append/only draw-blk c						; Add to our current state
	update-history draw-blk						; Remember it, so we can undo
	select-circle c/:C_CENTER					; Auto-select new circles
	update-viz
]
change-circle: does [
	update-history draw-blk						; Remember it, so we can undo
	update-viz
]

; Field offsets in a circle command
C_FCOLOR: 4		; Fill color
C_CENTER: 6		
C_RADIUS: 7
new-circle: func [center [pair!]] [
	compose [pen black fill-pen (DEF_FCOLOR) circle (center) (DEF_RADIUS)]
]

set-circle-color: func [c [block!] color][poke c C_FCOLOR color]
set-circle-size: func [c [block!] radius][poke c C_RADIUS to integer! radius]


mouse-up: func [event][
	add-circle new-circle event/offset
]
mouse-alt-up: func [event][
	select-circle event/offset
	redraw
	if circle-selected? [show-dialog]
]

redraw: does [canvas/draw: draw-blk]

undo: does [
	if head? history [exit]
	history: back history
	draw-blk: copy/deep first history
	clear-selection
	redraw
	update-viz
]

redo: does [
	if tail? history [exit]
	if not tail? next history [history: next history]			; don't move past last cmd
	if not tail? history [draw-blk: copy/deep first history]
	clear-selection
	redraw
	update-viz
]

adjust-diameter: func [circ "(modified)" sld-data][
	set-circle-size circ max MIN_RADIUS MAX_RADIUS * sld-data
	redraw
]

show-dialog: function [][
	str: form reduce ["Adjust diameter of circle at" selected-circle/:C_CENTER]
	val: selected-circle/:C_RADIUS / MAX_RADIUS
	view/flags [
		below  text str  s: slider data val [adjust-diameter selected-circle face/data]
	][modal popup]
	change-circle
]

;-------------------------------------------------------------------------------

update-history []		; [] is the initial empty drawing state

view [
	backdrop water
	across
	button "Undo" [undo]
	button "Redo" [redo]
	button "Quit" [unview]
	pad 450x0
	style text: text bold bottom 300 water white
	text "DRAW"
	text "REDO"
	text "CMD HIST"
	return
	canvas: base snow 640x480 all-over draw draw-blk
		on-up     [mouse-up event]
		on-alt-up [mouse-alt-up event]
	viz-draw: area 300x480
	viz-redo: area 300x480
	viz-cmds: area 300x480
	do [
		update-viz
	]
]
