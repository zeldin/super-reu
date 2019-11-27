
	.export index_clear, index_add
	.export index_fill0, index_maybe_refill, index_refill
	.exportzp index_avail
	
	.importzp blknum

	.zeropage

index_avail:	.res 2
index_index:	.res 1
	
	.bss

	.align 256

index_blknum0:	.res 256
index_blknum1:	.res 256
index_blknum2:	.res 256
index_blknum3:	.res 256
index_cntlo:	.res 256
index_cnthi:	.res 256

	.code


	;; Initialize the index for writing
	;; A - scratch
	;; X - preserved
	;; Y - preserved
index_clear:
	lda #0
	sta index_cntlo
	sta index_cnthi
	sta index_index
	rts

	;; Adds blocks to the index
	;; A - number of blocks
	;; X - scratch
	;; Y - preserved
	;; C - out: 1 = insufficient space in index
index_add:
	sta index_avail
	ldx index_index
	lda index_cntlo,x
	ora index_cnthi,x
	beq @new_entry
	clc
	lda index_blknum0,x
	adc index_cntlo,x
	eor blknum
	bne @make_new_entry
	lda index_blknum1,x
	adc index_cnthi,x
	eor blknum+1
	bne @make_new_entry
	lda index_blknum2,x
	adc #0
	eor blknum+2
	bne @make_new_entry
	lda index_blknum3,x
	adc #0
	eor blknum+3
	bne @make_new_entry
	; Block number matches, try to extend current entry
	clc
	lda index_cntlo,x
	adc index_avail
	bcc @okextend
	inc index_cnthi,x
	beq @overflow
	clc
@okextend:
	sta index_cntlo,x
	rts
@overflow:
	dec index_cnthi,x
@make_new_entry:
	inx
	beq @outofspace
@new_entry:
	lda blknum
	sta index_blknum0,x
	lda blknum+1
	sta index_blknum1,x
	lda blknum+2
	sta index_blknum2,x
	lda blknum+3
	sta index_blknum3,x
	lda index_avail
	sta index_cntlo,x
	lda #0
	sta index_cnthi,x
	inx
	beq @nonext
	sta index_cntlo,x
	sta index_cnthi,x
@nonext:
	dex
	stx index_index
	clc
	rts
@outofspace:
	sec
	rts


	;; Initialize the index for reading
	;; A - scratch
	;; X - scratch
	;; Y - preserved
	;; Z - out: 1 = index empty
index_fill0:
	ldx #0
	beq internal_fill

	;; Read the next entry from the index if necessary (does nothing if
	;; the current entry is still not depleted)
	;; A - scratch
	;; X - scratch
	;; Y - preserved
	;; Z - out: 1 = no more entries
index_maybe_refill:
	lda index_avail
	ora index_avail+1
	beq index_refill
	rts

	;; Read the next entry from the index (call when index_avail = 0)
	;; A - scratch
	;; X - scratch
	;; Y - preserved
	;; Z - out: 1 = no more entries
index_refill:
	ldx index_index
	beq end_of_index
internal_fill:
	lda index_blknum0,x
	sta blknum
	lda index_blknum1,x
	sta blknum+1
	lda index_blknum2,x
	sta blknum+2
	lda index_blknum3,x
	sta blknum+3
	lda index_cntlo,x
	sta index_avail
	lda index_cnthi,x
	sta index_avail+1
	inx
	ora index_avail
	beq @end
	stx index_index
@end:
	rts

end_of_index:
	lda #0
	sta index_avail
	sta index_avail+1
	rts
