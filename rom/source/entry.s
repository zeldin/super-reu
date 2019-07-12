
	.macpack cbm


vscrn = $fa
vreg  = $fc


screen = $400
	
	.word start
	.word start

	.byte "CBM80"

start:
	sei
@wait1:	
	lda $d011
	bpl @wait1
@wait2:	
	lda $d011
	bmi @wait2

	ldx #$ff
	txs

	ldx #17
init_vic_loop:
	lda vicinit-1,x
	sta $d010,x
	dex
	bne init_vic_loop
	lda #3
	sta $dd00

clear_screen:
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
	bne clear_screen

	ldx #message_length-1
print_message:	
	lda message,x
	sta screen,x
	dex
	bpl print_message

	lda #$1b
	sta $d011



	lda #3
	jsr setrow

	lda #$91
	sta $dea2


	ldx #0
@dumpdeloop:
	jsr dumpdereg
	inx
	cpx #8
	bcc @dumpdeloop


halt_here:	
	inc $d020
	jmp halt_here


dumpdereg:
	lda #>$de00
	jsr dumpreg
	ldx vreg
	jmp nextrow

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

printhex:
	tax
	lsr a
	lsr a
	lsr a
	lsr a
	jsr hexdigit
	txa

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
	.byte $15
	.byte $ff
	.byte 0
	.byte $ff
	.byte 0
	.byte 0
	.byte 0, 0
	.byte 0
	.byte 0

message:
	scrcode "hello, this is exrom code."
message_length = * - message

