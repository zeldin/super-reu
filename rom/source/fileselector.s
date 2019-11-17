
	.macpack cbm

	.export fileselector

	.import fatfs_mount, fatfs_open_rootdir, fatfs_next_dirent
	.import fatfs_open_subdir, fatfs_rewind_dir
	.import cluster_to_block, follow_fat
	.import direntry, cluster

	.import screen, clear_screen, setrow, nextrow, printtext, printhex
	.importzp vscrn
	
	.import initmmc64, selectmmc64, deselectmmc64
	.import blockread1, blockreadn, blockreadmulticmd, stopcmd
	.importzp mmcptr, blknum


files_per_page = 16

	.bss

file_flags:	.res	files_per_page
cluster0:	.res	files_per_page
cluster1:	.res	files_per_page
cluster2:	.res	files_per_page
cluster3:	.res	files_per_page

entry_num:	.res	1
entry_cnt:	.res	1
key:		.res	1
oldkey:		.res	1
skip_cnt:	.res	2
tmp_skip_cnt:	.res	2
	
	.code

carderror:
	cmp #8
	bne errormsg
	jsr printtext
	scrcode "no card inserted@"
	beq fail
errormsg:
	jsr printtext
	scrcode "error!@"
fail:
	jmp fail

fileselector:
	jsr clear_screen
	lda #0
	sta oldkey
	jsr setrow
	jsr printtext
	scrcode "checking sdcard...@"
	jsr initmmc64
	ldy #18
	bcs carderror
	cmp #2
	beq @sd2
	cmp #3
	bcs @sdhc
	jsr printtext
	scrcode "sd1@"
	beq @card_found
@sd2:
	jsr printtext
	scrcode "sd2@"
	beq @card_found
@sdhc:
	jsr printtext
	scrcode "sdhc@"
@card_found:

	jsr nextrow
	jsr printtext
	scrcode "checking for fat filesystem...@"

	jsr selectmmc64

	jsr fatfs_mount
	ldy #30
	bcc @mount_ok
	jmp errormsg
@mount_ok:
	bne @fat32
	jsr printtext
	scrcode "fat16@"
	beq @fat16
@fat32:
	jsr printtext
	scrcode "fat32@"
@fat16:

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
	beq @next_entry
	lda tmp_skip_cnt
	ora tmp_skip_cnt+1
	bne @skip_entry
	lda entry_num
	cmp #files_per_page
	bcs @moredir
	jsr clearline
	ldx #0
@displayname:
	lda direntry,x
	inx
	cmp #$40
	bcc @notalpha
	and #$3f
@notalpha:
	cpy #8
	bne @notdot
	dex
	lda #'.'
@notdot:
	sta (vscrn),y
	iny
	cpy #12
	bcc @displayname

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
	lda direntry+11
	sta file_flags,x
	lda direntry+26
	sta cluster0,x
	lda direntry+27
	sta cluster1,x
	lda direntry+20
	sta cluster2,x
	lda direntry+21
	sta cluster3,x
	
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
	scrcode "no files@"
@nofiles:
	jmp @nofiles


selection:
	lda #0
	sta entry_num
@donekey:
	jsr invert_line
@nokey:
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
	jmp cluster_to_block


drawline:
	lda #$43
@drawloop:
	sta (vscrn),y
	iny
	cpy #30
	bcc @drawloop
	rts

clearline:
	ldy #29
	lda #' '
@clearloop:
	sta (vscrn),y
	dey
	bpl @clearloop
	iny
	rts

invert_line:
	clc
	lda entry_num
	adc #5
	jsr setrow
	ldy #29
@invertloop:
	lda (vscrn),y
	eor #$80
	sta (vscrn),y
	dey
	bpl @invertloop
	rts
