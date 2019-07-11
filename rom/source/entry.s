
	.macpack cbm

	
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
	sta $0400,x
	sta $0500,x
	sta $0600,x
	sta $0700,x
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
	sta $0400,x
	dex
	bpl print_message

	lda #$1b
	sta $d011
		

halt_here:	
	inc $d020
	jmp halt_here


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

