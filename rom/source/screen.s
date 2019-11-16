
	.export screen, init_screen, clear_screen, setrow, nextrow, dumpreg
	.export printtext
	.exportzp vreg

	.import __SCRN_START__
	
screen = __SCRN_START__
font = $1000
AVEC = ((screen >> 6) & $3f0) ^ ((font >> 10) & $0f) ^ $300

bgcolor = 0
bordercolor = 0
textcolor = $f


	.zeropage

vscrn:	.res 2
vreg:	.res 2


	.code

	;; Init VIC registers; write $1b to $d011 afterwards to unblank screen
	;; A - scratch
	;; X - scratch
	;; Y - preserved
init_screen:
	ldx #$d021-$d010
init_vic_loop:
	lda vicinit-1,x
	sta $d010,x
	dex
	bne init_vic_loop
	lda #>AVEC
	sta $dd00
	lda #$3f
	sta $dd02
	rts	


	;; Clear the screen
	;; A - scratch
	;; X - scratch
	;; Y - preserved
clear_screen:
	ldx #0
@clear_screen:	
	lda #$20
	sta screen+$000,x
	sta screen+$100,x
	sta screen+$200,x
	sta screen+$300,x
	lda #textcolor
	sta $d800,x
	sta $d900,x
	sta $da00,x
	sta $db00,x
	inx
	bne @clear_screen
	rts


	;; Set vscrn to the start of a screen row
	;; A - in: row number
	;; X - preserved
	;; Y - out: set to 0
setrow:
	ldy #>screen/4
	sty vscrn+1
	sta vscrn
	asl a
	asl a
	adc vscrn
	asl a
	asl a
	rol vscrn+1
	asl a
	rol vscrn+1
	sta vscrn
	ldy #0
	rts


	;; Increment vscrn to the next row
	;; A - scratch
	;; X - preserved
	;; Y - out: set to 0
nextrow:
	clc
	lda #40
	adc vscrn
	sta vscrn
	bcc @nocarry
	inc vscrn+1
@nocarry:
	ldy #0
	rts


	;; Print a string following the jsr instruction
	;; A - scratch
	;; X - scratch
	;; Y - incremented by number of characters
printtext:
	pla
	sta vreg
	pla
	sta vreg+1
	ldx #0
@nextchar:
	inc vreg
	bne @nocarry
	inc vreg+1
@nocarry:
	lda (vreg,x)
	beq @endtext
	sta (vscrn),y
	iny
	cpy #40
	bcc @nextchar
	jsr nextrow
	beq @nextchar
@endtext:
	lda vreg+1
	pha
	lda vreg
	pha
	lda (vreg,x)
	rts


	;; Print a dump of one register at (vscrn),y
	;; A - in: high byte of register address
	;; X - in: low byte of register address
	;; Y - inout: incremented by 8
dumpreg:
	sta vreg+1
	stx vreg
	jsr printhex
	lda vreg
	jsr printhex
	lda #':'
	sta (vscrn),y
	iny
	lda #' '
	sta (vscrn),y
	iny
	ldx #0
	lda (vreg,x)


	;; Print an 8-bit hex number at (vscrn),y
	;; A - in: number to print
	;; X - scratch
	;; Y - inout: incremented by 2
printhex:
	tax
	lsr a
	lsr a
	lsr a
	lsr a
	jsr hexdigit
	txa


	;; Print one hex digit at (vscrn),y
	;; A - in: digit to print
	;; X - preserved
	;; Y - inout: incremented
hexdigit:
	and #$f
	ora #'0'
	cmp #10+'0'
	bcc @numeral
	sbc #'0'+9
@numeral:
	sta (vscrn),y
	iny
	rts


vicinit:
	.byte $0b
	.byte 0, 0, 0
	.byte 0
	.byte $08
	.byte 0
	.byte <AVEC
	.byte $ff
	.byte 0
	.byte $ff
	.byte 0
	.byte 0
	.byte 0, 0
	.byte bordercolor
	.byte bgcolor

