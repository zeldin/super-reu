
	.macpack cbm

	.export fileselector

	.import fatfs_mount

	.import screen, clear_screen, setrow, nextrow, printtext

	.import initmmc64, selectmmc64, deselectmmc64
	.import blockread1, blockreadn, blockreadmulticmd, stopcmd
	.importzp mmcptr, blknum


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
