
	.export fatfs_mount
	
	.import blockread1, blockreadn, blockreadmulticmd, stopcmd
	.importzp mmcptr, blknum

	.bss

	.align 256

fatfs_block:		.res 512
fat_type:		.res 1
blocks_per_cluster:	.res 1
cluster_shift:		.res 1
root_dir_entries:	.res 2
fat_start:		.res 4
root_dir_start:		.res 4
data_start:		.res 4

	.code

	;; Try to mount FAT filesystem
	;; C=1 - failed to mount
	;; C=0 - success, A=0: FAT16 A=1: FAT32
fatfs_mount:
	lda #0
	sta blknum
	sta blknum+1
	sta blknum+2
	sta blknum+3
	jsr read_block_internal
	bcs mount_failed
	jsr try_mount
	bcc mount_ok
	lda fatfs_block+$1be
	asl
	bne mount_failed
	lda fatfs_block+$1c6
	sta blknum
	lda fatfs_block+$1c7
	sta blknum+1
	lda fatfs_block+$1c8
	sta blknum+2
	lda fatfs_block+$1c9
	sta blknum+3
	ora blknum+2
	ora blknum+1
	ora blknum
	beq mount_failed
	jsr try_mount_block
	bcc mount_ok
mount_failed:
	sec
mount_ok:
	rts

try_mount_block:
	jsr read_block_internal
	bcs mount_failed

try_mount:
	sec
	lda blknum
	sbc #1
	sta blknum
	lda blknum+1
	sbc #0
	sta blknum+1
	lda blknum+2
	sbc #0
	sta blknum+2
	lda blknum+3
	sbc #0
	sta blknum+3
	lda fatfs_block+82
	cmp #'f'
	bne @mount_failed
	lda fatfs_block+83
	cmp #'a'
	bne @mount_failed
	lda fatfs_block+84
	cmp #'t'
	bne @mount_failed

	lda fatfs_block+11	; Check 512 bytes per sector
	bne @mount_failed
	lda fatfs_block+12
	cmp #2
	bne @mount_failed

	lda fatfs_block+14	; Check reserved sectors > 0
	ora fatfs_block+15
	beq @mount_failed

	lda fatfs_block+16	; Check FAT count
	cmp #2
	bne @mount_failed

	lda #1
	ldx #0
@find_cluster_shift:
	cmp fatfs_block+13
	beq @found_cluster_shift
	inx
	asl
	bcc @find_cluster_shift	
@mount_failed:
	sec
	rts
@found_cluster_shift:
	sta blocks_per_cluster
	stx cluster_shift

	lda fatfs_block+17
	sta root_dir_entries
	lda fatfs_block+18
	sta root_dir_entries+1

	clc
	lda fatfs_block+14
	adc blknum
	sta fat_start
	lda fatfs_block+15
	adc blknum+1
	sta fat_start+1
	lda #0
	adc blknum+2
	sta fat_start+2
	lda #0
	adc blknum+3
	sta fat_start+3

	lda fatfs_block+22
	bne @secperfat16
	lda fatfs_block+23
	beq @secperfat32
	sta root_dir_start+1
	lda #0
	sta root_dir_start
	beq @secperfat16b
@secperfat16:
	sta root_dir_start
	lda fatfs_block+23
	sta root_dir_start+1
	lda #0
@secperfat16b:
	sta root_dir_start+2
	sta root_dir_start+3
	beq @secperfatdone
@secperfat32:	
	lda fatfs_block+36
	sta root_dir_start
	lda fatfs_block+37
	sta root_dir_start+1
	lda fatfs_block+38
	sta root_dir_start+2
	lda fatfs_block+39
	sta root_dir_start+3
@secperfatdone:
	lda root_dir_start
	rol a
	rol root_dir_start+1
	rol root_dir_start+2
	rol root_dir_start+3
	clc
	adc fat_start
	sta root_dir_start
	lda root_dir_start+1
	adc fat_start+1
	sta root_dir_start+1
	lda root_dir_start+2
	adc fat_start+2
	sta root_dir_start+2
	lda root_dir_start+3
	adc fat_start+3
	sta root_dir_start+3

	clc
	ldx root_dir_entries+1
	lda root_dir_entries
	adc #15
	bcc @nocarry
	inx
@nocarry:
	stx data_start+1
	lsr data_start+1
	ror a
	lsr data_start+1
	ror a
	lsr data_start+1
	ror a
	lsr data_start+1
	ror a
	clc
	adc root_dir_start
	sta data_start
	lda data_start+1
	adc root_dir_start+1
	sta data_start+1
	lda #0
	adc root_dir_start+2
	sta data_start+2	
	lda #0
	adc root_dir_start+3
	sta data_start+3

	;; Compute number of clusters: totalSectors - (data_start - blknum)
	sec
	lda blknum
	sbc data_start
	sta blknum
	lda blknum+1
	sbc data_start+1
	sta blknum+1
	lda blknum+2
	sbc data_start+2
	sta blknum+2
	lda blknum+3
	sbc data_start+3
	sta blknum+3
	clc
	lda fatfs_block+19
	bne @totalsectors16
	lda fatfs_block+20
	bne @totalsectors16b
	lda fatfs_block+32
	adc blknum
	sta blknum
	lda fatfs_block+33
	adc blknum+1
	sta blknum+1
	lda fatfs_block+34
	adc blknum+2
	sta blknum+2
	lda fatfs_block+35
	adc blknum+3
	sta blknum+3
	jmp @totalsectors_done
@totalsectors16:
	adc blknum
	sta blknum
	lda fatfs_block+20
@totalsectors16b:
	adc blknum+1
	sta blknum+1
	bcc @totalsectors_done
	inc blknum+2
	bne @totalsectors_done
	inc blknum+3
@totalsectors_done:
	ldx cluster_shift
	beq @clusters_done
@toclusters:
	lsr blknum+3
	ror blknum+2
	ror blknum+1
	ror blknum
	dex
	bne @toclusters
@clusters_done:
	;; FAT32 if 65525 or more clusters
	lda blknum+3
	ora blknum+2
	bne @fat32
	lda blknum+1
	cmp #$ff
	bne @notfat32
	lda blknum
	cmp #$f5
	bcs @fat32
@fat16:
	lda #0
	beq @got_fat_type
@fat32:
	lda fatfs_block+44
	sta root_dir_start
	lda fatfs_block+45
	sta root_dir_start+1
	lda fatfs_block+46
	sta root_dir_start+2
	lda fatfs_block+47
	sta root_dir_start+3
	lda #1
	bne @got_fat_type
@notfat32:
	;; FAT12 if 4084 or less clusters
	cmp #$0f
	bcc @fat12
	bne @fat16
	lda blknum
	cmp #$f5
	bcs @fat16
@fat12:
	;; FAT12 not supported...
	sec
	rts

@got_fat_type:
	sta fat_type
	ldx #2
@adjust_start:
	sec
	lda data_start
	sbc blocks_per_cluster
	sta data_start
	bcs @noborrow
	lda data_start+1
	sbc #0
	sta data_start+1
	bcs @noborrow
	lda data_start+2
	sbc #0
	sta data_start+3
	bcs @noborrow
	dec data_start+3
@noborrow:
	dex
	bne @adjust_start
	clc
	lda fat_type
	rts

read_block_internal:
	lda #<fatfs_block
	sta mmcptr
	lda #>fatfs_block
	sta mmcptr+1
	jmp blockread1
