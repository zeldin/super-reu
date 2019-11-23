
	.macpack cbm

	.export fileselector

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

	.bss

file_flags:	.res	files_per_page
cluster0:	.res	files_per_page
cluster1:	.res	files_per_page
cluster2:	.res	files_per_page
cluster3:	.res	files_per_page

filename:	.res	27

entry_num:	.res	1
entry_cnt:	.res	1
key:		.res	1
oldkey:		.res	1
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

fileselector:
	jsr clear_screen
	lda #0
	sta oldkey
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
	scrcode "Navigate with CRSR, select with RETURN@"

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
	bcs @moredir
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
	clc
	rol $dc00
	lda $dc01
	ora #$79
	sta key
	sec
	rol $dc00
	lda $dc01
	lsr
	lsr
	lsr
	ora #$ef
	and key
	sta key
	lda #$bf
	sta $dc00
	lda $dc01
	ora #$ef
	and key
	sta key
	sec
	rol $dc00
	cmp oldkey
	beq @nokey
	sta oldkey
	jsr invert_line
	lda #2
	bit key
	beq @return
	lda #$10
	bit key
	beq @shift
	lda #4
	bit key
	beq @right
	lda #$80
	bit key
	bne @donekey
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
	beq @donekey
	clc
	lda skip_cnt
	adc #files_per_page
	sta skip_cnt
	bcc @doneright
	inc skip_cnt+1
@doneright:
	jmp next_page
@shift:
	lda #4
	bit key
	beq @left
	lda #$80
	bit key
	bne @to_donekey
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
	bne @to_donekey
	jsr fatfs_open_subdir
	jmp next_dir
@regular_file:
	lda #0
	jsr setrow
	ldx #0
@cleanup_screen:
	jsr clearline
	jsr nextrow
	inx
	cpx #24
	bcc @cleanup_screen
	jmp cluster_to_block


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
