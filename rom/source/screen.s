
	.export screen, clear_screen, setrow, nextrow, dumpreg
	.exportzp vreg

	
screen = $400


	.zeropage

vscrn:	.res 2
vreg:	.res 2


	.code


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
	lda #$f
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

