	;; A key's name, in reverse video, inside a printtext string.
.macro key name
	.if .match ({name}, "")
	.repeat .strlen (name), i
	.byte scrbyte {.strat (name, i)} ^ $80
	.endrepeat
	.else
	.byte scrbyte {name} ^ $80
	.endif
.endmacro
