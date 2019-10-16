
	.export initstream, getstreamdata
	
	.import initmmc64, selectmmc64, deselectmmc64
	.import blockread1, blockreadn, blockreadmulticmd, stopcmd
	.importzp mmcptr, blknum

avail_margin = 64		; number of 256 byte pages to not overwrite
	
	.zeropage

last_read_pos:		.res 1
avail_pages_low:	.res 1
avail_pages_high:	.res 1
max_avail_high:		.res 1
blockstoread:		.res 1
mmc_active:		.res 1

	.code

	;; Init MMC streaming
	;; X - in: expansion RAM size in 65536 byte pages (0 = 16 megabyte)
initstream:
	lda #0
	sta last_read_pos
	sta avail_pages_low
	sta avail_pages_high
	sta mmc_active
	sta $de15
	sta $de16
	sta $de17
	dex
	stx max_avail_high
@initial_fill:
	lda last_read_pos
	jsr getstreamdata
	lda mmc_active
	beq @initial_fill_stalled
	lda avail_pages_high
	cmp #4
	bcc @initial_fill
@initial_fill_stalled:
	rts


	;; Process fill of stream data
	;; A - in: read expansion RAM mid address
	;; X - out: number of available 256 byte pages (capped at 0xff)
	;; Y - scratch
	;; Z - out: no pages available (X = 0)
getstreamdata:
	tax
	sec
	sbc last_read_pos
	sta last_read_pos
	sec
	lda avail_pages_low
	sbc last_read_pos
	stx last_read_pos
	sta avail_pages_low
	bcs @nowrap1
	dec avail_pages_high
@nowrap1:
	lda mmc_active
	beq @mmc_idle

	lda #1
	bit $de13
	bne noread

	lda #0
	sta mmc_active
	jsr stopcmd
	lda blockstoread
	bne @not512
	inc avail_pages_high
	jmp @inc256

@not512:
	asl a
	bcc @nowrap2
	inc avail_pages_high
	clc
@nowrap2:
	adc avail_pages_low
	sta avail_pages_low
	bcc @mmc_idle
@inc256:
	inc avail_pages_high

@mmc_idle:
	sec
	lda #$100-avail_margin
	sbc avail_pages_low
	tax
	lda max_avail_high
	sbc avail_pages_high
	bcc noread
	lsr a
	bne doread256
	txa
	ror a
	bne doread

noread:
	ldx #$ff
	lda avail_pages_high
	bne @many_pages_avail
	ldx avail_pages_low
@many_pages_avail:
	rts


doread256:
	lda #0
doread:
	sta blockstoread

	jsr blockreadmulticmd
	lda blockstoread
	sta $de14
	lda #1
	sta $de13
	sta mmc_active
	clc
	lda blockstoread
	beq @inc256b
	adc blknum
	sta blknum
	bcc @nowrap0
@inc256b:
	inc blknum+1
	bne @nowrap0
	inc blknum+2
	bne @nowrap0
	inc blknum+3
@nowrap0:
	jmp noread
