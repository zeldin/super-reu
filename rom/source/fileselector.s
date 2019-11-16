
	.macpack cbm

	.export fileselector

	.import screen, clear_screen, setrow, nextrow, printtext

	.import initmmc64, selectmmc64, deselectmmc64
	.import blockread1, blockreadn, blockreadmulticmd, stopcmd
	.importzp mmcptr, blknum


	.code

carderror:
	cmp #8
	bne @notnocard
	jsr printtext
	scrcode "no card inserted@"
	beq fail	
@notnocard:	
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

	jsr selectmmc64

	lda #3
	sta screen+124
	
	lda #0
	sta blknum
	sta blknum+1
	sta blknum+2
	sta blknum+3

	lda #5
	sta screen+126

	lda #<(screen+160)
	sta mmcptr
	lda #>(screen+160)
	sta mmcptr+1

	jsr blockread1
	sta screen+127
	lda #'0'
	adc #0
	sta screen+128

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
