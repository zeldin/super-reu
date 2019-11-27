
	.export fatfs_mount, fatfs_open_rootdir, fatfs_next_dirent
	.export fatfs_open_subdir, fatfs_rewind_dir
	.export cluster_to_block, follow_fat
	.export direntry, cluster, blocks_per_cluster
	
	.import blockread1, blockreadn, blockreadmulticmd, stopcmd
	.importzp mmcptr, blknum

	.bss

	.align 256

fatfs_block:		.res 512
direntry:		.res 32
fat_type:		.res 1
blocks_per_cluster:	.res 1
cluster_shift:		.res 1
root_dir_entries:	.res 2
fat_start:		.res 4
root_dir_start:		.res 4
data_start:		.res 4
cluster:		.res 4
dir_cluster:		.res 4
dir_cnt:		.res 2
dir_entry_num:		.res 1
dir_type:		.res 1
		
	.code

follow_fat:
	lda fat_type
	beq @fat16
	lda cluster
	asl a
	lda cluster+1
	rol a
	sta blknum
	lda cluster+2
	rol a
	sta blknum+1
	lda cluster+3
	rol a
	sta blknum+2
	lda #0
	rol a
	bcc @fat32
@fat16:	
	lda cluster+1
	sta blknum
	lda cluster+2
	sta blknum+1
	lda cluster+3
	sta blknum+2
	lda #0
	clc
@fat32:
	sta blknum+3
	lda fat_start
	adc blknum
	sta blknum
	lda fat_start+1
	adc blknum+1
	sta blknum+1
	lda fat_start+2
	adc blknum+2
	sta blknum+2
	lda fat_start+3
	adc blknum+3
	sta blknum+3
	jsr read_block_internal
	bcs @fail
	lda cluster
	ldx fat_type
	beq @fat16b
	asl
	asl
	tax
	bcs @upper32
	lda fatfs_block,x
	sta cluster
	lda fatfs_block+1,x
	sta cluster+1
	lda fatfs_block+2,x
	sta cluster+2
	lda fatfs_block+3,x
	bcc @lower32
@upper32:
	lda fatfs_block+$100,x
	sta cluster
	lda fatfs_block+$101,x
	sta cluster+1
	lda fatfs_block+$102,x
	sta cluster+2
	lda fatfs_block+$103,x
@lower32:
	and #$0f
	sta cluster+3
	cmp #$0f
	bne cluster_to_block
	lda #$ff
	cmp cluster+2
	bne cluster_to_block
	cmp cluster+1
	bne cluster_to_block
	lda cluster
	cmp #$f8
	bcc cluster_to_block
@fail:	
	rts

@fat16b:
	asl
	tax
	bcs @upper16
	lda fatfs_block,x
	sta cluster
	lda fatfs_block+1,x
	bcc @lower16
@upper16:	
	lda fatfs_block+$100,x
	sta cluster
	lda fatfs_block+$101,x
@lower16:	
	sta cluster+1
	cmp #$ff
	bne @ok16
	lda cluster
	cmp #$f8
	bcs @fail
@ok16:
	lda #0
	sta cluster+2
	sta cluster+3
	
cluster_to_block:
	lda cluster
	sta blknum
	lda cluster+1
	sta blknum+1
	lda cluster+2
	sta blknum+2
	lda cluster+3
	sta blknum+3
	ldx cluster_shift
	beq @noshift
@doshift:
	asl blknum
	rol blknum+1
	rol blknum+2
	rol blknum+3
	dex
	bne @doshift
@noshift:
	clc
	lda blknum
	adc data_start
	sta blknum
	lda blknum+1
	adc data_start+1
	sta blknum+1
	lda blknum+2
	adc data_start+2
	sta blknum+2
	lda blknum+3
	adc data_start+3
	sta blknum+3
	rts

fatfs_open_subdir:
	lda cluster
	sta dir_cluster
	lda cluster+1
	sta dir_cluster+1
	lda cluster+2
	sta dir_cluster+2
	lda cluster+3
	sta dir_cluster+3
	ora cluster+2
	ora cluster+1
	ora cluster
	beq fatfs_open_rootdir
	lda #2
	sta dir_type
	
fatfs_rewind_dir:
	lda dir_type
	cmp #2
	bcc fatfs_open_rootdir
	lda dir_cluster
	sta cluster
	lda dir_cluster+1
	sta cluster+1
	lda dir_cluster+2
	sta cluster+2
	lda dir_cluster+3
	sta cluster+3
	lda #0
	sta dir_entry_num
	beq opendir_fat32
fatfs_open_rootdir:
	lda #0
	sta dir_entry_num
	lda fat_type
	sta dir_type
	beq opendir_fat16
	lda root_dir_start
	sta cluster
	lda root_dir_start+1
	sta cluster+1
	lda root_dir_start+2
	sta cluster+2
	lda root_dir_start+3
	sta cluster+3
opendir_fat32:
	lda blocks_per_cluster
	sta dir_cnt
	lda #1
	sta dir_cnt+1
	jmp cluster_to_block
opendir_fat16:		
	lda root_dir_start
	sta blknum
	lda root_dir_start+1
	sta blknum+1
	lda root_dir_start+2
	sta blknum+2
	lda root_dir_start+3
	sta blknum+3
	lda root_dir_entries
	sta dir_cnt
	lda root_dir_entries+1
	sta dir_cnt+1
	rts

end_dir:
	lda #0
	sta dir_cnt
	sta dir_cnt+1
	sec
	rts

fatfs_next_dirent:
	lda dir_cnt
	ora dir_cnt+1
	beq end_dir
	lda dir_entry_num
	bne @nofirst
	jsr read_block_internal
	bcs end_dir
	lda dir_type
	beq @fat16
	dec dir_cnt
@fat16:
	lda dir_entry_num
@nofirst:
	ldy #$e0
	asl
	asl
	asl
	asl
	asl
	tax
@copydirent:
	bcs @upper
	lda fatfs_block,x
	bcc @lower
@upper:
	lda fatfs_block+$100,x
@lower:
	sta direntry-$e0,y
	inx
	iny
	bne @copydirent
	ldx dir_entry_num
	inx
	txa
	and #$0f
	sta dir_entry_num
	ldx dir_type
	beq @fat16_fixup
	cmp #0
	bne @done
	lda dir_cnt
	bne @done
	jsr follow_fat
	bcc @more_clusters
	lda #0
	sta dir_cnt+1
	beq @done
@more_clusters:	
	lda blocks_per_cluster
	sta dir_cnt
@done:
	clc
	rts
@fat16_fixup:
	stx direntry+20
	stx direntry+21
	sec
	lda dir_cnt
	sbc #1
	sta dir_cnt
	bcs @done
	dec dir_cnt+1
	clc
	rts


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
