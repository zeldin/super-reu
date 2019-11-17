
	.macpack cbm

	.export fileselector

	.import fatfs_mount, fatfs_open_rootdir, fatfs_next_dirent
	.import cluster_to_block, follow_fat
	.import direntry, cluster

	.import screen, clear_screen, setrow, nextrow, printtext, printhex
	.importzp vscrn
	
	.import initmmc64, selectmmc64, deselectmmc64
	.import blockread1, blockreadn, blockreadmulticmd, stopcmd
	.importzp mmcptr, blknum


	.bss

	.align 16

cluster0:	.res	16
cluster1:	.res	16
cluster2:	.res	16
cluster3:	.res	16

entry_num:	.res	1
entry_cnt:	.res	1
key:		.res	1
oldkey:		.res	1

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

	lda #0
	sta entry_num
	jsr fatfs_open_rootdir
	lda #4
	jsr setrow
	jsr drawline
	jsr nextrow
@next_entry:
	jsr fatfs_next_dirent
	ldy #0
	bcs @enddir
	lda direntry
	beq @enddir
	cmp #$e5
	beq @next_entry
	lda direntry+11
	and #$3f
	cmp #$0f
	beq @next_entry
	lda entry_num
	cmp #16
	bcs @moredir
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

	iny
	lda direntry+21
	jsr printhex
	lda direntry+20
	jsr printhex
	lda direntry+27
	jsr printhex
	lda direntry+26
	jsr printhex

	ldx entry_num
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
	bne @next_entry
@moredir:
@enddir:
	lda #21
	jsr setrow
	jsr drawline
	lda entry_num
	sta entry_cnt
	bne selection
	lda #12
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
	jmp @donekey
@right:
	jmp @donekey
@shift:
	lda #4
	bit key
	beq @left
	lda #$80
	bit key
	bne @donekey
@up:
	ldx entry_num
	bne @okup
	ldx entry_cnt
@okup:
	dex
	stx entry_num
	jmp @donekey
@left:
	jmp @donekey

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
	jmp cluster_to_block


drawline:
	lda #$43
@drawloop:
	sta (vscrn),y
	iny
	cpy #30
	bcc @drawloop
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
