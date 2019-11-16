
	.macpack cbm

	.export fileselector

	.import fatfs_mount, fatfs_open_rootdir, fatfs_next_dirent
	.import direntry

	.import screen, clear_screen, setrow, nextrow, printtext, printhex
	.importzp vscrn
	
	.import initmmc64, selectmmc64, deselectmmc64
	.import blockread1, blockreadn, blockreadmulticmd, stopcmd
	.importzp mmcptr, blknum


	.bss

entry_num:	.res	1

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

	jsr nextrow
	inc entry_num
	bne @next_entry
@moredir:
@enddir:
	lda #21
	jsr setrow
	jsr drawline

@wait_here_1:
	lda $dc01
	and #$10
	beq @wait_here_1
@wait_here_2:
	lda $dc01
	and #$10
	bne @wait_here_2
	
	lda #$40
	sta blknum
	sta $d020
	lda #$2d ; $5a
	sta blknum+1
	lda #5
	sta blknum+2

	rts

drawline:
	lda #$43
@drawloop:
	sta (vscrn),y
	iny
	cpy #30
	bcc @drawloop
	rts
