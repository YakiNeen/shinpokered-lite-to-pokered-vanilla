
;Putting some useful functions into this file that are in fact used now
	

; does nothing since no stats are ever selected (barring glitches)
;joenote - let's get this working again and put it to use
DoubleSelectedStats:
	ld a, [H_WHOSETURN]
	and a
	ld a, [wPlayerStatsToDouble]
	ld hl, wBattleMonAttack
	jr z, .notEnemyTurn
	ld a, [wEnemyStatsToDouble]
	ld hl, wEnemyMonAttack
.notEnemyTurn
	ld c, 4
	ld b, a
.loop
	srl b
	call c, .doubleStat
	inc hl
	inc hl
	dec c
	ret z
	jr .loop
.doubleStat
	push bc
	ld a, [hli]
	ld b, a
	ld c, [hl] ; bc holds value of stat to double
;double the stat
	sla c
	rl b
;cap stat at 999
	;b register contains high byte & c register contains low byte
	ld a, c ;let's work on low byte first. Note that decimal 999 is $03E7 in hex.
	sub 999 % $100 ;a = a - ($03E7 % $100). Gives a = a - $E7. A byte % $100 always gives the lesser nibble.
	;Note that if a < $E7 then the carry bit 'c' in the flag register gets set due to overflowing with a negative result.
	ld a, b ;now let's work on the high byte
	sbc 999 / $100 ;a = a - ($03E7 / $100 + c_flag). Gives a = a - ($03 + c_flag). A byte / $100 always gives the greater nibble.
	;Note again that if a < $03 then the carry bit remains set. 
	;If the bit is already set from the lesser nibble, then its addition here can still make it remain set if a is low enough.
	jr c, .donecapping ;jump to next marker if the c_flag is set. This only remains set if BC <  the cap of $03E7.
	;else let's continue and set the 999 cap
	ld a, 999 / $100 ; else load $03 into a
	ld b, a ;and store it as the high byte
	ld a, 999 % $100 ; else load $E7 into a
	ld c, a ;and store it as the low byte
	;now registers b & c together contain $03E7 for a capped stat value of 999
.donecapping
	ld a, c
	ld [hld], a
	ld [hl], b
	pop bc
	ret


	
; does nothing since no stats are ever selected (barring glitches)
;joenote - let's get this working again and put it to use
HalveSelectedStats:
	ld a, [H_WHOSETURN]
	and a
	ld a, [wPlayerStatsToHalve]
	ld hl, wBattleMonAttack
	jr z, .notEnemyTurn
	ld a, [wEnemyStatsToHalve]
	ld hl, wEnemyMonAttack
.notEnemyTurn
	ld c, 4
	ld b, a
.loop
	srl b
	call c, .halveStat
	inc hl
	inc hl
	dec c
	ret z
	jr .loop
.halveStat
	ld a, [hl]
	srl a
	ld [hli], a
	rr [hl]
	or [hl]
	jr nz, .nonzeroStat
	ld [hl], 1
.nonzeroStat
	dec hl
	ret	
	
	
	
;joenote - this function checks to see if a pkmn is paralyzed or burned
;then it doubles attack if burned or quadruples speed if paralyzed.
;It's meant to be run right before healing paralysis or burn so as to 
;undo the stat changes.
UndoBurnParStats:
	ld hl, wBattleMonStatus
	ld de, wPlayerStatsToDouble
	ld a, [H_WHOSETURN]
	and a
	jr z, .checkburn
	ld hl, wEnemyMonStatus
	ld de, wEnemyStatsToDouble
.checkburn
	ld a, [hl]		;load statuses
	and 1 << BRN	;test for burn 
	jr z, .checkpar
	ld a, $01
	ld [de], a	;set attack to be doubled to undo the stat change of BRN
	call DoubleSelectedStats
	jr .return
.checkpar
	ld a, [hl]		;load statuses
	and 1 << PAR	;test for paralyze 
	jr z, .return
	ld a, $04
	ld [de], a	;set speed to be doubled (done twice) to undo the stat change of BRN
	call DoubleSelectedStats
	call DoubleSelectedStats
.return
	xor a
	ld [de], a	;reset the stat change bits
	ret

	
CalculateModifiedStats:
	ld c, 0
.loop
	call CalculateModifiedStat
	inc c
	ld a, c
	cp NUM_STATS - 1
	jr nz, .loop
	ret

; calculate modified stat for stat c (0 = attack, 1 = defense, 2 = speed, 3 = special)
CalculateModifiedStat:
	push bc
	push bc
	ld a, [wCalculateWhoseStats]
	and a
	ld a, c
	ld hl, wBattleMonAttack
	ld de, wPlayerMonUnmodifiedAttack
	ld bc, wPlayerMonStatMods
	jr z, .next
	ld hl, wEnemyMonAttack
	ld de, wEnemyMonUnmodifiedAttack
	ld bc, wEnemyMonStatMods
.next
	add c
	ld c, a
	jr nc, .noCarry1
	inc b
.noCarry1
	ld a, [bc]
	pop bc
	ld b, a
	push bc
	sla c
	ld b, 0
	add hl, bc
	ld a, c
	add e
	ld e, a
	jr nc, .noCarry2
	inc d
.noCarry2
	pop bc
	push hl
	ld hl, StatModifierRatios
	dec b
	sla b
	ld c, b
	ld b, 0
	add hl, bc
	xor a
	ld [H_MULTIPLICAND], a
	ld a, [de]
	ld [H_MULTIPLICAND + 1], a
	inc de
	ld a, [de]
	ld [H_MULTIPLICAND + 2], a
	ld a, [hli]
	ld [H_MULTIPLIER], a
	call Multiply
	ld a, [hl]
	ld [H_DIVISOR], a
	ld b, $4
	call Divide
	pop hl
	ld a, [H_DIVIDEND + 3]
	sub 999 % $100
	ld a, [H_DIVIDEND + 2]
	sbc 999 / $100
	jp c, .storeNewStatValue
; cap the stat at 999
	ld a, 999 / $100
	ld [H_DIVIDEND + 2], a
	ld a, 999 % $100
	ld [H_DIVIDEND + 3], a
.storeNewStatValue
	ld a, [H_DIVIDEND + 2]
	ld [hli], a
	ld b, a
	ld a, [H_DIVIDEND + 3]
	ld [hl], a
	or b
	jr nz, .done
	inc [hl] ; if the stat is 0, bump it up to 1
.done
	pop bc
	ret

	

;This function automatically adjusts the stat quantities for critical hits.
;Normally, unmodified stats will be used.
;But if this would cause less damage an a non-crit hit, then the modified stats are used instead.
;BC is unmodified defensive stat. HL points to unmodified offensive stat.
CritHitStatsPlayerPhysical:
	ld a, 1
	jr CritHitStatsCommon
CritHitStatsPlayerSpecial:
	ld a, 2
	jr CritHitStatsCommon
CritHitStatsEnemyPhysical:
	ld a, 3
	jr CritHitStatsCommon
CritHitStatsEnemySpecial:
	ld a, 4
	;fall through to CritHitStatsCommon
CritHitStatsCommon:
	ld [wCriticalHitOrOHKO], a
	call GetPredefRegisters	
	push de
	call .saveatk
	
	call .reset
	;get unmodified defensive stat, divide by 4, and place it as a multiplier
	push bc
	call .BCdiv4
	ld [H_MULTIPLIER], a
	pop bc
	;get modified offensive stat, divide by 4, and place it as a multiplicand
	push hl
	call .get_modified_offense
	call .HLdiv4
	ld [H_MULTIPLICAND + 2], a
	pop hl
	;multiply the two together then divide by 2
	call Multiply
	ld a, [H_MULTIPLICAND + 2]
	ld e, a
	ld a, [H_MULTIPLICAND + 1]
	ld d, a
	srl d
	rr e
	;save result by pushing de
	push de

	call .reset
	;get modified defensive stat, divide by 4, and place it as a multiplier
	push bc
	call Get_modified_defense
	call .BCdiv4
	ld [H_MULTIPLIER], a
	pop bc
	;get unmodified offensive stat, divide by 4, and place it as a multiplicand
	push hl
	ld hl, hDivideBCDBuffer
	call .HLdiv4
	pop hl
	ld [H_MULTIPLICAND + 2], a
	;multiply the two together and retrieve the previously saved product
	call Multiply
	pop de
	
	;If the first product (in de) is >= the second product (in the hram product addresses), 
	;then the critical hit would do less damage than a non-crit attack.
	;If so, restore the modified stats to prevent this.
	push bc
	ld a, [H_MULTIPLICAND + 1]
	ld b, a
	ld a, [H_MULTIPLICAND + 2]
	ld c, a
	ld a, e
	sub c
	ld a, d
	sbc b
	pop bc
	call .restoreatk
	call nc, .restoreStats
	
	pop de
	ld a, $1
	ld [wCriticalHitOrOHKO], a
	ret
.reset
	xor a
	ld [H_PRODUCT], a
	ld [H_MULTIPLICAND], a
	ld [H_MULTIPLICAND + 1], a
	ld [H_MULTIPLICAND + 2], a
	ret
.saveatk
	ld a, [hli]
	ld [hDivideBCDBuffer], a
	ld a, [hld]
	ld [hDivideBCDBuffer + 1], a
	ret
.restoreatk
	ld a, [hDivideBCDBuffer]
	ld [hli], a
	ld a, [hDivideBCDBuffer + 1]
	ld [hld], a
	ret
.HLdiv4
	ld a, [hli]
	ld d, a
	ld a, [hld]
	ld e, a
	srl d
	rr e
	srl d
	rr e
	ld a, e
	ret
.BCdiv4
	srl b
	rr c
	srl b
	rr c
	ld a, c
	ret
.get_modified_offense
	ld a, [wCriticalHitOrOHKO]
	ld hl, wBattleMonAttack
	cp 1
	ret z
	ld hl, wBattleMonSpecial
	cp 2
	ret z
	ld hl, wEnemyMonAttack
	cp 3
	ret z
	ld hl, wEnemyMonSpecial
	ret
.restoreStats
	call Get_modified_defense
	call .get_modified_offense
	ret
Get_modified_defense:
	ld a, [wCriticalHitOrOHKO]
	cp 1
	jr z, .enemyDef
	cp 2
	jr z, .enemySpec
	cp 3
	jr z, .playerDef
.playerSpec
	ld a, [wBattleMonSpecial]
	ld b, a
	ld a, [wBattleMonSpecial + 1]
	ld c, a
	ld a, [wPlayerBattleStatus3]
	bit HAS_LIGHT_SCREEN_UP, a
	ret z
	jr .adjust_and_finish
.enemyDef
	ld a, [wEnemyMonDefense]
	ld b, a
	ld a, [wEnemyMonDefense + 1]
	ld c, a
	ld a, [wEnemyBattleStatus3]
	bit HAS_REFLECT_UP, a
	ret z
	jr .adjust_and_finish
.enemySpec
	ld a, [wEnemyMonSpecial]
	ld b, a
	ld a, [wEnemyMonSpecial + 1]
	ld c, a
	ld a, [wEnemyBattleStatus3]
	bit HAS_LIGHT_SCREEN_UP, a
	ret z
	jr .adjust_and_finish
.playerDef
	ld a, [wBattleMonDefense]
	ld b, a
	ld a, [wBattleMonDefense + 1]
	ld c, a
	ld a, [wPlayerBattleStatus3]
	bit HAS_REFLECT_UP, a
	ret z
.adjust_and_finish
	sla c
	rl b
	call _BC999cap
	ret

	
	
;joenote - caps the stat in bc to 999
BC999cap:
	call GetPredefRegisters
_BC999cap:
	;b register contains high byte & c register contains low byte
	ld a, c ;let's work on low byte first. Note that decimal 999 is $03E7 in hex.
	sub 999 % $100 ;a = a - ($03E7 % $100). Gives a = a - $E7. A byte % $100 always gives the lesser nibble.
	;Note that if a < $E7 then the carry bit 'c' in the flag register gets set due to overflowing with a negative result.
	ld a, b ;now let's work on the high byte
	sbc 999 / $100 ;a = a - ($03E7 / $100 + c_flag). Gives a = a - ($03 + c_flag). A byte / $100 always gives the greater nibble.
	;Note again that if a < $03 then the carry bit remains set. 
	;If the bit is already set from the lesser nibble, then its addition here can still make it remain set if a is low enough.
	jr c, .donecapping ;jump to next marker if the c_flag is set. This only remains set if BC <  the cap of $03E7.
	;else let's continue and set the 999 cap
	ld a, 999 / $100 ; else load $03 into a
	ld b, a ;and store it as the high byte
	ld a, 999 % $100 ; else load $E7 into a
	ld c, a ;and store it as the low byte
	;now registers b & c together contain $03E7 for a capped stat value of 999
.donecapping
	ret
