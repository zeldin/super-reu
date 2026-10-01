
	.macpack cbm
	.include "screen.inc"

	.export fileselector

	.import index_file
	
	.import fatfs_mount, fatfs_open_rootdir, fatfs_next_dirent
	.import fatfs_open_subdir, fatfs_rewind_dir
	.import cluster_to_block, follow_fat
	.import direntry, cluster

	.import screen, clear_screen, setrow, nextrow, printtext, printhex
	.importzp vscrn
	
	.import initmmc64, selectmmc64, deselectmmc64, checkcardmmc64
	.import blockread1, blockreadn, blockreadmulticmd, stopcmd
	.importzp mmcptr, blknum


files_per_page = 16

	;; What the keys can ask for, and the timing of it, in frames.
ACT_NONE	= 0
ACT_RETURN	= 1
ACT_BACK	= 2
ACT_UP		= 3
ACT_DOWN	= 4
ACT_LEFT	= 5
ACT_RIGHT	= 6
DEBOUNCE	= 2		; held this long before it counts: 40 ms
REPEAT		= 25		; a move held this long starts repeating
RATE		= 4		; ...and repeats this often

	.bss

file_flags:	.res	files_per_page
cluster0:	.res	files_per_page
cluster1:	.res	files_per_page
cluster2:	.res	files_per_page
cluster3:	.res	files_per_page
blocks_high:	.res	files_per_page
blocks_mid:	.res	files_per_page
blocks_low:	.res	files_per_page
size_low:	.res	files_per_page
size_high:	.res	files_per_page
	; upper 16 bits of file size not needed, as it can be
	; computed from the number of blocks if needed
	
filename:	.res	27

entry_num:	.res	1
entry_cnt:	.res	1
	;; The keyboard, as the selection loop sees it: what the keys held now
	;; ask for, how many frames that has been so, and whether a press
	;; counts. See readaction and the loop after selection.
lastact:	.res	1
steady:		.res	1
armed:		.res	1
acted:		.res	1
krow0:		.res	1
krow1:		.res	1
krow2:		.res	1
krow6:		.res	1
krow7:		.res	1
kshift:		.res	1
skip_cnt:	.res	2
tmp_skip_cnt:	.res	2
longfile_status:.res	1

	
	.code

errormsg:
	jsr printtext
	scrcode "Error!@"
	lda #4
	jsr setrow
	jsr printtext
	scrcode "Please remove SDCARD@"
@waitremove:
	jsr checkcardmmc64
	beq @waitremove
	bne fileselector
carderror:
	cmp #8
	bne errormsg
	jsr printtext
	scrcode "No card inserted@"
	lda #4
	jsr setrow
	jsr printtext
	scrcode "Please insert an SDCARD@"
@waitinsert:
	jsr checkcardmmc64
	bne @waitinsert
	ldx #50
	ldy #0
@insertion_delay:
	dey
	bne @insertion_delay
	dex
	bne @insertion_delay

fileselector:
	jsr clear_screen
	;; Nothing counts until every key has been seen up. Whatever
	;; chose this: a key in the menu, or RETURN on the last movie,
	;; may still be down.
	lda #$ff
	sta lastact
	lda #0
	sta armed
	sta steady
	jsr setrow
	jsr printtext
	scrcode "Checking SDCARD...@"
	jsr initmmc64
	ldy #18
	bcs carderror
	cmp #2
	beq @sd2
	cmp #3
	bcs @sdhc
	jsr printtext
	scrcode "SD1@"
	beq @card_found
@sd2:
	jsr printtext
	scrcode "SD2@"
	beq @card_found
@sdhc:
	jsr printtext
	scrcode "SDHC@"
@card_found:

	jsr nextrow
	jsr printtext
	scrcode "Checking for FAT filesystem...@"

	jsr selectmmc64

	jsr fatfs_mount
	ldy #30
	bcc @mount_ok
	jmp errormsg
@mount_ok:
	cmp #0
	bne @fat32
	jsr printtext
	scrcode "FAT16@"
	beq @fat16
@fat32:
	jsr printtext
	scrcode "FAT32@"
@fat16:

	lda #23
	jsr setrow
	jsr printtext
	scrcode "Navigate with "
	key "CRSR"
	scrcode ", select with "
	key "RETURN"
	scrcode "@"

	jsr fatfs_open_rootdir
next_dir:
	lda #0
	sta skip_cnt
	sta skip_cnt+1
next_page:
	lda #' '
	sta screen+(3*40)+0
	sta screen+(3*40)+29
	clc
	lda skip_cnt
	adc #1
	sta tmp_skip_cnt
	lda skip_cnt+1
	adc #0
	sta tmp_skip_cnt+1
	lda #0
	sta entry_num
	jsr fatfs_rewind_dir
	lda #0
	sta longfile_status
	lda #4
	jsr setrow
	jsr drawline
	jsr nextrow
@skip_entry:
	sec
	lda tmp_skip_cnt
	sbc #1
	sta tmp_skip_cnt
	bcs @next_entry
	dec tmp_skip_cnt+1
@next_entry:
	jsr fatfs_next_dirent
	ldy #0
	bcs @to_enddir
	lda direntry
	bne @not_enddir
@to_enddir:
	jmp @enddir
@not_enddir:
	cmp #$e5
	beq @next_entry
	lda direntry+11
	and #$3f
	cmp #$0f
	bne @not_longfile
	jsr longfilename
	jmp @next_entry
@not_longfile:
	jsr shortfilename
	lda tmp_skip_cnt
	ora tmp_skip_cnt+1
	bne @skip_entry
	lda entry_num
	cmp #files_per_page
	bcc @space_available
	jmp @moredir
@space_available:
	jsr clearline
	ldx #0
@displayname:
	lda filename,y
	cpy #26
	beq @lastchar
	jsr ascii2screen
	sta (vscrn),y
	iny
	bne @displayname
@lastchar:
	sta (vscrn),y
	iny
	lda #$18
	bit direntry+11
	bne @nosize
	iny
	lda direntry+31
	jsr printhex
	lda direntry+30
	jsr printhex
	lda direntry+29
	jsr printhex
	lda direntry+28
	jsr printhex
@nosize:
	ldx entry_num
	lda direntry+26
	sta cluster0,x
	lda direntry+27
	sta cluster1,x
	lda direntry+20
	sta cluster2,x
	lda direntry+21
	sta cluster3,x
	lda direntry+31
	lsr
	sta blocks_high,x
	lda direntry+30
	ror
	sta blocks_mid,x
	lda direntry+29
	sta size_high,x
	ror
	sta blocks_low,x
	lda direntry+28
	sta size_low,x
	bcs @residue
	beq @noresidue
@residue:
	inc blocks_low,x
	bne @noresidue
	inc blocks_mid,x
	bne @noresidue
	inc blocks_high,x
@noresidue:
	lda direntry+11
	sta file_flags,x
	jsr colorize
	jsr nextrow
	inx
	stx entry_num
	jmp @next_entry
@moredir:
	lda #'>'
	sta screen+(3*40)+29
@enddir:
	lda skip_cnt
	ora skip_cnt+1
	beq @firstpage
	lda #'<'
	sta screen+(3*40)+0
@firstpage:
	ldx entry_num
	stx entry_cnt
@clear:
	cpx #files_per_page
	beq @noclear
	jsr clearline
	jsr nextrow
	inx
	bne @clear
@noclear:
	lda #5+files_per_page
	jsr setrow
	jsr drawline
	lda entry_cnt
	bne selection
	lda #4+(files_per_page/2)
	jsr setrow
	ldy #10
	jsr printtext
	scrcode "No files@"
@nofiles:
	jsr checkcardmmc64
	beq @nofiles
cardremoved:	
	jmp fileselector

selection:
	lda #0
	sta entry_num
@donekey:
	jsr invert_line
@nokey:
	jsr checkcardmmc64
	bne cardremoved
	;; Once a frame, so that it behaves the same whatever the CPU speed,
	;; and so that a frame is the unit everything below is counted in.
	jsr nextframe
	jsr readaction
	cmp lastact
	beq @steady
	sta lastact
	lda #0
	sta steady
	jmp @nokey
@steady:
	;; The same for another frame. It counts once it has held for
	;; DEBOUNCE frames, which is what takes the chatter out of a press and
	;; a release; held to REPEAT, a move up or down repeats every RATE.
	inc steady
	bne @counted
	dec steady			; and stays at 255 rather than wrapping
@counted:
	lda steady
	cmp #DEBOUNCE
	beq @settled
	cmp #REPEAT
	bne @nokey
	lda lastact			; only the move that was made when it
	cmp acted			; settled: letting go of SHIFT first
	bne @nokey			; turns up into down, and that must
	cmp #ACT_UP			; not start moving the other way
	beq @again
	cmp #ACT_DOWN
	bne @nokey
@again:
	lda #REPEAT-RATE
	sta steady
	lda lastact
	jmp @act
@settled:
	lda lastact
	bne @pressed
	lda #1				; everything is up: the next press counts
	sta armed
	jmp @nokey
@pressed:
	;; Something settled. It counts only if everything has been up since
	;; the last one: a change while keys are still down (SHIFT let go
	;; before the cursor key, or one key of two released) is not a new
	;; press.
	ldx armed
	beq @to_nokey
	ldx #0
	stx armed
	sta acted
@act:
	pha
	jsr invert_line			; the highlight off; @donekey puts it back
	pla
	cmp #ACT_RETURN
	bne @notreturn
	jmp @return
@notreturn:
	cmp #ACT_BACK
	bne @notback
	jmp @back
@notback:
	cmp #ACT_UP
	beq @up
	cmp #ACT_LEFT
	bne @notleft
	jmp @left
@notleft:
	cmp #ACT_RIGHT
	bne @down
	jmp @right
@to_nokey:
	jmp @nokey
@down:
	ldx entry_num
	inx
	cpx entry_cnt
	bne @okdown
	ldx #0
@okdown:	
	stx entry_num
@to_donekey:
	jmp @donekey
@right:
	lda screen+(3*40)+29
	cmp #' '
	beq @to_donekey
	clc
	lda skip_cnt
	adc #files_per_page
	sta skip_cnt
	bcc @doneright
	inc skip_cnt+1
@doneright:
	jmp next_page
@up:
	ldx entry_num
	bne @okup
	ldx entry_cnt
@okup:
	dex
	stx entry_num
	jmp @donekey
@left:
	lda screen+(3*40)+0
	cmp #' '
	beq @to_donekey
	sec
	lda skip_cnt
	sbc #files_per_page
	sta skip_cnt
	bcs @doneleft
	dec skip_cnt+1
@doneleft:
	jmp next_page

	;; The top left key: up a level, as choosing ".." does. The parent is
	;; whatever the ".." entry of this directory points at, so read through
	;; it for that; the root has none, and then nothing happens.
@back:
	jsr fatfs_rewind_dir
@backscan:
	jsr fatfs_next_dirent
	bcs @noparent
	lda direntry
	beq @noparent			; the end of the directory
	cmp #$2e			; "..", in the raw ASCII FAT keeps names in
	bne @backscan
	lda direntry+1
	cmp #$2e
	bne @backscan
	lda direntry+2
	cmp #$20
	bne @backscan
	lda direntry+11
	and #$10
	beq @backscan
	lda direntry+26
	sta cluster
	lda direntry+27
	sta cluster+1
	lda direntry+20
	sta cluster+2
	lda direntry+21
	sta cluster+3
	jsr fatfs_open_subdir
	jmp next_dir
@noparent:
	jmp next_page			; the same page again, read afresh

@return:
	ldx entry_num
	lda cluster0,x
	sta cluster
	lda cluster1,x
	sta cluster+1
	lda cluster2,x
	sta cluster+2
	lda cluster3,x
	sta cluster+3
	lda file_flags,x
	and #$18
	beq @regular_file
	and #$08
	beq @isdir
	jmp @donekey			; the volume label: nothing to open
@isdir:
	jsr fatfs_open_subdir
	jmp next_dir
@regular_file:
	lda size_low,x
	pha
	lda size_high,x
	pha
	lda blocks_low,x
	pha
	lda blocks_mid,x
	pha
	lda blocks_high,x
	pha
	lda #0
	jsr setrow
	ldx #0
@cleanup_screen:
	jsr clearline
	jsr nextrow
	inx
	cpx #24
	bcc @cleanup_screen
	jsr cluster_to_block
	pla
	tay
	pla
	tax
	pla
	jsr index_file
	pla
	tax
	pla
	rts


	;; Wait for the next frame
nextframe:
	lda $d011
	bpl nextframe
@low:
	lda $d011
	bmi @low
	rts

	;; What the keys held now ask for, as an ACT_ value in A. Each row of
	;; the matrix with one of these keys in it is read once:
	;;
	;;   row 0  RETURN, CRSR right/left, CRSR down/up
	;;   row 1  W, A, S, and the left SHIFT
	;;   row 2  D
	;;   row 6  the right SHIFT
	;;   row 7  the top left key, which goes up a level like ".."
	;;
	;; WASD and the cursor keys are the same moves; A and D, like the
	;; horizontal cursor key, turn the page. More than one at once is
	;; taken in the order below.
readaction:
	lda #%11111110
	sta $dc00
	lda $dc01
	sta krow0
	lda #%11111101
	sta $dc00
	lda $dc01
	sta krow1
	lda #%11111011
	sta $dc00
	lda $dc01
	sta krow2
	lda #%10111111
	sta $dc00
	lda $dc01
	sta krow6
	lda #%01111111			; row 7 last: it is what the menu
	sta $dc00			; leaves selected
	lda $dc01
	sta krow7
	lda #0
	sta kshift
	lda krow1
	and #$80			; left SHIFT
	beq @shifted
	lda krow6
	and #$10			; right SHIFT
	bne @unshifted
@shifted:
	inc kshift
@unshifted:
	lda krow0
	and #$02			; RETURN
	bne @notreturn
	lda #ACT_RETURN
	rts
@notreturn:
	lda krow7
	and #$02			; the top left key
	bne @notback
	lda #ACT_BACK
	rts
@notback:
	lda krow1
	and #$02			; W
	beq @up
	lda krow1
	and #$20			; S
	beq @down
	lda krow1
	and #$04			; A
	beq @left
	lda krow2
	and #$04			; D
	beq @right
	lda krow0
	and #$80			; CRSR down, up with SHIFT
	bne @noupdown
	lda kshift
	bne @up
@down:
	lda #ACT_DOWN
	rts
@up:
	lda #ACT_UP
	rts
@noupdown:
	lda krow0
	and #$04			; CRSR right, left with SHIFT
	bne @none
	lda kshift
	bne @left
@right:
	lda #ACT_RIGHT
	rts
@left:
	lda #ACT_LEFT
	rts
@none:
	lda #ACT_NONE
	rts

colorize:
	and #$18
	beq setlinedefcolor
	and #$08
	beq @notlabel
	ldy #6
	bne setlinecolor
@notlabel:
	ldy #13
	bne setlinecolor

drawline:
	lda #$40
	ldy #35
@drawloop:
	sta (vscrn),y
	dey
	bpl @drawloop
	ldy #11
	bne setlinecolor

clearline:
	ldy #39
	lda #' '
@clearloop:
	sta (vscrn),y
	dey
	bpl @clearloop
setlinedefcolor:
	ldy $d800
setlinecolor:
	lda vscrn+1
	pha
	and #$03
	ora #$d8
	sta vscrn+1
	tya
	ldy #39
@colorloop:
	sta (vscrn),y
	dey
	bpl @colorloop
	pla
	sta vscrn+1
	iny
	rts

invert_line:
	clc
	lda entry_num
	adc #5
	jsr setrow
	ldy #35
@invertloop:
	lda (vscrn),y
	eor #$80
	sta (vscrn),y
	dey
	bpl @invertloop
	rts

ascii2screen:	
	cmp #$20
	bcc @badchar
	cmp #$7f
	bcs @badchar
	cmp #$40
	beq @tolower
	cmp #$5b
	bcc @screendone
	cmp #$7e
	beq @tilde
	cmp #$60
	beq @backtick
	cmp #$5f
	beq @underscore
@tolower:
	and #$1f
@screendone:
	rts
@badchar:
	lda #$5e
	rts
@tilde:
	lda #$7a
	rts
@backtick:
	lda #$6d
	rts
@underscore:
	lda #$64
	rts

longfilename:
	lda #$40
	bit direntry
	bne @firstlong
	ldx direntry
	beq @badlong
	inx
	cpx longfile_status
	bne @badlong
	dex
@oklong:
	stx longfile_status
	cpx #3
	bcs @longdone
	dex
	beq @x0
	ldx #13
@x0:
	ldy #1
	clc
	jsr @get2ucs
	jsr @get2ucs
	jsr @get1ucs
	ldy #$e
	jsr @get2ucs
	jsr @get2ucs
	jsr @get2ucs
	ldy #$1c
@get2ucs:
	jsr @get1ucs
@get1ucs:
	bcs @skip
	lda direntry+1,y
	bne @nonasciichar
	lda direntry,y
	bne @asciichar
	lda #' '
@spacefill:
	sta filename,x
	inx
	cpx #27
	bcc @spacefill
@longdone:
	rts
@nonasciichar:
	lda #$ff
@asciichar:
	sta filename,x
	iny
	iny
	inx
	clc
@skip:
	rts

@badlong:
	lda #0
	sta longfile_status
	rts
@firstlong:
	lda direntry
	cmp #$80
	bcs @badlong
	and #$3f
	tax
	beq @badlong
	lda #' '
	cpx #3
	bcc @nooverflow
	lda #$69
@nooverflow:
	sta filename+26
	jmp @oklong


shortfilename:
	lda longfile_status
	cmp #1
	beq @use_longname
	ldx #0
	ldy #0
@copyname:
	lda direntry,x
	inx
	cpy #8
	bne @notdot
	dex
	lda #'.'
@notdot:
	sta filename,y
	iny
	cpy #12
	bcc @copyname
	lda #' '
@clear_filename:
	sta filename,y
	iny
	cpy #27
	bcc @clear_filename
	cmp filename+9
	bne @use_longname
	cmp filename+10
	bne @use_longname
	cmp filename+11
	bne @use_longname
	sta filename+8
@use_longname:
	lda #0
	sta longfile_status
	rts
