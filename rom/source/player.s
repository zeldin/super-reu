
	.export movie_player

	.import initstream, getstreamdata

	.import __MTX0_START__, __DOT0_START__
	.import __MTX1_START__, __DOT1_START__


	.bss

	.align 16

frame_header:	.res 16

	.zeropage

vswap:	.res 1
aswap:	.res 1
isntsc:	.res 1

	.code
	

movie_player:
	lda #0
	sta vswap
	sta aswap
	sta $d418
	sta $df04
	sta $df05
	sta $df06
	sta $df0a
	sta $df0b
	sta $df19
	sta $df1d
	sta $df29
	sta $df2d
	lda #$40
	sta $df09
	lda #<$d418
	sta $df12
	sta $df22
	lda #>$d418
	sta $df13
	sta $df23
	lda #$ff
	sta $d406
	sta $d40d
	sta $d414
	lda #$49
	sta $d404
	sta $d40b
	sta $d412
	jsr check_ntsc

	ldx #2
	lda #$10
	bit $df00	; Special case for 128K expansion
	beq @only128k
	lda $df06	; Unimplemented addr bits will read back as "1".
	eor #$ff	; Invert to get the implemented addr bits and
	tax		; increment to get total expansion memory size
	inx
@only128k:
	jsr initstream

	jmp @nextframe

@readblocked2:
	lda #0
	sta $df04
@readblocked1:
	lda #2
	sta $d020
@nextframe:
	lda $df05
	jsr getstreamdata
	beq @readblocked1

	lda #<frame_header
	sta $df02
	lda #>frame_header
	sta $df03
	lda #<16
	sta $df07
	lda #>16
	sta $df08
	lda #$91
	sta $df01
	jsr waitdma

	cpx frame_header+2
	bcc @readblocked2
	
	lda frame_header+4
	and #$04
	beq @noaudioprep

	lda aswap
	eor #$10
	sta aswap
	tax
	ldy isntsc
	lda $df04
	sta $df14,x
	lda $df05
	sta $df15,x
	lda $df06
	sta $df16,x
	lda frame_header+5
	sta $df17,x
	lda frame_header+6
	sta $df18,x
	lda #$80
	sta $df1a,x
	sta $df1b,x
	lda frame_header+10,y
	sta $df1c,x
	lda frame_header+11,y
	sta $df1e,x
	lda #$81
	sta $df11,x

@noaudioprep:	
	lda #0
	sta $df04
	clc
	lda $df05
	adc frame_header+3
	sta $df05
	bcc @nowrap1
	inc $df06
@nowrap1:

	ldx vswap
	lda frame_header+4
	and #$01
	beq @nobitmap
	txa
	eor #$04
	sta vswap
	tax
		
	lda #0
	sta $df02
	sta $df07
	lda swapdata+0,x
	sta $df03
	lda #>$2000
	sta $df08
	lda #$91
	sta $df01
	jsr waitdma

	lda #0
	sta $df02
	sta $df07
	lda swapdata+1,x
	sta $df03
	lda #>$0400
	sta $df08
	lda #$91
	sta $df01
	jsr waitdma

@nobitmap:
	lda #0
	sta $d020
	
@sync1:
	inc $d024
	lda $d012
	bne @sync1
	lda $d011
	bmi @sync1

	sta $ff00 ; trigger audio DMA, if set up
	lda #$3b
	sta $d011
	lda swapdata+2,x
	sta $d018
	lda swapdata+3,x
	sta $dd00

	lda frame_header+$f
	sta $d021
	lda frame_header+$e
	sta $d016

	lda frame_header+$4
	and #$02
	beq @nocram

	lda #0
	sta $df02
	sta $df07
	lda #>$d800
	sta $df03
	lda #>$0400
	sta $df08
	lda #$91
	sta $df01
	jsr waitdma

@nocram:
	lda frame_header+2
	beq end_of_movie
	jmp @nextframe

end_of_movie:
	lda #0
	sta $d020
	ldx #3
@wait0:
	inc $d024
	lda $d012
	beq @wait0
@wait1:
	inc $d024
	lda $d012
	bne @wait1
	lda $d011
	bmi @wait1
	lda #$0b
	sta $d011
	dex
	bne @wait0

	lda #$08
	sta $d016
	lda #$15
	sta $d018
	lda #0
	sta $d418
	sta $d404
	sta $d40b
	sta $d412
	
	rts

waitdma:
	inc $d024
	lda $df00
	bpl waitdma
	rts

check_ntsc:
	lda #0
	sta isntsc
	sei
@wait_top:
	lda $d011
	bmi @wait_top
@wait_bottom:
	lda $d011
	bpl @wait_bottom
@check_bottom_lines:
	lda $d012
	cmp #16
	bcs @ispal
	lda $d011
	bmi @check_bottom_lines
	inc isntsc
	inc isntsc
@ispal:
	cli
	rts


	.align 4


AVEC0 = ((__MTX0_START__ >> 6) & $3f0) ^ ((__DOT0_START__ >> 10) & $0f) ^ $300
AVEC1 = ((__MTX1_START__ >> 6) & $3f0) ^ ((__DOT1_START__ >> 10) & $0f) ^ $300

swapdata:
	.byte >__DOT0_START__, >__MTX0_START__, <AVEC0, >AVEC0
	.byte >__DOT1_START__, >__MTX1_START__, <AVEC1, >AVEC1
