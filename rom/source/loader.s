
	.macpack cbm

	.export loader

	.import initstream, getstreamdata

	.importzp vreg, vscrn

vartab = $2d
ndx = $c6
keyd = $277

loader:
	sec
	sbc #2
	sta vscrn
	bcs @nowrap
	dex
@nowrap:
	stx vscrn+1
	ldx #0
	stx $df04
	stx $df05
	stx $df06
	lda #$40
	sta $df09
	stx $df0a
	stx $df0b
	inx
	jsr initstream
	lda #0
	jsr getstreamdata
	beq @no_data

	lda #<vreg
	sta $df02
	lda #>vreg
	sta $df03
	lda #<2
	sta $df07
	lda #>2
	sta $df08
	lda #$91
	sta $df01
	jsr waitdma

	lda vreg
	sta $df02
	lda vreg+1
	sta $df03
	lda vscrn
	sta $df07
	lda vscrn+1
	sta $df08
	lda #$81
	sta $df01

	sei
	ldx #$ff
	txs
	cld
	lda #$37
	sta $01
	lda #$2f
	sta $00
	lda #$0b
	sta $d011
	ldx #@stub_size-1
@copy_stub:
	lda @stub,x
	sta $102,x
	dex
	bpl @copy_stub
	ldx #3
@copy_kbd:
	lda kbd_data,x
	sta keyd,x
	dex
	bpl @copy_kbd
	lda #0
	ldx #$37
	ldy #%10100011
	jmp $102

@no_data:
	rts

@stub:
	sty $de11
	stx $01
	tax
	tay
	jsr $ff84
	jsr $ff87
	jsr $ff8a
	jsr $ff81
	jsr $e453
	jsr $e3bf
	jsr $e422
	lda #'r'
	sta keyd
	lda #'u'
	sta keyd+1
	lda #'n'
	sta keyd+2
	lda #$d
	sta keyd+3
	lda #4
	sta ndx
	sei
	lda #$34
	sta $01
	sta $ff00
	lda #$37
	sta $01
	lda $df02
	sta vartab
	lda $df03
	sta vartab+1
	cli
	jmp $e39d

@stub_size = *-@stub

	
@feh:
	inc $d020
	jmp @feh

	
waitdma:
	inc $d024
	lda $df00
	bpl waitdma
	rts

kbd_data:
	.byte "rub",$d

