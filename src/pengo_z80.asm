;    0000-7fff ROM
;    8000-83ff Video RAM
;    8400-87ff Color RAM
;    8800-8fff RAM
;
;    memory mapped ports:
;
;    read:
;    9000      DSW1
;    9040      DSW0
;    9080      IN1
;    90c0      IN0
;
;    write:
;    8ff2-8ffd 6 pairs of two bytes:
;              the first byte contains the sprite image number (bits 2-7), Y flip (bit 0),
;              X flip (bit 1); the second byte the color
;    9005      sound voice 1 waveform (nibble)
;    9011-9013 sound voice 1 frequency (nibble)
;    9015      sound voice 1 volume (nibble)
;    900a      sound voice 2 waveform (nibble)
;    9016-9018 sound voice 2 frequency (nibble)
;    901a      sound voice 2 volume (nibble)
;    900f      sound voice 3 waveform (nibble)
;    901b-901d sound voice 3 frequency (nibble)
;    901f      sound voice 3 volume (nibble)
;    9022-902d Sprite coordinates, x/y pairs for 6 sprites
;    9040      interrupt enable
;    9041      sound enable
;    9042      palette bank selector
;    9043      flip screen
;    9044-9045 coin counters
;    9046      color lookup table bank selector
;    9047      character/sprite bank selector
;    9070      watchdog reset
;	
;	;; pengo
;	;; 33E6:	main A.I. routine to decrypt
;
;	pengo_moving_direction_8CF4:
;   $0: not moving
;   $8: up
;   $9: down
;   $A: left
;   $B: right
;   plus bit 2 set when breaking ice block/hitting wall (down+break = $D)

;	;; 8D00 -> 8D80 characters. snobees first then pengo & moving block
;	
;	+ 00:	x min 19 max D8 1 block = $8  (coords = 0: invisible)
;	+ 01:	y min 11 max F0 1 block = $10
;	+ 03:	snobee color
;	+ 04:	facing direction (0 up, 1 down, 2 left, 3 right)
;   + 05:   snobee/character index
;	+ 06:	instant move period (can be different from the one in 1C)
;	+ 07:	current period counter (increased automatically)
;	+ 09:
;	+ 0A:	stunned counter (used for stun/blinking stun)
;	+ 0B:	intermission related counter (used for animating pengos in intermission)
;   + 0C:   alive/walk counter (increases when pengo walks, snobee is alive)
;   + 10-11: path address pointer (demo/ice pack)
;	+ 1B:	 ?????
;	+ 1C:	move period for this level
;		pengo move period is 0A
;		easy level = 0C at act 1
;		medium level = 0B at act 1
;		hard = 0A (same speed as pengo at 1st level)
;		hardest = 09, 08 from act 5 (always faster than pengo)
;	+ 1D:	backup of 1E when block avoidance mode
;	+ 1E:	A.I. mode when 1F = 02
;		00 block avoidance mode (only active when a block is moving)
;	        01 roaming mode: wanders randomly, breaking no blocks, no hunt. But tries to avoid moving blocks
;	        02 block breaking mode:	wanders randomly, breaking all the blocks. Tries to avoid moving blocks that pengo throws
;		03 hunt mode 1:	X based (see description for details)
;		04 hunt mode 2:	exactly like 03 but y based
;		05 hunt mode 3:	combination of hunt modes 1 and 2: this is the most aggressive one, x & y based
;		06 roaming mode: same as 01
;		07 roaming mode: same as 01
;		08 hunt mode: same as 05
;		09 chicken mode: go up to reach upper border
;		0A chicken mode: go down to reach lower border
;		0B chicken mode: go left to reach left border
;		0C chicken mode: right to right border
;		0D chicken mode: on border, going up to corner
;		0E chicken mode: on border, going down to corner
;		0F chicken mode: on border, going left to corner
;		10 chicken mode: on border, going right to corner
;	
;	+ 1F:	behaviour (state machine, next state is state+1)
;	
;		00: dead, and no more eggs
;		01: alive and contemplating a move (static)
;		02: alive and moving
;		03: transition to stunned: keeps moving until aligned on grid
;		04: stunned (aligned on grid)
;		05: blinking stunned
;		06: stunned picked by pengo:	100 points
;		09  pushed by block (short transitions to 0A)
;		0A  pushed by block
;		0B  crushed by block
;		0C  crushed by block:	 gives 400/1600/... score
;		0D  about to hatch (short transitions to 0E)
;		0E  about to hatch (short transitions to 0F)
;		0F  hatching

x_pos = $0
y_pos = $01
animation_frame = $02
char_color = $03
facing_direction = $04
char_id = $05
instant_move_period = $06
current_period_counter = $07
unknown_09 = $09
; stunned counter for snobees, push block counter for pengo
stunned_push_block_counter = $0A
; maybe used for other misc snobees animations as well
intermission_dance_push_anim_counter = $0B
alive_walk_counter = $0C
path_address_pointer_or_misc_flags = $10
unknown_1A = $1A
unknown_1B = $1B
move_period = $1C
backup_ai_mode = $1D
ai_mode = $1E
char_state = $1F

	;; snobee move routine is "02_snobee_moving_33A5"
	;; the A.I. is done in handle_snobee_direction_change_33D8

	;; A.I. is handled as follows:
	;;
	;; - when eggs hatch at startup, behaviour is random from 8 possibles (code at $3CAE)
	;; - when stunned on a border/diamond align, if not killed, snobee
	;;   switches to 02:	 block breaking
	;; - when a snobee is killed and an egg hatches, game scans A.I. of
	;;   all alive snobees and sets one in 02: block breaking mode
	;;   if not already one in that state
	
	;; pengo struct 8D80 (shares a lot of members with snoobees)
	
;	+ 00:	x (coords = 0: invisible)
;	+ 01:	y
;	+ 02:	animation frame / sprite tile code
;	+ 03:	pengo color (can be changed, very funny effect!!)
;	+ 04:	facing direction 0:up,1:down,2:	left,3:	right
;	+ 05:	fixed to 5:	character index (pengo, change to sno bee with 0!)
;	+ 06:	speed (fixed to 0A, make it super fast by decreasing value!!)
;	+ 08:	moving FF=true 0=false
;	+ 0F:	fire pressed FF=true 0=false
;	+ 12:	saved number of seconds
;	+ 13:	saved number of minutes
;	+ 1E:	00$: alive, $FF: dead
;	+ 1F:	state.
;        1 stand-by (get ready)
;        2 walking
;        3 invalid state that reboots the game !!
;        4 breaking block
;        5 shaking wall
;        6 dying
;
;	;; moving block struct 8DA0 (Pengo can only push 1 block at a time)
;	+ 00:	x (coords = 0: invisible)
;	+ 01:	y
;	+ 04:	direction (0,1,2,3)
;	+ 0F:	number of snobee hit by this block
;	+ 1F:	00: not moving, 02: moving
	

	;; to stop music when playing game
	;; set 1875 to 1A instead of 19
	
	;; maze draw
	;; maze_data_8C20:
	;; 4 integer values
	;; offset 0:
	;; offset 1:
	;; offset 2:	current x
	;; offset 3:	current y

	;; eggs to hatch data:	 8DC0
	;; 00:	total number at level start
	;; 01:	current number
	;; data:	X (start=1)/ Y (start=2): divide by 2 to get real value
	;; coords are normal coord system (Y down)
	;; ex:	01 02 is top left corner
	;;      19 30 is bottom right corner
	;; set to 00 00 when hatched/destroyed
	;; 1F:	blink timer:	!= 0:	 blinking, = 0:	not blinking

INITIALISE_SYSTEM:
0000: 31 78 8F      ld   sp,stack_pointer_8FF0
0003: ED 56         im   1			; set interrupt mode to mode 1
0005: 21 28 A0      ld   hl,$0000
0008: 22 30 88      ld   (unknown_8830),hl
000B: C3 5C A3      jp   $03D4

000E:  .byte  $A0,$28

check_coin_inserted_0010:
0010: 3A 68 90      ld   a,(coin_input_90C0)
0013: 2F            cpl
0014: A0            and  b
0015: 28 07         jr   z,$001E
; coin inserted
0017: 7E            ld   a,(hl)
0018: A7            and  a
0019: 28 08         jr   z,$0023
001B: AF            xor  a
001C: 77            ld   (hl),a
001D: C9            ret
001E: CD B3 28      call $001B
0021: E1            pop  hl
0022: C9            ret

0023: 3E D7         ld   a,$FF
0025: 77            ld   (hl),a
0026: E1            pop  hl
0027: C9            ret

; main interrupt routine
0038: 08            ex  af,af'		; preserve AF registers
0039: D9            exx				; preserve HL,BC,DE registers
003A: DD E5         push ix			; preserve IX,IY registers 
003C: FD E5         push iy
003E: 2A 20 88      ld   hl,(cursor_x_8800)
0041: E5            push hl
0042: 3A A2 88      ld   a,(cursor_color_8802)
0045: F5            push af
0046: AF            xor  a
0047: 32 70 B8      ld   ($9070),a		; kick watchdog
004A: 32 E0 18      ld   (dip_switches_9040),a	; write 0: disable interrupts?
; decrease delay timers until 0 is reached, then they stay at 0
; those times are general purpose timers used throughout the game
; and loaded with various initialization values depending on the need
004D: 3A 20 88      ld   a,(delay_timer_8820)
0050: A7            and  a
0051: 28 04         jr   z,$0057		; if delay_timer_8820 == 0 goto $57
0053: 3D            dec  a				; else decrease it
0054: 32 00 88      ld   (delay_timer_8820),a	; and write it back
0057: 3A 21 A8      ld   a,(delay_timer_2_8821)	; same for other timer
005A: A7            and  a
005B: 28 04         jr   z,$0061				; skip if 0
005D: 3D            dec  a						; decrease it
005E: 32 01 88      ld   (delay_timer_2_8821),a	; and write it back
0061: 3A D7 AF      ld   a,($87FF)
0064: A7            and  a
0065: C2 B7 A1      jp   nz,$013F
0068: 2A 22 88      ld   hl,(timer_16bit_8822)
006B: 23            inc  hl
006C: 22 22 88      ld   (timer_16bit_8822),hl
006F: CD BC 12      call $32BC
0072: CD 0A 02      call coin_routine_02A2
0075: CD CD 22      call $02CD
0078: CD D7 02      call $027F
007B: CD B2 23      call $03B2
007E: CD 8A 2B      call $03AA
0081: 21 FB 8C      ld   hl,time_counter_8C5B
0084: 34            inc  (hl)
0085: 3E B5         ld   a,$3D	;  61 "microsecs"
0087: BE            cp   (hl)
0088: 30 B4         jr   nc,$009E
008A: 36 A0         ld   (hl),$00
008C: 23            inc  hl
008D: 34            inc  (hl)	;  1 more second
008E: 3E 13         ld   a,$3B	;  59 seconds
0090: BE            cp   (hl)
0091: 30 0B         jr   nc,$009E
0093: 36 00         ld   (hl),$00
0095: 23            inc  hl
0096: 34            inc  (hl)	;  1 more minute
0097: BE            cp   (hl)
0098: 30 24         jr   nc,$009E
; reset minute counter
009A: 36 20         ld   (hl),$00
009C: 23            inc  hl
; add hour, never called obviously as round "times out" before 2 minutes
; by monsters fleeing the scene
009D: 34            inc  (hl)
009E: 3E 20         ld   a,$00
00A0: DD 21 60 8C   ld   ix,sound_channel_0_struct_8C60
00A4: CD 99 BA      call update_sound_channel_1A99
00A7: 3E 29         ld   a,$01
00A9: DD 21 70 8C   ld   ix,sound_channel_1_struct_8C70
00AD: CD 99 92      call update_sound_channel_1A99
00B0: 3E 23         ld   a,$03
00B2: DD 21 90 AC   ld   ix,sound_channel_3_struct_8C90
00B6: CD B9 1A      call update_sound_channel_1A99
00B9: 3E 02         ld   a,$02
00BB: DD 21 28 8C   ld   ix,sound_channel_2_struct_8C80
00BF: CD 99 92      call update_sound_channel_1A99
00C2: 3E A4         ld   a,$04
00C4: DD 21 00 8C   ld   ix,sound_channel_4_struct_8CA0
00C8: CD 99 BA      call update_sound_channel_1A99
00CB: 21 20 8F      ld   hl,sound_related_8F20
00CE: 3A 1C 8C      ld   a,(sfx_1_playing)
00D1: A7            and  a
00D2: 28 23         jr   z,$00D7
00D4: 21 80 8F      ld   hl,sound_related_8F28
00D7: 11 06 AF      ld   de,sound_buffer_8F00+6
00DA: 01 25 00      ld   bc,$0005
00DD: ED B0         ldir
00DF: 7E            ld   a,(hl)
00E0: 32 B1 8F      ld   (sound_buffer_8F00+$11),a
00E3: 21 30 8F      ld   hl,sound_related_8F30
00E6: 3A 1D 8C      ld   a,(sfx_2_playing)
00E9: A7            and  a
00EA: 28 A3         jr   z,$00EF
00EC: 21 10 8F      ld   hl,sound_related_8F38
00EF: 11 0B AF      ld   de,sound_buffer_8F00+$B
00F2: 01 25 00      ld   bc,$0005
00F5: ED B0         ldir
00F7: 7E            ld   a,(hl)
00F8: 32 32 8F      ld   (sound_buffer_8F00+$12),a
00FB: 21 BF AC      ld   hl,sound_related_8CBF
00FE: CB 46         bit  0,(hl)
0100: 28 A5         jr   z,$010F
0102: CB 86         res  0,(hl)
; update sound status
0104: 21 80 87      ld   hl,sound_buffer_8F00
0107: 11 B8 10      ld   de,$9010
010A: 01 90 A8      ld   bc,$0010
010D: ED B0         ldir
010F: 3A 10 8F      ld   a,(sound_variable_8F10)
0112: CB 7F         bit  7,a
0114: 28 80         jr   z,$011E
0116: E6 A7         and  $07
0118: 32 B0 8F      ld   (sound_variable_8F10),a
011B: 32 05 B8      ld   ($9005),a
011E: 3A B1 87      ld   a,(sound_buffer_8F00+$11)
0121: CB 7F         bit  7,a
0123: 28 88         jr   z,$012D
0125: E6 AF         and  $07
0127: 32 B9 27      ld   (sound_buffer_8F00+$11),a
012A: 32 A2 B0      ld   ($900A),a
012D: 3A BA 27      ld   a,(sound_buffer_8F00+$12)
0130: CB 7F         bit  7,a
0132: 28 80         jr   z,$013C
0134: E6 A7         and  $07
0136: 32 B2 8F      ld   (sound_buffer_8F00+$12),a
0139: 32 0F B8      ld   ($900F),a
013C: CD BC 01      call useless_call_0194
013F: F1            pop  af
0140: 32 82 80      ld   (cursor_color_8802),a
0143: E1            pop  hl
0144: 22 80 80      ld   (cursor_x_8800),hl
0147: FD E1         pop  iy
0149: DD E1         pop  ix
014B: D9            exx
014C: CD F3 A9      call $015B
014F: CD 79 A1      call $0179
0152: 3E A1         ld   a,$01
0154: 32 E0 90      ld   (dip_switches_9040),a	; re-enable interrupts
0157: 08            ex   af,af'
0158: FB            ei
0159: ED 4D         reti		; end periodic interrupt (called at 0x38)

015B: 3A 19 88      ld   a,(currently_playing_8819)
015E: A7            and  a
015F: C0            ret  nz
0160: 3A A0 80      ld   a,(number_of_credits_8808)
0163: A7            and  a
0164: C8            ret  z
	;; start game (credits inserted)
0165: 3E A9         ld   a,$01
0167: 32 99 20      ld   (currently_playing_8819),a
016A: 31 58 87      ld   sp,stack_pointer_8FF0
016D: 21 B0 84      ld   hl,coin_has_been_inserted_0490
0170: E5            push hl
0171: 3E 01         ld   a,$01
0173: 32 40 B8      ld   (dip_switches_9040),a
0176: FB            ei
0177: ED 4D         reti
0179: 3A 80 B8      ld   a,($9080)
017C: 2F            cpl
017D: CB 67         bit  4,a
017F: C8            ret  z
0180: 3E 81         ld   a,$01
0182: 32 7F A7      ld   ($87FF),a
0185: 31 70 27      ld   sp,stack_pointer_8FF0
0188: 21 83 B8      ld   hl,$1003
018B: E5            push hl
018C: 3E 81         ld   a,$01
018E: 32 C0 90      ld   (dip_switches_9040),a
0191: FB            ei
0192: ED 4D         reti

useless_call_0194: 
0194: 3A 91 88      ld   a,(currently_playing_8819)
0197: A7            and  a
0198: C0            ret  nz		; return if game in play
0199: 3A C0 B8      ld   a,(coin_input_90C0)
019C: 2F            cpl			; flip all bits
019D: 47            ld   b,a
019E: E6 A1         and  $01
01A0: C8            ret  z

01A1: 3A A0 10      ld   a,($9080)
01A4: 2F            cpl
01A5: 4F            ld   c,a
01A6: E6 81         and  $01
01A8: C8            ret  z
01A9: CB 78         bit  7,b
01AB: C8            ret  z
01AC: CB 79         bit  7,c
01AE: C8            ret  z
01AF: 79            ld   a,c
01B0: E6 60         and  $60
01B2: C8            ret  z
01B3: 3E 01         ld   a,$01
01B5: 32 FF AF      ld   ($87FF),a
01B8: 31 78 8F      ld   sp,stack_pointer_8FF0
01BB: 21 C7 A1      ld   hl,display_team_names_01C7
01BE: E5            push hl
01BF: 3E A9         ld   a,$01
01C1: 32 E8 10      ld   (dip_switches_9040),a
01C4: FB            ei
01C5: ED 4D         reti

; looks like easter egg
display_team_names_01C7:
01C7: CD 65 A8      call clear_screen_and_colors_28E5
01CA: CD 1F 39      call clear_sprites_31B7
01CD: 21 56 81      ld   hl,$01FE
01D0: CD 7C 29      call print_line_typewriter_style_29F4
01D3: CD F4 01      call print_line_typewriter_style_29F4
01D6: 21 94 02      ld   hl,$021C
01D9: CD F4 01      call print_line_typewriter_style_29F4
01DC: CD 7C 29      call print_line_typewriter_style_29F4
01DF: 21 1D 82      ld   hl,$023D
01E2: CD 5C 09      call print_line_typewriter_style_29F4
01E5: CD 74 A9      call print_line_typewriter_style_29F4
01E8: 21 F1 AA      ld   hl,$0259
01EB: CD 74 A9      call print_line_typewriter_style_29F4
01EE: CD 5C 29      call print_line_typewriter_style_29F4
01F1: 3E FF         ld   a,$FF
01F3: CD D1 00      call delay_28D1
01F6: 3E 80         ld   a,$08
01F8: CD E6 13      call $1346
01FB: C3 00 A0      jp   $0000

01FE  02 02 18 44 49 52 45 43 54 45 44 20 42 D9 03 04   ...DIRECTED BÙ..
020E  10 4E 4F 42 55 4F 20 20 4B 4F 44 45 52 C1 02 0B   .NOBUO  KODERÁ..
021E  18 50 52 4F 47 52 41 4D 45 44 20 42 D9 03 0D 10   .PROGRAMED BÙ...
022E  41 4B 49 52 41 20 20 4E 41 4B 41 4B 55 4D C1 02   AKIRA  NAKAKUMÁ.
023E  14 18 44 45 53 49 47 4E 45 44 20 42 D9 03 16 10   ..DESIGNED BÙ...
024E  53 48 49 4E 4A 49 20 20 45 47 C9 02 1E 10 43 4F   SHINJI  EGÉ...CO
025E  52 45 4C 41 4E 44 20 54 45 43 48 4E 4F 4C 4F 47   RELAND TECHNOLOG
026E  59 20 49 4E 43 BA 12 20 16 31 39 38 32 3A 39 3A   Y INCº. .1982:9:
027E  B1

027F: 3A 48 B8      ld   a,(coin_input_90C0)
0282: 2F            cpl
0283: E6 68         and  $40
0285: C8            ret  z
; small cpu active delay loop
0286: 06 A0         ld   b,$00
0288: 10 5E         djnz $0288
028A: 10 5E         djnz $028A
028C: 3A E8 18      ld   a,(coin_input_90C0)
028F: 2F            cpl
0290: E6 60         and  $40
0292: C8            ret  z
0293: 3A C0 38      ld   a,(coin_input_90C0)
0296: 2F            cpl
0297: E6 40         and  $40
0299: 20 F8         jr   nz,$0293
029B: 21 08 A8      ld   hl,number_of_credits_8808
029E: 34            inc  (hl)
029F: C3 8B A3      jp   $038B
coin_routine_02A2:
02A2: 21 30 88      ld   hl,unknown_8830
02A5: 06 38         ld   b,$10
02A7: CD 38 A0      call check_coin_inserted_0010
02AA: 00            nop
02AB: 00            nop
02AC: 00            nop
02AD: 00            nop
02AE: 00            nop
02AF: 00            nop
02B0: 00            nop
02B1: 00            nop
02B2: 00            nop
02B3: 00            nop
02B4: 00            nop
02B5: 00            nop
02B6: 3A 68 90      ld   a,(coin_input_90C0)
02B9: 2F            cpl
02BA: E6 30         and  $10
02BC: 20 D8         jr   nz,$02B6
02BE: 21 B4 88      ld   hl,unknown_881C
02C1: 34            inc  (hl)
02C2: 21 81 88      ld   hl,unknown_8809
02C5: 3A 28 B8      ld   a,(dsw_1_9000_coinage)
02C8: 2F            cpl
02C9: E6 AF         and  $0F
02CB: 18 B2         jr   $0307
02CD: 21 31 88      ld   hl,unknown_8830+1
02D0: 06 00         ld   b,$20
02D2: CD 30 00      call check_coin_inserted_0010
02D5: 00            nop
02D6: 00            nop
02D7: 00            nop
02D8: 00            nop
02D9: 00            nop
02DA: 00            nop
02DB: 00            nop
02DC: 00            nop
02DD: 00            nop
02DE: 00            nop
02DF: 00            nop
02E0: 00            nop
02E1: 3A 48 B8      ld   a,(coin_input_90C0)
02E4: 2F            cpl
02E5: E6 20         and  $20
02E7: 20 D0         jr   nz,$02E1
02E9: 21 BE 88      ld   hl,unknown_881E
02EC: 34            inc  (hl)
02ED: 21 AA 88      ld   hl,unknown_880a
02F0: 3A 20 90      ld   a,(dsw_1_9000_coinage)
02F3: 2F            cpl
02F4: E6 A7         and  $0F
02F6: 47            ld   b,a
02F7: 3A 00 38      ld   a,(dsw_1_9000_coinage)
02FA: 2F            cpl
02FB: 0F            rrca
02FC: 0F            rrca
02FD: 0F            rrca
02FE: 0F            rrca
02FF: E6 8F         and  $0F
0301: B8            cp   b
0302: 20 83         jr   nz,$0307
0304: 21 A1 80      ld   hl,unknown_8809
0307: 01 83 83      ld   bc,$038B
030A: C5            push bc
030B: E5            push hl
030C: 4E            ld   c,(hl)
030D: 0C            inc  c
030E: 71            ld   (hl),c
030F: 87            add  a,a
0310: 21 05 03      ld   hl,table_032D
0313: 5F            ld   e,a
0314: 16 A0         ld   d,$00
0316: 19            add  hl,de
0317: 5E            ld   e,(hl)
0318: 23            inc  hl
0319: 56            ld   d,(hl)
031A: 69            ld   l,c
031B: 26 00         ld   h,$00
031D: 19            add  hl,de
031E: E5            push hl
031F: 7E            ld   a,(hl)
0320: 21 A0 80      ld   hl,number_of_credits_8808
0323: 86            add  a,(hl)
0324: 77            ld   (hl),a
0325: E1            pop  hl
0326: 23            inc  hl
0327: 7E            ld   a,(hl)
0328: 3C            inc  a
0329: E1            pop  hl
032A: C0            ret  nz
032B: 77            ld   (hl),a
032C: C9            ret

table_032D:
	.word	l_034D+$85-$4D 
	.word	l_034D+$61-$4D 
	.word	l_034D+$71-$4D  
	.word	l_034D+$59-$4D  
	.word	l_034D+$7C-$4D 
	.word	l_034D+$5D-$4D 
	.word	l_034D+$65-$4D 
	.word	l_034D+$52-$4D 
	.word	l_034D+$7F-$4D 
	.word	l_034D+$5F-$4D 
	.word	l_034D+$6C-$4D 
	.word	l_034D+$56-$4D 
	.word	l_034D+$77-$4D 
	.word	l_034D+$5B-$4D  
	.word	l_034D+$63-$4D  
	.word	l_034D 

l_034D:
FF 00 00 00 01 FF 00 00 01 FF 00 01 FF 01 FF 02
FF 03 FF 04 FF 05 FF 06 FF 00 01 00 01 01 01 FF
00 01 00 02 FF 01 01 01 01 02 FF 01 01 01 02 FF
01 02 FF 02 02 02 02 03 FF 02 02 02 03 FF

038B: 06 A8         ld   b,$00		; credit inserted sound
038D: CD 81 B0      call play_sfx_1889
0390: 21 83 88      ld   hl,unknown_880B
0393: CB 7E         bit  7,(hl)
0395: C8            ret  z
0396: CD 52 2B      call display_number_of_credits_2B7A
0399: 21 97 02      ld   hl,one_or_two_player_string_2A97
039C: 3A 80 88      ld   a,(number_of_credits_8808)
039F: FE A9         cp   $01
03A1: 20 AB         jr   nz,$03A6
03A3: 21 00 AA      ld   hl,one_player_only_string_2AA8
03A6: CD 5C 09      call print_line_typewriter_style_29F4
03A9: C9            ret

03AA: 21 B6 80      ld   hl,unknown_881E
03AD: 11 ED 10      ld   de,coin_counter_9045
03B0: 18 A6         jr   $03B8

03B2: 21 94 88      ld   hl,unknown_881C
03B5: 11 44 B8      ld   de,coin_counter_9044
03B8: 7E            ld   a,(hl)
03B9: A7            and  a
03BA: C8            ret  z
03BB: 23            inc  hl
03BC: 7E            ld   a,(hl)
03BD: CB 7F         bit  7,a
03BF: 20 AE         jr   nz,$03C7
03C1: 36 82         ld   (hl),$8A
03C3: 3E A9         ld   a,$01
03C5: 12            ld   (de),a
03C6: C9            ret
03C7: E6 5F         and  $7F
03C9: 28 AA         jr   z,$03CD
03CB: 35            dec  (hl)
03CC: C9            ret
03CD: 36 A8         ld   (hl),$00
03CF: 2B            dec  hl
03D0: 35            dec  (hl)
03D1: AF            xor  a
03D2: 12            ld   (de),a
03D3: C9            ret
03D4: 21 A0 90      ld   hl,dsw_1_9000_coinage
03D7: 06 20         ld   b,$20
03D9: 36 00         ld   (hl),$00
03DB: 23            inc  hl
03DC: 10 5B         djnz $03D9
; zero a lot of hardware stuff
03DE: AF            xor  a
03DF: 32 E8 10      ld   (dip_switches_9040),a
03E2: 32 C1 B0      ld   (sound_enable_9041),a
03E5: 32 EB 10      ld   (flip_screen_9043),a
03E8: 32 C4 B0      ld   (coin_counter_9044),a
03EB: 32 ED 10      ld   (coin_counter_9045),a
03EE: 32 C7 90      ld   (character_sprite_bank_selector_9047),a
03F1: 32 42 B8      ld   (palette_bank_selector_9042),a
03F4: 32 E6 90      ld   (color_lookup_table_bank_selector_9046),a
03F7: AF            xor  a
03F8: 21 A0 00      ld   hl,$0000
; zero a lot of global counters
03FB: 32 08 88      ld   (number_of_credits_8808),a
03FE: 22 81 88      ld   (unknown_8809),hl
0401: 32 AB 88      ld   (unknown_880B),a
0404: 22 94 88      ld   (unknown_881C),hl
0407: 22 BE 88      ld   (unknown_881E),hl
040A: 21 60 8C      ld   hl,sound_channel_0_struct_8C60
040D: 11 61 8C      ld   de,sound_channel_0_struct_8C60+1
0410: 01 F7 00      ld   bc,$005F
0413: 36 00         ld   (hl),$00
0415: ED B0         ldir
0417: 21 00 AF      ld   hl,sound_buffer_8F00
041A: 11 21 8F      ld   de,sound_buffer_8F00+1
041D: 01 3F 20      ld   bc,$003F
0420: 36 A0         ld   (hl),$00
0422: ED B0         ldir
0424: CD 4C B8      call enable_sound_18EC
0427: AF            xor  a
0428: 32 5F 0F      ld   ($87FF),a
042B: 3E 29         ld   a,$01
042D: 32 68 B8      ld   (dip_switches_9040),a
0430: FB            ei
0431: AF            xor  a
0432: 32 80 88      ld   (unknown_8828),a
0435: 32 29 A8      ld   (unknown_8829),a
0438: 21 20 00      ld   hl,$0000
043B: 22 0E A8      ld   (player_1_score_880E),hl
043E: 22 30 88      ld   (player_2_score_8810),hl
0441: 21 58 A7      ld   hl,$07D0
0444: 22 84 88      ld   (high_score_880C),hl
0447: CD 68 25      call init_highscore_table_2540
044A: 3A E0 18      ld   a,(dip_switches_9040)
044D: 2F            cpl
044E: 06 A0         ld   b,$00
0450: CB 57         bit  2,a
0452: 20 22         jr   nz,$0456
0454: 06 21         ld   b,$01
0456: 78            ld   a,b
0457: 32 18 A8      ld   (cocktail_mode_8818),a
045A: 3E 20         ld   a,$00
045C: 32 37 88      ld   (game_playing_8817),a
	;; initialize random number generator with $365A value
045F: 21 FA 36      ld   hl,$365A
0462: 22 26 88      ld   (random_seed_8826),hl
0465: 21 28 A8      ld   hl,video_tile_memory_8000
0468: 11 78 D7      ld   de,$FFF0
046B: A7            and  a
046C: 19            add  hl,de
046D: E5            push hl
046E: C1            pop  bc
046F: 2A 28 A8      ld   hl,(unknown_8828)
; WTF ?? protection routine to compute a checksum?
; or just memory test?
0472: CD 30 05      call wierd_memory_check_510
; exiting, a = 0xFC
0475: 32 2A A8      ld   (weird_variable_882A),a
	
loop_0478:
0478: 3E 20         ld   a,$00
047A: 32 B1 88      ld   (currently_playing_8819),a
047D: CD A0 24      call display_thanks_for_playing_04A0

	;;; loop
	
loop_0480:
0480: CD 21 2D      call display_title_screen_0521
0483: CD CB 22      call pack_ice_screen_22CB
0486: CD 69 2E      call display_demo_and_top_scores_6E1
0489: 3E 08         ld   a,$80
048B: CD 59 00      call delay_28D1
048E: 28 78         jr   z,loop_0480

;;; coin has been inserted
	
0490: 3E 20         ld   a,$00
0492: 32 67 90      ld   (character_sprite_bank_selector_9047),a
0495: 32 42 38      ld   (palette_bank_selector_9042),a
0498: 32 66 90      ld   (color_lookup_table_bank_selector_9046),a
049B: CD 2D 27      call wait_for_start_and_play_072D
;;; after game is over, loop back to "thanks for playing ..."
049E: 18 F8         jr   loop_0478

display_thanks_for_playing_04A0:
04A0: CD 6D A0      call clear_screen_and_colors_28E5
04A3: CD 17 31      call clear_sprites_31B7
04A6: CD B0 A3      call update_all_scores_2B10
04A9: 3A 5B A4      ld   a,table_04D0+3
04AC: FE 20         cp   $20
04AE: C0            ret  nz
04AF: 21 D0 24      ld   hl,table_04D0
04B2: CD 5C 29      call print_line_typewriter_style_29F4
; this part is an anti-tampering check in case a bootleg
; changes text here. It checks
; for space character but if not space, returns to bogus address
; push hl without pop hl
04B5: E5            push hl
04B6: 11 23 00      ld   de,$0003
04B9: 19            add  hl,de
04BA: 3E 00         ld   a,$20
04BC: BE            cp   (hl)
04BD: C0            ret  nz
04BE: E1            pop  hl
04BF: CD 54 01      call print_line_typewriter_style_29F4
04C2: 3E E0         ld   a,$40
04C4: CD F9 A0      call delay_28D1
04C7: CD 54 01      call print_line_typewriter_style_29F4
04CA: 3E E8         ld   a,$C0
04CC: CD F9 A0      call delay_28D1
04CF: C9            ret

table_04D0:
     dc.b	0x02,0x0A,0x90,0x20,0x20,0x20,0x20,0x20,0xA0,0x02,0x0D,0x90,0x20,0x20,0x20,0x54   | ......   T
     dc.b	0x48,0x41,0x4E,0x4B,0x53,0x20,0x46,0x4F,0x52,0x20,0x50,0x4C,0x41,0x59,0x49,0x4E   | HANKS FOR PLAYIN
     dc.b	0x47,0x3A,0x20,0xA0,0x02,0x10,0x90,0x20,0x20,0x20,0x20,0x20,0x54,0x52,0x59,0x20   | G:...     TRY
     dc.b	0x4F,0x4E,0x43,0x45,0x20,0x4D,0x4F,0x52,0x45,0x20,0x3D,0x20,0x20,0x20,0x20,0xA0   | ONCE MORE =

wierd_memory_check_510:
0510: AF            xor  a
0511: 86            add  a,(hl)
0512: 23            inc  hl
0513: CB 45         bit  0,l
0515: 28 01         jr   z,$0518
0517: 2F            cpl
0518: 0B            dec  bc
0519: 5F            ld   e,a
051A: 78            ld   a,b
051B: B1            or   c
051C: 7B            ld   a,e
051D: 20 F2         jr   nz,$0511
051F: 77            ld   (hl),a
0520: C9            ret

display_title_screen_0521:
0521: 3E A8         ld   a,$00
0523: 32 BE 20      ld   (player_number_8816),a
0526: CD 4D 08      call clear_screen_and_colors_28E5
0529: CD 37 99      call clear_sprites_31B7
052C: CD 90 0B      call update_all_scores_2B10
052F: CD BE A5      call draw_sega_logo_05BE
0532: 21 52 05      ld   hl,squash_snobee_msg_57A
; anti text-hack check (there are several text checks in the game)
0535: E5            push hl
0536: 11 A3 00      ld   de,$0003
0539: 19            add  hl,de
053A: 7E            ld   a,(hl)
053B: FE 53         cp   $53
053D: 20 E2         jr   nz,display_title_screen_0521
053F: E1            pop  hl
0540: CD 5C 09      call print_line_typewriter_style_29F4
0543: 21 B0 85      ld   hl,pengo_string_590
0546: CD 5C 09      call print_line_typewriter_style_29F4
0549: 21 90 85      ld   hl,snoobee_string_0598
054C: CD 5C 09      call print_line_typewriter_style_29F4
054F: 26 12         ld   h,$12
0551: 2E 07         ld   l,$07
0553: 22 00 88      ld   (cursor_x_8800),hl
0556: 3E 81         ld   a,$09
0558: 32 A2 88      ld   (cursor_color_8802),a
055B: CD FE 06      call draw_ice_block_tile_2EFE
055E: 21 2A AD      ld   hl,iceblock_string_05A2
0561: CD 74 A9      call print_line_typewriter_style_29F4
0564: 06 96         ld   b,$16
0566: 0E 87         ld   c,$07
0568: 3E A1         ld   a,$09
056A: 32 82 80      ld   (cursor_color_8802),a
056D: CD 01 AF      call set_diamond_position_2FA9
0570: 21 0E 05      ld   hl,diamondblock_string_05AE
0573: CD F4 01      call print_line_typewriter_style_29F4
; snobees appear and drag the title
0576: CD 01 1D      call pengo_intermission_or_title_1D29
0579: C9            ret
squash_snobee_msg_57A:
  05 06 91 53 51 55 41 53 48 20 54 48 45 20 53 4E   ...SQUASH THE SNO?BEEÓ
pengo_string_590:
  4F 3F 42 45 45 D3 0C 0B 91 50 45 4E 47 CF   ; ...PENGÏ
snoobee_string_0598: 0C 0F 98 53 4E 4F 3F 42 45 C5   ; .SNO?BEÅ...ICE B
iceblock_string_05A2: 0C 13 91 49 43 45 20 42 4C 4F 43 CB
diamondblock_string_05AE:  0C 17 98 44 49 41 4D 4F 4E 44 20 42 4C 4F 43 CB   ; ...DIAMOND BLOCË




draw_sega_logo_05BE:
05BE: 3E 81			ld   a,$09                                          
05C0: 32 82 80      ld   (cursor_color_8802),a
05C3: 3E 70         ld   a,$F0
05C5: 21 89 B3      ld   hl,$1B09
05C8: 22 80 80      ld   (cursor_x_8800),hl
05CB: CD A8 AF      call set_2x2_tile_2F00
05CE: 21 A3 1B      ld   hl,$1B0B
05D1: 22 00 88      ld   (cursor_x_8800),hl
05D4: CD A0 2F      call set_2x2_tile_2F00
05D7: 21 0D 93      ld   hl,$1B0D
05DA: 22 A0 88      ld   (cursor_x_8800),hl
05DD: CD 00 07      call set_2x2_tile_2F00
05E0: 21 A7 9B      ld   hl,$1B0F
05E3: 22 A8 20      ld   (cursor_x_8800),hl
05E6: CD 80 0F      call set_2x2_tile_2F00
05E9: 3E 94         ld   a,$9C
05EB: 21 89 B5      ld   hl,$1D09
05EE: 22 80 88      ld   (cursor_x_8800),hl
05F1: CD 0C A6      call set_4_consecutive_tiles_in_a_row_060C
05F4: 3E D4         ld   a,$5C
05F6: CD 84 06      call set_4_consecutive_tiles_in_a_row_060C
05F9: 21 11 93      ld   hl,$1B11
05FC: 22 A0 88      ld   (cursor_x_8800),hl
05FF: 3E 22         ld   a,$22		; (R) registered char
0601: CD B4 01      call set_tile_at_current_pos_293C
0604: 3C            inc  a			; bottom of (R) char
0605: CD B9 01      call move_cursor_1_2919
0608: CD 14 A1      call set_tile_at_current_pos_293C
060B: C9            ret

set_4_consecutive_tiles_in_a_row_060C:
060C: 06 A4         ld   b,$04
060E: CD 14 29      call set_tile_at_current_pos_293C
0611: 3C            inc  a
0612: 10 DA         djnz $060E
0614: C9            ret

draw_pengo_title_0615:
0615: 3E 00         ld   a,$00
0617: 32 02 A8      ld   (cursor_color_8802),a
061A: 21 50 06      ld   hl,table_0670
061D: 16 A0         ld   d,$A0
061F: 06 A8         ld   b,$08
0621: C5            push bc
0622: 3E A7         ld   a,$07
0624: 90            sub  b
0625: C6 2A         add  a,$02
0627: 47            ld   b,a
0628: 0E A5         ld   c,$05
062A: ED 43 28 88   ld   (cursor_x_8800),bc
062E: 7E            ld   a,(hl)
062F: 23            inc  hl
0630: A7            and  a
0631: 28 39         jr   z,$066C
0633: 47            ld   b,a
0634: CB 7F         bit  7,a
0636: 20 A5         jr   nz,$0645
0638: CB 77         bit  6,a
063A: 20 35         jr   nz,$0651
063C: 7A            ld   a,d
063D: CD 3C 81      call set_tile_at_current_pos_293C
0640: 14            inc  d
0641: 10 D1         djnz $063C
0643: 18 C1         jr   $062E
0645: E6 AF         and  $0F
0647: 47            ld   b,a
0648: 3E 20         ld   a,$20
064A: CD 14 A1      call set_tile_at_current_pos_293C
064D: 10 D3         djnz $064A
064F: 18 DD         jr   $062E
0651: E6 0F         and  $0F
0653: E5            push hl
0654: D5            push de
0655: 21 64 26      ld   hl,table_0664
0658: 16 20         ld   d,$00
065A: 5F            ld   e,a
065B: 19            add  hl,de
065C: 7E            ld   a,(hl)
065D: D1            pop  de
065E: E1            pop  hl
065F: CD B4 01      call set_tile_at_current_pos_293C
0662: 18 CA         jr   $062E
table_0664:
	A3 A8 C0 CD D3 E4 E8 E9
	
066C: C1			pop  bc                                             
066D: 10 12			djnz $0621                                          
066F: C9			ret                                                 
	
table_0670:
     0670  06 00 04 41 01 88 03 00 02 41 0A 40 04 00 01 41
     0680  03 41 03 41 41 02 41 04 00 01 41 41 01 41 01 41
     0690  01 41 01 41 01 41 02 41 41 01 00 01 41 41 01 41
     06A0  03 41 03 41 41 02 41 01 00 01 41 02 41 41 06 43
     06B0  41 44 02 00 01 42 01 81 46 47 84 02 42 45 01 00


;;;
display_top_scores_6C0: 
0C60: 3E A0         ld  a,$00
06C2: 32 E3 18      ld   (flip_screen_9043),a		; set normal mode (not cocktail)
06C5: CD 45 00      call clear_screen_and_colors_28E5
06C8: CD 3F 31      call clear_sprites_31B7
06CB: CD 38 03      call update_all_scores_2B10
06CE: CD 44 27      call display_highs_276C
; another protection against text-tampering (bootleg versions)
06D1: 21 7E 25      ld   hl,$057E
06D4: 7E            ld   a,(hl)
06D5: FE 51         cp   $51
06D7: 20 06         jr   nz,$06DF	; crashes the CPU
06D9: 3E FF         ld   a,$FF
06DB: CD D1 80      call delay_28D1
06DE: C9            ret
; tamper with stack and return in the woods: crash
06DF: E1            pop  hl
06E0: C9            ret
	;; demo mode
display_demo_and_top_scores_6E1:
06E1: 3E 2D         ld   a,$05
06E3: 32 3A 88      ld   (level_number_player1_8812),a
06E6: 32 B3 88      ld   (level_number_player2_8813),a
	;; set main counter to 0
06E9: 21 28 A0      ld   hl,$0000
06EC: 22 24 88      ld   (counter_lsb_8824),hl
	;; init number of lives
06EF: 3A 40 38      ld   a,(dip_switches_9040)
06F2: 2F            cpl
06F3: E6 18         and  $18
06F5: 0F            rrca
06F6: 0F            rrca
06F7: 0F            rrca
06F8: C6 22         add  a,$02
06FA: 32 34 88      ld   (lives_counter_p1_8814),a
06FD: 32 15 A8      ld   (lives_counter_p2_8815),a
0700: AF            xor  a
0701: 32 BE 20      ld   (player_number_8816),a
0704: 2A 8E 80      ld   hl,(random_seed_8826)
0707: 22 70 24      ld   (random_seed_backup_8CF0),hl ; backup random seed?
	;; init random number generator to the same value so demo mode
	;; works properly
070A: 21 F2 3E      ld   hl,$365A
070D: 22 2E 20      ld   (random_seed_8826),hl
; choose demo sequence 1 or 2 depending on bit 0 of demo_run_counter_8CF6
	;; demo sequence 1
0710: 11 A0 64      ld   de,move_table_6400
0713: 21 F6 8C      ld   hl,demo_run_counter_8CF6
0716: 34            inc  (hl)
0717: CB 46         bit  0,(hl)
0719: 28 03         jr   z,$071E
	;; demo sequence 2
071B: 11 00 66      ld   de,move_table_6600
071E: ED 53 72 24   ld   (demo_move_table_pointer_8CF2),de
0722: AF            xor  a
0723: 32 75 24      ld   (demo_mode_var_8CF5),a
0726: CD AD 89      call run_one_life_092D
0729: CD E0 86      call display_top_scores_6C0
072C: C9            ret

	
wait_for_start_and_play_072D:
072D: 3A 88 20      ld   a,(number_of_credits_8808)
0730: A7            and  a
0731: C8            ret  z
0732: AF            xor  a
0733: 32 16 88      ld   (player_number_8816),a
0736: CD 6D 28      call clear_screen_and_colors_28E5
0739: CD 10 03      call update_all_scores_2B10
073C: CD 04 2A      call $2A2C
073F: 21 8B 20      ld   hl,unknown_880B
0742: CB FE         set  7,(hl)
0744: E5            push hl
0745: CD 7C 87      call wait_for_start_0774
;;; game start
0748: E1            pop  hl
0749: CB BE         res  7,(hl)
074B: 3E 57         ld   a,$FF
074D: 32 BF 20      ld   (game_playing_8817),a
0750: CD 55 08      call play_one_game_087D
0753: AF            xor  a
0754: 32 B7 88      ld   (game_playing_8817),a
0757: 32 43 B8      ld   (flip_screen_9043),a
075A: 21 A0 88      ld   hl,cursor_x_8800
075D: 11 2A A0      ld   de,$002A
0760: A7            and  a
0761: 19            add  hl,de
0762: 46            ld   b,(hl)
0763: 3A 0A 20      ld   a,(weird_variable_882A)
0766: B8            cp   b
0767: CA 0D 87      jp   z,wait_for_start_and_play_072D
076A: AF            xor  a
076B: 2F            cpl
076C: 21 80 80      ld   hl,cursor_x_8800
076F: 2B            dec  hl
0770: 77            ld   (hl),a
0771: C3 2D A7      jp   wait_for_start_and_play_072D

wait_for_start_0774:
0774: CD 3F 31      call clear_sprites_31B7
	;; initialize pengo structure

0777: DD 21 A8 8D   ld   ix,pengo_struct_8D80
077B: DD 36 A0 B0   ld   (ix+x_pos),$B0 ; 176
077F: DD 36 81 D8   ld   (ix+y_pos),$58 ; 88
0783: DD 36 83 8B   ld   (ix+char_color),$0B
0787: DD 36 84 AA   ld   (ix+facing_direction),$02	; facing direction
078B: DD 36 85 AD   ld   (ix+char_id),$05	; ID of Pengo is 5
078F: DD 36 81 00   ld   (ix+$09),$00
0793: DD 36 83 00   ld   (ix+intermission_dance_push_anim_counter),$00
0797: CD CE 33      call display_snobee_sprite_33CE
079A: CD 0B 39      call set_character_sprite_code_and_color_39AB
079D: CD 75 80      call increase_counter_0875
07A0: CD B1 88      call $0819
07A3: 3A A0 10      ld   a,(dip_switches_9080)
07A6: 2F            cpl
07A7: E6 68         and  $60
07A9: 28 72         jr   z,$079D
07AB: CB 77         bit  6,a
07AD: 20 8D         jr   nz,$07BC
07AF: 21 08 88      ld   hl,number_of_credits_8808
07B2: 35            dec  (hl)
07B3: 3E 00         ld   a,$00
07B5: 32 16 88      ld   (player_number_8816),a
07B8: CD F9 07      call $07D1
07BB: C9            ret
07BC: 3A 80 88      ld   a,(number_of_credits_8808)
07BF: FE A9         cp   $01
07C1: 28 D2         jr   z,$079D
07C3: 21 88 20      ld   hl,number_of_credits_8808
07C6: 35            dec  (hl)
07C7: 35            dec  (hl)
07C8: 3E 00         ld   a,$80
07CA: 32 96 80      ld   (player_number_8816),a
07CD: CD F1 87      call $07D1
07D0: C9            ret
07D1: 3A 00 B8      ld   a,(dsw_1_9000_coinage)
07D4: 2F            cpl
07D5: E6 0F         and  $0F
07D7: 21 09 88      ld   hl,unknown_8809
07DA: CD 5B 07      call $07FB
07DD: 21 0A 88      ld   hl,unknown_880a
07E0: 3A 80 B0      ld   a,(dsw_1_9000_coinage)
07E3: 2F            cpl
07E4: E6 A7         and  $0F
07E6: 47            ld   b,a
07E7: 3A A8 10      ld   a,(dsw_1_9000_coinage)
07EA: 2F            cpl
07EB: 0F            rrca
07EC: 0F            rrca
07ED: 0F            rrca
07EE: 0F            rrca
07EF: E6 0F         and  $0F
07F1: B8            cp   b
07F2: 20 A3         jr   nz,$07F7
07F4: 21 81 88      ld   hl,unknown_8809
07F7: CD FB A7      call $07FB
07FA: C9            ret
07FB: E5            push hl
07FC: 4E            ld   c,(hl)
07FD: 87            add  a,a
07FE: 21 05 2B      ld   hl,table_032D
0801: 5F            ld   e,a
0802: 16 A0         ld   d,$00
0804: 19            add  hl,de
0805: 5E            ld   e,(hl)
0806: 23            inc  hl
0807: 56            ld   d,(hl)
0808: 69            ld   l,c
0809: 26 28         ld   h,$00
080B: 19            add  hl,de
080C: 0E A0         ld   c,$00
080E: 7E            ld   a,(hl)
080F: B7            or   a
0810: 20 24         jr   nz,$0816
0812: 0C            inc  c
0813: 2B            dec  hl
0814: 18 D8         jr   $080E
0816: E1            pop  hl
0817: 71            ld   (hl),c
0818: C9            ret
	
0819: DD 7E A3      ld   a,(ix+intermission_dance_push_anim_counter)
081C: 11 02 08      ld   de,table_0822
081F: C3 8F 05      jp   indirect_jump_2D8F

table_0822:
	 dc.w	block_pushed_3FFA
	 dc.w	$0830
	 dc.w	$085C
	 dc.w	block_pushed_401F
	 dc.w	$0846
	 dc.w	$085C
	 dc.w	$0870

0830: 26 A4         ld   h,$0C
0832: 2E 33         ld   l,$13
0834: 22 20 88      ld   (cursor_x_8800),hl
0837: CD 00 81      call put_blank_at_current_pos_2900
083A: CD B1 29      call move_cursor_1_2919
083D: 3E 4E         ld   a,$4E
083F: CD B4 01      call set_tile_at_current_pos_293C
0842: DD 34 AB      inc  (ix+intermission_dance_push_anim_counter)
0845: C9            ret

0846: 26 84         ld   h,$0C
0848: 2E B3         ld   l,$13
084A: 22 A0 88      ld   (cursor_x_8800),hl
084D: 3E EE         ld   a,$4E
084F: CD 3C 81      call set_tile_at_current_pos_293C
0852: CD B1 29      call move_cursor_1_2919
0855: CD 00 81      call put_blank_at_current_pos_2900
0858: DD 34 0B      inc  (ix+intermission_dance_push_anim_counter)
085B: C9            ret

085C: DD CB 09 66   bit  0,(ix+$09)
0860: CC 67 A8      call z,$0867
0863: CD 0A E0      call $4082
0866: C9            ret

0867: DD 36 82 20   ld   (ix+$0a),$20
086B: DD 36 81 AF   ld   (ix+$09),$0F
086F: C9            ret

0870: DD 36 0B 20   ld   (ix+intermission_dance_push_anim_counter),$00
0874: C9            ret
	
increase_counter_0875:
0875: 2A 24 A8      ld   hl,(counter_lsb_8824)
0878: 23            inc  hl
0879: 22 24 A8      ld   (counter_lsb_8824),hl
087C: C9            ret
	
play_one_game_087D:
087D: 21 00 20      ld   hl,$0000
0880: 22 86 88      ld   (player_1_score_880E),hl
0883: 22 38 88      ld   (player_2_score_8810),hl
0886: 3E A1         ld   a,$01
0888: 32 B2 88      ld   (level_number_player1_8812),a
088B: 32 3B 88      ld   (level_number_player2_8813),a
088E: 3A E0 90      ld   a,(dip_switches_9040) ;  dip switch
0891: 2F            cpl
0892: E6 B0         and  $18
0894: 0F            rrca
0895: 0F            rrca
0896: 0F            rrca
	;; gives 1,2,3 depending on lives settings
0897: C6 02         add  a,$02
0899: 32 14 A8      ld   (lives_counter_p1_8814),a
089C: 32 35 88      ld   (lives_counter_p2_8815),a
	;; game loop (lives)
089F: 21 3E 88      ld   hl,player_number_8816
08A2: CB 7E         bit  7,(hl)
08A4: 20 80         jr   nz,$08AE
08A6: 3A B4 88      ld   a,(lives_counter_p1_8814)
08A9: E6 F7         and  $7F
	;; game over:	return
08AB: C8            ret  z
08AC: 18 20         jr   $08CE
08AE: 3A B4 88      ld   a,(lives_counter_p1_8814)
08B1: E6 7F         and  $7F
08B3: 47            ld   b,a
08B4: 3A 35 88      ld   a,(lives_counter_p2_8815)
08B7: E6 7F         and  $7F
08B9: 4F            ld   c,a
08BA: 80            add  a,b
08BB: C8            ret  z
08BC: CB 46         bit  0,(hl)
08BE: 20 27         jr   nz,$08C7
08C0: 78            ld   a,b
08C1: A7            and  a
08C2: 20 82         jr   nz,$08CE
08C4: 34            inc  (hl)
08C5: 18 55         jr   $08BC
08C7: 79            ld   a,c
08C8: A7            and  a
08C9: 20 2B         jr   nz,$08CE
08CB: 34            inc  (hl)
08CC: 18 4E         jr   $08BC
08CE: CD 50 28      call $2878
08D1: CD D6 A0      call play_one_life_08D6
08D4: 18 E9         jr   $089F
	
play_one_life_08D6:
08D6: 21 36 88      ld   hl,player_number_8816
08D9: CB 7E         bit  7,(hl)
08DB: 20 07         jr   nz,$08E4
08DD: 7E            ld   a,(hl)
08DE: E6 D7         and  $7F
08E0: 28 C3         jr   z,run_one_life_092D
08E2: 18 84         jr   $08F0
08E4: CB 46         bit  0,(hl)
08E6: C4 EC AE      call nz,swap_players_0EC4
08E9: 3A 3E 88      ld   a,(player_number_8816)
08EC: E6 56         and  $7E
08EE: 28 15         jr   z,run_one_life_092D ; new game?
	;; restart after having died
08F0: CD 4D 28      call clear_screen_and_colors_28E5
08F3: CD B7 11      call clear_sprites_31B7
08F6: CD 30 2B      call update_all_scores_2B10
08F9: CD 76 84      call draw_status_bar_2C76
08FC: CD A4 2D      call draw_lives_2D0C
08FF: CD CB AD      call display_eggs_2D4B
0902: CD DE 8F      call display_player_ready_0F76
0905: CD DD AE      call draw_borders_2E5D
0908: CD DF 8E      call $0E77
090B: 3E 89         ld   a,$09
090D: 32 AA 20      ld   (cursor_color_8802),a
0910: ED 4B B0 8D   ld   bc,(diamond_block_1_xy_8DB0)
0914: CD 09 2F      call set_diamond_position_2FA9
0917: ED 4B 3A 8D   ld   bc,(diamond_block_2_xy_8DB2)
091B: CD A9 07      call set_diamond_position_2FA9
091E: ED 4B 34 25   ld   bc,(diamond_block_3_xy_8DB4)
0922: CD 29 0F      call set_diamond_position_2FA9
0925: CD 6E A5      call $0D66
0928: CD 50 8D      call $0DD0
092B: 18 7B         jr   $09A0
	
; runs until pengo is killed, then returns
run_one_life_092D: 
092D: CD 87 A8      call get_level_number_288F
0930: FE B1         cp   $11
;; reset level number after level 16
;; no increase of the difficulty level!!!!
0932: 20 A3         jr   nz,$0937
0934: 3E A1         ld   a,$01
0936: 77            ld   (hl),a

;; compute number of eggs/enemies
;; levels 1-2 -> 6
;; levels 3-7 -> 8
;; levels 8-11 -> 10
;; levels 12-16 -> 12
	
0937: 06 06         ld   b,$06
0939: FE 03         cp   $03
093B: 38 0E         jr   c,$094B
093D: 06 08         ld   b,$08
093F: FE 88         cp   $08
0941: 38 88         jr   c,$094B
0943: 06 8A         ld   b,$0A
0945: FE 8C         cp   $0C
0947: 38 AA         jr   c,$094B
0949: 06 8C         ld   b,$0C
094B: 78            ld   a,b
094C: 32 40 85      ld   (total_eggs_to_hatch_8DC0),a
094F: 32 DD 8D      ld   (current_nb_eggs_to_hatch_8DDD),a
0952: 32 98 8D      ld   (remaining_alive_snobees_8D98),a
0955: 21 05 8D      ld   hl,snobee_1_struct_8D00+5
0958: 11 20 00      ld   de,$0020
095B: 36 01         ld   (hl),$01
095D: 19            add  hl,de
095E: 36 A2         ld   (hl),$02
0960: 19            add  hl,de
0961: 36 AB         ld   (hl),$03
0963: 19            add  hl,de
0964: 36 84         ld   (hl),$04
0966: 21 05 85      ld   hl,pengo_struct_8D80+5
0969: 36 AD         ld   (hl),$05
096B: 21 25 25      ld   hl,moving_block_struct_8DA0+5
096E: 36 86         ld   (hl),$06
0970: CD 6D 28      call clear_screen_and_colors_28E5
0973: CD B7 31      call clear_sprites_31B7
0976: CD B0 2B      call update_all_scores_2B10
0979: 3A 19 88      ld   a,(currently_playing_8819)
097C: A7            and  a
097D: 28 06         jr   z,$0985
097F: CD 7E AC      call draw_status_bar_2C76
0982: CD A4 0D      call draw_lives_2D0C
0985: CD 47 99      call init_snobee_positions_31EF
0988: CD 03 3A      call init_moving_block_3283
098B: CD 03 9A      call $32AB
098E: CD 42 31      call init_pengo_structure_31C2
0991: CD A1 05      call draw_maze_2DA1	;  draw the maze
0994: 3E 20         ld   a,$20
0996: 32 A0 80      ld   (video_tile_memory_8000),a
0999: AF            xor  a
; zero minutes and seconds for round completion time
099A: 32 BA 8D      ld   (pengo_struct_8D80+$12),a
099D: 32 93 8D      ld   (pengo_struct_8D80+$13),a
	
09A0: CD C4 8D      call $0D44
09A3: DD 21 00 85   ld   ix,pengo_struct_8D80
09A7: CD C6 9B      call display_snobee_sprite_33CE
09AA: CD 2B 19      call set_character_sprite_code_and_color_39AB
09AD: CD 58 BE      call get_div8_ix_coords_3E78
09B0: CD 09 43      call clear_2x2_tiles_at_current_pos_43A9
09B3: 06 FF         ld   b,$FF		; stop sound
09B5: CD 89 90      call play_sfx_1889
09B8: 06 A2         ld   b,$02		; start music
09BA: CD 89 18      call play_sfx_1889
09BD: 3A 40 B8      ld   a,(dip_switches_9040)
09C0: 2F            cpl
09C1: CB 6F         bit  5,a	;  rack test dip switch
09C3: C2 0B A2      jp   nz,level_completed_0A2B ; end of level
09C6: 3E C0         ld   a,$40
09C8: CD 51 08      call delay_28D1	;  intro music?
09CB: 3A 68 24      ld   a,(sound_channel_0_struct_8C60)
09CE: A7            and  a
09CF: 20 FA         jr   nz,$09CB
; set state to 6 (start, normal mode)
; others modes: 4: fast music, 3: fast music, enemies giving up
09D1: 3E 06         ld   a,$06
09D3: 32 BB 8C      ld   (game_phase_8CBB),a
09D6: AF            xor  a
09D7: 21 5B 8C      ld   hl,time_counter_8C5B
09DA: 77            ld   (hl),a
09DB: 23            inc  hl
09DC: 77            ld   (hl),a
09DD: 23            inc  hl
09DE: 77            ld   (hl),a
; a timer which is used for instance for egg blink
09DF: 21 D6 25      ld   hl,timer_16_bit_8DDE
09E2: 36 A0         ld   (hl),$08
09E4: 23            inc  hl
09E5: 36 A0         ld   (hl),$80
	
main_game_loop_09E7: 
09E7: 3A 68 24      ld   a,(sound_channel_0_struct_8C60)
09EA: A7            and  a
09EB: 20 AF         jr   nz,$09F4
09ED: F3            di
09EE: 06 A0         ld   b,$08		; play in-game music
09F0: CD 89 18      call play_sfx_1889
09F3: FB            ei
09F4: CD 75 08      call increase_counter_0875
09F7: CD 0E 33      call $330E	;  timer to animate snobees when pengo killed
09FA: CD B4 33      call $3314	;  timer to end the level (and if 1 or 0 snobee make it disappear...)
09FD: CD 1A 33      call $331A	;  ??? something to do with eggs hatching...
0A00: CD 20 33      call $3320	;  ???
0A03: CD 73 15      call pengo_moves_3D73
0A06: CD 1E 69      call pengo_block_push_41BE
0A09: CD B9 C1      call snobee_block_break_4919
0A0C: CD 84 EB      call $4B0C	;  ???
0A0F: CD 48 E3      call blink_on_egg_locations_4B48
	;; this routine eats a lot of CPU!!!
0A12: CD 4E 4B      call handle_pengo_snobee_collisions_4BE6
0A15: CD 55 E4      call handle_pengo_eats_stunned_snobees_4C55
; check player state (alive/dead)
0A18: 3A BE 8D      ld   a,(pengo_struct_8D80+$1E)
0A1B: CB 7F         bit  7,a
0A1D: C2 D2 A4      jp   nz,player_dies_0CD2
0A20: 3A 98 8D      ld   a,(remaining_alive_snobees_8D98)
0A23: A7            and  a
0A24: 20 E9         jr   nz,main_game_loop_09E7
0A26: CD DD AB      call $0BDD	;  ???
0A29: 38 94         jr   c,main_game_loop_09E7
	
level_completed_0A2B:
0A2B: 06 2C         ld   b,$04		; level completed sound
0A2D: CD 89 90      call play_sfx_1889
0A30: F3            di
0A31: DD 21 28 8D   ld   ix,pengo_struct_8D80
0A35: 3A 5C AC      ld   a,(elapsed_seconds_since_start_of_round_8C5C)
0A38: DD 86 12      add  a,(ix+$12)
0A3B: 06 00         ld   b,$00
0A3D: FE 3C         cp   $3C
0A3F: 38 2C         jr   c,$0A45
0A41: D6 B4         sub  $3C
0A43: 06 29         ld   b,$01
0A45: DD 77 B2      ld   (ix+$12),a
0A48: 3A D5 8C      ld   a,(elapsed_minutes_since_start_of_round_8C5D)
0A4B: DD 86 B3      add  a,(ix+$13)
0A4E: 80            add  a,b
0A4F: DD 77 33      ld   (ix+$13),a
0A52: FB            ei
0A53: CD 39 A4      call clear_maze_and_borders_0C39
0A56: CD 75 0C      call pengo_walks_out_the_screen_0C55
0A59: CD 0C 85      call draw_lives_2D0C
; prints times and associated bonuses
0A5C: 21 00 0B      ld   hl,text_start_0B20
0A5F: CD 54 01      call print_line_typewriter_style_29F4
0A62: 21 13 AB      ld   hl,text_start_0B20+$1B
0A65: CD 54 01      call print_line_typewriter_style_29F4
0A68: 21 F6 AB      ld   hl,text_start_0B20+$36
0A6B: CD 54 01      call print_line_typewriter_style_29F4
0A6E: 21 71 0B      ld   hl,text_start_0B20+$51
0A71: CD F4 81      call print_line_typewriter_style_29F4
0A74: 21 AC 0B      ld   hl,text_start_0B20+$6C
0A77: CD F4 81      call print_line_typewriter_style_29F4
0A7A: 21 0F 0B      ld   hl,text_start_0B20+$87
0A7D: CD F4 81      call print_line_typewriter_style_29F4
0A80: 21 EA AB      ld   hl,text_start_0B20+$A2
0A83: CD 54 01      call print_line_typewriter_style_29F4
0A86: 3E 20         ld   a,$20
0A88: CD F9 A0      call delay_28D1
0A8B: 3A 1B 8D      ld   a,(pengo_struct_8D80+$13)		; round time (minutes)
0A8E: 26 A0         ld   h,$00
0A90: 6F            ld   l,a
0A91: CD 40 83      call convert_number_2B40
0A94: 26 23         ld   h,$03
0A96: 2E A4         ld   l,$0C
0A98: 22 20 88      ld   (cursor_x_8800),hl
0A9B: 3E 10         ld   a,$10
0A9D: 32 02 A8      ld   (cursor_color_8802),a
0AA0: CD 47 A4      call write_2_digits_to_screen_2C6F
0AA3: 3A 1A 8D      ld   a,(pengo_struct_8D80+$12)		; round time (seconds)
0AA6: 26 A0         ld   h,$00
0AA8: 6F            ld   l,a
0AA9: CD 68 03      call convert_number_2B40
0AAC: 26 A3         ld   h,$03
0AAE: 2E B3         ld   l,$13
0AB0: 22 20 88      ld   (cursor_x_8800),hl
0AB3: CD 6F 84      call write_2_digits_to_screen_2C6F
0AB6: 3E 00         ld   a,$20
0AB8: CD 79 28      call delay_28D1
0ABB: 2E 02         ld   l,$02
0ABD: 26 10         ld   h,$10
0ABF: 11 28 A0      ld   de,$0000
0AC2: DD 7E 3B      ld   a,(ix+$13)
0AC5: A7            and  a
0AC6: 20 33         jr   nz,$0AFB
0AC8: 06 A1         ld   b,$01
0ACA: CD 0F B8      call sound_18AF
0ACD: 2E 2A         ld   l,$02
0ACF: 26 0E         ld   h,$0E
0AD1: 11 01 20      ld   de,$0001
0AD4: DD 7E 12      ld   a,(ix+$12)
0AD7: FE 32         cp   $32
0AD9: 30 20         jr   nc,$0AFB
0ADB: 26 0C         ld   h,$0C
0ADD: 11 32 20      ld   de,$0032
0AE0: FE 00         cp   $28
0AE2: 30 B7         jr   nc,$0AFB
0AE4: 26 82         ld   h,$0A
0AE6: 11 64 28      ld   de,$0064
0AE9: FE BE         cp   $1E
0AEB: 30 AE         jr   nc,$0AFB
0AED: 26 A8         ld   h,$08
0AEF: 11 C8 20      ld   de,$00C8
0AF2: FE 34         cp   $14
0AF4: 30 25         jr   nc,$0AFB
0AF6: 26 26         ld   h,$06
0AF8: 11 5C 01      ld   de,$01F4
0AFB: D5            push de
0AFC: 3E B0         ld   a,$18
0AFE: 22 20 80      ld   (cursor_x_8800),hl
0B01: 06 98         ld   b,$18
0B03: CD 0D A9      call set_attribute_at_current_pos_292D
0B06: 10 7B         djnz $0B03
0B08: D1            pop  de
0B09: CD 07 A8      call add_to_current_player_score_28AF
0B0C: 3E 00         ld   a,$80
0B0E: CD 51 28      call delay_28D1
0B11: CD 8F 00      call get_level_number_288F
0B14: E6 A1         and  $01
0B16: CC 01 1D      call z,pengo_intermission_or_title_1D29		; level number is even; call pengo intermission
0B19: CD 8F 00      call get_level_number_288F
0B1C: 34            inc  (hl)
0B1D: C3 2D 81      jp   run_one_life_092D

text_start_0B20:
  02 03 18 47 41 4D 45 20 54 49 4D 45 20 20 20 20   ...GAME TIME
0B30  4D 49 4E 3A 20 20 20 53 45 43 BA 02 06 11 46 52   MIN:   SECº...FR
0B40  4F 4D 20 30 30 20 54 4F 20 31 39 20 3A 35 30 30   OM 00 TO 19 :500
0B50  30 20 50 54 53 BA 02 08 11 46 52 4F 4D 20 32 30   0 PTSº...FROM 20
0B60  20 54 4F 20 32 39 20 3A 32 30 30 30 20 50 54 53    TO 29 :2000 PTS
0B70  BA 02 0A 11 46 52 4F 4D 20 33 30 20 54 4F 20 33   º...FROM 30 TO 3
0B80  39 20 3A 31 30 30 30 20 50 54 53 BA 02 0C 11 46   9 :1000 PTSº...F
0B90  52 4F 4D 20 34 30 20 54 4F 20 34 39 20 3A 3A 35   ROM 40 TO 49 ::5
0BA0  30 30 20 50 54 53 BA 02 0E 11 46 52 4F 4D 20 35   00 PTSº...FROM 5
0BB0  30 20 54 4F 20 35 39 20 3A 3A 3A 31 30 20 50 54   0 TO 59 :::10 PT
0BC0  53 BA 02 10 11 36 30 20 41 4E 44 20 4F 56 45 52   Sº...60 AND OVER
0BD0  20 20 20 20 4E 4F 20 42 4F 4E 55 53 BA        NO BONUSº



0BDD: CD EC 83      call $0BEC
0BE0: CD 79 8B      call $0BF9
0BE3: D8            ret  c
0BE4: CD B6 8C      call $0C1E
0BE7: D8            ret  c
0BE8: CD 8E 8C      call $0C26
0BEB: C9            ret

0BEC: 21 37 85      ld   hl,pengo_struct_8D80+char_state
0BEF: 7E            ld   a,(hl)
0BF0: FE A2         cp   $02
0BF2: 38 A4         jr   c,$0BF8
0BF4: 20 A2         jr   nz,$0BF8
0BF6: 36 A1         ld   (hl),$01
0BF8: C9            ret
0BF9: 21 1F 8D      ld   hl,snobee_1_struct_8D00+char_state
0BFC: 11 20 00      ld   de,$0020
0BFF: 06 2C         ld   b,$04
0C01: 7E            ld   a,(hl)
0C02: FE A2         cp   $02
0C04: 38 A4         jr   c,$0C0A
0C06: 20 A2         jr   nz,$0C0A
0C08: 36 A1         ld   (hl),$01
0C0A: 19            add  hl,de
0C0B: 10 54         djnz $0C01
0C0D: 21 BF 8D      ld   hl,snobee_1_struct_8D00+char_state
0C10: 06 24         ld   b,$04
0C12: 7E            ld   a,(hl)
0C13: FE 03         cp   $03
0C15: 38 02         jr   c,$0C19
0C17: 37            scf		; set carry flag
0C18: C9            ret
0C19: 19            add  hl,de
0C1A: 10 5E         djnz $0C12
0C1C: A7            and  a
0C1D: C9            ret
0C1E: 21 9F 8D      ld   hl,block_moving_flag_8DBF
0C21: 7E            ld   a,(hl)
0C22: A7            and  a
0C23: C8            ret  z
0C24: 37            scf		; set carry flag
0C25: C9            ret

; start from second slot
0C26: 21 ED 8C      ld   hl,breaking_block_slots_8CC0+5
0C29: 11 2E A0      ld   de,$0006
0C2C: 06 A4         ld   b,$04
0C2E: 7E            ld   a,(hl)
0C2F: A7            and  a
0C30: 20 25         jr   nz,$0C37
0C32: 19            add  hl,de
0C33: 10 F9         djnz $0C2E
0C35: A7            and  a
0C36: C9            ret
0C37: 37            scf
0C38: C9            ret

clear_maze_and_borders_0C39:
0C39: 06 20         ld   b,$20
0C3B: C5            push bc
0C3C: 3E 00         ld   a,$20
0C3E: 90            sub  b
0C3F: 3C            inc  a
0C40: 47            ld   b,a
0C41: 0E 28         ld   c,$00
0C43: ED 43 A0 88   ld   (cursor_x_8800),bc
0C47: 3E 28         ld   a,$00
0C49: CD 30 07      call draw_attribute_line_2F30
0C4C: 3E A1         ld   a,$01
0C4E: CD F9 28      call delay_28D1
0C51: C1            pop  bc
0C52: 10 4F         djnz $0C3B
0C54: C9            ret

; once level is completed, depending on the initial X,
; pengo leaves the screen, and sometimes falls

pengo_walks_out_the_screen_0C55:
0C55: DD 21 28 8D   ld   ix,pengo_struct_8D80
0C59: DD 7E 20      ld   a,(ix+x_pos)
; choose the shortest path to leave the screen
0C5C: DD 36 04 22   ld   (ix+facing_direction),$02		; facing direction: right
0C60: FE A8         cp   $80
0C62: 30 A4         jr   nc,$0C68			; > 128 keep right
0C64: DD 36 2C A3   ld   (ix+facing_direction),$03		; facing direction: right
0C68: DD 36 2E 87   ld   (ix+instant_move_period),$0F
0C6C: DD 36 A8 5F   ld   (ix+$08),$FF
0C70: CD 55 08      call increase_counter_0875
; small cpu-dependent loop
0C73: 06 80         ld   b,$80
0C75: 10 FE         djnz $0C75
0C77: CD 4A 91      call animate_pengo_39A4
0C7A: DD 34 07      inc  (ix+current_period_counter)
0C7D: DD 7E 27      ld   a,(ix+current_period_counter)
0C80: DD BE 2E      cp   (ix+instant_move_period)
0C83: 38 C3         jr   c,$0C70
0C85: DD 36 A7 28   ld   (ix+current_period_counter),$00
0C89: DD 7E A0      ld   a,(ix+x_pos)
0C8C: A7            and  a
0C8D: C8            ret  z
0C8E: FE C8         cp   $C8		; going right and X=200?
0C90: CC 08 0C      call z,handle_pengo_stumble_0CA0
0C93: DD 7E 20      ld   a,(ix+x_pos)
0C96: FE 80         cp   $28
0C98: CC 99 0C      call z,handle_pengo_stumble_0CB9
0C9B: CD D7 95      call move_character_according_to_direction_3DD7
0C9E: 18 78         jr   $0C70

handle_pengo_stumble_0CA0:
0CA0: DD 7E 2C      ld   a,(ix+facing_direction)
0CA3: FE 2B         cp   $03			; is pengo facing left?
0CA5: C0            ret  nz
; only when facing left
0CA6: CD 54 A5      call get_random_value_2D7C
0CA9: E6 29         and  $01
0CAB: C8            ret  z
; once out of 2, pengo stumbles/rests
0CAC: DD 36 2A 68   ld   (ix+animation_frame),$E0
0CB0: CD 8B 39      call set_character_sprite_code_and_color_39AB
0CB3: 3E 40         ld   a,$40
0CB5: CD D1 80      call delay_28D1
0CB8: C9            ret

handle_pengo_stumble_0CB9:
0CB9: DD 7E 24      ld   a,(ix+facing_direction)
0CBC: FE 22         cp   $02
0CBE: C0            ret  nz
0CBF: CD F4 05      call get_random_value_2D7C
0CC2: E6 A1         and  $01
0CC4: C8            ret  z
; once out of 2, pengo stumbles/rests
0CC5: DD 36 A2 42   ld   (ix+animation_frame),$E2
0CC9: CD 83 11      call set_character_sprite_code_and_color_39AB
0CCC: 3E E0         ld   a,$40
0CCE: CD F9 28      call delay_28D1
0CD1: C9            ret

player_dies_0CD2:
0CD2: CD 48 0B      call $0BE0
0CD5: DA E7 A1      jp   c,main_game_loop_09E7
0CD8: 06 25         ld   b,$05
0CDA: CD A9 18      call play_sfx_1889		; player dies music
0CDD: 3E 06         ld   a,$06
0CDF: 32 9F 8D      ld   (pengo_struct_8D80+char_state),a
0CE2: DD 21 08 8D   ld   ix,pengo_struct_8D80
0CE6: CD 3B B7      call pengo_dies_3FB3
0CE9: 3E 2E         ld   a,$06
0CEB: DD BE 97      cp   (ix+char_state)
0CEE: 28 7A         jr   z,$0CE2
0CF0: F3            di
0CF1: DD 21 28 8D   ld   ix,pengo_struct_8D80
0CF5: 3A 5C AC      ld   a,(elapsed_seconds_since_start_of_round_8C5C)
0CF8: DD 86 12      add  a,(ix+$12)
0CFB: 06 00         ld   b,$00
0CFD: FE 3C         cp   $3C
0CFF: 38 AC         jr   c,$0D05
0D01: D6 1C         sub  $3C
0D03: 06 A9         ld   b,$01
0D05: DD 77 92      ld   (ix+$12),a
0D08: 3A F5 84      ld   a,(elapsed_minutes_since_start_of_round_8C5D)
0D0B: DD 86 93      add  a,(ix+$13)
0D0E: 80            add  a,b
0D0F: DD 77 B3      ld   (ix+$13),a
0D12: FB            ei
0D13: 3E 00         ld   a,$00
0D15: 32 9E 8D      ld   (pengo_struct_8D80+$1E),a
0D18: CD 9E 28      call	get_nb_lives_289E
0D1B: 7E            ld   a,(hl)
0D1C: 3D            dec  a
0D1D: 77            ld   (hl),a
0D1E: E6 57         and  $7F
0D20: CA 57 8E      jp   z,$0ED7
0D23: 3A 99 20      ld   a,(currently_playing_8819)
0D26: A7            and  a
0D27: C8            ret  z
; called when game in play
0D28: 3E 00         ld   a,$80
0D2A: CD 51 08      call delay_28D1
0D2D: CD 19 A4      call clear_maze_and_borders_0C39
0D30: CD 10 0E      call $0E38
0D33: 21 16 88      ld   hl,player_number_8816
0D36: CB 7E         bit  7,(hl)
0D38: 28 A7         jr   z,$0D41
0D3A: 34            inc  (hl)
0D3B: CB 46         bit  0,(hl)
0D3D: CC C4 86      call z,swap_players_0EC4
0D40: C9            ret
0D41: 34            inc  (hl)
0D42: 34            inc  (hl)
0D43: C9            ret
	
0D44: CD 36 08      call get_nb_lives_289E
0D47: FE AD         cp   $05
0D49: D0            ret  nc
0D4A: 3D            dec  a
0D4B: 87            add  a,a
0D4C: 26 8B         ld   h,$23
0D4E: 6F            ld   l,a
0D4F: 22 00 88      ld   (cursor_x_8800),hl
0D52: E5            push hl
0D53: CD 00 01      call put_blank_at_current_pos_2900
0D56: CD A0 29      call put_blank_at_current_pos_2900
0D59: E1            pop  hl
0D5A: 26 A0         ld   h,$00
0D5C: 22 A0 88      ld   (cursor_x_8800),hl
0D5F: CD A8 A9      call put_blank_at_current_pos_2900
0D62: CD 80 09      call put_blank_at_current_pos_2900
0D65: C9            ret
	
0D66: DD 21 A0 25   ld   ix,pengo_struct_8D80
0D6A: 21 35 8D      ld   hl,table_0D9D
0D6D: 4E            ld   c,(hl)
0D6E: 23            inc  hl
0D6F: 46            ld   b,(hl)
0D70: 23            inc  hl
0D71: E5            push hl
0D72: CD 82 30      call look_for_hidden_egg_300A
0D75: 38 23         jr   c,$0D9A
0D77: CD AF 85      call does_bc_match_a_diamond_block_xy_0daf
0D7A: 38 96         jr   c,$0D9A
0D7C: E1            pop  hl
0D7D: 79            ld   a,c
0D7E: C6 A2         add  a,$02
0D80: 87            add  a,a
0D81: 87            add  a,a
0D82: 87            add  a,a
0D83: DD 77 80      ld   (ix+x_pos),a
0D86: 78            ld   a,b
0D87: 87            add  a,a
0D88: 87            add  a,a
0D89: 87            add  a,a
0D8A: DD 77 A9      ld   (ix+y_pos),a
0D8D: DD 36 82 08   ld   (ix+animation_frame),$08
0D91: DD 36 96 00   ld   (ix+ai_mode),$00
0D95: DD 36 97 01   ld   (ix+char_state),$01
0D99: C9            ret
0D9A: E1            pop  hl
0D9B: 18 D0         jr   $0D6D

table_0D9D:
0D 0E 0D 0C 0D 10 0B 0E 0F 0E 0B 10 0F 10 0B 0C 0F 0C

does_bc_match_a_diamond_block_xy_0daf:
0DAF: C5            push bc
0DB0: 50            ld   d,b
0DB1: 59            ld   e,c
0DB2: 2A 38 8D      ld   hl,(diamond_block_1_xy_8DB0)
0DB5: CD 99 05      call compare_hl_to_de_2D99
0DB8: 28 B3         jr   z,$0DCD
0DBA: 2A 3A 8D      ld   hl,(diamond_block_2_xy_8DB2)
0DBD: CD 99 05      call compare_hl_to_de_2D99
0DC0: 28 A3         jr   z,$0DCD
0DC2: 2A 1C 85      ld   hl,(diamond_block_3_xy_8DB4)
0DC5: CD 91 AD      call compare_hl_to_de_2D99
0DC8: 28 83         jr   z,$0DCD
0DCA: C1            pop  bc
0DCB: AF            xor  a
0DCC: C9            ret
0DCD: C1            pop  bc
0DCE: 37            scf
0DCF: C9            ret

0DD0: 21 04 0E      ld   hl,table_0E2C
0DD3: DD 21 A0 8D   ld   ix,snobee_1_struct_8D00
0DD7: DD 7E 97      ld   a,(ix+char_state)
0DDA: A7            and  a
0DDB: C4 00 86      call nz,$0E00
0DDE: DD 21 28 25   ld   ix,snobee_2_struct_8D20
0DE2: DD 7E 9F      ld   a,(ix+char_state)
0DE5: A7            and  a
0DE6: C4 80 8E      call nz,$0E00
0DE9: DD 21 C0 85   ld   ix,snobee_3_struct_8D40
0DED: DD 7E B7      ld   a,(ix+char_state)
0DF0: A7            and  a
0DF1: C4 00 86      call nz,$0E00
0DF4: DD 21 60 8D   ld   ix,snobee_4_struct_8D60
0DF8: DD 7E 1F      ld   a,(ix+char_state)
0DFB: A7            and  a
0DFC: C4 A0 0E      call nz,$0E00
0DFF: C9            ret

0E00: 4E            ld   c,(hl)
0E01: 23            inc  hl
0E02: 46            ld   b,(hl)
0E03: 23            inc  hl
0E04: 56            ld   d,(hl)
0E05: 23            inc  hl
0E06: E5            push hl
0E07: D5            push de
0E08: CD 47 A1      call convert_coords_to_screen_address_296F
0E0B: 3E 20         ld   a,$20
0E0D: BE            cp   (hl)
0E0E: 28 A6         jr   z,$0E16
0E10: D1            pop  de
0E11: 78            ld   a,b
0E12: 82            add  a,d
0E13: 47            ld   b,a
0E14: 18 59         jr   $0E07
0E16: D1            pop  de
0E17: 79            ld   a,c
0E18: C6 22         add  a,$02
0E1A: 87            add  a,a
0E1B: 87            add  a,a
0E1C: 87            add  a,a
0E1D: DD 77 20      ld   (ix+x_pos),a
0E20: 78            ld   a,b
0E21: 87            add  a,a
0E22: 87            add  a,a
0E23: 87            add  a,a
0E24: DD 77 29      ld   (ix+y_pos),a
0E27: CD CE 33      call display_snobee_sprite_33CE
0E2A: E1            pop  hl
0E2B: C9            ret

table_0E2C:
  01 02 02 19 1E FE 19 02 02 01 1E FE


0E38: 21 48 8D      ld   hl,unknown_8DE0
0E3B: 06 02         ld   b,$02
0E3D: C5            push bc
0E3E: 0E A5         ld   c,$0D
0E40: C5            push bc
0E41: 3E 2A         ld   a,$02
0E43: 90            sub  b
0E44: 87            add  a,a
0E45: 87            add  a,a
0E46: 87            add  a,a
0E47: 87            add  a,a
0E48: C6 A2         add  a,$02
0E4A: 57            ld   d,a
0E4B: 3E AD         ld   a,$0D
0E4D: 91            sub  c
0E4E: 87            add  a,a
0E4F: C6 01         add  a,$01
0E51: 5F            ld   e,a
0E52: CD F5 0E      call $0E5D
0E55: C1            pop  bc
0E56: 0D            dec  c
0E57: 20 E7         jr   nz,$0E40
0E59: C1            pop  bc
0E5A: 10 49         djnz $0E3D
0E5C: C9            ret

0E5D: 36 00         ld   (hl),$00
0E5F: 06 A8         ld   b,$08
0E61: C5            push bc
0E62: D5            push de
0E63: 42            ld   b,d
0E64: 4B            ld   c,e
0E65: E5            push hl
0E66: CD 47 A1      call convert_coords_to_screen_address_296F
0E69: 7E            ld   a,(hl)
0E6A: E1            pop  hl
0E6B: FE 20         cp   $20
0E6D: CB 16         rl   (hl)
0E6F: D1            pop  de
0E70: C1            pop  bc
0E71: 14            inc  d
0E72: 14            inc  d
0E73: 10 EC         djnz $0E61
0E75: 23            inc  hl
0E76: C9            ret
0E77: 3E 00         ld   a,$00
0E79: 32 02 A8      ld   (cursor_color_8802),a
0E7C: 21 48 8D      ld   hl,unknown_8DE0
0E7F: 06 2A         ld   b,$02
0E81: C5            push bc
0E82: 0E 85         ld   c,$0D
0E84: C5            push bc
0E85: 3E AD         ld   a,$0D
0E87: 91            sub  c
0E88: 87            add  a,a
0E89: C6 29         add  a,$01
0E8B: 5F            ld   e,a
0E8C: 78            ld   a,b
0E8D: 16 2A         ld   d,$02
0E8F: 3D            dec  a
0E90: 28 25         jr   z,$0E97
0E92: CD 8B 0E      call $0EAB
0E95: 18 05         jr   $0E9C
0E97: 16 12         ld   d,$12
0E99: CD A7 A6      call $0EA7
0E9C: C1            pop  bc
0E9D: 0D            dec  c
0E9E: 20 4C         jr   nz,$0E84
0EA0: C1            pop  bc
0EA1: 10 DE         djnz $0E81
0EA3: CD 3C 07      call show_maze_with_line_delay_effect_2F14
0EA6: C9            ret

0EA7: 06 2F         ld   b,$07
0EA9: 18 2A         jr   $0EAD
0EAB: 06 A8         ld   b,$08
0EAD: C5            push bc
0EAE: D5            push de
0EAF: ED 53 20 88   ld   (cursor_x_8800),de
0EB3: CB 16         rl   (hl)
0EB5: 30 05         jr   nc,$0EBC
0EB7: E5            push hl
0EB8: CD DE 2E      call draw_ice_block_tile_2EFE
0EBB: E1            pop  hl
0EBC: D1            pop  de
0EBD: C1            pop  bc
0EBE: 14            inc  d
0EBF: 14            inc  d
0EC0: 10 4B         djnz $0EAD
0EC2: 23            inc  hl
0EC3: C9            ret

; restore the saved memory for characters (pengo+alive snobees)
swap_players_0EC4:
0EC4: 21 A0 8D      ld   hl,snobee_1_struct_8D00
0EC7: 11 28 8E      ld   de,backup_player_struct_8E00
0ECA: 06 A0         ld   b,$00
0ECC: 7E            ld   a,(hl)
0ECD: F5            push af
0ECE: 1A            ld   a,(de)
0ECF: 77            ld   (hl),a
0ED0: F1            pop  af
0ED1: 12            ld   (de),a
0ED2: 23            inc  hl
0ED3: 13            inc  de
0ED4: 10 5E         djnz $0ECC
0ED6: C9            ret

0ED7: CD B7 11      call clear_sprites_31B7
0EDA: 06 26         ld   b,$06
0EDC: CD A9 18      call play_sfx_1889
0EDF: 21 EC 87      ld   hl,table_0F4C
0EE2: CD 06 AF      call erase_rectangular_char_zone_0F2E
0EE5: 21 79 87      ld   hl,$0F51
0EE8: 3A B6 88      ld   a,(player_number_8816)
0EEB: CB 47         bit  0,a
0EED: 28 2B         jr   z,$0EF2
0EEF: 21 5D A7      ld   hl,$0F5D
0EF2: CD 5C 29      call print_line_typewriter_style_29F4
0EF5: 21 69 A7      ld   hl,$0F69
0EF8: CD 5C 29      call print_line_typewriter_style_29F4
0EFB: 3E 80         ld   a,$80
0EFD: CD D1 80      call delay_28D1
0F00: CD 27 2D      call $258F
0F03: 21 BE 20      ld   hl,player_number_8816
0F06: CB 7E         bit  7,(hl)
0F08: 28 87         jr   z,$0F11
0F0A: 34            inc  (hl)
0F0B: CB 46         bit  0,(hl)
0F0D: CC E4 A6      call z,swap_players_0EC4
0F10: C9            ret
0F11: 34            inc  (hl)
0F12: 34            inc  (hl)
0F13: 21 00 AC      ld   hl,video_attribute_memory_8400
0F16: 16 A4         ld   d,$04
0F18: 1E 02         ld   e,$2A
0F1A: 19            add  hl,de
0F1B: 4E            ld   c,(hl)
0F1C: 21 A0 80      ld   hl,video_tile_memory_8000
0F1F: 16 57         ld   d,$FF
0F21: 1E 70         ld   e,$F0
0F23: 19            add  hl,de
0F24: 7E            ld   a,(hl)
0F25: B9            cp   c
0F26: C8            ret  z
0F27: 21 A8 20      ld   hl,cursor_x_8800
0F2A: 2B            dec  hl
0F2B: 36 57         ld   (hl),$FF
0F2D: C9            ret

; erase chars & set fixed color attribute
erase_rectangular_char_zone_0F2E:
0F2E: 5E            ld   e,(hl)
0F2F: 23            inc  hl
0F30: 56            ld   d,(hl)
0F31: 23            inc  hl
0F32: 7E            ld   a,(hl)
0F33: 32 02 88      ld   (cursor_color_8802),a
0F36: 23            inc  hl
0F37: 4E            ld   c,(hl)
0F38: 23            inc  hl
0F39: 46            ld   b,(hl)
0F3A: C5            push bc
0F3B: D5            push de
0F3C: ED 53 00 88   ld   (cursor_x_8800),de
0F40: CD 80 09      call put_blank_at_current_pos_2900
0F43: 0D            dec  c
0F44: 20 7A         jr   nz,$0F40
0F46: D1            pop  de
0F47: C1            pop  bc
0F48: 14            inc  d
0F49: 10 47         djnz $0F3A
0F4B: C9            ret

table_0F4C:
0F4C  08 0C 10 0C 05 09 0D 10 50 4C 41 59 45 52 20 20  ; ..... ..PLAYER
0F5C  B1 09 0D 10 50 4C 41 59 45 52 20 20 B2 09 0F 10  ; ± ..PLAYER  ² ..
0F6C  47 41 4D 45 20 20 4F 56 45 D2 21 E3 0F B2 16 88  ; GAME  OVEÒ!ã.²..

display_player_ready_0F76:
0F76: 21 6B 0F	    ld   hl,str_player_1_FE3                                       
0F79: 3A 16 88      ld   a,(player_number_8816)
0F7C: CB 47         bit  0,a
0F7E: 28 A3         jr   z,$0F83
0F80: 21 6E 8F      ld   hl,str_player_2_FEE
0F83: CD 74 A9      call print_line_typewriter_style_29F4
0F86: 21 79 8F      ld   hl,str_ready_FF9
0F89: CD 74 A9      call print_line_typewriter_style_29F4
0F8C: 3E 00         ld   a,$80
0F8E: CD 51 28      call delay_28D1
0F91: 21 DE 87      ld   hl,rect_dimensions_FDE
0F94: CD 06 0F      call erase_rectangular_char_zone_0F2E
0F97: C9            ret
0F98: 06 B0         ld   b,$10
0F9A: 0E 81         ld   c,$09
0F9C: 16 A5         ld   d,$05
0F9E: 1E 82         ld   e,$0A
0FA0: 21 8F 84      ld   hl,maze_hole_wall_bit_table_8C27
0FA3: D5            push de
0FA4: C5            push bc
0FA5: D5            push de
0FA6: E5            push hl
0FA7: CD 4F A9      call convert_coords_to_screen_address_296F
0FAA: 7E            ld   a,(hl)
0FAB: E1            pop  hl
0FAC: 77            ld   (hl),a
0FAD: 23            inc  hl
0FAE: 0C            inc  c
0FAF: D1            pop  de
0FB0: 1D            dec  e
0FB1: 20 F2         jr   nz,$0FA5
0FB3: C1            pop  bc
0FB4: 04            inc  b
0FB5: D1            pop  de
0FB6: 15            dec  d
0FB7: 20 EA         jr   nz,$0FA3
0FB9: C9            ret
0FBA: 06 B0         ld   b,$10
0FBC: 0E 81         ld   c,$09
0FBE: 16 A5         ld   d,$05
0FC0: 1E A2         ld   e,$0A
0FC2: 21 8F 84      ld   hl,maze_hole_wall_bit_table_8C27
0FC5: D5            push de
0FC6: C5            push bc
0FC7: D5            push de
0FC8: E5            push hl
0FC9: 7E            ld   a,(hl)
0FCA: F5            push af
0FCB: CD 4F A9      call convert_coords_to_screen_address_296F
0FCE: F1            pop  af
0FCF: 77            ld   (hl),a
0FD0: E1            pop  hl
0FD1: 23            inc  hl
0FD2: 0C            inc  c
0FD3: D1            pop  de
0FD4: 1D            dec  e
0FD5: 20 F0         jr   nz,$0FC7
0FD7: C1            pop  bc
0FD8: 04            inc  b
0FD9: D1            pop  de
0FDA: 15            dec  d
0FDB: 20 E8         jr   nz,$0FC5
0FDD: C9            ret


; control chars + PLAYER 1
rect_dimensions_FDE:
	dc.b	$09,$10,$00,$0A,$05
str_player_1_FE3:
	dc.b	$0A,$11,$10,$50,$4C,$41,$59,$45,$52,$20,$B1
str_player_2_FEE:
	dc.b	$0A,$11,$10
	dc.b	"PLAYER "
	dc.b	$B2		; 2 with bit 7 set
str_ready_FF9:
	dc.b	$0B,$13,$10,$52,$45,$41,$44,$D9		; READY

jmp_1003:
1003: 3E 00         ld   a,$00
1005: 32 47 B8      ld   (character_sprite_bank_selector_9047),a
1008: 32 CA 90      ld   (palette_bank_selector_9042),a
100B: 32 46 B8      ld   (color_lookup_table_bank_selector_9046),a
100E: CD 7A 18      call disable_sound_18F2
1011: CD B7 B9      call clear_sprites_31B7
1014: CD C9 10      call $1041
1017: CD 3B 98      call wait_a_while_103B
101A: CD 9C 13      call $1314
101D: CD 3B 98      call wait_a_while_103B
1020: CD 79 14      call diagnostic_screen_14F1
1023: CD 3B 98      call wait_a_while_103B
1026: CD 4E 14      call $1466
1029: CD 3B 98      call wait_a_while_103B
102C: CD 85 11      call $110D
102F: CD 3B 98      call wait_a_while_103B
1032: CD FE 16      call $1676
1035: CD 3B 98      call wait_a_while_103B
1038: C3 88 00      jp   $0000

103B: 3E 0A         ld   a,$0A
103D: CD D1 28      call delay_28D1
1040: C9            ret

1041: DD E3         ex   (sp),ix
1043: 0E 00         ld   c,$00
1045: 21 00 A8      ld   hl,video_tile_memory_8000
1048: CD 7A 10      call memory_test_10F2
104B: 38 02         jr   c,$104F
104D: CB C1         set  0,c
104F: 21 00 00      ld   hl,cursor_x_8800
1052: CD F2 10      call memory_test_10F2
1055: 38 02         jr   c,$1059
1057: CB C9         set  1,c
1059: DD E3         ex   (sp),ix
105B: CD E5 28      call clear_screen_and_colors_28E5
105E: 21 81 10      ld   hl,table_1081
1061: CD DC 01      call print_line_typewriter_style_29F4
1064: CD FA 10      call $10D2
1067: CD CA 98      call $10E2
106A: 21 A7 10      ld   hl,table_1081+$E
106D: 79            ld   a,c
106E: A7            and  a
106F: 28 03         jr   z,$1074
1071: 21 9D 98      ld   hl,table_1081+$9D-$81
1074: F5            push af
1075: CD F4 29      call print_line_typewriter_style_29F4
1078: F1            pop  af
1079: 20 FE         jr   nz,$1079
107B: 3E 02         ld   a,$02
107D: CD 46 9B      call $1346
1080: C9            ret

table_1081:
     1081  08 0A 10 52 41 4D 53 20 20 20 54 45 53 D4 08 12   ...RAMS   TESÔ..
     1091  10 41 4C 4C 20 52 41 4D 53 20 4F CB 08 12 16 52   .ALL RAMS OË...R
     10A1  41 4D 53 20 42 41 C4 08 0D 10 52 41 4D 31 20 4F   AMS BAÄ...RAM1 O
     10B1  CB 08 0D 16 52 41 4D 31 20 42 41 C4 08 0F 10 52   Ë...RAM1 BAÄ...R
     10C1  41 4D 32 20 4F CB 08 0F 16 52 41 4D 32 20 42 41   AM2 OË...RAM2 BA
     10D1  C4

10D2: 21 20 10      ld   hl,table_1081+$A8-$81
10D5: CB 41         bit  0,c
10D7: 28 03         jr   z,$10DC
10D9: 21 B2 98      ld   hl,table_1081+$B2-$81
10DC: C5            push bc
10DD: CD F4 29      call print_line_typewriter_style_29F4
10E0: C1            pop  bc
10E1: C9            ret
10E2: 21 35 10      ld   hl,table_1081+$BD-$81
10E5: CB 49         bit  1,c
10E7: 28 03         jr   z,$10EC
10E9: 21 C7 98      ld   hl,hl,table_1081+$C7-$81
10EC: C5            push bc
10ED: CD DC 01      call print_line_typewriter_style_29F4
10F0: C1            pop  bc
10F1: C9            ret

memory_test_10F2:
10F2: FD E3         ex   (sp),iy
10F4: 51            ld   d,c
10F5: 01 00 08      ld   bc,$0800
10F8: 3E DD         ld   a,$55
10FA: 77            ld   (hl),a
10FB: BE            cp   (hl)
10FC: C0            ret  nz
10FD: 3E AA         ld   a,$AA
10FF: 77            ld   (hl),a
1100: BE            cp   (hl)
1101: C0            ret  nz
1102: 23            inc  hl
1103: 0B            dec  bc
1104: 78            ld   a,b
1105: B1            or   c
1106: 28 D8         jr   z,$10F8
1108: 4A            ld   c,d
1109: FD E3         ex   (sp),iy
110B: AF            xor  a
110C: C9            ret

; looks like diagnostics
110D: CD 65 A0      call clear_screen_and_colors_28E5
1110: 21 B6 12      ld   hl,table_121E
1113: CD F4 A9      call print_line_typewriter_style_29F4
1116: 21 AD 12      ld   hl,$122D
1119: CD F4 A9      call print_line_typewriter_style_29F4
111C: 21 BF 12      ld   hl,$123F
111F: CD 74 A1      call print_line_typewriter_style_29F4
1122: 3A 68 10      ld   a,(dip_switches_9040)
1125: CD 4A 39      call $11CA
1128: 21 6E 92      ld   hl,$1246
112B: CD 74 A1      call print_line_typewriter_style_29F4
112E: 3A 28 90      ld   a,(dsw_1_9000_coinage)
1131: CD CA 91      call $11CA
1134: 21 E5 12      ld   hl,$124D
1137: CD F4 A9      call print_line_typewriter_style_29F4
113A: 3A C0 90      ld   a,(dip_switches_9040)
113D: 2F            cpl
113E: CB 4F         bit  1,a
1140: 20 2E         jr   nz,$1148
1142: 21 76 92      ld   hl,$125E
1145: CD 74 A1      call print_line_typewriter_style_29F4
1148: 21 EC 92      ld   hl,$1264
114B: 3A C0 18      ld   a,(dip_switches_9040)
114E: 2F            cpl
114F: CB 57         bit  2,a
1151: 28 03         jr   z,$1156
1153: 21 71 92      ld   hl,$1271
1156: CD 5C 29      call print_line_typewriter_style_29F4
1159: 3A 40 10      ld   a,(dip_switches_9040)
115C: 2F            cpl
115D: 0F            rrca
115E: 0F            rrca
115F: 0F            rrca
1160: E6 2B         and  $03
1162: C6 2A         add  a,$02
1164: F6 B8         or   $30
1166: 21 2C 93      ld   hl,$1304
1169: 22 80 00      ld   (cursor_x_8800),hl
116C: CD B4 A9      call set_tile_at_current_pos_293C
116F: 21 7C 92      ld   hl,$127C
1172: CD 5C 29      call print_line_typewriter_style_29F4
1175: 21 86 92      ld   hl,$1286
1178: CD 5C 29      call print_line_typewriter_style_29F4
117B: 3A 40 10      ld   a,(dip_switches_9040)
117E: 2F            cpl
117F: CB 6F         bit  5,a
1181: 20 86         jr   nz,$1189
1183: 21 15 3A      ld   hl,$1295
1186: CD DC A9      call print_line_typewriter_style_29F4
1189: 21 1B 3A      ld   hl,$129B
118C: CD DC A9      call print_line_typewriter_style_29F4
118F: 3A 40 10      ld   a,(dip_switches_9040)
1192: 2F            cpl
1193: CB 77         bit  6,a
1195: 28 06         jr   z,$119D
1197: 21 AE 92      ld   hl,$12AE
119A: CD 5C 29      call print_line_typewriter_style_29F4
119D: 21 E6 92      ld   hl,$12E6
11A0: 3A 68 10      ld   a,(dip_switches_9040)
11A3: 2F            cpl
11A4: 07            rlca
11A5: 07            rlca
11A6: E6 2B         and  $03
11A8: 28 39         jr   z,$11BB
11AA: 21 C5 92      ld   hl,$12ED
11AD: FE 81         cp   $01
11AF: 28 0A         jr   z,$11BB
11B1: 21 F6 92      ld   hl,$12F6
11B4: FE 82         cp   $02
11B6: 28 83         jr   z,$11BB
11B8: 21 7D 12      ld   hl,$12FD
11BB: CD F4 A9      call print_line_typewriter_style_29F4
11BE: 21 87 93      ld   hl,$1307
11C1: CD 74 A1      call print_line_typewriter_style_29F4
11C4: 3E 36         ld   a,$1E
11C6: CD 6E 93      call $1346
11C9: C9            ret

11CA: 2F            cpl
11CB: 06 88         ld   b,$08
11CD: 0E CF         ld   c,$4F
11CF: 0F            rrca
11D0: 30 82         jr   nc,$11D4
11D2: 0E C3         ld   c,$43
11D4: F5            push af
11D5: 79            ld   a,c
11D6: CD BC 29      call set_tile_at_current_pos_293C
11D9: CD 00 A9      call put_blank_at_current_pos_2900
11DC: F1            pop  af
11DD: 10 EE         djnz $11CD
11DF: C9            ret

11E0: E6 27         and  $0F
11E2: 87            add  a,a
11E3: 16 80         ld   d,$00
11E5: 5F            ld   e,a
11E6: 21 D6 91      ld   hl,$11FE
11E9: 19            add  hl,de
11EA: 3E 22         ld   a,$0A
11EC: 32 28 08      ld   (cursor_x_8800),a
11EF: 7E            ld   a,(hl)
11F0: CD BC 29      call set_tile_at_current_pos_293C
11F3: 23            inc  hl
11F4: 3E 91         ld   a,$11
11F6: 32 80 88      ld   (cursor_x_8800),a
11F9: 7E            ld   a,(hl)
11FA: CD BC 29      call set_tile_at_current_pos_293C
11FD: C9            ret

11FE  34 31 33 31 32 31 31 31 31 32 31 33 31 34 31 35   4131211112131415
120E  31 36 4D 42 4D 42 4D 42 4D 42 4D 42 4D 42 4D 42   16MBMBMBMBMBMBMB
table_121E:
121E  08 04 10 44 49 50 20 53 57 49 54 43 48 45 D3 08   ...DIP SWITCHEÓ.
122E  06 10 31 20 32 20 33 20 34 20 35 20 36 20 37 20   ..1 2 3 4 5 6 7
123E  B8 04 08 10 31 53 57 A0 04 0A 10 32 53 57 A0 04   ¸...1SW ...2SW .
124E  0F 18 44 45 4D 4F 20 53 4F 55 4E 44 53 20 4F CE   ..DEMO SOUNDS OÎ
125E  10 0F 18 4F 46 C6 04 11 10 54 41 42 4C 45 20 54   ...OFÆ...TABLE T
126E  59 50 C5 04 11 10 55 50 20 52 49 47 48 D4 06 13   YPÅ...UP RIGHÔ..
127E  18 50 45 4E 47 4F 45 D3 04 15 10 52 41 43 4B 20   .PENGOEÓ...RACK
128E  54 45 53 54 20 4F CE 0E 15 10 4F 46 C6 04 0D 10   TEST OÎ...OFÆ...
129E  42 4F 4E 55 53 20 35 30 30 30 30 20 50 54 53 BA   BONUS 50000 PTSº
12AE  0A 0D 10 33 30 30 30 B0 04 19 10 43 4F 49 4E 31   ...3000°...COIN1
12BE  20 20 20 43 4F 49 4E 20 20 20 43 52 45 44 49 D4      COIN   CREDIÔ
12CE  04 1B 10 43 4F 49 4E 32 20 20 20 43 4F 49 4E 20   ...COIN2   COIN
12DE  20 20 43 52 45 44 49 D4 0F 17 18 45 41 53 D9 0F     CREDIÔ...EASÙ.
12EE  17 18 4D 45 44 49 55 CD 0F 17 18 48 41 52 C4 0F   ..MEDIUÍ...HARÄ.
12FE  17 18 48 41 52 44 45 53 D4 04 17 18 44 49 46 46   ..HARDESÔ...DIFF
130E  49 43 55 4C 54 D9 CD E5 28 89 64 13 CD F4 29 2F   ICULTÙÍå(.d.Íô)/

1314: CD 4D 28      call clear_screen_and_colors_28E5
1317: 21 64 93      ld   hl,$1364
131A: CD 5C 29      call print_line_typewriter_style_29F4
131D: AF            xor  a
131E: 32 C8 08      ld   (unknown_8860),a
1321: CD 5F 3B      call check_memory_13DF
1324: CD D6 93      call $13FE
1327: CD 9D 3C      call $141D
132A: CD B4 94      call $143C
132D: 21 F2 3B      ld   hl,$1372
1330: 3A C8 88      ld   a,(unknown_8860)
1333: A7            and  a
1334: 28 83         jr   z,$1339
1336: 21 00 13      ld   hl,$1380
1339: F5            push af
133A: CD 5C 29      call print_line_typewriter_style_29F4
133D: F1            pop  af
133E: 20 7E         jr   nz,$133E
1340: 3E 2A         ld   a,$02
1342: CD 6E 93      call $1346
1345: C9            ret

1346: 47            ld   b,a
1347: C5            push bc
1348: CD 78 93      call $1350
134B: C1            pop  bc
134C: D8            ret  c
134D: 10 78         djnz $1347
134F: C9            ret

1350: 06 C0         ld   b,$40
1352: C5            push bc
1353: 3E 01         ld   a,$01
1355: CD D1 A8      call delay_28D1
1358: C1            pop  bc
1359: 3A 80 10      ld   a,(dip_switches_9080)
135C: CB 6F         bit  5,a
135E: 37            scf
135F: C8            ret  z
1360: 10 D8         djnz $1352
1362: A7            and  a
1363: C9            ret

 1364  08 0A 10 45 50 52 4F 4D 53 20 54 45 53 D4 08 18   ...EPROMS TESÔ..
 1374  10 41 4C 4C 20 52 4F 4D 53 20 4F CB 08 18 16 42   .ALL ROMS OË...B
 1384  41 44 20 52 4F 4D D3 08 0E 10 52 4F 4D 31 20 4F   AD ROMÓ...ROM1 O
 1394  CB 08 0E 16 52 4F 4D 31 20 42 41 C4 08 10 10 52   Ë...ROM1 BAÄ...R
 13A4  4F 4D 32 20 4F CB 08 10 16 52 4F 4D 32 20 42 41   OM2 OË...ROM2 BA
 13B4  C4 08 12 10 52 4F 4D 33 20 4F CB 08 12 16 52 4F   Ä...ROM3 OË...RO
 13C4  4D 33 20 42 41 C4 08 14 10 52 4F 4D 34 20 4F CB   M3 BAÄ...ROM4 OË
 13D4  08 14 16 52 4F 4D 34 20 42 41 C4 89   ...ROM4 BAÄ.....

check_memory_13DF:
13DF: 21 80 28      ld   hl,$0000                                       
13E2: 01 28 A0      ld   bc,$2000                                       
13E5: CD DB 3C      call checksum_memory_145B
13E8: 21 D0 FF      ld   hl,$7FF8
13EB: 77            ld   (hl),a
13EC: BE            cp   (hl)
13ED: 21 0B 3B      ld   hl,$138B
13F0: 28 A0         jr   z,$13FA
13F2: 3E 7F         ld   a,$FF
13F4: 32 C8 88      ld   (unknown_8860),a
13F7: 21 95 93      ld   hl,$1395
13FA: CD 5C 29      call print_line_typewriter_style_29F4
13FD: C9            ret

13FE: 21 80 08      ld   hl,$2000
1401: 01 00 08      ld   bc,$2000
1404: CD D3 14      call $checksum_memory_145B
1407: 21 FA 57      ld   hl,$7FFA
140A: 77            ld   (hl),a
140B: BE            cp   (hl)
140C: 21 28 13      ld   hl,$13A0
140F: 28 08         jr   z,$1419
1411: 3E FF         ld   a,$FF
1413: 32 60 00      ld   (unknown_8860),a
1416: 21 22 13      ld   hl,$13AA
1419: CD F4 29      call print_line_typewriter_style_29F4
141C: C9            ret
141D: 21 00 C8      ld   hl,$4000
1420: 01 88 08      ld   bc,$2000
1423: CD 73 9C      call checksum_memory_145B
1426: 21 74 7F      ld   hl,$7FFC
1429: 77            ld   (hl),a
142A: BE            cp   (hl)
142B: 21 9D 9B      ld   hl,$13B5
142E: 28 80         jr   z,$1438
1430: 3E 77         ld   a,$FF
1432: 32 E8 88      ld   (unknown_8860),a
1435: 21 BF 9B      ld   hl,$13BF
1438: CD F4 29      call print_line_typewriter_style_29F4
143B: C9            ret
143C: 21 88 60      ld   hl,ice_pack_tiles_6000
143F: 01 F8 97      ld   bc,$1FF8
1442: CD D3 14      call checksum_memory_145B
1445: 21 FE 57      ld   hl,$7FFE
1448: 77            ld   (hl),a
1449: BE            cp   (hl)
144A: 21 E2 13      ld   hl,$13CA
144D: 28 20         jr   z,$1457
144F: 3E FF         ld   a,$FF
1451: 32 60 00      ld   (unknown_8860),a
1454: 21 D4 13      ld   hl,$13D4
1457: CD F4 29      call print_line_typewriter_style_29F4
145A: C9            ret

checksum_memory_145B: AF            xor  a
145C: 86            add  a,(hl)
145D: 23            inc  hl
145E: 0B            dec  bc
145F: 57            ld   d,a
1460: 78            ld   a,b
1461: B1            or   c
1462: 7A            ld   a,d
1463: 20 DF         jr   nz,$145C
1465: C9            ret

1466: CD 6D 28      call clear_screen_and_colors_28E5
1469: 21 00 88      ld   hl,$0000
146C: 22 88 A0      ld   (cursor_x_8800),hl
146F: CD C6 9C      call draw_horizontal_line_14C6
1472: 21 1B 00      ld   hl,$001B
1475: 22 00 00      ld   (cursor_x_8800),hl
1478: CD C6 14      call draw_horizontal_line_14C6
147B: 21 00 AA      ld   hl,$2200
147E: 22 88 A0      ld   (cursor_x_8800),hl
1481: CD F0 9C      call draw_horizontal_line_14D8
1484: 21 88 14      ld   hl,$1400
1487: 22 00 A0      ld   (cursor_x_8800),hl
148A: CD F0 14      call draw_horizontal_line_14D8
148D: 21 00 09      ld   hl,$2100
1490: 22 88 88      ld   (cursor_x_8800),hl
1493: CD D8 9C      call draw_horizontal_line_14D8
1496: 21 8B 0E      ld   hl,$0E03
1499: 22 00 00      ld   (cursor_x_8800),hl
149C: 3E 9B         ld   a,$13
149E: 32 8A A0      ld   (cursor_color_8802),a
14A1: CD CF 9C      call $14E7
14A4: 21 8B 10      ld   hl,$1003
14A7: 22 00 A0      ld   (cursor_x_8800),hl
14AA: 3E 9F         ld   a,$17
14AC: 32 8A A0      ld   (cursor_color_8802),a
14AF: CD E7 9C      call $14E7
14B2: 21 8B 12      ld   hl,$1203
14B5: 22 00 00      ld   (cursor_x_8800),hl
14B8: 3E 9E         ld   a,$16
14BA: 32 8A 88      ld   (cursor_color_8802),a
14BD: CD E7 9C      call $14E7
14C0: 3E 14         ld   a,$3C
14C2: CD CE 13      call $1346
14C5: C9            ret
draw_horizontal_line_14C6:
14C6: 06 0C         ld   b,$24
14C8: 3E 98         ld   a,$10
14CA: 32 8A A0      ld   (cursor_color_8802),a
14CD: 3E 03         ld   a,$03
14CF: CD 3C 29      call set_tile_at_current_pos_293C
14D2: CD 19 29      call move_cursor_1_2919
14D5: 10 F8         djnz $14CF
14D7: C9            ret

draw_horizontal_line_14D8:
14D8: 06 1C         ld   b,$1C
14DA: 3E 98         ld   a,$10
14DC: 32 8A 88      ld   (cursor_color_8802),a
14DF: 3E 03         ld   a,$03
14E1: CD 3C 01      call set_tile_at_current_pos_293C
14E4: 10 73         djnz $14E1
14E6: C9            ret

14E7: 06 16         ld   b,$16
14E9: 3E 03         ld   a,$03
14EB: CD 3C 01      call set_tile_at_current_pos_293C
14EE: 10 73         djnz $14EB
14F0: C9            ret

diagnostic_screen_14F1:
14F1: CD E5 28      call clear_screen_and_colors_28E5
14F4: 3E 98         ld   a,$10
14F6: 32 8A 88      ld   (cursor_color_8802),a
14F9: 21 5B 9E      ld   hl,$165B		; player controls
14FC: 11 8E 04      ld   de,$0406
14FF: ED 53 28 08   ld   (cursor_x_8800),de
1503: CD 46 3D      call display_string_at_15C6
1506: 11 2E 87      ld   de,$0706
1509: ED 53 28 08   ld   (cursor_x_8800),de
150D: CD 46 3D      call display_string_at_15C6
1510: 11 A1 0A      ld   de,$0A09
1513: CD E3 95      call $15E3
1516: 3A C0 90      ld   a,(dip_switches_9040)
1519: E6 04         and  $04
151B: 28 18         jr   z,$1535
151D: 11 09 91      ld   de,$1109
1520: CD CB 95      call $15E3
1523: 21 D7 3E      ld   hl,$1657
1526: 11 2E 8A      ld   de,$0A06
1529: CD 54 3D      call $15D4
152C: 21 71 96      ld   hl,$1659
152F: 11 06 91      ld   de,$1106
1532: CD 54 15      call $15D4
1535: 11 20 82      ld   de,$0220
1538: 06 A2         ld   b,$0A
153A: 0E 7F         ld   c,$FF
153C: 3A 00 90      ld   a,(dip_switches_9080)
153F: 21 9A 3E      ld   hl,$161A
1542: E6 A8         and  $20
1544: 20 20         jr   nz,$154E
1546: BB            cp   e
1547: 28 82         jr   z,$154B
1549: 15            dec  d
154A: C8            ret  z
154B: 21 9F 3E      ld   hl,$161F
154E: 5F            ld   e,a
154F: C5            push bc
1550: D5            push de
1551: 11 09 87      ld   de,$0709
1554: ED 53 00 20   ld   (cursor_x_8800),de
1558: CD 46 15      call display_string_at_15C6
155B: 3A 80 10      ld   a,(dip_switches_9080)
155E: 21 B2 96      ld   hl,$161A
1561: E6 C0         and  $40
1563: 20 83         jr   nz,$1568
1565: 21 9F 3E      ld   hl,$161F
1568: 11 3B 87      ld   de,$0713
156B: ED 53 28 08   ld   (cursor_x_8800),de
156F: CD C6 95      call display_string_at_15C6
1572: 3A 40 90      ld   a,(coin_input_90C0)
1575: 11 12 A2      ld   de,$0A12
1578: CD 30 15      call $1598
157B: 3A 40 10      ld   a,(dip_switches_9040)
157E: E6 84         and  $04
1580: 28 21         jr   z,$158B
1582: 3A 08 10      ld   a,($9080)
1585: 11 92 39      ld   de,$1112
1588: CD 10 95      call $1598
158B: 3E 81         ld   a,$01
158D: CD 51 A0      call delay_28D1
1590: D1            pop  de
1591: C1            pop  bc
1592: 0D            dec  c
1593: 20 A7         jr   nz,$153C
1595: 10 A5         djnz $153C
1597: C9            ret
1598: 01 81 04      ld   bc,$0401
159B: F5            push af
159C: 21 8C 16      ld   hl,$1624
159F: A1            and  c
15A0: 28 2B         jr   z,$15A5
15A2: 21 AF 96      ld   hl,$1627
15A5: ED 53 28 08   ld   (cursor_x_8800),de
15A9: C5            push bc
15AA: CD 4E 95      call display_string_at_15C6
15AD: C1            pop  bc
15AE: F1            pop  af
15AF: 14            inc  d
15B0: CB 01         rlc  c
15B2: 10 4F         djnz $159B
15B4: 21 8C 16      ld   hl,$1624
15B7: E6 80         and  $80
15B9: 28 03         jr   z,$15BE
15BB: 21 27 96      ld   hl,$1627
15BE: ED 53 80 00   ld   (cursor_x_8800),de
15C2: CD 4E 95      call display_string_at_15C6
15C5: C9            ret

; hl: points to tile
; < de: x,y
; only used in service/test mode? not in game anyway
display_string_at_15C6:
15C6: 7E            ld   a,(hl)
15C7: 23            inc  hl
15C8: 4F            ld   c,a
15C9: E6 FF         and  $7F
15CB: CD BC A1      call set_tile_at_current_pos_293C
15CE: 79            ld   a,c
15CF: E6 80         and  $80
15D1: 28 F3         jr   z,display_string_at_15C6
15D3: C9            ret

15D4: 06 85         ld   b,$05
15D6: E5            push hl
15D7: ED 53 80 88   ld   (cursor_x_8800),de
15DB: CD C6 95      call display_string_at_15C6
15DE: E1            pop  hl
15DF: 14            inc  d
15E0: 10 DC         djnz $15D6
15E2: C9            ret

15E3: 21 AA 3E      ld   hl,$162A
15E6: ED 53 80 00   ld   (cursor_x_8800),de
15EA: 14            inc  d
15EB: CD 46 3D      call display_string_at_15C6
15EE: 21 BB 16      ld   hl,$1633
15F1: ED 53 80 88   ld   (cursor_x_8800),de
15F5: 14            inc  d
15F6: CD 46 15      call display_string_at_15C6
15F9: 21 3C 96      ld   hl,$163C
15FC: ED 53 00 20   ld   (cursor_x_8800),de
1600: 14            inc  d
1601: CD C6 9D      call display_string_at_15C6
1604: 21 CD 16      ld   hl,$1645
1607: ED 53 88 A0   ld   (cursor_x_8800),de
160B: 14            inc  d
160C: CD EE 15      call display_string_at_15C6
160F: 21 4E 9E      ld   hl,$164E
1612: ED 53 00 00   ld   (cursor_x_8800),de
1616: CD C6 15      call display_string_at_15C6
1619: C9            ret
161A: 20 A8         jr   nz,$163C
161C: 20 A8         jr   nz,$163E
161E: A0            and  b
161F: DB 54         in   a,($54)
1621: C9            ret

1622  52 D4 20 4F CE 4F 46 C6 55 50 3A 3A 3A 3A 3A 3A   ;RÔ OÎOFÆUP::::::
1632  BA 44 4F 57 4E 3A 3A 3A 3A BA 4C 45 46 54 3A 3A   ;ºDOWN::::ºLEFT::
1642  3A 3A BA 52 49 47 48 54 3A 3A 3A BA 50 55 53 48   ;::ºRIGHT:::ºPUSH
1652  3A 3A 3A 3A BA 50 B1 50 B2 50 4C 41 59 45 52 20   ;::::ºP±P²PLAYER
1662  43 4F 4E 54 52 4F 4C D3 31 50 20 20 20 20 20 20   ;CONTROLÓ1P
1672  20 20 32 D0 

1676: F3			di                                                  
1677: 3E 04         ld   a,$04
1679: 32 03 04      ld   (unknown_8C03),a
167C: CD B0 16      call coin_test_screen_init_16B0
167F: 3E 3C         ld   a,$3C
1681: CD F7 9E      call $16DF
1684: 28 00         jr   z,$16AE
1686: 78            ld   a,b
1687: A7            and  a
1688: CA 26 16      jp   z,$16AE
168B: 32 00 A4      ld   (unknown_8C00),a
168E: CD 9E 17      call $1716
1691: 06 00         ld   b,$00
1693: DA A1 9E      jp   c,$16A1
1696: CD 81 17      call $1781
1699: 06 01         ld   b,$01
169B: D2 A1 9E      jp   nc,$16A1
169E: CD 34 17      call $17BC
16A1: CD B3 9F      call $179B
16A4: 21 8B A4      ld   hl,unknown_8C03
16A7: 34            inc  (hl)
16A8: 3E 08         ld   a,$20
16AA: BE            cp   (hl)
16AB: C2 7F 9E      jp   nz,$167F
16AE: FB            ei
16AF: C9            ret
coin_test_screen_init_16B0:
16B0: CD E5 28      call clear_screen_and_colors_28E5
16B3: 21 C0 9E      ld   hl,$16C0
16B6: CD F4 29      call print_line_typewriter_style_29F4
16B9: 21 CD 9E      ld   hl,$16CD
16BC: CD F4 29      call print_line_typewriter_style_29F4
16BF: C9            ret

16C0  08 00 10 43 4F 49 4E 53 20 54 45 53 D4 06 02 10   ...COINS TESÔ...
16D0  42 41 44 20 20 20 47 4F 4F 44 20 20 42 41 C4 DF   BAD   GOOD  BAÄß
16E0  D5 45 EA 16 D1 48 15 A8 F7 41 16 65 36 00 E5 F8   ÕEê.ÑH.¨÷A.e6.åø
16F0  16 C0 1B 7A A7 A8 F7 41 06 00 3A 80 90 2F CB 6F   .À.z§¨÷A..:../Ëo
1700  40 12 C0 90 86 41 AF E3 E7 E8 84 12 C0 90 AF E3   @.À..A¯ãçè..À.¯ã
1710  6F 40 32 70 90 61 3E 05 32 02 8C BE 24 9A 01 8C   o@2p.a>.2..¾$...
1720  4D 5A 17 E5 67 17 BA 02 8C B8 B2 02 8C E5 5A 17   MZ.åg.º..¸²..åZ.
1730  CD 67 17 F8 A7 62 49 17 21 01 8C 9D 21 02 8C 9D   Íg.ø§bI.!...!...
1740  4A 49 17 E5 5A 17 43 30 17 E5 5A 17 A1 01 8C 1D   JI.åZ.C0.åZ.¡...
1750  C2 49 17 BA 02 8C A7 60 37 61 06 04 0E BB 0D 88   ÂI.º..§`7a...»..

16C5: C1            pop  bc
16C6: 66            ld   h,(hl)
16C7: DB 08         in   a,($20)
16C9: DC 45 DB      call c,$5345
16CC: D4 8E 02      call nc,$0206
16CF: 98            sbc  a,b
16D0: 42            ld   b,d
16D1: C9            ret
16D2: 44            ld   b,h
16D3: A8            xor  b
16D4: 20 A8         jr   nz,$16F6
16D6: 47            ld   b,a
16D7: 4F            ld   c,a
16D8: 4F            ld   c,a
16D9: CC 20 A8      call z,$2020
16DC: 42            ld   b,d
16DD: C9            ret
16DE: C4 57 D5      call nz,$D5DF
16E1: CD EA 9E      call $16EA
16E4: D1            pop  de
16E5: C0            ret  nz
16E6: 15            dec  d
16E7: 20 DF         jr   nz,$16E0
16E9: C9            ret
16EA: 16 4D         ld   d,$65
16EC: 1E 88         ld   e,$00
16EE: CD 70 16      call $16F8
16F1: C0            ret  nz
16F2: 1B            dec  de
16F3: 7A            ld   a,d
16F4: A7            and  a
16F5: 20 F7         jr   nz,$16EE
16F7: C9            ret
16F8: 06 88         ld   b,$00
16FA: 3A 80 90      ld   a,($9080)
16FD: 2F            cpl
16FE: CB 6F         bit  5,a
1700: C0            ret  nz
1701: 3A 40 18      ld   a,(coin_input_90C0)
1704: 06 69         ld   b,$41
1706: 2F            cpl
1707: CB 67         bit  4,a
1709: C0            ret  nz
170A: 04            inc  b
170B: 3A 40 18      ld   a,(coin_input_90C0)
170E: 2F            cpl
170F: CB 6F         bit  5,a
1711: C0            ret  nz
1712: 32 D8 90      ld   ($9070),a
1715: C9            ret
1716: 3E 85         ld   a,$05
1718: 32 82 8C      ld   (unknown_8C02),a
171B: 3E 24         ld   a,$24
171D: 32 01 24      ld   (unknown_8C01),a
1720: CD 72 97      call kick_watchdog_175A
1723: CD E7 3F      call $1767
1726: 3A 2A 0C      ld   a,(unknown_8C02)
1729: 90            sub  b
172A: 32 2A 0C      ld   (unknown_8C02),a
172D: CD DA 3F      call kick_watchdog_175A
1730: CD CF 17      call $1767
1733: 78            ld   a,b
1734: A7            and  a
1735: CA 49 97      jp   z,$1749
1738: 21 81 8C      ld   hl,unknown_8C01
173B: 35            dec  (hl)
173C: 21 82 8C      ld   hl,unknown_8C02
173F: 35            dec  (hl)
1740: CA 61 97      jp   z,$1749
1743: CD DA 3F      call kick_watchdog_175A
1746: C3 B8 97      jp   $1730
1749: CD DA 3F      call kick_watchdog_175A
174C: 21 29 0C      ld   hl,unknown_8C01
174F: 35            dec  (hl)
1750: C2 E1 17      jp   nz,$1749
1753: 3A 02 24      ld   a,(unknown_8C02)
1756: A7            and  a
1757: C8            ret  z
1758: 37            scf
1759: C9            ret

; active cpu loop then write into watchdog
kick_watchdog_175A:
175A: 06 84         ld   b,$04
175C: 0E 3B         ld   c,$BB
175E: 0D            dec  c
175F: 20 7D         jr   nz,$175E
1761: 10 79         djnz $175C
1763: 32 F0 18      ld   ($9070),a
1766: C9            ret

1767: 06 80         ld   b,$00
1769: 3A 80 04      ld   a,(unknown_8C00)
176C: FE 69         cp   $41
176E: C2 F1 17      jp   nz,$1779
1771: 3A C0 10      ld   a,(coin_input_90C0)
1774: CB 67         bit  4,a
1776: C0            ret  nz
1777: 04            inc  b
1778: C9            ret
1779: 3A C0 10      ld   a,(coin_input_90C0)
177C: CB 6F         bit  5,a
177E: C0            ret  nz
177F: 04            inc  b
1780: C9            ret
1781: 3E A4         ld   a,$24
1783: 32 81 04      ld   (unknown_8C01),a
1786: CD 72 97      call kick_watchdog_175A
1789: CD E7 3F      call $1767
178C: 78            ld   a,b
178D: A7            and  a
178E: CA 1B 17      jp   z,$1793
1791: 37            scf
1792: C9            ret
1793: 21 01 24      ld   hl,unknown_8C01
1796: 35            dec  (hl)
1797: C2 86 97      jp   nz,$1786
179A: C9            ret
179B: 78            ld   a,b
179C: 06 87         ld   b,$07
179E: A7            and  a
179F: CA 2B 3F      jp   z,$17AB
17A2: 06 25         ld   b,$0D
17A4: FE 29         cp   $01
17A6: CA 83 97      jp   z,$17AB
17A9: 06 93         ld   b,$13
17AB: 78            ld   a,b
17AC: 32 28 08      ld   (cursor_x_8800),a
17AF: 3A 03 24      ld   a,(unknown_8C03)
17B2: 32 81 88      ld   (cursor_y_8801),a
17B5: 3A 00 24      ld   a,(unknown_8C00)
17B8: CD BC 29      call set_tile_at_current_pos_293C
17BB: C9            ret
17BC: CD CF 17      call $1767
17BF: 78            ld   a,b
17C0: 06 2A         ld   b,$02
17C2: A7            and  a
17C3: C8            ret  z
17C4: 32 F8 10      ld   ($9070),a
17C7: 18 73         jr   $17BC
17C9: CD 65 A0      call clear_screen_and_colors_28E5
17CC: CD C7 97      call $17EF
17CF: 21 D9 97      ld   hl,string_17D9
17D2: CD 5C 29      call print_line_typewriter_style_29F4
17D5: CD FD 97      call $17FD
17D8: C9            ret

string_17D9:
  03 00 10 30 20 31 20 32 20 33 20 20 20 20 20 30   ...0 1 2 3     0
     17E9  20 31 20 32 20 B3

17EF: 21 F0 E7      ld   hl,$4FF0
17F2: 11 59 4F      ld   de,$4FF1
17F5: 01 0F 80      ld   bc,$000F
17F8: 36 80         ld   (hl),$00
17FA: ED B0         ldir
17FC: C9            ret

17FD: 21 00 81      ld   hl,$0100
1800: 22 88 A0      ld   (cursor_x_8800),hl
1803: AF            xor  a
1804: 32 8A A0      ld   (cursor_color_8802),a
1807: 0E 00         ld   c,$00
1809: CD 33 90      call $181B
180C: 21 84 01      ld   hl,$010C
180F: 22 00 00      ld   (cursor_x_8800),hl
1812: 3E 98         ld   a,$10
1814: 32 8A 88      ld   (cursor_color_8802),a
1817: CD 1B 18      call $181B
181A: C9            ret
181B: 06 10         ld   b,$10
181D: C5            push bc
181E: 26 88         ld   h,$00
1820: 69            ld   l,c
1821: CD 40 03      call convert_number_2B40
1824: 3A 8A A0      ld   a,(cursor_color_8802)
1827: F5            push af
1828: 3E 98         ld   a,$10
182A: 32 8A A0      ld   (cursor_color_8802),a
182D: CD 6F 04      call write_2_digits_to_screen_2C6F
1830: F1            pop  af
1831: 32 02 00      ld   (cursor_color_8802),a
1834: CD 88 29      call put_blank_at_current_pos_2900
1837: 3E 00         ld   a,$00
1839: CD 3C 29      call set_tile_at_current_pos_293C
183C: CD 3C 29      call set_tile_at_current_pos_293C
183F: 3C            inc  a
1840: CD 14 29      call set_tile_at_current_pos_293C
1843: CD 3C 01      call set_tile_at_current_pos_293C
1846: 3C            inc  a
1847: CD 3C 01      call set_tile_at_current_pos_293C
184A: CD 14 29      call set_tile_at_current_pos_293C
184D: 3C            inc  a
184E: CD 14 29      call set_tile_at_current_pos_293C
1851: CD 3C 29      call set_tile_at_current_pos_293C
1854: CD E8 18      call $1860
1857: C1            pop  bc
1858: 21 8A 88      ld   hl,cursor_color_8802
185B: 34            inc  (hl)
185C: 0C            inc  c
185D: 10 BE         djnz $181D
185F: C9            ret
1860: C5            push bc
1861: 06 23         ld   b,$0B
1863: C3 23 01      jp   move_cursor_b_290B
1866: 3A E8 90      ld   a,(coin_input_90C0)
1869: 2F            cpl
186A: E6 87         and  $0F
186C: 28 70         jr   z,$1866
186E: C9            ret

186F: 77            ld   (hl),a
1870: 78            ld   a,b
1871: A7            and  a
1872: 28 8E         jr   z,$187A
1874: 3A 19 88      ld   a,(currently_playing_8819)
1877: A7            and  a
1878: 37            scf
1879: C8            ret  z
	;; not demo mode:	 start music
187A: 7E            ld   a,(hl)
187B: 23            inc  hl
187C: A7            and  a
187D: 28 03         jr   z,$1882
187F: 7E            ld   a,(hl)
1880: B8            cp   b
1881: D8            ret  c
	
1882: 78            ld   a,b
1883: 77            ld   (hl),a
1884: 2B            dec  hl
1885: 36 01         ld   (hl),$01
1887: AF            xor  a
1888: C9            ret
	
play_sfx_1889: F3            di
188A: 21 48 A4      ld   hl,sound_channel_0_struct_8C60
188D: 04            inc  b
188E: 28 9C         jr   z,$18A4
1890: 05            dec  b
1891: CD 70 18      call $1870
1894: 38 0C         jr   c,$18A2
1896: 21 F9 8C      ld   hl,sound_channel_1_struct_8C70+1
1899: CD 82 18      call $1882
189C: 21 81 8C      ld   hl,sound_channel_2_struct_8C80+1
189F: CD 82 90      call $1882
18A2: FB            ei
18A3: C9            ret
18A4: 36 88         ld   (hl),$00
18A6: AF            xor  a
18A7: 32 58 A4      ld   (sound_channel_1_struct_8C70),a
18AA: 32 A8 A4      ld   (sound_channel_2_struct_8C80),a
18AD: 18 DB         jr   $18A2

sound_18AF:
18AF: F3            di
18B0: 21 90 8C      ld   hl,sound_channel_3_struct_8C90
18B3: 04            inc  b
18B4: 28 0D         jr   z,$18C3
18B6: 05            dec  b
18B7: CD 70 18      call $1870
18BA: 38 8D         jr   c,$18C1
18BC: 3E 77         ld   a,$FF
18BE: 32 34 A4      ld   (sfx_1_playing),a
18C1: FB            ei
18C2: C9            ret

18C3: 36 00         ld   (hl),$00
18C5: 18 FA         jr   $18C1

update_sound_18c7:
18C7: F3            di
18C8: 21 28 A4      ld   hl,sound_channel_4_struct_8CA0
18CB: 04            inc  b
18CC: 28 92         jr   z,$18E8
18CE: 05            dec  b
18CF: 3A 40 90      ld   a,(dip_switches_9040)
18D2: 2F            cpl
18D3: CB 4F         bit  1,a
18D5: 28 05         jr   z,$18DC
18D7: CD 7A 18      call $187A
18DA: 18 8B         jr   $18DF
18DC: CD F8 18      call $1870
18DF: 38 05         jr   c,$18E6
18E1: 3E FF         ld   a,$FF
18E3: 32 BD A4      ld   (sfx_2_playing),a
18E6: FB            ei
18E7: C9            ret
18E8: 36 88         ld   (hl),$00
18EA: 18 72         jr   $18E6

enable_sound_18EC:
18EC: 3E 89         ld   a,$01
18EE: 32 C9 90      ld   (sound_enable_9041),a
18F1: C9            ret

disable_sound_18F2:
18F2: 3E 88         ld   a,$00
18F4: 32 C9 90      ld   (sound_enable_9041),a
18F7: C9            ret

18F8: 57            ld   d,a
18F9: E6 70         and  $70
18FB: 5F            ld   e,a
18FC: 0F            rrca
18FD: 83            add  a,e
18FE: 5F            ld   e,a
18FF: 7A            ld   a,d
1900: E6 27         and  $0F
1902: 87            add  a,a
1903: 83            add  a,e
1904: 16 28         ld   d,$00
1906: 5F            ld   e,a
1907: 21 92 31      ld   hl,table_1912
190A: 19            add  hl,de
190B: 5E            ld   e,(hl)
190C: 23            inc  hl
190D: 56            ld   d,(hl)
190E: CD 5A 19      call $19D2
1911: C9            ret

table_1912:  41 00 45 00 49 00 4D 00 52 00 57 00 5C 00 62 00   
			 67 00 6E 00 74 00 7B 00 82 00 8A 00 92 00 9B 00   
			 A4 00 AE 00 B9 00 C4 00 CF 00 DC 00 E9 00 F6 00   
			 05 01 15 01 25 01 37 01 49 01 5D 01 72 01 88 01   
			 9F 01 B8 01 D2 01 ED 01 0B 02 2A 02 4B 02 6E 02   
			 93 02 BA 02 E3 02 0F 03 3E 03 70 03 A4 03 DB 03   
			 16 04 54 04 96 04 DC 04 26 05 74 05 C2 05 1F 06   
			 7D 06 E0 06 48 07 B7 07 2D 08 A9 08 2D 09 B9 09   
			 4D 0A E9 0A 8F 0B 3F 0C FA 0C C0 0D 91 0E 6F 0F   
			 5A 10 52 11 5A 12 72 13 9A 14 D3 15 1F 17 7F 18   
			 F4 19 80 1B 22 1D DE 1E B4 20 A5 22 B5 24 E4 26   
			 34 29 01 00 01 00 01 00 01 00 01 00 01 00 01 00   


19D2: D5            push de
19D3: 3A BE 24      ld   a,(sound_related_8CBE)
19D6: 11 74 19      ld   de,jump_table_19DC
19D9: C3 8F AD      jp   indirect_jump_2D8F
jump_table_19DC:
	dc.w	$19E6
	dc.w	$19FC
	dc.w	$1A01
	dc.w	$1A06
	dc.w	$1A0B
	dc.w	$01A1
	
19E6: 21 29 0F      ld   hl,sound_buffer_8F00+1                                       
19E9: D1            pop  de
19EA: 7B            ld   a,e
19EB: 77            ld   (hl),a
19EC: 23            inc  hl
19ED: 0F            rrca
19EE: 0F            rrca
19EF: 0F            rrca
19F0: 0F            rrca
19F1: 77            ld   (hl),a
19F2: 23            inc  hl
19F3: 7A            ld   a,d
19F4: 77            ld   (hl),a
19F5: 23            inc  hl
19F6: 0F            rrca
19F7: 0F            rrca
19F8: 0F            rrca
19F9: 0F            rrca
19FA: 77            ld   (hl),a
19FB: C9            ret

19FC: 21 88 8F      ld   hl,sound_related_8F20
19FF: 18 E8         jr   $19E9

1A01: 21 18 A7      ld   hl,sound_related_8F30
1A04: 18 6B         jr   $19E9
1A06: 21 00 A7      ld   hl,sound_related_8F28
1A09: 18 F6         jr   $19E9

1A0B: 21 38 A7      ld   hl,sound_related_8F38
1A0E: 18 F1         jr   $19E9

1A10: CB E7         set  4,a
1A12: 18 8A         jr   $1A16
1A14: CB EF         set  5,a

1A16: F5            push af
1A17: 3A BE 04      ld   a,(sound_related_8CBE)
1A1A: 11 A8 1A      ld   de,table_1A20
1A1D: C3 8F 2D      jp   indirect_jump_2D8F

table_1A20:
   dc.w	$1A2A 
   dc.w	$1A53 
   dc.w	$1A58 
   dc.w	$1A5D
   dc.w	$1A62
   
1A2A: 21 8D A7      ld   hl,sound_buffer_8F00+5
1A2D: F1            pop  af
1A2E: CB 67         bit  4,a
1A30: 20 08         jr   nz,$1A3A
1A32: CB 6F         bit  5,a
1A34: 20 99         jr   nz,$1A47
1A36: E6 0F         and  $0F
1A38: 77            ld   (hl),a
1A39: C9            ret

1A3A: E6 0F         and  $0F
1A3C: 47            ld   b,a
1A3D: 7E            ld   a,(hl)
1A3E: 80            add  a,b
1A3F: FE 27         cp   $0F
1A41: 38 02         jr   c,$1A45
1A43: 3E 27         ld   a,$0F
1A45: 77            ld   (hl),a
1A46: C9            ret

1A47: E6 27         and  $0F
1A49: 47            ld   b,a
1A4A: 7E            ld   a,(hl)
1A4B: 90            sub  b
1A4C: FE 87         cp   $0F
1A4E: 38 89         jr   c,$1A51
1A50: AF            xor  a
1A51: 77            ld   (hl),a
1A52: C9            ret

1A53: 21 24 07      ld   hl,sound_8F24
1A56: 18 D5         jr   $1A2D

1A58: 21 BC 8F      ld   hl,sound_8F34
1A5B: 18 D0         jr   $1A2D

1A5D: 21 2C 07      ld   hl,sound_8F2C
1A60: 18 E3         jr   $1A2D

1A62: 21 14 A7      ld   hl,sound_8F3C
1A65: 18 C6         jr   $1A2D

1A67: F5            push af
1A68: 3A 36 A4      ld   a,(sound_related_8CBE)
1A6B: 11 59 92      ld   de,table_1A71
1A6E: C3 A7 2D      jp   indirect_jump_2D8F
table_1A71:
  dc.w	$1A7B 
  dc.w	$1A85  
  dc.w	$1A8A  
  dc.w	$1A8F 
  dc.w	$1A94  


1A7B: 21 10 07      ld   hl,sound_variable_8F10
1A7E: F1            pop  af
1A7F: E6 07         and  $07
1A81: 77            ld   (hl),a
1A82: CB FE         set  7,(hl)
1A84: C9            ret

1A85: 21 0D A7      ld   hl,sound_8F25
1A88: 18 7C         jr   $1A7E

1A8A: 21 1D A7      ld   hl,sound_8F35
1A8D: 18 EF         jr   $1A7E

1A8F: 21 2D 07      ld   hl,sound_8F2D
1A92: 18 62         jr   $1A7E

1A94: 21 3D 8F      ld   hl,sound_8F3D
1A97: 18 E5         jr   $1A7E

; I'm not going to dive too deep in that code
; < ix: pointer on sound channel ($8C60, $8C70, ...)
; offset 0: $F when not playing

update_sound_channel_1A99:
1A99: 32 BE 04      ld   (sound_related_8CBE),a
1A9C: DD 7E 00      ld   a,(ix+$00)
1A9F: A7            and  a
1AA0: C8            ret  z
1AA1: E6 27         and  $0F
1AA3: FE 01         cp   $01
1AA5: CC 63 94      call z,$1C4B
1AA8: DD 34 23      inc  (ix+$0b)
1AAB: DD 7E 83      ld   a,(ix+$0b)
1AAE: DD BE 0A      cp   (ix+$0a)
1AB1: D8            ret  c
1AB2: DD 36 0B 88   ld   (ix+$0b),$00
1AB6: DD 34 09      inc  (ix+$09)
1AB9: DD CB 0E 46   bit  0,(ix+$0e)
1ABD: C4 9B 1C      call nz,$1C9B
1AC0: DD 7E 21      ld   a,(ix+$09)
1AC3: DD BE 80      cp   (ix+$08)
1AC6: D8            ret  c
1AC7: DD 36 81 00   ld   (ix+$09),$00
1ACB: DD 7E 84      ld   a,(ix+alive_walk_counter)
1ACE: CB 47         bit  0,a
1AD0: 28 0C         jr   z,$1ADE
1AD2: DD 36 0C 88   ld   (ix+alive_walk_counter),$00
1AD6: CB 7F         bit  7,a
1AD8: 28 8C         jr   z,$1ADE
1ADA: DD 36 0E 77   ld   (ix+$0e),$FF
1ADE: DD 6E 02      ld   l,(ix+$02)
1AE1: DD 66 8B      ld   h,(ix+$03)
1AE4: 11 6C 32      ld   de,$1AE4
1AE7: D5            push de
1AE8: 7E            ld   a,(hl)
1AE9: E5            push hl
1AEA: 21 05 33      ld   hl,table_1B2D
1AED: 01 23 88      ld   bc,$000B
1AF0: ED B1         cpir
1AF2: 28 CC         jr   z,$1B38
1AF4: FE 70         cp   $F8
1AF6: 20 18         jr   nz,$1B10
1AF8: 3E 0F         ld   a,$0F
1AFA: DD CB 0E CE   bit  0,(ix+$0e)
1AFE: 28 8A         jr   z,$1B02
1B00: 3E D7         ld   a,$FF
1B02: DD 77 8C      ld   (ix+alive_walk_counter),a
1B05: DD 36 26 80   ld   (ix+$0e),$00
1B09: 3E 80         ld   a,$00
1B0B: CD 96 32      call $1A16
1B0E: 18 21         jr   $1B19
1B10: CD 78 18      call $18F8
1B13: DD 7E A5      ld   a,(ix+$0d)
1B16: CD 96 1A      call $1A16
1B19: E1            pop  hl
1B1A: 23            inc  hl
1B1B: 7E            ld   a,(hl)
1B1C: DD 77 08      ld   (ix+$08),a
1B1F: 23            inc  hl
1B20: DD 75 82      ld   (ix+$02),l
1B23: DD 74 2B      ld   (ix+$03),h
1B26: D1            pop  de
1B27: 21 3F 04      ld   hl,sound_related_8CBF
1B2A: CB C6         set  0,(hl)
1B2C: C9            ret

table_1B2D:
    dc.b	FF FE FD FC FB FA F9 F7 F6 F5 F4

1B38: CB 21         sla  c
1B3A: CB 10         rl   b
1B3C: 21 C5 1B      ld   hl,jump_table_1B45
1B3F: 09            add  hl,bc
1B40: 5E            ld   e,(hl)
1B41: 23            inc  hl
1B42: 56            ld   d,(hl)
1B43: EB            ex   de,hl
1B44: E9            jp   (hl)

jump_table_1B45
  dc.w	$1C47  
  dc.w	$1BAC 
  dc.w	$1C3F 
  dc.w	$1C34 
  dc.w	$1C2C 
  dc.w	$1B5B 
  dc.w	$1B98 
  dc.w	$1BA2 
  dc.w	$1BBF  
  dc.w	$1C15 
  dc.w	$1C22  


1B5B: DD 36 80 00   ld   (ix+$00),$00
1B5F: 3E 80         ld   a,$00
1B61: CD 96 32      call $1A16
1B64: DD 36 8E 28   ld   (ix+$0e),$00
1B68: 21 97 0C      ld   hl,sound_related_8CBF
1B6B: CB C6         set  0,(hl)
1B6D: 3A 3E 04      ld   a,(sound_related_8CBE)
1B70: FE 83         cp   $03
1B72: 28 87         jr   z,$1B7B
1B74: FE 84         cp   $04
1B76: 28 93         jr   z,$1B8B
1B78: E1            pop  hl
1B79: E1            pop  hl
1B7A: C9            ret
1B7B: 3A 11 27      ld   a,(sound_variable_8F11)
1B7E: F6 58         or   $F0
1B80: 32 39 0F      ld   (sound_variable_8F11),a
1B83: 21 3C 04      ld   hl,sfx_1_playing
1B86: 36 28         ld   (hl),$00
1B88: E1            pop  hl
1B89: E1            pop  hl
1B8A: C9            ret
1B8B: 3A 92 07      ld   a,(sound_buffer_8F00+$12)
1B8E: F6 D8         or   $F0
1B90: 32 92 8F      ld   (sound_buffer_8F00+$12),a
1B93: 21 BD 24      ld   hl,sfx_2_playing
1B96: 18 6E         jr   $1B86
1B98: E1            pop  hl
1B99: 23            inc  hl
1B9A: 7E            ld   a,(hl)
1B9B: 23            inc  hl
1B9C: E5            push hl
1B9D: CD 10 B2      call $1A10
1BA0: E1            pop  hl
1BA1: C9            ret
1BA2: E1            pop  hl
1BA3: 23            inc  hl
1BA4: 7E            ld   a,(hl)
1BA5: 23            inc  hl
1BA6: E5            push hl
1BA7: CD 94 32      call $1A14
1BAA: E1            pop  hl
1BAB: C9            ret
1BAC: E1            pop  hl
1BAD: 23            inc  hl
1BAE: DD CB 07 FE   bit  7,(ix+$07)
1BB2: CC 6E 1B      call z,$1BEE
1BB5: CD F8 B3      call $1BF8
1BB8: 3A 3B 8C      ld   a,(game_phase_8CBB)
1BBB: DD 77 A2      ld   (ix+$0a),a
1BBE: C9            ret
1BBF: E1            pop  hl
1BC0: 23            inc  hl
1BC1: DD CB 2E FE   bit  7,(ix+$06)
1BC5: CC 4C 33      call z,$1BCC
1BC8: CD 5E 9B      call $1BD6
1BCB: C9            ret
1BCC: 7E            ld   a,(hl)
1BCD: DD 77 2E      ld   (ix+$06),a
1BD0: 3D            dec  a
1BD1: DD CB 86 FE   set  7,(ix+$06)
1BD5: C9            ret
1BD6: EB            ex   de,hl
1BD7: DD 6E 84      ld   l,(ix+$04)
1BDA: DD 66 05      ld   h,(ix+$05)
1BDD: DD 7E 86      ld   a,(ix+$06)
1BE0: 3D            dec  a
1BE1: DD 77 2E      ld   (ix+$06),a
1BE4: E6 F7         and  $7F
1BE6: C0            ret  nz
1BE7: DD CB 2E 3E   res  7,(ix+$06)
1BEB: EB            ex   de,hl
1BEC: 23            inc  hl
1BED: C9            ret
1BEE: 7E            ld   a,(hl)
1BEF: DD 77 87      ld   (ix+$07),a
1BF2: 3D            dec  a
1BF3: DD CB 87 FE   set  7,(ix+$07)
1BF7: C9            ret

1BF8: E5            push hl
1BF9: CD 68 B4      call $1C68
1BFC: E1            pop  hl
1BFD: EB            ex   de,hl
1BFE: DD 6E 04      ld   l,(ix+$04)
1C01: DD 66 8D      ld   h,(ix+$05)
1C04: DD 7E 07      ld   a,(ix+$07)
1C07: 3D            dec  a
1C08: DD 77 07      ld   (ix+$07),a
1C0B: E6 7F         and  $7F
1C0D: C0            ret  nz
1C0E: DD CB 07 36   res  7,(ix+$07)
1C12: EB            ex   de,hl
1C13: 23            inc  hl
1C14: C9            ret
1C15: E1            pop  hl
1C16: 23            inc  hl
1C17: 7E            ld   a,(hl)
1C18: DD 77 0D      ld   (ix+$0d),a
1C1B: 23            inc  hl
1C1C: E5            push hl
1C1D: CD 16 1A      call $1A16
1C20: E1            pop  hl
1C21: C9            ret
1C22: E1            pop  hl
1C23: 23            inc  hl
1C24: 7E            ld   a,(hl)
1C25: 23            inc  hl
1C26: E5            push hl
1C27: CD 4F 92      call $1A67
1C2A: E1            pop  hl
1C2B: C9            ret
1C2C: E1            pop  hl
1C2D: 23            inc  hl
1C2E: 7E            ld   a,(hl)
1C2F: 23            inc  hl
1C30: DD 77 0A      ld   (ix+$0a),a
1C33: C9            ret
1C34: E1            pop  hl
1C35: 23            inc  hl
1C36: 7E            ld   a,(hl)
1C37: 23            inc  hl
1C38: DD 75 04      ld   (ix+$04),l
1C3B: DD 74 8D      ld   (ix+$05),h
1C3E: C9            ret
1C3F: E1            pop  hl
1C40: 23            inc  hl
1C41: 7E            ld   a,(hl)
1C42: 23            inc  hl
1C43: DD 77 86      ld   (ix+$0e),a
1C46: C9            ret

1C47: E1            pop  hl
1C48: 23            inc  hl
1C49: 23            inc  hl
1C4A: C9            ret

1C4B: CD 68 94      call $1C68
1C4E: DD 73 02      ld   (ix+$02),e
1C51: DD 72 8B      ld   (ix+$03),d
1C54: 3A 33 8C      ld   a,(game_phase_8CBB)
1C57: DD 77 0A      ld   (ix+$0a),a
1C5A: DD 77 0B      ld   (ix+$0b),a
1C5D: AF            xor  a
1C5E: DD 77 20      ld   (ix+$08),a
1C61: DD 77 8E      ld   (ix+$06),a
1C64: DD 77 07      ld   (ix+$07),a
1C67: C9            ret

1C68: 3A 36 A4      ld   a,(sound_related_8CBE)
1C6B: 87            add  a,a
1C6C: 16 88         ld   d,$00
1C6E: 5F            ld   e,a
1C6F: 21 91 1C      ld   hl,$1C91
1C72: 19            add  hl,de
1C73: 5E            ld   e,(hl)
1C74: 23            inc  hl
1C75: 56            ld   d,(hl)
1C76: EB            ex   de,hl
1C77: DD 7E 88      ld   a,(ix+$00)
1C7A: F6 0F         or   $0F
1C7C: DD 77 00      ld   (ix+$00),a
1C7F: DD 7E 89      ld   a,(ix+y_pos)
1C82: 87            add  a,a
1C83: 16 00         ld   d,$00
1C85: 5F            ld   e,a
1C86: 19            add  hl,de
1C87: 5E            ld   e,(hl)
1C88: 23            inc  hl
1C89: 56            ld   d,(hl)
1C8A: DD 73 04      ld   (ix+$04),e
1C8D: DD 72 8D      ld   (ix+$05),d
1C90: C9            ret

table_1C91:
     00 70 20 70 40 70 60 70 70 70

1C9B: DD 7E 08      ld   a,(ix+$08)
1C9E: 21 B3 34      ld   hl,table_1CB3
; check if A is in the table
1CA1: 01 20 88      ld   bc,$0008
1CA4: ED B1         cpir
1CA6: CB 21         sla  c
1CA8: CB 10         rl   b
1CAA: 21 33 34      ld   hl,jump_table_1CBB
1CAD: 09            add  hl,bc
1CAE: 5E            ld   e,(hl)
1CAF: 23            inc  hl
1CB0: 56            ld   d,(hl)
1CB1: EB            ex   de,hl
1CB2: E9            jp   (hl)

table_1CB3:
	dc.b	$10,$08,$04,$02,$01,$18,$0C,$06
	
jump_table_1CBB:
	dc.w	$1D15 
	dc.w	$1D00 
	dc.w	$1CEB 
	dc.w	$1CCB 
	dc.w	$1CCB 
	dc.w	$1CD0 
	dc.w	$1CD2 
	dc.w	$1CDA 

1CCB: CD C8 94      call sound_related_1CE0
1CCE: 18 98         jr   sound_related_1CE0

1CD0: 18 0E         jr   sound_related_1CE0

1CD2: DD 7E 09      ld   a,(ix+$09)
1CD5: E6 01         and  $01
1CD7: C0            ret  nz
1CD8: 18 8E         jr   sound_related_1CE0

1CDA: DD 7E 09      ld   a,(ix+$09)
1CDD: E6 03         and  $03
1CDF: C0            ret  nz

sound_related_1CE0:
1CE0: 3E 89         ld   a,$01
1CE2: CD 9C 32      call $1A14
1CE5: 21 BF A4      ld   hl,sound_related_8CBF
1CE8: CB C6         set  0,(hl)
1CEA: C9            ret

1CEB: DD 7E 81      ld   a,(ix+$09)
1CEE: 21 68 1C      ld   hl,sound_related_1CE0
1CF1: E5            push hl
1CF2: FE 8D         cp   $05
1CF4: C8            ret  z
1CF5: FE 0A         cp   $0A
1CF7: C8            ret  z
1CF8: FE 0F         cp   $0F
1CFA: C8            ret  z
1CFB: FE 14         cp   $14
1CFD: C8            ret  z
1CFE: E1            pop  hl
1CFF: C9            ret

1D00: DD 7E 89      ld   a,(ix+$09)
1D03: 21 60 34      ld   hl,sound_related_1CE0
1D06: E5            push hl
1D07: FE 83         cp   $03
1D09: C8            ret  z
1D0A: FE 2E         cp   $06
1D0C: C8            ret  z
1D0D: FE 89         cp   $09
1D0F: C8            ret  z
1D10: FE A3         cp   $0B
1D12: C8            ret  z
1D13: E1            pop  hl
1D14: C9            ret

1D15: DD 7E A1      ld   a,(ix+$09)
1D18: 21 48 1C      ld   hl,sound_related_1CE0
1D1B: E5            push hl
1D1C: FE 82         cp   $02
1D1E: C8            ret  z
1D1F: FE 84         cp   $04
1D21: C8            ret  z
1D22: FE 2D         cp   $05
1D24: C8            ret  z
1D25: E1            pop  hl
1D26: C9            ret
1D27: D7            rst  $10
1D28: 7F            ld   a,a

; the main idea of this routine is to move characters automatically
; during non-playing parts of the game
pengo_intermission_or_title_1D29:
1D29: 06 87         ld   b,$07
1D2B: CD 09 30      call play_sfx_1889	; dance music
1D2E: 3E 68         ld   a,$40
1D30: CD 51 28      call delay_28D1
1D33: CD 60 B5      call init_all_characters_states_1D60
1D36: CD DD 08      call increase_counter_0875
	;; small active loop
1D39: 06 00         ld   b,$00
1D3B: 10 FE         djnz $1D3B


; here we move 6 objects max: 6 pengos, using the ice block
; sprite structure
1D3D: CD A2 B5      call move_snobee_1_title_1DA2
1D40: CD 80 9D      call move_snobee_2_title_1DA8	; 2
1D43: CD 2E 35      call move_snobee_3_title_1DAE	; 3
1D46: CD 9C 9D      call move_snobee_4_title_1DB4	; 4
1D49: CD 3A 35      call move_character_following_path_1DBA	; pengo
1D4C: CD 48 9D      call move_character_intermission_path_1DC0	; moving block
1D4F: DD 21 08 8D   ld   ix,moving_block_struct_8DA0
1D53: 3E 05         ld   a,$05
1D55: DD BE B7      cp   (ix+char_state)
1D58: 20 74         jr   nz,$1D36
1D5A: 3E C0         ld   a,$40
1D5C: CD 51 28      call delay_28D1
1D5F: C9            ret

	;; init snobees, pengo, and moving block to an empty state (0) and init sprites
	;; used for title, intermission and ice pack screens, not in real game
init_all_characters_states_1D60:
1D60: DD 21 80 05   ld   ix,snobee_1_struct_8D00
1D64: 11 A8 80      ld   de,$0020
1D67: DD 36 37 80   ld   (ix+char_state),$00
1D6B: DD 36 2D 81   ld   (ix+char_id),$01
1D6F: DD 19         add  ix,de
1D71: DD 36 B7 00   ld   (ix+char_state),$00
1D75: DD 36 85 02   ld   (ix+char_id),$02
1D79: DD 19         add  ix,de
1D7B: DD 36 B7 00   ld   (ix+char_state),$00
1D7F: DD 36 2D 83   ld   (ix+char_id),$03
1D83: DD 19         add  ix,de
1D85: DD 36 37 80   ld   (ix+char_state),$00
1D89: DD 36 2D 84   ld   (ix+char_id),$04
1D8D: DD 19         add  ix,de
1D8F: DD 36 B7 00   ld   (ix+char_state),$00
1D93: DD 36 85 05   ld   (ix+char_id),$05
1D97: DD 19         add  ix,de
1D99: DD 36 B7 00   ld   (ix+char_state),$00
1D9D: DD 36 85 86   ld   (ix+char_id),$06
1DA1: C9            ret

move_snobee_1_title_1DA2:
1DA2: DD 21 80 05   ld   ix,snobee_1_struct_8D00
1DA6: 18 34         jr   $1DC4

move_snobee_2_title_1DA8:
1DA8: DD 21 A0 05   ld   ix,snobee_2_struct_8D20
1DAC: 18 3E         jr   $1DC4

move_snobee_3_title_1DAE:
1DAE: DD 21 40 25   ld   ix,snobee_3_struct_8D40
1DB2: 18 90         jr   $1DC4

move_snobee_4_title_1DB4:
1DB4: DD 21 60 25   ld   ix,snobee_4_struct_8D60
1DB8: 18 A2         jr   $1DC4

move_character_following_path_1DBA:
1DBA: DD 21 80 25   ld   ix,pengo_struct_8D80
1DBE: 18 84         jr   $1DC4

; moves character in auto mode with 3 modes
; not playing (title)
; intermission
; intermission >= level 10
move_character_intermission_path_1DC0:
1DC0: DD 21 20 05   ld   ix,moving_block_struct_8DA0

1DC4: 11 D1 9D      ld   de,table_title_1DF9	; table for demo/title
1DC7: 3A 99 00      ld   a,(currently_playing_8819)
1DCA: A7            and  a
; not playing, skip (we can branch that test in demo mode with invincibility on
; otherwise it can't be false)
1DCB: 28 8D         jr   z,$1DDA
; get level number to know what dance to do
1DCD: CD 0F A0      call get_level_number_288F
1DD0: 11 49 1D      ld   de,table_low_levels_1DE1
1DD3: FE 0A         cp   $0A
1DD5: 38 03         jr   c,$1DDA	; less than level 10
; >= level 10
1DD7: 11 ED B5      ld   de,table_high_levels_1DED	; table for level 10 and more

1DDA: DD 7E 1F      ld   a,(ix+char_state)		; get char to know where to jump
1DDD: C3 8F AD      jp   indirect_jump_2D8F

do_nothing_1DE0:
1DE0: C9            ret

table_low_levels_1DE1:
	dc.w	init_characters_for_intermission_1E05
	dc.w	do_nothing_1DE0
	dc.w	move_character_intermission_1EC4
	dc.w	how_to_dance_20DC
	dc.w	move_character_intermission_1EC4
	dc.w	do_nothing_1DE0
table_high_levels_1DED:
	dc.w	init_characters_level_10_1E54
	dc.w	do_nothing_1DE0
	dc.w	move_character_intermission_1F52
	dc.w	do_nothing_1DE0
	dc.w	how_to_dance_20DC
	dc.w	do_nothing_1DE0
table_title_1DF9:
	dc.w	change_character_title_phase_1E9C
	dc.w	do_nothing_1DE0
	dc.w	move_character_intermission_1F90
	dc.w	move_character_intermission_204E
	dc.w	do_nothing_1DE0
	dc.w	do_nothing_1DE0

	
init_characters_for_intermission_1E05:
1E05: DD 36 88 00   ld   (ix+x_pos),$00		; left
1E09: DD 36 89 B0   ld   (ix+y_pos),$98		; center
1E0D: DD 36 8A 08   ld   (ix+animation_frame),$08
1E11: DD 7E 8D      ld   a,(ix+char_id)
;  differently colored pengos: yellow, cyan, yellow, pink, yellow
1E14: 3C            inc  a
1E15: 3C            inc  a
1E16: DD 77 03      ld   (ix+char_color),a
1E19: CD 26 1E      call init_character_for_auto_mode_1E26
1E1C: DD 7E 05      ld   a,(ix+char_id)
1E1F: FE 01         cp   $01
1E21: C0            ret  nz
1E22: DD 34 37      inc  (ix+char_state)
1E25: C9            ret

; called in intermission, in menu ...
init_character_for_auto_mode_1E26:
1E26: DD 36 04 8B   ld   (ix+facing_direction),$03
1E2A: DD 36 06 82   ld   (ix+instant_move_period),$0A
1E2E: DD 36 07 88   ld   (ix+current_period_counter),$00
1E32: DD 36 08 77   ld   (ix+$08),$FF
1E36: DD 36 09 88   ld   (ix+$09),$00
1E3A: DD 36 0A 88   ld   (ix+stunned_push_block_counter),$00
1E3E: DD 36 23 88   ld   (ix+intermission_dance_push_anim_counter),$00
1E42: CD A7 28      call get_level_number_288F
1E45: 0F            rrca
1E46: 3D            dec  a
1E47: DD 77 96      ld   (ix+ai_mode),a ; set mode as level number / 2:	level 16: hardest hunt mode
1E4A: CD 23 39      call set_character_sprite_code_and_color_39AB
1E4D: CD E6 1B      call display_snobee_sprite_33CE
1E50: DD 34 1F      inc  (ix+char_state)
1E53: C9            ret

; different intermission: only piano + pengo playing
init_characters_level_10_1E54:
1E54: 21 84 1E      ld   hl,table_1E84
1E57: CD 64 1E      call next_auto_move_1E64
1E5A: DD 7E 05      ld   a,(ix+char_id)
1E5D: FE 01         cp   $01
1E5F: C0            ret  nz
1E60: DD 34 37      inc  (ix+char_state)
1E63: C9            ret

next_auto_move_1E64:
1E64: DD 7E 05      ld   a,(ix+char_id)
1E67: 3D            dec  a
1E68: 07            rlca
1E69: 07            rlca
1E6A: 16 88         ld   d,$00
1E6C: 5F            ld   e,a
1E6D: 19            add  hl,de
1E6E: 7E            ld   a,(hl)
1E6F: 23            inc  hl
1E70: DD 77 00      ld   (ix+x_pos),a
1E73: 7E            ld   a,(hl)
1E74: 23            inc  hl
1E75: DD 77 89      ld   (ix+y_pos),a
1E78: 7E            ld   a,(hl)
1E79: 23            inc  hl
1E7A: DD 77 02      ld   (ix+animation_frame),a
1E7D: 7E            ld   a,(hl)
1E7E: 23            inc  hl
1E7F: DD 77 8B      ld   (ix+char_color),a
1E82: 18 2A         jr   init_character_for_auto_mode_1E26


table_1E84:
  00 98 08 09 70 88 70 10 80 88 70 10 70 98 70 10  
1E94  80 98 70 10 70 90 F0 0B

change_character_title_phase_1E9C:
1E9C: 21 24 1E      ld   hl,table_1EAC
1E9F: CD 4C 96      call next_auto_move_1E64
1EA2: DD 7E 05      ld   a,(ix+char_id)
1EA5: FE 04         cp   $04
1EA7: D0            ret  nc
1EA8: DD 34 37      inc  (ix+char_state)
1EAB: C9            ret

table_1EAC:  00 28 08 0A 00 50 08 0B 00 70 08 01 00 08 08 0B
1EBC  00 18 08 0D 00 38 08 0C

move_character_intermission_1EC4:
1EC4: CD 78 36      call animate_intermission_penguins_1ef0
1EC7: DD 34 8F      inc  (ix+current_period_counter)
1ECA: DD 7E 07      ld   a,(ix+current_period_counter)
1ECD: DD BE 8E      cp   (ix+instant_move_period)
1ED0: D8            ret  c
1ED1: DD 36 8F 00   ld   (ix+current_period_counter),$00
1ED5: 3E 18         ld   a,$18
1ED7: DD BE 88      cp   (ix+x_pos)
1EDA: CC 9F 1F      call z,$1F17
1EDD: 3E B0         ld   a,$B0
1EDF: DD BE 88      cp   (ix+x_pos)
1EE2: CC 0C 37      call z,change_chars_state_from_01_to_02_1f24
1EE5: 3E D8         ld   a,$F0
1EE7: DD BE 88      cp   (ix+x_pos)
1EEA: CC C6 37      call z,$1F4E
1EED: C3 D7 15      jp   move_character_according_to_direction_3DD7

animate_intermission_penguins_1ef0:
1EF0: 3A AC 88      ld   a,(counter_lsb_8824)
1EF3: E6 1F         and  $1F
1EF5: C0            ret  nz
	;; counter 1 out of 32 xxx
1EF6: 06 88         ld   b,$00
1EF8: DD 7E 1F      ld   a,(ix+char_state)
1EFB: FE 04         cp   $04
1EFD: 20 09         jr   nz,$1F08
; this is reached only when penguins dance during the intermission
1EFF: DD 7E 36      ld   a,(ix+ai_mode)
1F02: FE 2B         cp   $03
1F04: 20 2A         jr   nz,$1F08
1F06: 06 B2         ld   b,$3A
; can be called directly with b = $12
1F08: DD 34 8C      inc  (ix+alive_walk_counter)
1F0B: DD 7E 24      ld   a,(ix+alive_walk_counter)
1F0E: E6 2B         and  $03
1F10: C0            ret  nz
1F11: DD 34 A4      inc  (ix+alive_walk_counter)
1F14: C3 05 39      jp   base_frame_selected_3985

1F17: DD E5         push ix
1F19: 11 20 80      ld   de,$0020
1F1C: DD 19         add  ix,de
1F1E: DD 34 9F      inc  (ix+char_state)
1F21: DD E1         pop  ix
1F23: C9            ret

change_chars_state_from_01_to_02_1f24:
1F24: DD 7E 85      ld   a,(ix+char_id)
1F27: FE 81         cp   $01
1F29: C0            ret  nz
1F2A: DD E5         push ix
1F2C: DD 34 9F      inc  (ix+char_state)
1F2F: 11 20 80      ld   de,$0020
1F32: DD 19         add  ix,de
1F34: DD 34 1F      inc  (ix+char_state)
1F37: DD 19         add  ix,de
1F39: DD 34 B7      inc  (ix+char_state)
1F3C: DD 19         add  ix,de
1F3E: DD 34 9F      inc  (ix+char_state)
1F41: DD 19         add  ix,de
1F43: DD 34 37      inc  (ix+char_state)
1F46: DD 19         add  ix,de
1F48: DD 34 9F      inc  (ix+char_state)
1F4B: DD E1         pop  ix
1F4D: C9            ret

1F4E: DD 34 1F      inc  (ix+char_state)
1F51: C9            ret

move_character_intermission_1F52:
1F52: DD 7E 05      ld   a,(ix+char_id)
1F55: FE 01         cp   $01
1F57: CC F0 B6      call z,animate_intermission_penguins_1ef0
1F5A: DD 34 07      inc  (ix+current_period_counter)
1F5D: DD 7E 87      ld   a,(ix+current_period_counter)
1F60: DD BE 86      cp   (ix+instant_move_period)
1F63: D8            ret  c
1F64: DD 36 87 28   ld   (ix+current_period_counter),$00
1F68: 3E E8         ld   a,$60
1F6A: DD BE 80      cp   (ix+x_pos)
1F6D: CC FB 37      call z,$1F7B
1F70: 3E 58         ld   a,$F0
1F72: DD BE 00      cp   (ix+x_pos)
1F75: CC 4E B7      call z,$1F4E
1F78: C3 57 3D      jp   move_character_according_to_direction_3DD7
1F7B: CD 24 B7      call change_chars_state_from_01_to_02_1f24
1F7E: DD E5         push ix
1F80: DD 21 20 05   ld   ix,moving_block_struct_8DA0
1F84: DD 34 9F      inc  (ix+char_state)
1F87: DD 34 37      inc  (ix+char_state)
1F8A: DD E1         pop  ix
1F8C: DD 35 9F      dec  (ix+char_state)
1F8F: C9            ret

move_character_intermission_1F90:
1F90: CD 4C 1F      call $1FE4
1F93: DD 34 87      inc  (ix+current_period_counter)
1F96: DD 7E 07      ld   a,(ix+current_period_counter)
1F99: DD BE 86      cp   (ix+instant_move_period)
1F9C: D8            ret  c
1F9D: DD 36 87 80   ld   (ix+current_period_counter),$00
1FA1: CD 45 37      call $1FC5
1FA4: 3E D7         ld   a,$FF
1FA6: DD BE 80      cp   (ix+x_pos)
1FA9: CC 8A A8      call z,change_last_3_characters_char_states_200a
1FAC: 3E 60         ld   a,$48
1FAE: DD BE 00      cp   (ix+x_pos)
1FB1: CC 32 88      call z,$2032
; check if X position is in the table (aligned on 8)
1FB4: 21 5F 1F      ld   hl,table_1FF7
1FB7: DD 7E 80      ld   a,(ix+x_pos)
1FBA: 01 93 00      ld   bc,$0013
1FBD: ED B1         cpir
1FBF: CC BD A8      call z,$203D
1FC2: C3 5F BD      jp   move_character_according_to_direction_3DD7
1FC5: DD 7E 2D      ld   a,(ix+char_id)
1FC8: FE 29         cp   $01
1FCA: C0            ret  nz
1FCB: DD 7E 28      ld   a,(ix+x_pos)
1FCE: E6 2F         and  $07
1FD0: C0            ret  nz
1FD1: 06 16         ld   b,$16
1FD3: 0E 07         ld   c,$07
1FD5: DD CB 80 5E   bit  3,(ix+x_pos)
1FD9: 28 05         jr   z,$1FE0
1FDB: CD C2 E3      call set_2x2_tile_color_0C_4BC2
1FDE: 18 83         jr   $1FE3
1FE0: CD 50 CB      call set_2x2_tile_color_09_4BD8
1FE3: C9            ret

1FE4: DD 7E 85      ld   a,(ix+char_id)
1FE7: FE 82         cp   $02
1FE9: CA 70 36      jp   z,animate_intermission_penguins_1ef0
1FEC: 3A AC 08      ld   a,(counter_lsb_8824)
1FEF: E6 1F         and  $1F
1FF1: C0            ret  nz
	;; counter 1 out of 32 xxx
; set bouncing snobee up as base
; when stepping on title screen, we can notice that the
; 4 snobees dragging the "pengo" titles aren't all snobees
; at first, but facing penguins. The code below turns them
; to snobees
1FF2: 06 92         ld   b,$12
1FF4: C3 A0 1F      jp   $1F08
table_1FF7:
  38 40 48 50 58 60 68 70 78 80 88 90 98 A0 A8 B0
  B8 C0 C8
 ; used during intermission, no game logic
change_last_3_characters_char_states_200a:
200A: DD E5         push ix
200C: DD 34 BF      inc  (ix+char_state)
200F: DD 21 40 8D   ld   ix,snobee_4_struct_8D60
2013: 11 20 20      ld   de,$0020
2016: DD 34 1F      inc  (ix+char_state)
2019: DD 34 B7      inc  (ix+char_state)
201C: DD 19         add  ix,de
201E: DD 34 BF      inc  (ix+char_state)
2021: DD 34 97      inc  (ix+char_state)
2024: DD 19         add  ix,de
2026: DD 34 BF      inc  (ix+char_state)
2029: DD 34 97      inc  (ix+char_state)
202C: DD E1         pop  ix
202E: CD B5 06      call draw_pengo_title_0615
2031: C9            ret
2032: DD 7E 05      ld   a,(ix+char_id)
2035: FE 01         cp   $01
2037: C8            ret  z
2038: FE 24         cp   $04
203A: D0            ret  nc
203B: E1            pop  hl
203C: C9            ret
203D: 0F            rrca
203E: 0F            rrca
203F: 0F            rrca
2040: E6 97         and  $1F
2042: D6 A2         sub  $02
2044: 6F            ld   l,a
2045: 26 2E         ld   h,$06
2047: 22 28 88      ld   (cursor_x_8800),hl
204A: CD A0 A1      call put_blank_at_current_pos_2900
204D: C9            ret

; snobees drag title
move_character_intermission_204E:
204E: CD 6C 1F      call $1FE4
2051: DD 34 27      inc  (ix+current_period_counter)
2054: DD 7E 07      ld   a,(ix+current_period_counter)
2057: DD BE 26      cp   (ix+instant_move_period)
205A: D8            ret  c
205B: DD 36 27 00   ld   (ix+current_period_counter),$00
205F: CD 4D 97      call $1FC5
2062: DD 7E 28      ld   a,(ix+x_pos)
2065: E6 2F         and  $07
2067: CC 04 20      call z,$20A4
206A: DD 7E 28      ld   a,(ix+x_pos)
206D: FE E1         cp   $69
206F: CC 85 00      call z,$2085
2072: DD 7E 00      ld   a,(ix+x_pos)
2075: FE 28         cp   $28
2077: CC 93 00      call z,$2093
207A: DD 7E 00      ld   a,(ix+x_pos)
207D: FE F8         cp   $F8
207F: CC 98 20      call z,$2098
2082: C3 FF B5      jp   move_character_according_to_direction_3DD7

2085: DD 7E 81      ld   a,(ix+$09)
2088: A7            and  a
2089: C0            ret  nz
208A: DD 36 2C A2   ld   (ix+facing_direction),$02
208E: DD 36 09 DF   ld   (ix+$09),$FF
2092: C9            ret

2093: DD 36 24 03   ld   (ix+facing_direction),$03
2097: C9            ret

2098: DD 34 1F      inc  (ix+char_state)
209B: DD 7E 25      ld   a,(ix+char_id)
209E: FE 26         cp   $06
20A0: DD 34 BF      inc  (ix+char_state)
20A3: C9            ret

20A4: DD 7E 28      ld   a,(ix+x_pos)
20A7: 0F            rrca
20A8: 0F            rrca
20A9: 0F            rrca
20AA: E6 97         and  $1F
20AC: D6 A1         sub  $01
20AE: FE A3         cp   $03
20B0: D8            ret  c
20B1: FE 18         cp   $18
20B3: D0            ret  nc
20B4: 6F            ld   l,a
20B5: 26 01         ld   h,$01
20B7: 22 00 A8      ld   (cursor_x_8800),hl
20BA: 3E A6         ld   a,$0E			; attribute for "pengo" title
20BC: DD CB 04 66   bit  0,(ix+facing_direction)
20C0: 20 A2         jr   nz,$20C4
20C2: 3E A0         ld   a,$00
20C4: 06 80         ld   b,$08
20C6: C5            push bc
20C7: CD A5 01      call set_attribute_at_current_pos_292D
20CA: CD 91 A1      call move_cursor_1_2919
20CD: C1            pop  bc
20CE: 10 7E         djnz $20C6
20D0: C9            ret

select_proper_jump_table_20D1:
20D1: 26 00         ld   h,$00
20D3: DD 6E B6      ld   l,(ix+ai_mode)
20D6: 29            add  hl,hl
20D7: 19            add  hl,de
20D8: 5E            ld   e,(hl)
20D9: 23            inc  hl
20DA: 56            ld   d,(hl)
20DB: C9            ret

how_to_dance_20DC:
20DC: 11 C8 20      ld   de,jump_table_table_20E8
20DF: CD 59 20      call select_proper_jump_table_20D1
20E2: DD 7E AB      ld   a,(ix+intermission_dance_push_anim_counter)
20E5: C3 8F 05      jp   indirect_jump_2D8F

jump_table_table_20E8:
	 .word	jump_table_20F8
	 .word	jump_table_214C
	 .word	jump_table_2180 
	 .word	jump_table_21B8
	 .word	jump_table_21CC 
	 .word	jump_table_2265  
	 .word	jump_table_21CC 
	 .word	jump_table_2265 

jump_table_20F8:  
	.word	$2130  
	.word	block_pushed_3FFA 
	.word	block_broken_406E 
	.word	block_pushed_401F 
	.word	block_broken_406E 
	.word	block_pushed_3FFA  
	.word	block_broken_406E  
	.word	block_pushed_401F 
	.word	block_broken_406E  
	.word	$2138 
	.word	block_pushed_3FFA  
	.word	block_broken_406E  
	.word	block_pushed_401F  
	.word	block_broken_406E  
	.word	block_pushed_3FFA 
	.word	block_broken_406E   
	.word	block_pushed_401F 
	.word	block_broken_406E 
	.word	$2140 
	.word	block_pushed_3FFA 
	.word	block_broken_406E 
	.word	block_pushed_401F 
	.word	block_broken_406E  
	.word	block_pushed_3FFA 
	.word	block_broken_406E 
	.word	block_pushed_401F  
	.word	block_broken_406E 
	.word	$2148 


2130: DD 36 04 A1   ld   (ix+facing_direction),$01
2134: DD 34 0B      inc  (ix+intermission_dance_push_anim_counter)
2137: C9            ret

2138: DD 36 04 A2   ld   (ix+facing_direction),$02
213C: DD 34 0B      inc  (ix+intermission_dance_push_anim_counter)
213F: C9            ret

2140: DD 36 AC 83   ld   (ix+facing_direction),$03
2144: DD 34 8B      inc  (ix+intermission_dance_push_anim_counter)
2147: C9            ret

2148: DD 34 9F      inc  (ix+char_state)
214B: C9            ret

jump_table_214C 
	.word	$2140
	.word	block_pushed_3FFA 
	.word	block_broken_406E
	.word	block_pushed_401F
	.word	block_broken_406E
	.word	block_pushed_3FFA
	.word	block_broken_406E 
	.word	block_pushed_401F
	.word	block_broken_406E
	.word	$2170
	.word	block_broken_406E 
	.word	$217C 
	.word	block_broken_406E
	.word	$2170
	.word	block_broken_406E 
	.word	$217C
	.word	block_broken_406E
	 

2170: 06 50         ld   b,$78
2172: DD 70 02      ld   (ix+animation_frame),b
2175: CD AB 11      call set_character_sprite_code_and_color_39AB
2178: DD 34 0B      inc  (ix+intermission_dance_push_anim_counter)
217B: C9            ret
217C: 06 54         ld   b,$7C
217E: 18 7A         jr   $2172

jump_table_2180:
	 .word	$218E
	 .word	$21A2
	 .word	$218E
	 .word	$21AD
	 .word	$218E
	 .word	$2140
	 .word	$2148


218E: DD CB 09 E6   bit  0,(ix+$09)
2192: CC 99 21      call z,$2199
2195: CD 82 E0      call $4082
2198: C9            ret

2199: DD 36 82 0A   ld   (ix+stunned_push_block_counter),$0A
219D: DD 36 81 8F   ld   (ix+$09),$0F
21A1: C9            ret

21A2: DD 36 AA 14   ld   (ix+animation_frame),$94
21A6: CD 2B 19      call set_character_sprite_code_and_color_39AB
21A9: DD 34 A3      inc  (ix+intermission_dance_push_anim_counter)
21AC: C9            ret

21AD: DD 36 82 12   ld   (ix+animation_frame),$12
21B1: CD AB 11      call set_character_sprite_code_and_color_39AB
21B4: DD 34 0B      inc  (ix+intermission_dance_push_anim_counter)
21B7: C9            ret

jump_table_21B8:
	.word	$218E 
	.word	$2130 
	.word	$218E 
	.word	$2140 
	.word	$21C4 
	.word	$2148 

21C4: DD 36 8C 80   ld   (ix+alive_walk_counter),$00
21C8: DD 34 8B      inc  (ix+intermission_dance_push_anim_counter)
21CB: C9            ret

; 32 values
jump_table_21CC:
	 .word	$2240
	 .word	$218E 
	 .word	$220C
	 .word	block_broken_406E
	 .word	$221B 
	 .word	block_broken_406E  
	 .word	$220C  
	 .word	block_broken_406E 
     .word	$221B  
	 .word	$218E  
	 .word	$220C  
	 .word	block_broken_406E  
	 .word	$221B  
	 .word	block_broken_406E  
	 .word	$220C  
	 .word	block_broken_406E 
     .word	$221B 
	 .word	$218E 
	 .word	$218E 
	 .word	$222A 
	 .word	$218E 
	 .word	$2235  
	 .word	$220C 
	 .word	block_broken_406E 
     .word	$221B 
	 .word	block_broken_406E 
	 .word	$220C  
	 .word	block_broken_406E 
	 .word	$221B  
	 .word	$218E  
	 .word	$2297 
	 .word	$2148 

220C: DD 36 28 72   ld   (ix+x_pos),$72
2210: DD 36 01 3A   ld   (ix+y_pos),$92
2214: CD EE 33      call display_snobee_sprite_33CE
2217: DD 34 A3      inc  (ix+intermission_dance_push_anim_counter)
221A: C9            ret

221B: DD 36 20 70   ld   (ix+x_pos),$70
221F: DD 36 A1 18   ld   (ix+y_pos),$90
2223: CD CE 33      call display_snobee_sprite_33CE
2226: DD 34 AB      inc  (ix+intermission_dance_push_anim_counter)
2229: C9            ret
222A: DD 36 2A 7C   ld   (ix+animation_frame),$F4
222E: CD 0B 39      call set_character_sprite_code_and_color_39AB
2231: DD 34 A3      inc  (ix+intermission_dance_push_anim_counter)
2234: C9            ret
2235: DD 36 22 F0   ld   (ix+animation_frame),$F0
2239: CD AB 91      call set_character_sprite_code_and_color_39AB
223C: DD 34 0B      inc  (ix+intermission_dance_push_anim_counter)
223F: C9            ret

2240: 26 B3         ld   h,$13
2242: 2E 84         ld   l,$0C
2244: 22 A0 88      ld   (cursor_x_8800),hl
2247: 3E 3A         ld   a,$12
2249: 32 2A 88      ld   (cursor_color_8802),a
224C: 3E B8         ld   a,$90
224E: 06 A4         ld   b,$04
2250: CD 94 29      call set_tile_at_current_pos_293C
2253: 3C            inc  a
2254: 10 DA         djnz $2250
2256: CD 03 29      call move_cursor_4_2923
2259: 06 04         ld   b,$04
225B: CD 3C 81      call set_tile_at_current_pos_293C
225E: 3C            inc  a
225F: 10 D2         djnz $225B
2261: DD 34 83      inc  (ix+intermission_dance_push_anim_counter)
2264: C9            ret


jump_table_2265:
	dc.w	$2240
	dc.w	$2297 
	dc.w	$218E 
	dc.w	$218E 
	dc.w	$218E 
	dc.w	$22A6 
	dc.w	$22B5 
	dc.w	block_broken_406E
	dc.w	$22C0
	dc.w	block_broken_406E
	dc.w	$22B5
	dc.w	block_broken_406E
	dc.w	$2297
	dc.w	$218E
	dc.w	$218E
	dc.w	$22A6
	dc.w	$22B5 
	dc.w	block_broken_406E 
	dc.w	$22C0
	dc.w	$218E
	dc.w	$218E
	dc.w	$22B5
	dc.w	block_broken_406E
	dc.w	$2297
	dc.w	$2148 

2297: DD 36 20 00   ld   (ix+x_pos),$00
229B: DD 36 21 00   ld   (ix+y_pos),$00
229F: CD CE 33      call display_snobee_sprite_33CE
22A2: DD 34 AB      inc  (ix+intermission_dance_push_anim_counter)
22A5: C9            ret

22A6: DD 36 28 56   ld   (ix+x_pos),$7E
22AA: DD 36 29 88   ld   (ix+y_pos),$88
22AE: CD CE 33      call display_snobee_sprite_33CE
22B1: DD 34 A3      inc  (ix+intermission_dance_push_anim_counter)
22B4: C9            ret

22B5: DD 36 22 E8   ld   (ix+animation_frame),$E8
22B9: CD AB 91      call set_character_sprite_code_and_color_39AB
22BC: DD 34 0B      inc  (ix+intermission_dance_push_anim_counter)
22BF: C9            ret
22C0: DD 36 2A 4C   ld   (ix+animation_frame),$EC
22C4: CD 0B B1      call set_character_sprite_code_and_color_39AB
22C7: DD 34 83      inc  (ix+intermission_dance_push_anim_counter)
22CA: C9            ret

pack_ice_screen_22CB:
22CB: CD B9 23      call set_bank_selectors_2319
22CE: CD 25 23      call show_ice_pack_screen_2325
22D1: CD 60 B5      call init_all_characters_states_1D60
22D4: CD 55 08      call increase_counter_0875
; active wait
22D7: 06 00         ld   b,$00
22D9: 10 FE         djnz $22D9
22DB: 10 FE         djnz $22DB
22DD: 3A 24 A8      ld   a,(counter_lsb_8824)
22E0: A7            and  a
22E1: 20 2E         jr   nz,$22E9
22E3: 3A 25 88      ld   a,(counter_msb_8825)
22E6: CD 5C 24      call set_sky_color_24FC
; move 6 characters. For that, use the 6 sprites
; (4 snobees, pengo, and ice block) to display 2 snobees
; and 4 penguins
22E9: CD B6 23      call move_snobee_pack_ice_1_233E
22EC: CD E4 23      call move_snobee_pack_ice_2_2344
22EF: CD 4A 03      call move_snobee_pack_ice_3_234A
22F2: CD 70 23      call move_snobee_pack_ice_4_2350
22F5: CD 56 03      call move_pengo_pack_ice_2356
22F8: CD F4 23      call move_pengo_pack_ice_235C
22FB: DD 7E B7      ld   a,(ix+char_state)
22FE: FE 22         cp   $02
2300: 20 52         jr   nz,$22D4
2302: 3E C0         ld   a,$40
2304: CD 51 08      call delay_28D1
2307: CD 44 8C      call cycle_sky_color_24EC
230A: CD A6 2B      call clr_bank_selectors_230E
230D: C9            ret

clr_bank_selectors_230E:
230E: AF            xor  a
230F: 32 47 B8      ld   (character_sprite_bank_selector_9047),a
2312: 32 E2 90      ld   (palette_bank_selector_9042),a
2315: 32 46 B8      ld   (color_lookup_table_bank_selector_9046),a
2318: C9            ret

; switch banks, just for the ice pack animation screen
set_bank_selectors_2319:
2319: 3E 01         ld   a,$01
231B: 32 47 B8      ld   (character_sprite_bank_selector_9047),a
231E: 32 E2 B0      ld   (palette_bank_selector_9042),a
2321: 32 EE 10      ld   (color_lookup_table_bank_selector_9046),a
2324: C9            ret

show_ice_pack_screen_2325:
2325: 21 A8 04      ld   hl,video_attribute_memory_8400
2328: 11 81 A4      ld   de,$8401
232B: 01 56 83      ld   bc,$03FE
232E: 36 90         ld   (hl),$10
2330: ED B0         ldir
2332: 21 A0 60      ld   hl,ice_pack_tiles_6000
2335: 11 00 A8      ld   de,video_tile_memory_8000
2338: 01 A0 04      ld   bc,$0400
233B: ED B0         ldir
233D: C9            ret

move_snobee_pack_ice_1_233E:
233E: DD 21 A8 25   ld   ix,snobee_1_struct_8D00
2342: 18 B4         jr   $2360

move_snobee_pack_ice_2_2344:
2344: DD 21 28 25   ld   ix,snobee_2_struct_8D20
2348: 18 96         jr   $2360

move_snobee_pack_ice_3_234A:
234A: DD 21 E8 25   ld   ix,snobee_3_struct_8D40
234E: 18 90         jr   $2360

move_snobee_pack_ice_4_2350:
2350: DD 21 60 8D   ld   ix,snobee_4_struct_8D60
2354: 18 82         jr   $2360

move_pengo_pack_ice_2356:
2356: DD 21 80 8D   ld   ix,pengo_struct_8D80
235A: 18 A4         jr   $2360

move_pengo_pack_ice_235C:
235C: DD 21 A0 8D   ld   ix,moving_block_struct_8DA0
2360: DD 7E 9F      ld   a,(ix+char_state)		; state, only from pack_ice screen (states are different: only 3 states)
2363: 11 49 8B      ld   de,table_2369
2366: C3 27 0D      jp   indirect_jump_2D8F
table_2369:
  .word	$2373 
  .word	$23E7 
  .word	$236F 

236F: CD FF 23      call $23FF
2372: C9            ret

2373: 21 B7 23      ld   hl,table_23B7
2376: DD 7E 05      ld   a,(ix+char_id)
2379: 3D            dec  a
237A: 87            add  a,a
237B: 87            add  a,a
237C: 87            add  a,a
237D: 16 00         ld   d,$00
237F: 5F            ld   e,a
2380: 19            add  hl,de
2381: 7E            ld   a,(hl)
2382: DD 77 A8      ld   (ix+x_pos),a
2385: 23            inc  hl
2386: 7E            ld   a,(hl)
2387: DD 77 81      ld   (ix+y_pos),a
238A: 23            inc  hl
238B: 7E            ld   a,(hl)
238C: 87            add  a,a
238D: 87            add  a,a
238E: DD 77 02      ld   (ix+animation_frame),a
2391: 23            inc  hl
2392: 7E            ld   a,(hl)
2393: DD 77 A3      ld   (ix+char_color),a
2396: 23            inc  hl
2397: 7E            ld   a,(hl)
2398: DD 77 04      ld   (ix+facing_direction),a
239B: 23            inc  hl
239C: 7E            ld   a,(hl)
239D: DD 77 A6      ld   (ix+instant_move_period),a
23A0: 23            inc  hl
23A1: DD 36 87 A8   ld   (ix+current_period_counter),$00
23A5: 7E            ld   a,(hl)
23A6: DD 77 B8      ld   (ix+path_address_pointer_or_misc_flags),a
23A9: 23            inc  hl
23AA: 7E            ld   a,(hl)
23AB: DD 77 91      ld   (ix+path_address_pointer_or_misc_flags+1),a
23AE: 23            inc  hl
23AF: DD 36 B2 00   ld   (ix+$12),$00
23B3: DD 34 97      inc  (ix+char_state)
23B6: C9            ret

; x,y,frame,color,facing direction,move period,pointer on move table
table_23B7:
78 50 0E 02 01 0C 00 68 
78 50 0E 03 01 0C 00 6B
78 50 0E 04 01 0C 00 69 
78 50 0E 05 01 0C 20 6A
78 50 0E 08 01 0C 00 6D 
78 50 0E 0C 01 0C 00 6E


23E7: CD 57 8B      call $23FF
23EA: DD 34 AF      inc  (ix+current_period_counter)
23ED: DD 7E 87      ld   a,(ix+current_period_counter)
23F0: DD BE 06      cp   (ix+instant_move_period)
23F3: D8            ret  c
23F4: DD 36 07 A0   ld   (ix+current_period_counter),$00
23F8: CD 35 24      call $2435
23FB: CD A0 24      call $24A0
23FE: C9            ret

23FF: 3A 24 88      ld   a,(counter_lsb_8824)
2402: E6 A7         and  $07
2404: C0            ret  nz
	;; counter 1 out of 8 xxx
2405: DD 34 84      inc  (ix+alive_walk_counter)
2408: DD 7E 2A      ld   a,(ix+animation_frame)
240B: E6 D0         and  $F8
240D: DD CB 84 56   bit  2,(ix+alive_walk_counter)
2411: 20 02         jr   nz,$2415
2413: CB D7         set  2,a
2415: DD 77 22      ld   (ix+animation_frame),a
2418: DD 7E 04      ld   a,(ix+facing_direction)
241B: FE 03         cp   $03
241D: 20 04         jr   nz,$2423
241F: DD CB A2 CE   set  1,(ix+animation_frame)
2423: DD CB B2 6E   bit  0,(ix+$12)
2427: 28 2C         jr   z,$242D
2429: DD CB A2 CE   set  1,(ix+animation_frame)
242D: CD 83 11      call set_character_sprite_code_and_color_39AB
2430: C9            ret

2431: CD 85 91      call base_frame_selected_3985
2434: C9            ret

2435: DD 6E 30      ld   l,(ix+path_address_pointer_or_misc_flags)
2438: DD 66 11      ld   h,(ix+$11)
243B: 7E            ld   a,(hl)
243C: 47            ld   b,a
243D: E6 C0         and  $C0
243F: 20 AE         jr   nz,$244F
2441: 78            ld   a,b
2442: E6 A7         and  $07
2444: DD 77 2C      ld   (ix+facing_direction),a
2447: 23            inc  hl
2448: DD 75 38      ld   (ix+path_address_pointer_or_misc_flags),l
244B: DD 74 B1      ld   (ix+$11),h
244E: C9            ret
244F: 07            rlca
2450: 07            rlca
2451: E6 03         and  $03
2453: 11 68 04      ld   de,table_2468
2456: CD AF 2D      call indirect_jump_2D8F
2459: DD 6E 30      ld   l,(ix+path_address_pointer_or_misc_flags)
245C: DD 66 11      ld   h,(ix+$11)
245F: 23            inc  hl
2460: DD 75 38      ld   (ix+path_address_pointer_or_misc_flags),l
2463: DD 74 B1      ld   (ix+$11),h
2466: 18 CD         jr   $2435

table_2468:
     dc.w	$249F  
	 dc.w	$2475  
	 dc.w	$248E  
	 dc.w	$2470  

2470: DD 34 1F      inc  (ix+char_state)
2473: E1            pop  hl
2474: C9            ret

2475: DD 6E 30      ld   l,(ix+path_address_pointer_or_misc_flags)
2478: DD 66 11      ld   h,(ix+$11)
247B: 7E            ld   a,(hl)
247C: 87            add  a,a
247D: 87            add  a,a
247E: 87            add  a,a
247F: DD 77 A2      ld   (ix+animation_frame),a
2482: DD 36 3A A0   ld   (ix+$12),$00
2486: CB 6E         bit  5,(hl)
2488: C8            ret  z
2489: DD 36 B2 D7   ld   (ix+$12),$FF
248D: C9            ret

248E: DD 6E 10      ld   l,(ix+path_address_pointer_or_misc_flags)
2491: DD 66 31      ld   h,(ix+$11)
2494: 7E            ld   a,(hl)
2495: E6 0F         and  $0F
2497: DD 77 26      ld   (ix+instant_move_period),a
249A: DD 36 07 20   ld   (ix+current_period_counter),$00
249E: C9            ret

249F: C9            ret

24A0: 21 1D 24      ld   hl,display_snobee_sprite_24BD
24A3: E5            push hl
24A4: DD 7E 2C      ld   a,(ix+facing_direction)
24A7: 11 85 24      ld   de,move_table_24AD
24AA: C3 8F A5      jp   indirect_jump_2D8F

move_table_24AD:
	.word	decrease_y_24C0  
	.word	increase_y_24C4 
	.word	decrease_x_24C8 
	.word	increase_x_24CC 
	.word	dec_y_inc_x_24D0 
	.word	dec_y_dec_x_24D7 
	.word	inc_y_inc_x_24DE 
	.word	inc_y_dec_x_24E5 


display_snobee_sprite_24BD: 
24BD: C3 CE 13      jp   display_snobee_sprite_33CE

decrease_y_24C0:
24C0: DD 35 29      dec  (ix+y_pos)
24C3: C9            ret

increase_y_24C4:
24C4: DD 34 29      inc  (ix+y_pos)
24C7: C9            ret

decrease_x_24C8:
24C8: DD 35 28      dec  (ix+x_pos)
24CB: C9            ret

increase_x_24CC:
24CC: DD 34 28      inc  (ix+x_pos)
24CF: C9            ret

dec_y_inc_x_24D0:
24D0: CD 68 24      call decrease_y_24C0
24D3: CD CC 04      call increase_x_24CC
24D6: C9            ret

dec_y_dec_x_24D7:
24D7: CD C0 04      call decrease_y_24C0
24DA: CD E8 24      call decrease_x_24C8
24DD: C9            ret

inc_y_inc_x_24DE:
24DE: CD 6C 24      call increase_y_24C4
24E1: CD CC 24      call increase_x_24CC
24E4: C9            ret

inc_y_dec_x_24E5:
24E5: CD 4C 24      call increase_y_24C4
24E8: CD C8 24      call decrease_x_24C8
24EB: C9            ret

cycle_sky_color_24EC:
24EC: 06 84         ld   b,$0C
24EE: C5            push bc
24EF: 78            ld   a,b
24F0: CD DC 24      call set_sky_color_24FC
24F3: 3E 09         ld   a,$09
24F5: CD D1 80      call delay_28D1
24F8: C1            pop  bc
24F9: 10 F3         djnz $24EE
24FB: C9            ret

set_sky_color_24FC:
24FC: E6 A7         and  $0F
24FE: F6 30         or   $10
2500: 21 C0 A4      ld   hl,$8440		; attribute memory
2503: 11 BD 80      ld   de,$0015
2506: 0E B4         ld   c,$1C
2508: 06 A3         ld   b,$0B
250A: 77            ld   (hl),a
250B: 23            inc  hl
250C: 10 7C         djnz $250A
250E: 19            add  hl,de
250F: 0D            dec  c
2510: 20 7E         jr   nz,$2508
2512: 21 E8 87      ld   hl,$87C0
2515: 06 3F         ld   b,$3F
2517: 77            ld   (hl),a
2518: 23            inc  hl
2519: 10 FC         djnz $2517
251B: C9            ret
; another hidden "credits" string, not referenced anywhere.
 251C  53 4E 4F 2D 42 45 45 20 44 49 53 50 4C 41 59 20  ; SNO-BEE DISPLAY
 252C  20 42 59 20 4E 41 4B 41 4B 55 4D 41 20 41 4B 49  ;  BY NAKAKUMA AKI
 253C  52 41 FF FF A1 D0 07 8A 58 88 A2 52 88 8A 4C 88  ; RA

; set default hiscores all to 20000
; (would be a good location to load highscores)
init_highscore_table_2540:
2540: 21 50 AF      ld   hl,$07D0		; 20000
2543: 22 D8 20      ld   (hiscore_pos_5_8840+$18),hl		; best score
2546: 22 D2 80      ld   (hiscore_pos_5_8840+$12),hl		; 2nd score
2549: 22 CC 20      ld   (hiscore_pos_5_8840+$C),hl		; ...
254C: 22 C6 80      ld   (hiscore_pos_5_8840+6),hl
254F: 22 40 88      ld   (hiscore_pos_5_8840),hl
; set text attributes for names
2552: 21 E2 88      ld   hl,high_score_names_8842
2555: 11 06 A0      ld   de,$0006
2558: 3E A1         ld   a,$01
255A: 06 A5         ld   b,$05
255C: 77            ld   (hl),a
255D: 19            add  hl,de
255E: 10 5C         djnz $255C
; set default names (AKIRA)
2560: 21 F3 80      ld   hl,hiscore_pos_5_8840+$18+3
2563: 3E E9         ld   a,$41		; AAA
2565: CD 81 8D      call set_3_chars_2589
2568: 21 D5 80      ld   hl,hiscore_pos_5_8840+$12+3
256B: 3E CB         ld   a,$4B		; KKK
256D: CD 81 8D      call set_3_chars_2589
2570: 21 C7 88      ld   hl,hiscore_pos_5_8840+$C+3
2573: 3E 49         ld   a,$49		; III
2575: CD 89 25      call set_3_chars_2589
2578: 21 C1 88      ld   hl,hiscore_pos_5_8840+9
257B: 3E 52         ld   a,$52		; RRR
257D: CD 89 25      call set_3_chars_2589
2580: 21 C3 80      ld   hl,hiscore_pos_5_8840+3
2583: 3E E9         ld   a,$41		; AAA
2585: CD 81 8D      call set_3_chars_2589
2588: C9            ret

set_3_chars_2589:
2589: 77            ld   (hl),a
258A: 23            inc  hl
258B: 77            ld   (hl),a
258C: 23            inc  hl
258D: 77            ld   (hl),a
258E: C9            ret

258F: CD 48 26      call compute_score_insertion_position_2648
2592: 3A D7 88      ld   a,(score_insertion_position_885F)
2595: FE 06         cp   $06
2597: C8            ret  z
2598: CD 6D 28      call clear_screen_and_colors_28E5
259B: CD B7 31      call clear_sprites_31B7
259E: 06 81         ld   b,$09			; 0xA in MAME menu
25A0: CD 21 98      call play_sfx_1889		; play highscore entry music
25A3: CD 96 8E      call create_highscore_entry_269E
25A6: 21 B2 08      ld   hl,todays_best_text_27F7+$81A-$7F7
25A9: 06 88         ld   b,$08
25AB: CD 5B 8F      call print_b_lines_277B
25AE: 21 86 06      ld   hl,$0606
25B1: 22 00 88      ld   (cursor_x_8800),hl
25B4: 3E B0         ld   a,$10
25B6: 32 A2 88      ld   (cursor_color_8802),a
25B9: CD 8D 26      call get_current_player_score_ptr_in_de_268D
25BC: EB            ex   de,hl
25BD: CD 40 03      call convert_number_2B40
25C0: CD D4 0C      call write_5_digits_to_screen_2C54
25C3: 3E 38         ld   a,$30
25C5: CD 1C A9      call set_tile_at_current_pos_293C
25C8: 21 A7 AE      ld   hl,$060F
25CB: 22 A8 20      ld   (cursor_x_8800),hl
25CE: CD 27 28      call get_level_number_288F
25D1: 26 00         ld   h,$00
25D3: 6F            ld   l,a
25D4: CD E0 2B      call convert_number_2B40
25D7: CD 6F 04      call write_2_digits_to_screen_2C6F
25DA: 21 B6 06      ld   hl,$0616
25DD: 22 00 88      ld   (cursor_x_8800),hl
25E0: 3E C1         ld   a,$41
25E2: 06 83         ld   b,$03
25E4: CD BC 09      call set_tile_at_current_pos_293C
25E7: 10 53         djnz $25E4
25E9: 3A DF 20      ld   a,(score_insertion_position_885F)
25EC: 3D            dec  a
25ED: 47            ld   b,a
25EE: 87            add  a,a
25EF: 80            add  a,b
25F0: C6 86         add  a,$0E
25F2: 57            ld   d,a
25F3: 1E 16         ld   e,$16
25F5: D5            push de
25F6: FD E1         pop  iy
25F8: DD 21 16 A6   ld   ix,$0616
25FC: 1E A2         ld   e,$02
25FE: ED 53 28 88   ld   (cursor_x_8800),de
2602: 3E 90         ld   a,$18
2604: 06 B7         ld   b,$17
2606: CD 05 A1      call set_attribute_at_current_pos_292D
2609: 10 D3         djnz $2606
260B: 3A FF 88      ld   a,(score_insertion_position_885F)
260E: 47            ld   b,a
260F: 3E 05         ld   a,$05
2611: 90            sub  b
2612: 87            add  a,a
2613: 47            ld   b,a
2614: 87            add  a,a
2615: 80            add  a,b
2616: 16 20         ld   d,$00
2618: 5F            ld   e,a
2619: 21 43 A8      ld   hl,high_score_names_8842+1
261C: 19            add  hl,de
261D: E5            push hl
261E: CD EF 26      call $26CF
2621: E1            pop  hl
2622: 3A D6 88      ld   a,(currently_active_letter_885E)
2625: 77            ld   (hl),a
2626: 23            inc  hl
2627: DD 23         inc  ix
2629: FD 23         inc  iy
262B: E5            push hl
262C: CD CF 26      call $26CF
262F: E1            pop  hl
2630: 3A F6 88      ld   a,(currently_active_letter_885E)
2633: 77            ld   (hl),a
2634: 23            inc  hl
2635: DD 23         inc  ix
2637: FD 23         inc  iy
2639: E5            push hl
263A: CD EF 26      call $26CF
263D: E1            pop  hl
263E: 3A F6 88      ld   a,(currently_active_letter_885E)
2641: 77            ld   (hl),a
2642: 3E A8         ld   a,$80
2644: CD F9 A0      call delay_28D1
2647: C9            ret

compute_score_insertion_position_2648:
2648: 3E A6         ld   a,$06
264A: 32 D7 88      ld   (score_insertion_position_885F),a
264D: CD 8D 26      call get_current_player_score_ptr_in_de_268D
2650: 2A 60 88      ld   hl,(hiscore_pos_5_8840)
2653: CD 99 85      call compare_hl_to_de_2D99
2656: D0            ret  nc
2657: 3E 05         ld   a,$05
2659: 32 5F A8      ld   (score_insertion_position_885F),a
265C: 2A 66 88      ld   hl,(hiscore_pos_5_8840+6)
265F: CD 99 05      call compare_hl_to_de_2D99
2662: D0            ret  nc
2663: 3E 2C         ld   a,$04
2665: 32 FF 88      ld   (score_insertion_position_885F),a
2668: 2A C4 88      ld   hl,(hiscore_pos_5_8840+12)
266B: CD 99 05      call compare_hl_to_de_2D99
266E: D0            ret  nc
266F: 3E 03         ld   a,$03
2671: 32 5F A8      ld   (score_insertion_position_885F),a
2674: 2A 72 88      ld   hl,(hiscore_pos_5_8840+$12)	; pos 2
2677: CD 99 85      call compare_hl_to_de_2D99
267A: D0            ret  nc
267B: 3E 02         ld   a,$02
267D: 32 5F A8      ld   (score_insertion_position_885F),a
2680: 2A D0 88      ld   hl,(hiscore_pos_5_8840+$18)	; pos 1
2683: CD 99 05      call compare_hl_to_de_2D99
2686: D0            ret  nc
2687: 3E 29         ld   a,$01
2689: 32 FF 88      ld   (score_insertion_position_885F),a
268C: C9            ret

get_current_player_score_ptr_in_de_268D:
268D: 3A 3E 88      ld   a,(player_number_8816)
2690: CB 47         bit  0,a		; is this player 1 or 2?
2692: 28 25         jr   z,$2699
2694: ED 5B 10 A8   ld   de,(player_2_score_8810)
2698: C9            ret
2699: ED 5B A6 88   ld   de,(player_1_score_880E)
269D: C9            ret

create_highscore_entry_269E:
; make room for newly attained highscore
269E: 11 60 88      ld   de,hiscore_pos_5_8840
26A1: 21 6E 88      ld   hl,hiscore_pos_5_8840+6
26A4: 3A D7 88      ld   a,(score_insertion_position_885F)
26A7: 47            ld   b,a
26A8: 3E A5         ld   a,$05
26AA: 90            sub  b
26AB: 28 A9         jr   z,$26B6
26AD: 87            add  a,a
26AE: 47            ld   b,a
26AF: 87            add  a,a
26B0: 80            add  a,b
26B1: 06 00         ld   b,$00
26B3: 4F            ld   c,a
26B4: ED B0         ldir
26B6: EB            ex   de,hl
26B7: E5            push hl
26B8: CD AD 26      call get_current_player_score_ptr_in_de_268D
26BB: E1            pop  hl
26BC: 73            ld   (hl),e
26BD: 23            inc  hl
26BE: 72            ld   (hl),d
26BF: 23            inc  hl
26C0: E5            push hl
; also note down act
26C1: CD 8F 00      call get_level_number_288F
26C4: E1            pop  hl
26C5: 77            ld   (hl),a
26C6: 23            inc  hl
; put space in name, will be filled later
26C7: 3E 20         ld   a,$20
26C9: 77            ld   (hl),a
26CA: 23            inc  hl
26CB: 77            ld   (hl),a
26CC: 23            inc  hl
26CD: 77            ld   (hl),a
26CE: C9            ret

26CF: 3E 10         ld   a,$10
26D1: 32 02 A8      ld   (cursor_color_8802),a
26D4: 21 F6 88      ld   hl,currently_active_letter_885E
26D7: 36 41         ld   (hl),$41
; loop to select current letter in name
26D9: CD 56 07      call write_active_letter_to_screen_2756
26DC: 3E A2         ld   a,$0A
26DE: CD 79 A0      call delay_28D1
26E1: 06 AC         ld   b,$0C
26E3: C5            push bc
26E4: CD 5B A2      call read_player_inputs_2AFB
26E7: 2F            cpl		; flip bits
26E8: C1            pop  bc
26E9: E6 8C         and  $8C
26EB: 28 2F         jr   z,$26F4
26ED: 3E 29         ld   a,$01
26EF: CD D1 80      call delay_28D1
26F2: 10 CF         djnz $26E3
26F4: CD DB 2A      call read_player_inputs_2AFB
26F7: 2F            cpl
26F8: CB 7F         bit  7,a
26FA: 20 E6         jr   nz,$274A
26FC: CB 57         bit  2,a
26FE: 20 10         jr   nz,$2730
2700: CB 5F         bit  3,a
2702: 20 B9         jr   nz,$273D
2704: 3A C8 84      ld   a,(sound_channel_0_struct_8C60)
2707: A7            and  a
2708: 20 A0         jr   nz,$2712
270A: E1            pop  hl
270B: E1            pop  hl
270C: 3E C0         ld   a,$40
270E: CD 51 28      call delay_28D1
2711: C9            ret
2712: CD 75 08      call increase_counter_0875
2715: 3A 25 88      ld   a,(counter_msb_8825)
2718: E6 A7         and  $07
271A: 20 D8         jr   nz,$26F4
271C: 06 B0         ld   b,$10
271E: 3A 25 80      ld   a,(counter_msb_8825)
2721: CB 5F         bit  3,a
2723: 20 AA         jr   nz,$2727
2725: 06 BE         ld   b,$16
2727: 78            ld   a,b
2728: 32 82 80      ld   (cursor_color_8802),a
272B: CD FE 8F      call write_active_letter_to_screen_2756
272E: 18 44         jr   $26F4
2730: 21 D6 88      ld   hl,currently_active_letter_885E
2733: 35            dec  (hl)
2734: 3E E0         ld   a,$40
2736: BE            cp   (hl)
2737: 20 A0         jr   nz,$26D9
2739: 36 5B         ld   (hl),$5B
273B: 18 9C         jr   $26D9
273D: 21 5E 88      ld   hl,currently_active_letter_885E
2740: 34            inc  (hl)
2741: 3E DC         ld   a,$5C		; did we reach after Z yet?
2743: BE            cp   (hl)
2744: 20 13         jr   nz,$26D9
2746: 36 C1         ld   (hl),$41	; wrap to A
2748: 18 27         jr   $26D9
274A: CD CB 2F      call write_active_letter_to_screen_with_color_2756
274D: 3E 98         ld   a,$18
274F: 32 02 88      ld   (cursor_color_8802),a
2752: CD F6 27      call write_active_letter_to_screen_2756
2755: C9            ret

; < ix contains XY of letter to insert in name
write_active_letter_to_screen_2756:
2756: DD E5         push ix		; ix contains X,Y
2758: E1            pop  hl		; get ix in hl (interface needs it)
2759: 22 00 88      ld   (cursor_x_8800),hl
275C: 3A D6 88      ld   a,(currently_active_letter_885E)	; currently active letter
275F: CD 1C A9      call set_tile_at_current_pos_293C
2762: C9            ret

write_active_letter_to_screen_with_color_2756:
2763: 3E 98         ld   a,$18
2765: 32 AA 20      ld   (cursor_color_8802),a
2768: FD E5         push iy
276A: 18 6C         jr   $2758

display_highs_276C:
276C: 21 5F 2F      ld   hl,todays_best_text_27F7
276F: 06 02         ld   b,$02
2771: CD F4 01      call print_line_typewriter_style_29F4
2774: 10 5B         djnz $2771
2776: 21 E5 28      ld   hl,score_act_text_2845
2779: 06 06         ld   b,$06
print_b_lines_277B:
277B: CD F4 01      call print_line_typewriter_style_29F4
277E: 10 5B         djnz print_b_lines_277B
2780: 3E 91         ld   a,$11
2782: 32 82 80      ld   (cursor_color_8802),a
2785: 11 AE A6      ld   de,$0E06
2788: 21 F0 80      ld   hl,hiscore_pos_5_8840+$18
278B: CD 33 8F      call write_best_score_27B3
278E: 11 86 11      ld   de,$1106
2791: 21 52 88      ld   hl,hiscore_pos_5_8840+$12
2794: CD 3B 27      call write_best_score_27B3
2797: 11 06 B4      ld   de,$1406
279A: 21 C4 88      ld   hl,hiscore_pos_5_8840+12
279D: CD B3 27      call write_best_score_27B3
27A0: 11 86 BF      ld   de,$1706
27A3: 21 EE 20      ld   hl,hiscore_pos_5_8840+6
27A6: CD 1B 2F      call write_best_score_27B3
27A9: 11 AE B2      ld   de,$1A06
27AC: 21 C0 80      ld   hl,hiscore_pos_5_8840
27AF: CD B3 27      call write_best_score_27B3
27B2: C9            ret

; < DE: XY
; < HL: address of score
write_best_score_27B3:
27B3: ED 53 A0 88   ld   (cursor_x_8800),de
27B7: 5E            ld   e,(hl)
27B8: 23            inc  hl
27B9: 56            ld   d,(hl)
27BA: 23            inc  hl
27BB: E5            push hl
27BC: EB            ex   de,hl
27BD: CD 40 03      call convert_number_2B40
27C0: CD D4 0C      call write_5_digits_to_screen_2C54
27C3: 3E 38         ld   a,$30
27C5: CD 1C A9      call set_tile_at_current_pos_293C
27C8: 06 83         ld   b,$03
27CA: CD 80 09      call put_blank_at_current_pos_2900
27CD: 10 53         djnz $27CA
27CF: E1            pop  hl
27D0: 7E            ld   a,(hl)
27D1: 23            inc  hl
27D2: E5            push hl
27D3: 26 00         ld   h,$00
27D5: 6F            ld   l,a
27D6: CD E0 2B      call convert_number_2B40
27D9: CD 6F 04      call write_2_digits_to_screen_2C6F
27DC: 06 A5         ld   b,$05
27DE: CD A0 09      call put_blank_at_current_pos_2900
27E1: 10 53         djnz $27DE
27E3: E1            pop  hl
27E4: CD 68 2F      call $27E8
27E7: C9            ret
27E8: 7E            ld   a,(hl)
27E9: CD 1C A9      call set_tile_at_current_pos_293C
27EC: 23            inc  hl
27ED: 7E            ld   a,(hl)
27EE: CD BC 29      call set_tile_at_current_pos_293C
27F1: 23            inc  hl
27F2: 7E            ld   a,(hl)
27F3: CD 3C 01      call set_tile_at_current_pos_293C
27F6: C9            ret
todays_best_text_27F7:
  07 08 18 54 4F 44 41 59 3E 53 20 20 42 45 53 54  ; ...TODAY>S  BEST
2807  20 B5 07 05 10 4C 49 53 54 20 4F 46 20 50 4C 41  ;  µ...LIST OF PLA
2817  59 45 D2 05 02 18 45 4E 54 45 52 20 59 4F 55 52  ; YEÒ...ENTER YOUR
2827  20 49 4E 49 54 49 41 4C D3 07 04 17 53 43 4F 52  ;  INITIALÓ...SCOR
2837  45 20 20 20 41 43 54 20 20 20 4E 41 4D C5   ; E   ACT   NAMÅ..
score_act_text_2845:  07 0B 19 53 43 4F 52 45 20 20 20 41 43 54 20 20 20 4E  ; .SCORE   ACT   N
2857  41 4D C5 02 0E 11 31 53 D4 02 11 11 32 4E C4 02  ; AMÅ...1SÔ...2NÄ.
2867  14 11 33 52 C4 02 17 11 34 54 C8 02 1A 11 35 54  ; ..3RÄ...4TÈ...5TH
2877  C8 

set_proper_screen_orientation_2878:
2878: 06 20         ld   b,$00
287A: 3A B0 88      ld   a,(cocktail_mode_8818)
287D: CB 47         bit  0,a
287F: 28 A9         jr   z,$288A
2881: 3A 3E 88      ld   a,(player_number_8816)
2884: CB 47         bit  0,a
2886: 28 A2         jr   z,$288A
2888: 06 5F         ld   b,$FF
288A: 78            ld   a,b
288B: 32 6B B8      ld   (flip_screen_9043),a
288E: C9            ret
	
get_level_number_288F:
288F: 21 12 A8      ld   hl,level_number_player1_8812
2892: 3A 36 88      ld   a,(player_number_8816)
2895: CB 47         bit  0,a
2897: 28 03         jr   z,$289C
2899: 21 13 A8      ld   hl,level_number_player2_8813
289C: 7E            ld   a,(hl)
289D: C9            ret
	
get_nb_lives_289E: 
289E: 21 34 88      ld   hl,lives_counter_p1_8814
28A1: 3A 3E 88      ld   a,(player_number_8816)
28A4: CB 47         bit  0,a
28A6: 28 A3         jr   z,$28AB
28A8: 21 B5 88      ld   hl,lives_counter_p2_8815
28AB: 7E            ld   a,(hl)
28AC: E6 57         and  $7F
28AE: C9            ret

add_to_current_player_score_28AF:
28AF: 3A 19 A8      ld   a,(currently_playing_8819)
28B2: A7            and  a
28B3: C8            ret  z
28B4: 3A 36 88      ld   a,(player_number_8816)
28B7: CB 47         bit  0,a
28B9: 28 0B         jr   z,$28C6
28BB: 2A 10 A8      ld   hl,(player_2_score_8810)
28BE: 19            add  hl,de
28BF: 22 38 88      ld   (player_2_score_8810),hl
28C2: CD 24 A4      call update_and_display_p1_score_2C24
28C5: C9            ret

; add de to player 1 score
28C6: 2A 86 88      ld   hl,(player_1_score_880E)
28C9: 19            add  hl,de
28CA: 22 86 88      ld   (player_1_score_880E),hl
28CD: CD 86 03      call update_and_display_p1_score_2BAE
28D0: C9            ret

	;; a:	value to wait (1 = 1/5th of seconds roughly speaking)
delay_28D1:
28D1: 32 20 A8      ld   (delay_timer_8820),a
28D4: 3A 00 88      ld   a,(delay_timer_8820)
28D7: A7            and  a
28D8: 20 DA         jr   nz,$28D4
28DA: C9            ret

	;; unused wait routine
delay_28DB: 32 21 A8      ld   (delay_timer_2_8821),a
28DE: 3A 01 88      ld   a,(delay_timer_2_8821)
28E1: A7            and  a
28E2: 20 5A         jr   nz,$28DE
28E4: C9            ret
	
clear_screen_and_colors_28E5:
28E5: 21 28 A8      ld   hl,video_tile_memory_8000
28E8: 11 A1 08      ld   de,$8001
28EB: 01 D6 A3      ld   bc,$03FE
28EE: 36 20         ld   (hl),$20
; copy overlap to clear tiles
28F0: ED B0         ldir
; same thing with attributes
28F2: 21 20 84      ld   hl,video_attribute_memory_8400
28F5: 11 01 2C      ld   de,$8401
28F8: 01 DE 03      ld   bc,$03FE
28FB: 36 00         ld   (hl),$00
28FD: ED B0         ldir
28FF: C9            ret

put_blank_at_current_pos_2900:
2900: F5            push af
2901: 3E 28         ld   a,$20
2903: CD 1C A9      call set_tile_at_current_pos_293C
2906: F1            pop  af
2907: C9            ret

; this seems to be never called
2908: C5            push bc
2909: 06 AB         ld   b,$03

move_cursor_b_290B:
290B: F5            push af
290C: E5            push hl
290D: 21 A8 20      ld   hl,cursor_x_8800
2910: 7E            ld   a,(hl)
2911: 90            sub  b
2912: 77            ld   (hl),a
2913: 23            inc  hl
2914: 34            inc  (hl)
2915: E1            pop  hl
2916: F1            pop  af
2917: C1            pop  bc
2918: C9            ret

move_cursor_1_2919:
2919: C5            push bc
291A: 06 A1         ld   b,$01
291C: 18 4D         jr   move_cursor_b_290B

move_cursor_2_291E:
291E: C5            push bc
291F: 06 AA         ld   b,$02
2921: 18 40         jr   move_cursor_b_290B

move_cursor_4_2923:
2923: C5            push bc
2924: 06 84         ld   b,$04
2926: 18 4B         jr   move_cursor_b_290B

move_cursor_1A_2928:
2928: C5            push bc
2929: 06 9A         ld   b,$1A
292B: 18 D6         jr   move_cursor_b_290B

; < A: attribute code to put at current screen address
; (doesn't write at this address but in attributes at +$400)
; updates current position

set_attribute_at_current_pos_292D:
292D: F5            push af
292E: C5            push bc
292F: D5            push de
2930: E5            push hl
2931: F5            push af
2932: ED 4B 00 88   ld   bc,(cursor_x_8800)
2936: CD 47 29      call convert_coords_to_screen_address_296F
2939: F1            pop  af
293A: 18 B3         jr   $294F
	
; < A: tile code to put at current screen address with current color
; updates current position X+=1, and Y+=1 if X at end of line

set_tile_at_current_pos_293C:
293C: F5            push af			; store a lot of registers :)
293D: C5            push bc
293E: D5            push de
293F: E5            push hl
2940: F5            push af			; save A again
2941: ED 4B 80 80   ld   bc,(cursor_x_8800)						; get current X & Y
2945: CD 4F A9      call convert_coords_to_screen_address_296F	; convert to address in HL
2948: F1            pop  af			; restore A
2949: 77            ld   (hl),a		; put value of A at screen XY
294A: 3A 82 80      ld   a,(cursor_color_8802)	; get current attribute
294D: E6 9F         and  $1F			; mask attribute bits
294F: 11 00 A4      ld   de,$0400		; address of attributes = screen + 0x400
2952: 19            add  hl,de
2953: 77            ld   (hl),a			; store attribute for tile
2954: 79            ld   a,c
2955: 3C            inc  a						; X += 1
2956: 4F            ld   c,a
2957: FE 1D         cp   $1D					; X > $1C (end of line) ?
2959: 38 0B         jr   c,$2966				; no, store X and Y and go out
295B: 0E 00         ld   c,$00					; set C (X) to 0
295D: 78            ld   a,b
295E: 3C            inc  a
295F: 47            ld   b,a					; Y += 1
2960: FE 8C         cp   $24					; Y > $24 (end of screen) ?
2962: 38 82         jr   c,$2966				; no, leave it
2964: 06 80         ld   b,$00					; start of screen
2966: ED 43 A8 20   ld   (cursor_x_8800),bc		; update current cursor pos
296A: E1            pop  hl
296B: D1            pop  de
296C: C1            pop  bc
296D: F1            pop  af
296E: C9            ret
	
; converts coordinates to screen address
; 8000 is bottom of screen
; < B: X
; < C: Y
; > HL
convert_coords_to_screen_address_296F: 
296F: 78            ld   a,b		; load B into A
2970: FE 20         cp   $20		; is A < $20
2972: 30 B5         jr   nc,$2989	; if A >= $20 goto $2989
2974: 79            ld   a,c		; load C (Y) into A
2975: FE 1C         cp   $1C		; compare
2977: 30 39         jr   nc,$29B2	; if A >= $1C goto $29B2
2979: 87            add  a,a		; multiply a by 2
297A: 16 A0         ld   d,$00
297C: 5F            ld   e,a		; extend a into DE
297D: 21 B6 01      ld   hl,screen_line_address_table_29B6
2980: 19            add  hl,de		; to get an entry into address table
2981: 5E            ld   e,(hl)		; load e
2982: 23            inc  hl
2983: 56            ld   d,(hl)		; load d: loads address in DE
2984: 26 80         ld   h,$00
2986: 68            ld   l,b
; acts like multiply table for Y plus X
2987: 19            add  hl,de
2988: C9            ret
; handle limit cases
2989: FE 2A         cp   $22
298B: 30 8C         jr   nc,$2999
298D: 21 AA 00      ld   hl,$8002
2990: CB 47         bit  0,a
2992: 28 A3         jr   z,$2997
2994: 21 22 80      ld   hl,$8022
2997: 18 0E         jr   $29A7
2999: FE 24         cp   $24
299B: 30 15         jr   nc,$29B2
299D: 21 C2 AB      ld   hl,$83C2		; set screen address to 83C2
29A0: CB 47         bit  0,a
29A2: 28 83         jr   z,$29A7
29A4: 21 4A A3      ld   hl,$83E2		; set screen address to 83E2
29A7: 3E 9B         ld   a,$1B
29A9: B9            cp   c
29AA: 38 86         jr   c,$29B2
29AC: 91            sub  c
29AD: 16 A8         ld   d,$00
29AF: 5F            ld   e,a
29B0: 19            add  hl,de
29B1: C9            ret
29B2: 21 A0 80      ld   hl,video_tile_memory_8000
29B5: C9            ret

screen_line_address_table_29B6:  
	.word	$83A0,$8380,$8360,$8340,$8320,$8300,$82E0,$82C0
	.word	$82A0,$8280,$8260,$8240,$8220,$8200,$81E0,$81C0
	.word	$81A0,$8180,$8160,$8140,$8120,$8100,$80E0,$80C0
	.word	$80A0,$8080,$8060,$8040,$8020,$8000,$8000
;29C6:  A0 82 80 82 60 82 40 82 20 82 00 82 E0 81 C0 81 
;29D6:  A0 81 80 81 60 81 40 81 20 81 00 81 E0 80 C0 80 
;29E6:  A0 80 80 80 60 80 40 80 20 80 00 80 00 80 

; HL contains pointer on coordinates + color & attributes + text
print_line_typewriter_style_29F4:
29F4: 7E            ld   a,(hl)					; load text X
29F5: 32 00 88      ld   (cursor_x_8800),a		; store in current X
29F8: 23            inc  hl
29F9: 7E            ld   a,(hl)                 ; load text Y
29FA: 32 A1 88      ld   (cursor_y_8801),a      ; store in current Y
29FD: 23            inc  hl
29FE: 7E            ld   a,(hl)					; load text color
29FF: 32 2A 88      ld   (cursor_color_8802),a	; store in current color
2A02: 23            inc  hl
2A03: 7E            ld   a,(hl)					; get character
2A04: CB 7F         bit  7,a
2A06: 20 B2         jr   nz,$2A1A
2A08: CD 14 A1      call set_tile_at_current_pos_293C
2A0B: 23            inc  hl
2A0C: 3A A2 88      ld   a,(cursor_color_8802)
2A0F: CB 7F         bit  7,a		; stop when last bit is set
2A11: 28 F0         jr   z,$2A03
2A13: 3E 04         ld   a,$04
2A15: CD D1 80      call delay_28D1
2A18: 18 C9         jr   $2A03
2A1A: E6 D7         and  $7F
2A1C: CD 94 29      call set_tile_at_current_pos_293C
2A1F: 23            inc  hl
2A20: 3A A2 88      ld   a,(cursor_color_8802)
2A23: CB 7F         bit  7,a
2A25: C8            ret  z
2A26: 3E A4         ld   a,$04
2A28: CD F9 A0      call delay_28D1
2A2B: C9            ret

2A2C: 21 55 A2      ld   hl,push_string_2A7D
2A2F: CD F4 81      call print_line_typewriter_style_29F4
2A32: 21 2F 2A      ld   hl,start_button_string_2A87
2A35: CD F4 81      call print_line_typewriter_style_29F4
2A38: 01 3F 2A      ld   bc,one_or_two_player_string_2A97
2A3B: 16 01         ld   d,$01
2A3D: 3A 08 A8      ld   a,(number_of_credits_8808)
2A40: BA            cp   d
2A41: 20 2B         jr   nz,$2A46
2A43: 01 80 02      ld   bc,one_player_only_string_2AA8
2A46: 60            ld   h,b
2A47: 69            ld   l,c
2A48: CD 7C A1      call print_line_typewriter_style_29F4
2A4B: 21 90 02      ld   hl,credit_string_2AB8
2A4E: CD 7C 29      call print_line_typewriter_style_29F4
2A51: CD 7A 83      call display_number_of_credits_2B7A
2A54: 21 EE 2A      ld   hl,copyright_string_2ACE
2A57: CD F4 81      call print_line_typewriter_style_29F4
2A5A: 21 FC 2A      ld   hl,bonus_for_30000_pts_2ADC
2A5D: CD F4 81      call print_line_typewriter_style_29F4
2A60: 21 7B A2      ld   hl,for_50000_pts_2AF3
2A63: 3A 68 B8      ld   a,(dip_switches_9040)
2A66: CB 47         bit  0,a
; if DWS is set accordignly, overwrite "30000" string with "50000"
2A68: C4 7C A1      call nz,print_line_typewriter_style_29F4
2A6B: 3E AB         ld   a,$0B
2A6D: 32 2A 88      ld   (cursor_color_8802),a
2A70: 26 34         ld   h,$14
2A72: 2E 23         ld   l,$03
2A74: 22 20 88      ld   (cursor_x_8800),hl
2A77: 3E 24         ld   a,$24
2A79: CD 00 87      call set_2x2_tile_2F00
2A7C: C9            ret
push_string_2A7D:
	dc.b	$0A,$09,$17,$50,$20,$55,$20,$53,$20
	dc.b	$C8,$07,$0C,$10,$53,$54,$41   . .P U S È...STA
2A8D  52 54 20 20 42 55 54 54 4F CE 07 0F 18 31 20 4F   RT  BUTTOÎ...1 O
2A9D  52 20 32 20 50 4C 41 59 45 52 D3 07 0F 18 31 20   R 2 PLAYERÓ...1
2AAD  50 4C 41 59 45 52 20 4F 4E 4C D9 07 12 10 43 52   PLAYER ONLÙ...CR
2ABD  45 44 49 54 A0 07 0F 10 46 52 45 45 20 50 4C 41   EDIT ...FREE PLA
2ACD  D9 

copyright_string_2ACE;
	08 19 10 40 20 53 45 47 41 20 31 39 38 B2
bonus_for_30000_pts_2ADC:
  06 15 18 42 4F 4E 55 53 20 46 4F 52 20 33 30 30 30   ;..BONUS FOR 3000
  30 20 50 54 53 BA
for_50000_pts_2AF3:
	10 15 18 35 30 30 30 B0  ; 0 PTSº...5000°


; > A (active low): control bits
read_player_inputs_2AFB:
2AFB: 3A 18 A8      ld   a,(cocktail_mode_8818)
2AFE: A7            and  a
2AFF: 28 8B         jr   z,$2B0C
2B01: 3A BE 20      ld   a,(player_number_8816)
2B04: E6 81         and  $01
2B06: 28 84         jr   z,$2B0C
; read player 2 joystick
2B08: 3A 00 B0      ld   a,($9080)
2B0B: C9            ret
; read player 1 joystick
2B0C: 3A 40 B0      ld   a,(coin_input_90C0)
2B0F: C9            ret

update_all_scores_2B10:
2B10: 21 20 2B      ld   hl,score_titles_string_2B20
2B13: CD F4 01      call print_line_typewriter_style_29F4
2B16: CD BB 2B      call write_hiscore_to_screen_2B93
2B19: CD AE 03      call update_and_display_p1_score_2BAE
2B1C: CD 24 2C      call update_and_display_p1_score_2C24
2B1F: C9            ret

score_titles_string_2B20:
	dc.b	$01,$22,$11,$31,$50,$20,$20,$20,$20,$20,$20,$20
	dc.b	$48,$49,$20,$20,$20,$20,$20,$20,$20,$32,$D0   ; 01 21 10 43 52 45 44 49 D4        2Ð.!.CREDIÔ

; < HL: write pseudo-BCD 4 digits at current cursor
; updates number_buffer_8803
convert_number_2B40:
2B40: DD E5         push ix
2B42: FD E5         push iy
2B44: FD 21 78 AB   ld   iy,powers_of_ten_table_2B70
2B48: DD 21 AB 20   ld   ix,number_buffer_8803
2B4C: AF            xor  a
2B4D: FD 5E 80      ld   e,(iy+x_pos)
2B50: FD 56 01      ld   d,(iy+y_pos)
2B53: A7            and  a
2B54: ED 52         sbc  hl,de
2B56: 38 A3         jr   c,$2B5B
2B58: 3C            inc  a
2B59: 18 F8         jr   $2B53
2B5B: 19            add  hl,de
2B5C: F6 30         or   $30		; add '0' character
2B5E: DD 77 A8      ld   (ix+$00),a	; store in buffer
2B61: DD 23         inc  ix
2B63: FD 23         inc  iy
2B65: FD 23         inc  iy
2B67: CB 43         bit  0,e
2B69: 28 61         jr   z,$2B4C
2B6B: FD E1         pop  iy
2B6D: DD E1         pop  ix
2B6F: C9            ret
powers_of_ten_table_2B70: 
	dc.w	10000,1000,100,10,1

display_number_of_credits_2B7A:
2B7A: 3A 80 88		ld   a,(number_of_credits_8808)                                      
2B7D: 26 00         ld   h,$00
2B7F: 6F            ld   l,a
2B80: CD C0 0B      call convert_number_2B40
2B83: 26 BA         ld   h,$12
2B85: 2E 8F         ld   l,$0F
2B87: 22 A8 20      ld   (cursor_x_8800),hl
2B8A: 3E 90         ld   a,$10
2B8C: 32 82 80      ld   (cursor_color_8802),a
2B8F: CD 6F 04      call write_2_digits_to_screen_2C6F
2B92: C9            ret

write_hiscore_to_screen_2B93:
2B93: 2A 0C 88      ld   hl,(high_score_880C)
2B96: CD E0 2B      call convert_number_2B40
2B99: 26 22         ld   h,$22
2B9B: 2E 0C         ld   l,$0C
2B9D: 22 00 88      ld   (cursor_x_8800),hl
2BA0: 3E 90         ld   a,$10
2BA2: 32 82 80      ld   (cursor_color_8802),a
2BA5: CD FC AC      call write_5_digits_to_screen_2C54
2BA8: 3E 98         ld   a,$30		; write the fixed '0' for score
2BAA: CD BC 09      call set_tile_at_current_pos_293C
2BAD: C9            ret

update_and_display_p1_score_2BAE:
2BAE: 2A A6 88      ld   hl,(player_1_score_880E)
2BB1: CD 40 03      call convert_number_2B40
2BB4: 26 22         ld   h,$22
2BB6: 2E A3         ld   l,$03
2BB8: 22 A0 88      ld   (cursor_x_8800),hl
2BBB: 3E 10         ld   a,$10
2BBD: 32 02 88      ld   (cursor_color_8802),a
2BC0: CD D4 0C      call write_5_digits_to_screen_2C54
2BC3: 3E 38         ld   a,$30		; write the fixed '0' for score
2BC5: CD 1C A9      call set_tile_at_current_pos_293C
2BC8: CD 76 0B      call check_p1_score_for_extra_life_2BAE
2BCB: 2A 8C 20      ld   hl,(high_score_880C)
2BCE: ED 5B 0E 88   ld   de,(player_1_score_880E)
2BD2: CD 99 2D      call compare_hl_to_de_2D99
2BD5: D0            ret  nc
2BD6: ED 53 0C 88   ld   (high_score_880C),de
2BDA: CD BB 2B      call write_hiscore_to_screen_2B93
2BDD: C9            ret

check_p1_score_for_extra_life_2BAE:
2BDE: 21 B4 80      ld   hl,lives_counter_p1_8814
2BE1: CB 7E         bit  7,(hl)
2BE3: C0            ret  nz
2BE4: E5            push hl
2BE5: 2A 8E 20      ld   hl,(player_1_score_880E)
2BE8: 11 38 8B      ld   de,$0BB8
2BEB: 3A E8 10      ld   a,(dip_switches_9040)
2BEE: CB 47         bit  0,a
2BF0: 28 A3         jr   z,$2BF5
2BF2: 11 88 13      ld   de,$1388		; 5000
2BF5: CD 99 05      call compare_hl_to_de_2D99
2BF8: E1            pop  hl
2BF9: D8            ret  c
2BFA: 34            inc  (hl)
2BFB: CB FE         set  7,(hl)
2BFD: CD 13 05      call draw_lives_2D13
2C00: 06 A1         ld   b,$01
2C02: CD 0F B8      call sound_18AF
2C05: C9            ret

check_p2_score_for_extra_life_2C06:
2C06: 21 B5 88      ld   hl,lives_counter_p2_8815
2C09: CB 7E         bit  7,(hl)
2C0B: C0            ret  nz
2C0C: E5            push hl
2C0D: 2A 38 88      ld   hl,(player_2_score_8810)
2C10: 11 98 0B      ld   de,$0BB8
2C13: 3A 40 38      ld   a,(dip_switches_9040)
2C16: CB 47         bit  0,a
2C18: 28 23         jr   z,$2C1D
2C1A: 11 A8 13      ld   de,$1388		; 5000
2C1D: CD 99 85      call compare_hl_to_de_2D99
2C20: E1            pop  hl
2C21: D8            ret  c
2C22: 18 FE         jr   $2BFA

update_and_display_p1_score_2C24:
2C24: 2A B0 88      ld   hl,(player_2_score_8810)
2C27: CD 68 03      call convert_number_2B40
2C2A: 26 22         ld   h,$22
2C2C: 2E B5         ld   l,$15
2C2E: 22 A0 88      ld   (cursor_x_8800),hl
2C31: 3E 10         ld   a,$10
2C33: 32 02 A8      ld   (cursor_color_8802),a
2C36: CD 74 2C      call write_5_digits_to_screen_2C54
2C39: 3E 30         ld   a,$30
2C3B: CD 3C 81      call set_tile_at_current_pos_293C
2C3E: CD 26 A4      call check_p2_score_for_extra_life_2C06
2C41: 2A AC 88      ld   hl,(high_score_880C)
2C44: ED 5B 38 88   ld   de,(player_2_score_8810)
2C48: CD 99 A5      call compare_hl_to_de_2D99
2C4B: D0            ret  nc
2C4C: ED 53 AC 88   ld   (high_score_880C),de
2C50: CD 3B 2B      call write_hiscore_to_screen_2B93
2C53: C9            ret

write_5_digits_to_screen_2C54:
2C54: 06 25         ld   b,$05		; write 5 numbers
2C56: 21 23 88      ld   hl,number_buffer_8803	; source
2C59: 7E            ld   a,(hl)
2C5A: FE 10         cp   $30		; compare to '0'
2C5C: 20 A1         jr   nz,$2C67	; different from 0, write all numbers
; do not write leading zeroes
2C5E: 3E 00         ld   a,$20
2C60: CD 14 A1      call set_tile_at_current_pos_293C
2C63: 23            inc  hl
2C64: 10 7B         djnz $2C59
2C66: C9            ret
2C67: 7E            ld   a,(hl)
2C68: CD 14 A1      call set_tile_at_current_pos_293C
2C6B: 23            inc  hl
2C6C: 10 59         djnz $2C67
2C6E: C9            ret

write_2_digits_to_screen_2C6F:
2C6F: 06 02         ld   b,$02		; write 2 numbers
2C71: 21 06 A8      ld   hl,number_buffer_8803+3	; source
2C74: 18 4B         jr   $2C59

; draws SEGA, ACT x, and flags
draw_status_bar_2C76:
2C76: 21 5C 2C      ld   hl,sega_1982_string_2CF4
2C79: CD F4 81      call print_line_typewriter_style_29F4
2C7C: 21 22 2D      ld   hl,act_string_2D02
2C7F: CD 54 01      call print_line_typewriter_style_29F4
2C82: CD 8F A0      call get_level_number_288F
2C85: 26 28         ld   h,$00
2C87: 6F            ld   l,a
2C88: CD E0 A3      call convert_number_2B40
2C8B: CD E7 04      call write_2_digits_to_screen_2C6F
2C8E: 21 A7 21      ld   hl,$2107		; X,Y
2C91: 22 00 A8      ld   (cursor_x_8800),hl
2C94: 3E A2         ld   a,$0A
2C96: 32 22 88      ld   (cursor_color_8802),a
2C99: CD 8F 80      call get_level_number_288F
2C9C: FE 26         cp   $06
2C9E: 38 24         jr   c,$2CA4
2CA0: D6 A5         sub  $05
2CA2: 18 58         jr   $2C9C
2CA4: 47            ld   b,a
2CA5: C5            push bc
2CA6: 3E 86         ld   a,$0E
2CA8: CD 14 A1      call set_tile_at_current_pos_293C
2CAB: 3E AF         ld   a,$0F
2CAD: CD B4 01      call set_tile_at_current_pos_293C
2CB0: C1            pop  bc
2CB1: 10 F2         djnz $2CA5
2CB3: 06 00         ld   b,$00
2CB5: CD 8F 80      call get_level_number_288F
2CB8: FE 26         cp   $06
2CBA: 38 25         jr   c,$2CC1
2CBC: D6 25         sub  $05
2CBE: 04            inc  b
2CBF: 18 57         jr   $2CB8
2CC1: 05            dec  b
2CC2: 04            inc  b
2CC3: C8            ret  z
2CC4: C5            push bc
2CC5: 78            ld   a,b
2CC6: 3D            dec  a
2CC7: 16 28         ld   d,$00
2CC9: 5F            ld   e,a
2CCA: 21 80 A5      ld   hl,x_table_2D08
2CCD: 19            add  hl,de
2CCE: 7E            ld   a,(hl)
2CCF: 26 23         ld   h,$23
2CD1: 6F            ld   l,a
; draw a penguin holding the "5 levels" flag
2CD2: 22 20 88      ld   (cursor_x_8800),hl
2CD5: E5            push hl
2CD6: 3E A0         ld   a,$08
2CD8: CD 94 29      call set_tile_at_current_pos_293C
2CDB: 3E 09         ld   a,$09
2CDD: CD 3C 81      call set_tile_at_current_pos_293C
2CE0: E1            pop  hl
2CE1: 26 28         ld   h,$00
2CE3: 22 28 88      ld   (cursor_x_8800),hl
2CE6: 3E 82         ld   a,$0A
2CE8: CD 14 A1      call set_tile_at_current_pos_293C
2CEB: 3E AB         ld   a,$0B
2CED: CD B4 01      call set_tile_at_current_pos_293C
2CF0: C1            pop  bc
2CF1: 10 D1         djnz $2CC4	; draws flags as long as needed
2CF3: C9            ret
sega_1982_string_2CF4:
	dc.b	$11,$21,$10,$40	; attributes + copyright char
	dc.b	"SEGA 198"
	dc.b	"2"+$80
act_string_2D02;
	dc.b	$01,$21,$10
	dc.b	"AC"
	dc.b	'T'+$80 
x_table_2D08:
	dc.b 	$1A,$18,$16,$14 

draw_lives_2D0C:
2D0C: CD 36 08      call get_nb_lives_289E
2D0F: A7            and  a
2D10: C8            ret  z
2D11: 18 05         jr   $2D18


draw_lives_2D13:
2D13: CD 9E 00      call get_nb_lives_289E
2D16: 3D            dec  a
2D17: C8            ret  z
2D18: FE A5         cp   $05
2D1A: 38 A2         jr   c,$2D1E
2D1C: 3E A4         ld   a,$04
2D1E: 47            ld   b,a
2D1F: 3E 8B         ld   a,$0B
2D21: 32 AA 20      ld   (cursor_color_8802),a
2D24: 0E 8C         ld   c,$24		; pengo life upper left tile
2D26: C5            push bc
2D27: 78            ld   a,b
2D28: 3D            dec  a
2D29: 87            add  a,a
2D2A: 26 8B         ld   h,$23
2D2C: 6F            ld   l,a
2D2D: 22 A8 20      ld   (cursor_x_8800),hl
2D30: E5            push hl
2D31: 79            ld   a,c
2D32: CD 14 29      call set_tile_at_current_pos_293C
2D35: 3C            inc  a
2D36: CD 14 29      call set_tile_at_current_pos_293C
2D39: E1            pop  hl
2D3A: 26 A0         ld   h,$00
2D3C: 22 A0 88      ld   (cursor_x_8800),hl
2D3F: 3C            inc  a
2D40: CD BC 09      call set_tile_at_current_pos_293C
2D43: 3C            inc  a
2D44: CD BC 09      call set_tile_at_current_pos_293C
2D47: C1            pop  bc
2D48: 10 74         djnz $2D26
2D4A: C9            ret
	;; 
display_eggs_2D4B: 
2D4B: 3A E0 25      ld   a,(total_eggs_to_hatch_8DC0)
2D4E: 47            ld   b,a
2D4F: 3E 0C         ld   a,$0C
2D51: 90            sub  b
2D52: CB 3F         srl  a
2D54: C6 80         add  a,$08
2D56: 26 A0         ld   h,$00
2D58: 6F            ld   l,a
2D59: 22 00 88      ld   (cursor_x_8800),hl
2D5C: 3E B0         ld   a,$10
2D5E: 32 A2 80      ld   (cursor_color_8802),a
2D61: E5            push hl
2D62: 3E 96         ld   a,$16
2D64: CD BC 09      call set_tile_at_current_pos_293C
2D67: 10 53         djnz $2D64
2D69: E1            pop  hl
2D6A: 3A 41 85      ld   a,(remaining_eggs_to_hatch_8DC1)
2D6D: 47            ld   b,a
2D6E: 3A 40 8D      ld   a,(total_eggs_to_hatch_8DC0)
2D71: 90            sub  b
2D72: 47            ld   b,a
2D73: 22 00 88      ld   (cursor_x_8800),hl
2D76: CD A0 29      call put_blank_at_current_pos_2900
2D79: 10 FB         djnz $2D76
2D7B: C9            ret

	;; return random 8 bit value
	;;
	;; can be translated in python as follows

;hl = 0x365A  # pengo start value after a reboot
;
;def pengo_random():
;    global hl
;    b = (hl & 0xFF00) >> 8
;    c = (hl & 0xFF)
;    hl = (hl * 2)
;    bc = (b << 8) + c
;    hl = (hl + bc) & 0xFFFF
;
;    a = c
;    h = (hl & 0xFF00) >> 8
;    a = (a + h) & 0xFF
;
;    hl = (hl & 0xFF) + (a<<8)
;    return a
;
;print ("%x" % pengo_random()) # 0xFD
;print ("%x" % pengo_random()) # 0x05
;print ("%x" % pengo_random()) # 0x39

get_random_value_2D7C:
2D7C: C5            push bc
2D7D: E5            push hl
2D7E: 2A 26 80      ld   hl,(random_seed_8826)
2D81: 44            ld   b,h
2D82: 4D            ld   c,l
2D83: 29            add  hl,hl
2D84: 09            add  hl,bc
2D85: 79            ld   a,c
2D86: 84            add  a,h
2D87: 67            ld   h,a
2D88: 22 8E 80      ld   (random_seed_8826),hl
2D8B: E1            pop  hl
2D8C: C1            pop  bc
2D8D: C9            ret
2D8E: EB            ex   de,hl

;; kinds of jmp (de,a*2) (68k instruction)
;; < de:	jump table
;; < a:	index
indirect_jump_2D8F: 
2D8F: 26 00         ld   h,$00
2D91: 6F            ld   l,a
2D92: 29            add  hl,hl
2D93: 19            add  hl,de
2D94: 5E            ld   e,(hl)
2D95: 23            inc  hl
2D96: 56            ld   d,(hl)
2D97: EB            ex   de,hl
2D98: E9            jp   (hl)

; computes D-H, then E-L if D-H != 0
; < HL
; < DE
; < Z if equal, NZ otherwise, C flag set for first different value
compare_hl_to_de_2D99:
2D99: 7C            ld   a,h
2D9A: 92            sub  d
2D9B: C0            ret  nz
2D9C: 7D            ld   a,l
2D9D: 93            sub  e
2D9E: C9            ret
	
2D9F: 5F            ld   e,a
2DA0: 57            ld   d,a
	
draw_maze_2DA1:
2DA1: CD DD AE      call draw_borders_2E5D
2DA4: CD 65 0E      call $2ECD
2DA7: CD BC AF      call show_maze_with_line_delay_effect_2F14
2DAA: 3A C0 B0      ld   a,(dip_switches_9040)
2DAD: 2F            cpl		; flip bits
2DAE: CB 6F         bit  5,a
2DB0: C0            ret  nz	; rack test:	don't draw
	
2DB1: 06 01         ld   b,$01			; draw maze sound
2DB3: CD 89 90      call play_sfx_1889	; sound routine

	;; install a modifiable routine in ram_code_8C24 (self-modifying code used
	;; for maze path drawing)
	
2DB6: 06 85         ld   b,$0D
2DB8: 11 11 2E      ld   de,to_copy_2E39
2DBB: 21 24 8C      ld   hl,ram_code_8C24
2DBE: 1A            ld   a,(de)
2DBF: 77            ld   (hl),a
2DC0: 13            inc  de
2DC1: 23            inc  hl
2DC2: 10 7A         djnz $2DBE

	;; initialize
2DC4: DD 21 28 24   ld   ix,maze_data_8C20
2DC8: DD 36 1F 80   ld   (ix+$3f),$00
2DCC: 21 80 A8      ld   hl,$0000
2DCF: 22 22 8C      ld   maze_data_8C20+2,hl ;  first hole at 0,0
2DD2: CD 95 31      call draw_one_hole_311D	;  first hole in block path drawn at 0,0
	;; will try to initiate paths every 2 blocks (vertically and horizontally)
	;; in the end, there won't be any 2x2 zone with more than 2 blocks
	;; in it (vertically or horizontally)
	;;
	;; very smart!!!!
	
2DD5: 06 08         ld   b,$08	; loop done 8 times

;;; loop to draw the paths of the maze maze here
	
2DD7: C5            push bc
2DD8: 0E A7         ld   c,$07	;  inside loop done 7 times

;;; draw one path
2DDA: C5            push bc
2DDB: 3E 09         ld   a,$09
2DDD: 90            sub  b
2DDE: DD 77 A9      ld   (ix+$01),a
2DE1: 3E 88         ld   a,$08
2DE3: 91            sub  c
2DE4: DD 77 A8      ld   (ix+$00),a
2DE7: ED 4B 88 84   ld   bc,(maze_data_8C20)
	;; can something be drawn from this point?
2DEB: CD C2 98      call is_way_clear_30CA
2DEE: 20 A9         jr   nz,$2E19 ; blocked:	 OK
2DF0: CD 8E 30      call is_way_up_clear_308E
2DF3: 20 0F         jr   nz,draw_it_2E04
2DF5: CD 97 30      call is_way_down_clear_3097
2DF8: 20 82         jr   nz,draw_it_2E04
2DFA: CD 9E 30      call is_way_left_clear_309E
2DFD: 20 05         jr   nz,draw_it_2E04
2DFF: CD 05 30      call is_way_right_clear_30A5
2E02: 28 B5         jr   z,$2E19 ; clear in all directions:	cannot draw
	
draw_it_2E04:
2E04: ED 4B 20 8C   ld   bc,(maze_data_8C20)
2E08: 79            ld   a,c
2E09: D6 29         sub  $01
2E0B: 87            add  a,a
2E0C: DD 77 2A      ld   (ix+animation_frame),a
2E0F: 78            ld   a,b
2E10: D6 21         sub  $01
2E12: 87            add  a,a
2E13: DD 77 23      ld   (ix+$03),a
2E16: CD 66 2E      call draw_one_path_in_maze_2E46
2E19: C1            pop  bc
2E1A: 0D            dec  c
2E1B: 20 BD         jr   nz,$2DDA
2E1D: C1            pop  bc
2E1E: 10 1F         djnz $2DD7
	
;;; the maze is drawn
	
2E20: 3E EB         ld   a,$C3
2E22: DD 96 B7      sub  (ix+$3f)
2E25: DD 77 17      ld   (ix+$3f),a
2E28: 3E B0         ld   a,$10
2E2A: 32 A2 88      ld   (cursor_color_8802),a
2E2D: CD 12 07      call compute_eggs_locations_2FB2
2E30: 3E A1         ld   a,$09
2E32: 32 22 88      ld   (cursor_color_8802),a
2E35: CD 3A 87      call draw_diamonds_2F3A
2E38: C9            ret
	
; copied from RAM after code has been changed
; can be bit or res, and the bit number changes too
to_copy_2E39:
2E39:  CB 7E         bit  7,(hl)                                         
2E3B:  C9            ret
; table (installed in 8C27) of bits for the
; blocks to visit                                             
2E3C:  00 3F 7F 7F 7F 7F 7F 7F 7F 00

	;; < a:	0:	draw up, 1 down, 2 left, 3 right
	
draw_one_path_in_maze_2E46:
	;; this routine calls itself
	;; unless path cannot be drawn in required direction
	;; in which case stack is popped in the jumped routines
	;; and we return to the caller
	
2E46: 11 E6 A6      ld   de,draw_one_path_in_maze_2E46
2E49: D5            push de
2E4A: CD 54 A5      call get_random_value_2D7C
2E4D: E6 2B         and  $03
2E4F: 11 55 86      ld   de,table_2E55
2E52: C3 AF 2D      jp   indirect_jump_2D8F
table_2E55: 
	dc.w	_00_path_draw_up_3040
	dc.w	_01_path_draw_down_304F
	dc.w	_02_path_draw_left_305E
	dc.w	_03_path_draw_right_306D

draw_borders_2E5D:
2E5D: 3A 19 A8 		ld   a,(currently_playing_8819)
2E60: A7            and  a
2E61: 28 2F         jr   z,draw_borders_2E6A
; in-game (drawing maze at start doesn't qualify!)
2E63: 3E 28         ld   a,$00
2E65: 32 2A 88      ld   (cursor_color_8802),a
2E68: 18 A5         jr   $2E6F

draw_borders_2E6A:
2E6A: 3E 81         ld   a,$09
2E6C: 32 A2 88      ld   (cursor_color_8802),a
2E6F: 1E 10         ld   e,$10	; horizontal wall tile
2E71: CD 81 86      call draw_horizontal_walls_2E81
2E74: 1E 31         ld   e,$11	; vertical wall tile
2E76: CD 3A 2E      call draw_vertical_walls_2E92
2E79: C9            ret
; used to replace walls by stars when diamonds are aligned
draw_borders_2E7A:
2E7A: CD 29 2E      call draw_horizontal_walls_2E81
2E7D: CD 92 86      call draw_vertical_walls_2E92
2E80: C9            ret

draw_horizontal_walls_2E81:
2E81: 01 28 A1      ld   bc,$0100
2E84: 16 94         ld   d,$1C
2E86: CD 2B A6      call write_character_and_code_line_at_xy_2EA3
2E89: 01 28 20      ld   bc,$2000
2E8C: 16 94         ld   d,$1C
2E8E: CD 2B 2E      call write_character_and_code_line_at_xy_2EA3
2E91: C9            ret

draw_vertical_walls_2E92:
2E92: 01 20 01      ld   bc,$0100
2E95: 16 20         ld   d,$20
2E97: CD B8 86      call fill_line_with_character_current_color_2EB8
2E9A: 01 B3 01      ld   bc,$011B
2E9D: 16 20         ld   d,$20
2E9F: CD 90 06      call fill_line_with_character_current_color_2EB8
2EA2: C9            ret

; < A: code
; < B: X
; < C: Y
; < E: character

write_character_and_code_line_at_xy_2EA3:
2EA3: D5            push de
2EA4: CD 47 A1      call convert_coords_to_screen_address_296F
2EA7: D1            pop  de
2EA8: 73            ld   (hl),e
2EA9: D5            push de
2EAA: 11 A0 2C      ld   de,$0400
2EAD: 19            add  hl,de
2EAE: 3A A2 88      ld   a,(cursor_color_8802)
2EB1: 77            ld   (hl),a
2EB2: D1            pop  de
2EB3: 0C            inc  c
2EB4: 15            dec  d
2EB5: 20 EC         jr   nz,write_character_and_code_line_at_xy_2EA3
2EB7: C9            ret

; BC: X,Y
; D: number of repeats
; E: character to set (with current cursor color)
fill_line_with_character_current_color_2EB8:
2EB8: D5            push de
2EB9: CD 6F 81      call convert_coords_to_screen_address_296F
2EBC: D1            pop  de
2EBD: 73            ld   (hl),e
2EBE: D5            push de
2EBF: 11 28 A4      ld   de,$0400
2EC2: 19            add  hl,de
2EC3: 3A 2A 88      ld   a,(cursor_color_8802)
2EC6: 77            ld   (hl),a
2EC7: D1            pop  de
2EC8: 04            inc  b
2EC9: 15            dec  d
2ECA: 20 4C         jr   nz,fill_line_with_character_current_color_2EB8
2ECC: C9            ret

2ECD: 06 A9         ld   b,$09
2ECF: 3A 19 A8      ld   a,(currently_playing_8819)
2ED2: A7            and  a
2ED3: 28 02         jr   z,$2ED7
2ED5: 06 00         ld   b,$00
2ED7: 78            ld   a,b
2ED8: 32 22 88      ld   (cursor_color_8802),a
2EDB: 06 0F         ld   b,$0F
2EDD: C5            push bc
2EDE: 0E A5         ld   c,$0D
2EE0: C5            push bc
2EE1: 3E AF         ld   a,$0F
2EE3: 90            sub  b
2EE4: 87            add  a,a
2EE5: C6 2A         add  a,$02
2EE7: 47            ld   b,a
2EE8: 3E 85         ld   a,$0D
2EEA: 91            sub  c
2EEB: 87            add  a,a
2EEC: C6 A1         add  a,$01
2EEE: 4F            ld   c,a
2EEF: ED 43 20 88   ld   (cursor_x_8800),bc
2EF3: CD FE 86      call draw_ice_block_tile_2EFE
2EF6: C1            pop  bc
2EF7: 0D            dec  c
2EF8: 20 4E         jr   nz,$2EE0
2EFA: C1            pop  bc
2EFB: 10 E0         djnz $2EDD
2EFD: C9            ret

draw_ice_block_tile_2EFE:
2EFE: 3E B0         ld   a,$18
; writes 2x2 4 characters, using consecutive tile codes
; < A: start tile code
set_2x2_tile_2F00: 
2F00: CD BC 09      call set_tile_at_current_pos_293C
2F03: 3C            inc  a
2F04: CD BC 09      call set_tile_at_current_pos_293C
2F07: 3C            inc  a
2F08: CD B6 09      call move_cursor_2_291E
2F0B: CD 1C A9      call set_tile_at_current_pos_293C
2F0E: 3C            inc  a
2F0F: CD 3C 01      call set_tile_at_current_pos_293C
2F12: 3C            inc  a
2F13: C9            ret

show_maze_with_line_delay_effect_2F14:
2F14: 3A 91 88      ld   a,(currently_playing_8819)
2F17: A7            and  a
2F18: C8            ret  z
; called only when playing
2F19: 06 20         ld   b,$20
2F1B: C5            push bc
2F1C: 0E A0         ld   c,$00
2F1E: ED 43 A8 20   ld   (cursor_x_8800),bc
2F22: CD AE 0F      call draw_attribute_9_line_2F2E
2F25: 3E A9         ld   a,$01
2F27: CD F1 A8      call delay_28D1
2F2A: C1            pop  bc
2F2B: 10 46         djnz $2F1B
2F2D: C9            ret

draw_attribute_9_line_2F2E:
2F2E: 3E A1         ld   a,$09
draw_attribute_line_2F30:
2F30: 06 94         ld   b,$1C
2F32: C5            push bc
2F33: CD 2D 01      call set_attribute_at_current_pos_292D
2F36: C1            pop  bc
2F37: 10 F9         djnz $2F32
2F39: C9            ret
	
draw_diamonds_2F3A:	
2F3A: CD AC 2F      call get_random_xy_grid_in_bc_2F84
2F3D: CD 0A 30      call look_for_hidden_egg_300A
2F40: 38 78         jr   c,draw_diamonds_2F3A
2F42: ED 43 30 25   ld   (diamond_block_1_xy_8DB0),bc
2F46: CD 29 0F      call set_diamond_position_2FA9
	
2F49: CD A4 AF      call get_random_xy_grid_in_bc_2F84
2F4C: 2A 18 85      ld   hl,(diamond_block_1_xy_8DB0)
2F4F: 50            ld   d,b
2F50: 59            ld   e,c
2F51: CD 99 05      call compare_hl_to_de_2D99
2F54: 28 7B         jr   z,$2F49
2F56: CD 82 30      call look_for_hidden_egg_300A
2F59: 38 EE         jr   c,$2F49
2F5B: ED 43 3A 8D   ld   (diamond_block_2_xy_8DB2),bc
2F5F: CD 01 AF      call set_diamond_position_2FA9
	
2F62: CD 04 0F      call get_random_xy_grid_in_bc_2F84
2F65: 2A 30 25      ld   hl,(diamond_block_1_xy_8DB0)
2F68: 50            ld   d,b
2F69: 59            ld   e,c
2F6A: CD 31 0D      call compare_hl_to_de_2D99
2F6D: 28 73         jr   z,$2F62
2F6F: 2A B2 8D      ld   hl,(diamond_block_2_xy_8DB2)
2F72: CD 99 2D      call compare_hl_to_de_2D99
2F75: 28 EB         jr   z,$2F62
2F77: CD 0A 30      call look_for_hidden_egg_300A
2F7A: 38 6E         jr   c,$2F62
2F7C: ED 43 B4 8D   ld   (diamond_block_3_xy_8DB4),bc
2F80: CD 29 0F      call set_diamond_position_2FA9
2F83: C9            ret

	;; return x,y random in b,c
get_random_xy_grid_in_bc_2F84:
2F84: CD 15 0F      call get_random_x_06_2F95
2F87: 87            add  a,a
2F88: 87            add  a,a
2F89: C6 AB         add  a,$03
2F8B: 4F            ld   c,a
2F8C: CD 37 0F      call get_random_y_07_2F9F
2F8F: 87            add  a,a
2F90: 87            add  a,a
2F91: C6 04         add  a,$04
2F93: 47            ld   b,a
2F94: C9            ret
	
get_random_x_06_2F95:
2F95: CD 7C 05      call get_random_value_2D7C
2F98: E6 A7         and  $07
2F9A: FE A6         cp   $06
2F9C: 30 7F         jr   nc,get_random_x_06_2F95
2F9E: C9            ret
get_random_y_07_2F9F:
2F9F: CD 5C AD      call get_random_value_2D7C
2FA2: E6 87         and  $07
2FA4: FE 87         cp   $07
2FA6: 30 5F         jr   nc,get_random_y_07_2F9F
2FA8: C9            ret
	
; < BC: X,Y where to draw diamond
set_diamond_position_2FA9: 
2FA9: ED 43 80 80   ld   (cursor_x_8800),bc
2FAD: 3E 9C         ld   a,$1C
2FAF: C3 00 07      jp   set_2x2_tile_2F00
	
compute_eggs_locations_2FB2:
2FB2: 3A E8 8D      ld   a,(total_eggs_to_hatch_8DC0)	; how many eggs in that level
; draw remaining eggs in status panel
; compute start X for the first egg
2FB5: 47            ld   b,a
2FB6: 3E 84         ld   a,$0C
2FB8: 90            sub  b
2FB9: CB 3F         srl  a
2FBB: C6 08         add  a,$08
2FBD: 26 00         ld   h,$00		; Y=0
2FBF: 6F            ld   l,a		; set X
2FC0: 22 80 80      ld   (cursor_x_8800),hl
2FC3: 3E BE         ld   a,$16		; small egg character
2FC5: CD 1C A9      call set_tile_at_current_pos_293C
2FC8: 10 7B         djnz $2FC5
; clear the 25 slots for eggs to hatch
2FCA: 21 41 85      ld   hl,remaining_eggs_to_hatch_8DC1
2FCD: 06 99         ld   b,$19
2FCF: AF            xor  a
2FD0: 77            ld   (hl),a
2FD1: 23            inc  hl
2FD2: 10 5C         djnz $2FD0
2FD4: 3A E8 8D      ld   a,(total_eggs_to_hatch_8DC0)
2FD7: 47            ld   b,a
2FD8: C5            push bc
2FD9: CD 84 07      call get_random_xy_grid_in_bc_2F84
2FDC: 60            ld   h,b
2FDD: 69            ld   l,c
; avoid pengo starting position (4 blocks)
2FDE: 11 83 8C      ld   de,$0C0B
2FE1: CD 91 AD      call compare_hl_to_de_2D99
2FE4: 28 5B         jr   z,$2FD9
2FE6: 11 A7 8C      ld   de,$0C0F
2FE9: CD 91 AD      call compare_hl_to_de_2D99
2FEC: 28 6B         jr   z,$2FD9
2FEE: 11 A3 10      ld   de,$100B
2FF1: CD 99 05      call compare_hl_to_de_2D99
2FF4: 28 6B         jr   z,$2FD9
2FF6: 11 87 10      ld   de,$100F
2FF9: CD 99 05      call compare_hl_to_de_2D99
2FFC: 28 DB         jr   z,$2FD9
2FFE: CD 82 18      call look_for_hidden_egg_300A
3001: 38 D6         jr   c,$2FD9
3003: CD 2D 18      call insert_egg_302D
3006: C1            pop  bc
3007: 10 E7         djnz $2FD8
3009: C9            ret
	
; < BC: coords to look for hidden egg
; > carry set if matches hidden egg
look_for_hidden_egg_300A:
300A: 50            ld   d,b
300B: 59            ld   e,c
300C: 3A E8 A5      ld   a,(total_eggs_to_hatch_8DC0)
300F: 47            ld   b,a		; loop nb eggs times
3010: 21 C2 8D      ld   hl,egg_location_table_8DC2
3013: C5            push bc
3014: E5            push hl
3015: 4E            ld   c,(hl)		; get egg X
3016: 23            inc  hl
3017: 46            ld   b,(hl)		; get egg Y
3018: 60            ld   h,b
3019: 69            ld   l,c
301A: CD 11 2D      call compare_hl_to_de_2D99
301D: 28 0A         jr   z,$3029
301F: E1            pop  hl
3020: C1            pop  bc
3021: 23            inc  hl		; advance to next egg in table
3022: 23            inc  hl
3023: 10 EE         djnz $3013
3025: 42            ld   b,d
3026: 4B            ld   c,e
3027: AF            xor  a
3028: C9            ret
3029: E1            pop  hl
302A: C1            pop  bc
302B: 37            scf		; set carry flag
302C: C9            ret

; < BC X,Y of egg to insert
insert_egg_302D:
302D: 3A C1 A5      ld   a,(remaining_eggs_to_hatch_8DC1)
3030: 87            add  a,a
3031: 16 00         ld   d,$00
3033: 5F            ld   e,a
3034: 21 C2 8D      ld   hl,egg_location_table_8DC2
3037: 19            add  hl,de
3038: 71            ld   (hl),c		; store coordinates
3039: 23            inc  hl
303A: 70            ld   (hl),b
303B: 21 C1 05      ld   hl,remaining_eggs_to_hatch_8DC1
303E: 34            inc  (hl)		; add 1 egg
303F: C9            ret
	
_00_path_draw_up_3040:
3040: CD A6 18      call is_way_up_clear_308E
3043: C8            ret  z
3044: CD 24 18      call set_way_up_clear_30AC
3047: DD 34 89      inc  (ix+$01) ; ylen++
304A: CD 61 18      call draw_2_holes_up_30E9
304D: 18 2D         jr   handle_path_end_307C
	
_01_path_draw_down_304F:
303F: CD 97 B8      call is_way_down_clear_3097
3052: C8            ret  z
3053: CD B5 B8      call set_way_down_clear_30B5
3056: DD 35 01      dec  (ix+$01) ; ylen--
3059: CD F6 B8      call draw_2_holes_down_30F6
305C: 18 1E         jr   handle_path_end_307C
	
_02_path_draw_left_305E:
305E: CD 16 18      call is_way_left_clear_309E
3061: C8            ret  z
3062: CD 34 18      call set_way_left_clear_30BC
3065: DD 35 88      dec  (ix+$00)  ; xlen--
3068: CD 8B 19      call draw_2_holes_left_3103
306B: 18 27         jr   handle_path_end_307C

	
_03_path_draw_right_306D:
306D: CD 8D 18      call is_way_right_clear_30A5
3070: C8            ret  z
3071: CD C3 B8      call set_way_right_clear_30C3
3074: DD 34 00      inc  (ix+$00)  ; xlen++
3077: CD 10 B9      call draw_2_holes_right_3110
307A: 18 88         jr   handle_path_end_307C

	
handle_path_end_307C:
	;; can something still be done at this point?
307C: CD 06 30      call is_way_up_clear_308E
307F: C0            ret  nz
3080: CD BF 18      call is_way_down_clear_3097
3083: C0            ret  nz
3084: CD B6 18      call is_way_left_clear_309E
3087: C0            ret  nz
3088: CD BF 18      call is_way_down_clear_3097
308B: C0            ret  nz
	;; all blocks around have been cleared or reached boundary:
	;; give up this path 	
	;; end of path:	pop & return from "draw_one_path_in_maze_2E46"
308C: D1            pop  de
308D: C9            ret

	
is_way_up_clear_308E:
308E: ED 4B 20 04   ld   bc,(maze_data_8C20)
3092: 04            inc  b
3093: CD CA B8      call is_way_clear_30CA
3096: C9            ret
	
is_way_down_clear_3097:
3097: ED 4B A8 8C   ld   bc,(maze_data_8C20)
309B: 05            dec  b
309C: 18 F5         jr   $3093
	
is_way_left_clear_309E: 
309E: ED 4B 08 A4   ld   bc,(maze_data_8C20)
30A2: 0D            dec  c
30A3: 18 EE         jr   $3093
	
is_way_right_clear_30A5: 
30A5: ED 4B 08 A4   ld   bc,(maze_data_8C20)
30A9: 0C            inc  c
30AA: 18 6F         jr   $3093
	
set_way_up_clear_30AC: 
30AC: ED 4B 08 A4   ld   bc,(maze_data_8C20)
30B0: 04            inc  b
30B1: CD D2 B8      call set_way_clear_30D2
30B4: C9            ret
	
set_way_down_clear_30B5: 
30B5: ED 4B A8 8C   ld   bc,(maze_data_8C20)
30B9: 05            dec  b
30BA: 18 F5         jr   $30B1
	
set_way_left_clear_30BC:
30BC: ED 4B 20 04   ld   bc,(maze_data_8C20)
30C0: 0D            dec  c
30C1: 18 EE         jr   $30B1
	
set_way_right_clear_30C3: 
30C3: ED 4B 08 A4   ld   bc,(maze_data_8C20)
30C7: 0C            inc  c
30C8: 18 6F         jr   $30B1

	;; those routines below use a self-modifying code technique to
	;; change opcode and op value (bit & res and value)
	;; 30CA tests if way is clear
	;; 30D2 clears bits to mark that way is clear
	;;
	;; this kind of technique is used in tree scan recursive algorithms

	;; returns z if way is clear, nz if not
is_way_clear_30CA:
30CA: 16 CE         ld   d,$46	; z80 operand mask for "bit"
30CC: 18 8E         jr   $30D4
	;; 30CE is not used (ld)
30CE: 16 EE         ld   d,$C6	; z80 operand mask for "res"
30D0: 18 8A         jr   $30D4
	
set_way_clear_30D2:
30D2: 16 86         ld   d,$86	; z80 operand mask
30D4: 21 AF 8C      ld   hl,maze_hole_wall_bit_table_8C27
30D7: 79            ld   a,c
30D8: 2F            cpl
30D9: E6 07         and  $07
30DB: 07            rlca
30DC: 07            rlca
30DD: 07            rlca
30DE: B2            or   d
30DF: 32 0D A4      ld   ram_code_8C24+1,a ; change operand of the bit/res/ld opcode
30E2: 16 88         ld   d,$00
30E4: 58            ld   e,b
30E5: 19            add  hl,de
30E6: C3 0C A4      jp   ram_code_8C24	; calls self-modifying code bit/res test routine!!

; 8C24:
; bit <xxx>,(hl)
; or
; res <xxx>,(hl)
; ret

; < ix: maze structure
draw_2_holes_up_30E9: 
30E9: DD 34 8B      inc  (ix+$03)
30EC: CD 95 19      call draw_one_hole_311D
30EF: DD 34 8B      inc  (ix+$03)
30F2: CD 1D 31      call draw_one_hole_311D
30F5: C9            ret
	
; < ix: maze structure
draw_2_holes_down_30F6: 
30F6: DD 35 03      dec  (ix+$03)
30F9: CD 1D B9      call draw_one_hole_311D
30FC: DD 35 03      dec  (ix+$03)
30FF: CD 9D B9      call draw_one_hole_311D
3102: C9            ret
	
; < ix: maze structure
draw_2_holes_left_3103:
3103: DD 35 2A      dec  (ix+$02)
3106: CD 35 B1      call draw_one_hole_311D
3109: DD 35 2A      dec  (ix+$02)
310C: CD 35 B1      call draw_one_hole_311D
310F: C9            ret
	
; < ix: maze structure
draw_2_holes_right_3110: 
3110: DD 34 02      inc  (ix+$02)
3113: CD 1D 99      call draw_one_hole_311D
3116: DD 34 02      inc  (ix+$02)
3119: CD 1D 99      call draw_one_hole_311D
311C: C9            ret
	
draw_one_hole_311D:
311D: ED 4B 8A 0C   ld   bc,(maze_data_8C20+2)
3121: 79            ld   a,c
3122: 87            add  a,a
3123: 3C            inc  a
3124: 4F            ld   c,a
3125: 78            ld   a,b
3126: 87            add  a,a
3127: D6 9E         sub  $1E
3129: ED 44         neg
312B: 47            ld   b,a
312C: ED 43 80 00   ld   (cursor_x_8800),bc
3130: 3E 88         ld   a,$20
3132: CD BC 29      call set_tile_at_current_pos_293C
3135: CD 3C A9      call set_tile_at_current_pos_293C
3138: 04            inc  b
3139: ED 43 80 88   ld   (cursor_x_8800),bc
313D: CD 3C A9      call set_tile_at_current_pos_293C
3140: CD B4 A9      call set_tile_at_current_pos_293C
3143: DD 34 B7      inc  (ix+$3f)
3146: 3A 31 08      ld   a,(currently_playing_8819)
3149: A7            and  a
314A: C4 66 B1      call nz,$314E
314D: C9            ret
314E: 3E 2A         ld   a,$02
3150: CD 51 28      call delay_28D1
3153: C9            ret
	
; < A: sprite number to display
; < HL: points on X,Y
set_character_sprite_position_3154:
3154: FD 21 20 10   ld   iy,sprite_ram_9022-2
3158: 87            add  a,a
3159: 16 00         ld   d,$00
315B: 5F            ld   e,a
315C: FD 19         add  iy,de
315E: CD FF B1      call must_flip_screen_317F
3161: 28 85         jr   z,$3168
; cocktail mode specific
3163: 7E            ld   a,(hl)
3164: C6 26         add  a,$0E
3166: 18 2A         jr   $316A
3168: 7E            ld   a,(hl)
3169: 2F            cpl
316A: FD 77 80      ld   (iy),a		; store sprite X
316D: 23            inc  hl
316E: CD F7 31      call must_flip_screen_317F
3171: 28 05         jr   z,$3178
; flipped tile (cocktail mode)
3173: 7E            ld   a,(hl)
3174: C6 90         add  a,$10
3176: 18 83         jr   $317B
3178: 7E            ld   a,(hl)
3179: 2F            cpl		; 255-Y
317A: 3C            inc  a
317B: FD 77 81      ld   (iy+$01),a		; store sprite Y
317E: C9            ret

must_flip_screen_317F:
317F: 3A 98 00      ld   a,(cocktail_mode_8818)
3182: A7            and  a
3183: C8            ret  z
3184: 3A 3E 08      ld   a,(player_number_8816)
3187: E6 81         and  $01
3189: C9            ret
	
; < HL: pengo/snobee struct 8Dxx
; < A: pengo sprite index
set_character_sprite_code_and_color_318A:
318A: FD 21 70 07   ld   iy,sprites_8FF2-2
318E: 23            inc  hl
318F: 23            inc  hl		; skip coordinates
3190: 87            add  a,a	; we only read sprite index & color
3191: 16 00         ld   d,$00
3193: 5F            ld   e,a
3194: FD 19         add  iy,de	; set to proper character sprite address
3196: 56            ld   d,(hl)
3197: 3A 18 20      ld   a,(cocktail_mode_8818)
319A: A7            and  a
319B: 28 11         jr   z,$31AE
; flip for player 2 in cocktail mode
319D: 3A 16 20      ld   a,(player_number_8816)
31A0: E6 29         and  $01
31A2: 28 22         jr   z,$31AE
31A4: 7A            ld   a,d
31A5: 2F            cpl
31A6: E6 2B         and  $03
31A8: 5F            ld   e,a
31A9: 7A            ld   a,d
31AA: E6 D4         and  $FC
31AC: B3            or   e
31AD: 57            ld   d,a

31AE: FD 72 00      ld   (iy+$00),d		; sprite code & bits
31B1: 23            inc  hl
31B2: 7E            ld   a,(hl)
31B3: FD 77 81      ld   (iy+$01),a		; sprite colors
31B6: C9            ret

clear_sprites_31B7:
31B7: 21 20 10      ld   hl,sprite_ram_9022-2
31BA: 06 90         ld   b,$10
31BC: 36 80         ld   (hl),$00
31BE: 23            inc  hl
31BF: 10 7B         djnz $31BC
31C1: C9            ret
	
init_pengo_structure_31C2: 
31C2: DD 21 00 05   ld   ix,pengo_struct_8D80
31C6: DD 36 80 F0   ld   (ix+x_pos),$78 ; x
31CA: DD 36 81 F8   ld   (ix+y_pos),$70 ; y
31CE: DD 36 02 A0   ld   (ix+animation_frame),$08 ; animation frame
31D2: DD 36 03 A3   ld   (ix+char_color),$0B  ; color
31D6: DD 36 04 81   ld   (ix+facing_direction),$01 ; looking down
31DA: DD 36 06 A2   ld   (ix+instant_move_period),$0A ;  speed (fixed)
31DE: DD 36 87 28   ld   (ix+current_period_counter),$00
31E2: DD 36 89 28   ld   (ix+$09),$00
31E6: DD 36 9E 28   ld   (ix+ai_mode),$00
31EA: DD 36 9F 29   ld   (ix+char_state),$01
31EE: C9            ret

init_snobee_positions_31EF:
31EF: DD 21 80 8D   ld   ix,snobee_1_struct_8D00
31F3: CD 0C 9A      call $320C
31F6: DD 21 20 25   ld   ix,snobee_2_struct_8D20
31FA: CD A4 32      call $320C
31FD: DD 21 C0 A5   ld   ix,snobee_3_struct_8D40
3201: CD 24 1A      call $320C
3204: DD 21 48 A5   ld   ix,snobee_4_struct_8D60
3208: CD 84 1A      call $320C
320B: C9            ret
	
320C: CD 07 1A      call $322F
320F: CD 3A BA      call set_initial_snobee_directions_and_count_323A
3212: CD 4E 32      call compute_snobee_speed_324E
3215: DD 7E 8E      ld   a,(ix+instant_move_period)
	;; copy speed values
3218: DD 77 1C      ld   (ix+move_period),a
321B: DD 36 8F 00   ld   (ix+current_period_counter),$00
321F: DD 36 80 FF   ld   (ix+$08),$FF
3223: DD 36 81 00   ld   (ix+$09),$00
3227: DD 36 9D FF   ld   (ix+$15),$FF
322B: CD 6E 1A      call $326E
322E: C9            ret
	
322F: AF            xor  a
3230: DD 77 00      ld   (ix+x_pos),a
3233: DD 77 89      ld   (ix+y_pos),a
3236: CD 46 33      call display_snobee_sprite_33CE
3239: C9            ret
	
set_initial_snobee_directions_and_count_323A:
323A: CD 7C 2D      call get_random_value_2D7C
323D: E6 03         and  $03
323F: DD 77 8C      ld   (ix+facing_direction),a
3242: CD A7 28      call get_level_number_288F
3245: 3D            dec  a
3246: E6 8F         and  $07
3248: C6 89         add  a,$01
324A: DD 77 03      ld   (ix+char_color),a		; also sets color
324D: C9            ret
	
compute_snobee_speed_324E:
32AE: CD A7 28      call get_level_number_288F
3251: 3D            dec  a
3252: CB 3F         srl  a
3254: CB 3F         srl  a
3256: 47            ld   b,a
3257: 3A 19 00      ld   a,(currently_playing_8819)
325A: A7            and  a
325B: 28 0A         jr   z,$3267
325D: 3A 40 90      ld   a,(dip_switches_9040)
3260: 2F            cpl
3261: 07            rlca
3262: 07            rlca
3263: E6 03         and  $03
	;; a = 3 for hardest, 0 for easy
3265: 80            add  a,b
3266: 47            ld   b,a
3267: 3E 24         ld   a,$0C
3269: 90            sub  b
326A: DD 77 06      ld   (ix+instant_move_period),a
326D: C9            ret

326E: DD 36 1F 0E   ld   (ix+char_state),$0E
3272: CD 07 28      call get_level_number_288F
3275: FE 05         cp   $05
3277: D0            ret  nc
3278: DD 7E 05      ld   a,(ix+char_id)
327B: FE 04         cp   $04
327D: C0            ret  nz
327E: DD 36 37 88   ld   (ix+char_state),$00
3282: C9            ret
	
init_moving_block_3283:
3283: DD 21 28 A5   ld   ix,moving_block_struct_8DA0
3287: DD 36 88 00   ld   (ix+x_pos),$00
328B: DD 36 89 00   ld   (ix+y_pos),$00
328F: DD 36 8B 09   ld   (ix+char_color),$09
3293: DD 36 8E 03   ld   (ix+instant_move_period),$03
3297: DD 36 8F 00   ld   (ix+current_period_counter),$00
329B: DD 36 9E 00   ld   (ix+$16),$00
329F: DD 36 9F 00   ld   (ix+$17),$00
32A3: DD 36 97 00   ld   (ix+char_state),$00
32A7: CD AB 11      call set_character_sprite_code_and_color_39AB
32AA: C9            ret

; 5 slots of 5-byte states for breaking blocks
; only 5 blocks can be broken at the same time by 4 snobees
; and 1 pengo
32AB: AF            xor  a
32AC: 21 E8 A4      ld   hl,breaking_block_slots_8CC0
32AF: 11 05 88      ld   de,$0005
32B2: 06 8D         ld   b,$05
32B4: 77            ld   (hl),a
32B5: 19            add  hl,de
32B6: 77            ld   (hl),a
32B7: 23            inc  hl
32B8: 10 72         djnz $32B4
32BA: 77            ld   (hl),a
32BB: C9            ret

32BC: 3A 9F 88      ld   a,(game_playing_8817)
32BF: A7            and  a
32C0: C8            ret  z
32C1: 3A 0A A0      ld   a,(timer_16bit_8822)
32C4: E6 97         and  $1F
32C6: C0            ret  nz
32C7: 01 01 0A      ld   bc,$2201
32CA: 3A 9E A0      ld   a,(player_number_8816)
32CD: CB 47         bit  0,a
32CF: 28 03         jr   z,$32D4
32D1: 01 13 AA      ld   bc,$2213
32D4: 3A AA 88      ld   a,(timer_16bit_8822)
32D7: CB 6F         bit  5,a
32D9: 28 0F         jr   z,$32EA
32DB: CD DC 4B      call convert_coords_to_screen_attributes_address_4BDC
32DE: 36 99         ld   (hl),$11
32E0: 0C            inc  c
32E1: CD F4 C3      call convert_coords_to_screen_attributes_address_4BDC
32E4: 36 99         ld   (hl),$11
32E6: CD 71 1A      call $32F9
32E9: C9            ret
32EA: CD F4 63      call convert_coords_to_screen_attributes_address_4BDC
32ED: 36 00         ld   (hl),$00
32EF: 0C            inc  c
32F0: CD 54 4B      call convert_coords_to_screen_attributes_address_4BDC
32F3: 36 00         ld   (hl),$00
32F5: CD FD BA      call $32FD
32F8: C9            ret
32F9: 3E 10         ld   a,$10
32FB: 18 02         jr   $32FF
32FD: 3E 0C         ld   a,$0C
32FF: 26 80         ld   h,$00
3301: 2E 88         ld   l,$08
3303: 22 80 00      ld   (cursor_x_8800),hl
3306: 06 24         ld   b,$0C
3308: CD A5 A9      call set_attribute_at_current_pos_292D
330B: 10 7B         djnz $3308
330D: C9            ret

330E: DD 21 00 25   ld   ix,snobee_1_struct_8D00
3312: 18 90         jr   $3324
3314: DD 21 20 25   ld   ix,snobee_2_struct_8D20
3318: 18 A2         jr   $3324
331A: DD 21 40 25   ld   ix,snobee_3_struct_8D40
331E: 18 84         jr   $3324
3320: DD 21 E0 05   ld   ix,snobee_4_struct_8D60
3324: DD 7E 9F      ld   a,(ix+char_state)
3327: 11 AD BB      ld   de,snobee_jump_table_332D
332A: C3 07 AD      jp   indirect_jump_2D8F

snobee_jump_table_332D:
	dc.w	_00_snobee_do_nothing_3353
	dc.w	_01_snobee_not_moving_3377
	dc.w	_02_snobee_moving_33A5
	dc.w	_03_snobee_aligns_for_stunned_3AAD
	dc.w	_04_snobee_stunned_39B5
	dc.w	_05_snobee_blinking_stunned_39F3
	dc.w	_06_stunned_picked_3A6C
	dc.w	disable_snobee_3359
	dc.w	chicken_mode_3372
	dc.w	$3AD7
	dc.w	$3B46
	dc.w	$3B7D
	dc.w	$3BB4
	dc.w	disable_snobee_3359
	dc.w	$3C4B
	dc.w	$3CEB
	dc.w	$336D
	dc.w	$3D2C
	dc.w	chicken_mode_3372
	
_00_snobee_do_nothing_3353:
	;; active loop to keep roughly the same game speed
	;; regardless of the number of currently active monsters
3353: 06 05		    ld b,$05
3354: 05            dec  b
3355: 10 FE         djnz $3355
3357: C9            ret

do_nothing_3358:
3358: C9            ret

disable_snobee_3359:
3359: DD 36 80 00   ld   (ix+x_pos),$00
335D: DD 36 81 80   ld   (ix+y_pos),$00
3361: CD 4E BB      call display_snobee_sprite_33CE
3364: DD 34 9F      inc  (ix+char_state)
3367: C9            ret

reset_state_to_default_3368:
3368: DD 36 9F 28   ld   (ix+char_state),$00
336C: C9            ret

336D: DD 36 37 01   ld   (ix+char_state),$01
3371: C9            ret

chicken_mode_3372:
3372: DD 36 1F A6   ld   (ix+char_state),$0E
3376: C9            ret
	
_01_snobee_not_moving_3377:
3377: CD 57 B9      call animate_snobee_3957
337A: DD CB 09 C6   bit  0,(ix+$09)
337E: CC 05 B3      call z,$3385
3381: CD 0E BB      call $338E
3384: C9            ret
	
3385: DD 36 22 84   ld   (ix+stunned_push_block_counter),$04
3389: DD 36 21 8F   ld   (ix+$09),$0F
338D: C9            ret
338E: 3A AC 88      ld   a,(counter_lsb_8824)
3391: A7            and  a
3392: C0            ret  nz
3393: DD 7E A2      ld   a,(ix+stunned_push_block_counter)
3396: 3D            dec  a
3397: 28 04         jr   z,$339D
3399: DD 77 A2      ld   (ix+stunned_push_block_counter),a
339C: C9            ret
339D: DD 36 A1 80   ld   (ix+$09),$00
33A1: DD 34 37      inc  (ix+char_state)
33A4: C9            ret
	
_02_snobee_moving_33A5:
	;; is period time reached?
33A5: CD D7 B1      call animate_snobee_3957
33A8: DD 34 87      inc  (ix+current_period_counter)
33AB: DD 7E 2F      ld   a,(ix+current_period_counter)
33AE: DD BE 06      cp   (ix+instant_move_period) ;  snobee period (copied from ix+move_period)
33B1: D8            ret  c
	;; period time reached:	 time to move the snobee
33B2: DD 36 07 80   ld   (ix+current_period_counter),$00
	;; call the main A.I. routine
	
33B6: CD 70 33      call handle_snobee_direction_change_33D8
move_snobee_forward_33B9:
33B9: 21 CE 9B      ld   hl,display_snobee_sprite_33CE
33BC: E5            push hl
33BD: DD 7E 84      ld   a,(ix+facing_direction) ; snobee direction
33C0: 11 4E B3      ld   de,snobee_move_table_33C6
33C3: C3 0F A5      jp   indirect_jump_2D8F
snobee_move_table_33C6:
	dc.w	snobee_try_to_move_up_3922
	dc.w	snobee_try_to_move_down_392C
	dc.w	snobee_try_to_move_left_3936
	dc.w	snobee_try_to_move_right_3940
	
display_snobee_sprite_33CE:
33CE: DD 7E 05      ld   a,(ix+char_id)		; load sprite index
33D1: DD E5         push ix
33D3: E1            pop  hl
33D4: CD D4 31      call set_character_sprite_position_3154
33D7: C9            ret
	
handle_snobee_direction_change_33D8:
33D8: DD 7E 00      ld   a,(ix+x_pos)		; load X
33DB: E6 0F         and  $0F
33DD: FE 08         cp   $08			; not at the limit
33DF: C0            ret  nz
	
33E0: DD 7E 81      ld   a,(ix+y_pos)		; load Y
33E3: E6 8F         and  $0F
33E5: C0            ret  nz				; not at the limit
	
	;; x and y coords are aligned for possible direction change
	;; direction change can take place
	
33E6: 3A 75 0C      ld   a,(elapsed_minutes_since_start_of_round_8C5D)
33E9: FE 82         cp   $02
33EB: 30 96         jr   nc,snobees_play_chicken_3403 ; after 2 minutes, snobees run to the corners and disappear
	
33ED: 3A 18 05      ld   a,(remaining_alive_snobees_8D98)
33F0: FE 83         cp   $03
33F2: 30 BA         jr   nc,$342E ; > 3 :	go
33F4: FE 82         cp   $02
33F6: 20 84         jr   nz,$33FC
	;; only 2 snobees remaining
	;; reset counter
33F8: AF            xor  a
33F9: 32 23 20      ld   (five_second_counter_8823),a
33FC: 3A 8B 88      ld   a,(five_second_counter_8823)
33FF: FE 03         cp   $03
3401: 38 2B         jr   c,$342E
	;; after 15 seconds, the last snobee runs and disappears
snobees_play_chicken_3403:
3403: DD 7E 96      ld   a,(ix+ai_mode)
3406: FE 81         cp   $09
3408: 30 DF         jr   nc,apply_snobee_behaviour_3461 ; already in one of the "chicken" states
	;; set chicken state
340A: DD 36 34 8F   ld   (ix+move_period),$07 ; set speed to very fast fleeing snobee
	;; choose a corner to flee to
340E: CD 54 2D      call get_random_value_2D7C
3411: E6 03         and  $03
3413: C6 09         add  a,$09
3415: DD 77 1E      ld   (ix+ai_mode),a ; set A.I. "flee" mode

3418: 3E 8B         ld   a,$03
341A: 32 33 8C      ld   (game_phase_8CBB),a
341D: 06 FF         ld   b,$FF
341F: CD A1 90      call play_sfx_1889
3422: 06 80         ld   b,$09			; super fast game music
3424: CD A1 30      call play_sfx_1889
3427: 06 01         ld   b,$01
3429: CD C7 90      call update_sound_18c7
342C: 18 1B         jr   apply_snobee_behaviour_3461
	
	;; normal movement

	;; compute difficulty level from level number
	;; level 01:	3
	;; level 08:	4
	;; level 12:	5
	;; level 15:	6
	
342E: CD A7 28      call get_level_number_288F
3431: 3D            dec  a	; level - 1
3432: 0F            rrca	; level * 64
3433: 0F            rrca
3434: E6 8B         and  $03	; level & 0x3
3436: C6 8B         add  a,$03	; level += 3
3438: 47            ld   b,a
3439: 3A 98 05      ld   a,(remaining_alive_snobees_8D98)
343C: B8            cp   b
343D: 30 0C         jr   nc,$344B ; jump if more alive snobees than the difficulty value
	;; all snobees take A.I. mode "block breaking"
343F: CD 66 1A      call compute_snobee_speed_324E
3442: D6 89         sub  $01
3444: DD 77 34      ld   (ix+move_period),a ; change/adjust speed
3447: DD 36 96 02   ld   (ix+ai_mode),$02 ; breaking block mode
	
344B: 3A 75 A4      ld   a,(elapsed_minutes_since_start_of_round_8C5D)
344E: FE 89         cp   $01
3450: 38 0F         jr   c,apply_snobee_behaviour_3461
3452: F5            push af
	;; after 1 minute, accelerate snobees & set A.I. mode to breaking block mode
3453: CD 4E BA      call compute_snobee_speed_324E
3456: D6 89         sub  $01
3458: C1            pop  bc
3459: 90            sub  b
345A: DD 77 1C      ld   (ix+move_period),a ; change/adjust speed
345D: DD 36 1E 02   ld   (ix+ai_mode),$02 ; breaking block mode
	
apply_snobee_behaviour_3461:
3461: DD 7E 96      ld   a,(ix+ai_mode)
3464: 11 42 1C      ld   de,snobee_behaviour_table_346A
3467: C3 A7 05      jp   indirect_jump_2D8F

snobee_behaviour_table_346A:
	dc.w	_00_snobee_mode_block_avoid_351E
	dc.w	_01_snobee_mode_roaming_3649
	dc.w	_02_snobee_mode_block_eat_3843 ;  block breaking mode
	dc.w	_03_snobee_mode_pengo_hunt_1_on_x_378A
	dc.w	_04_snobee_mode_pengo_hunt_2_on_y_37C2
	dc.w	_05_snobee_mode_pengo_hunt_3_37FA ; the most aggressive mode
	dc.w	_01_snobee_mode_roaming_3649
	dc.w	_01_snobee_mode_roaming_3649
	dc.w	_05_snobee_mode_pengo_hunt_3_37FA
	dc.w	chicken_mode_reach_border_348C
	dc.w	chicken_mode_reach_border_348C
	dc.w	chicken_mode_reach_border_348C
	dc.w	chicken_mode_reach_border_348C
	dc.w	chicken_mode_go_up_to_corner_34D0
	dc.w	chicken_mode_go_down_to_corner_3503
	dc.w	chicken_mode_go_left_to_corner_350C
	dc.w	chicken_mode_go_right_to_corner_3515
	

chicken_mode_reach_border_348C:
348C: DD 7E 01      ld   a,(ix+y_pos)
348F: FE F0         cp   $F0
3491: 28 2C         jr   z,$34BF
3493: FE 10         cp   $10
3495: 28 28         jr   z,$34BF
3497: DD 7E 88      ld   a,(ix+x_pos)
349A: FE 50         cp   $D8
349C: 28 9A         jr   z,$34B0
349E: FE 18         cp   $18
34A0: 28 86         jr   z,$34B0
34A2: DD 7E 36      ld   a,(ix+ai_mode)
34A5: D6 21         sub  $09
34A7: E6 03         and  $03
34A9: DD 77 8C      ld   (ix+facing_direction),a
34AC: CD FE 38      call $38D6
34AF: C9            ret

34B0: CD 7C 2D      call get_random_value_2D7C
34B3: E6 01         and  $01
34B5: DD 77 8C      ld   (ix+facing_direction),a
34B8: C6 0D         add  a,$0D
34BA: DD 77 1E      ld   (ix+ai_mode),a ;  select corner to flee
34BD: E1            pop  hl
34BE: C9            ret

	;; change direction by a random value but only left/right
34BF: CD 7C 05      call get_random_value_2D7C
34C2: E6 89         and  $01
34C4: C6 8A         add  a,$02
34C6: DD 77 04      ld   (ix+facing_direction),a
34C9: C6 25         add  a,$0D
34CB: DD 77 96      ld   (ix+ai_mode),a ;  select corner to flee
34CE: E1            pop  hl
34CF: C9            ret
	
chicken_mode_go_up_to_corner_34D0:
24D0: DD 7E 01      ld   a,(ix+y_pos)
34D3: FE 10         cp   $10
34D5: 28 1C         jr   z,$34F3
34D7: CD 78 3E      call get_div8_ix_coords_3E78
34DA: DD 7E 04      ld   a,(ix+facing_direction)
34DD: 11 A1 CB      ld   de,is_grid_free_jump_table_43A1
34E0: CD A7 2D      call indirect_jump_2D8F
34E3: FE 34         cp   $1C
34E5: 28 24         jr   z,$34F3
34E7: FE 35         cp   $1D
34E9: 28 20         jr   z,$34F3
34EB: FE 36         cp   $1E
34ED: 28 04         jr   z,$34F3
34EF: CD D6 38      call $38D6
34F2: C9            ret

34F3: DD 36 8A C8   ld   (ix+animation_frame),$C8
34F7: DD 36 0B 06   ld   (ix+intermission_dance_push_anim_counter),$06
34FB: DD 77 1C      ld   (ix+move_period),a
34FE: DD 36 9F 39   ld   (ix+char_state),$11
3502: C9            ret

chicken_mode_go_down_to_corner_3503:
3503: DD 7E 29      ld   a,(ix+y_pos)
3506: FE D8         cp   $F0
3508: 28 C1         jr   z,$34F3
350A: 18 43         jr   $34D7
chicken_mode_go_left_to_corner_350C:
350C: DD 7E 80      ld   a,(ix+x_pos)
350F: FE 18         cp   $18
3511: 28 E0         jr   z,$34F3
3513: 18 C2         jr   $34D7
chicken_mode_go_right_to_corner_3515:
3515: DD 7E 80      ld   a,(ix+x_pos)
3518: FE 70         cp   $D8
351A: 28 57         jr   z,$34F3
351C: 18 39         jr   $34D7
	
_00_snobee_mode_block_avoid_351E:
351E: CD A0 B6      call find_an_empty_space_3608
3521: DD 4E 38      ld   c,(ix+path_address_pointer_or_misc_flags)
3524: FD 21 20 05   ld   iy,moving_block_struct_8DA0
3528: FD 7E 84      ld   a,(iy+facing_direction)
352B: 11 B1 BD      ld   de,table_3531
352E: C3 07 2D      jp   indirect_jump_2D8F
table_3531:
	.word	snobee_avoids_block_up_3539 
	.word	snobee_avoids_block_down_355D 
	.word	snobee_avoids_block_left_3573 
	.word	snobee_avoids_block_right_3589 

snobee_avoids_block_up_3539:
3539: 06 03			ld   b,$03                                          
353B: CB 79         bit  7,c
353D: 20 0E         jr   nz,$354D
353F: 06 82         ld   b,$02
3541: CB 71         bit  6,c
3543: 20 88         jr   nz,$354D
3545: 06 80         ld   b,$00
3547: CB 61         bit  4,c
3549: 20 8E         jr   nz,$3559
354B: 06 81         ld   b,$01
354D: DD 7E 35      ld   a,(ix+backup_ai_mode)
3550: DD 77 1E      ld   (ix+ai_mode),a ; sets saved A.I. mode
3553: DD 7E B4      ld   a,(ix+move_period)
3556: DD 77 06      ld   (ix+instant_move_period),a
3559: DD 70 84      ld   (ix+facing_direction),b
355C: C9            ret

snobee_avoids_block_down_355D:
355D: 06 02         ld   b,$02
355F: CB 71         bit  6,c
3561: 20 6A         jr   nz,$354D
3563: 06 83         ld   b,$03
3565: CB 79         bit  7,c
3567: 20 64         jr   nz,$354D
3569: 06 81         ld   b,$01
356B: CB 69         bit  5,c
356D: 20 6A         jr   nz,$3559
356F: 06 00         ld   b,$00
3571: 18 DA         jr   $354D

snobee_avoids_block_left_3573:
3573: 06 00         ld   b,$00
3575: CB 61         bit  4,c
3577: 20 D4         jr   nz,$354D
3579: 06 01         ld   b,$01
357B: CB 69         bit  5,c
357D: 20 CE         jr   nz,$354D
357F: 06 82         ld   b,$02
3581: CB 71         bit  6,c
3583: 20 54         jr   nz,$3559
3585: 06 83         ld   b,$03
3587: 18 44         jr   $354D

snobee_avoids_block_right_3589:
3589: 06 81         ld   b,$01
358B: CB 69         bit  5,c
358D: 20 3E         jr   nz,$354D
358F: 06 00         ld   b,$00
3591: CB 61         bit  4,c
3593: 20 B8         jr   nz,$354D
3595: 06 03         ld   b,$03
3597: CB 79         bit  7,c
3599: 20 BE         jr   nz,$3559
359B: 06 02         ld   b,$02
359D: 18 AE         jr   $354D
	
avoids_moving_block_359F:
359F: FD 21 88 0D   ld   iy,moving_block_struct_8DA0
35A3: FD 7E 2C      ld   a,(iy+facing_direction) ; block direction
35A6: 11 84 B5      ld   de,jump_table_35AC
35A9: C3 0F A5      jp   indirect_jump_2D8F
jump_table_35AC:
	.word	snobee_threatened_by_moving_block_up_35B4
	.word	snobee_threatened_by_moving_block_down_35D8
	.word	snobee_threatened_by_moving_block_left_35E8
	.word	snobee_threatened_by_moving_block_right_35F8

	
snobee_threatened_by_moving_block_up_35B4:
35B4: FD 7E 00      ld   a,(iy+x_pos)
35B7: DD BE 80      cp   (ix+x_pos)
35BA: C0            ret  nz	; not same x:	no danger
35BB: FD 7E 81      ld   a,(iy+y_pos)
35BE: DD BE 81      cp   (ix+y_pos)
35C1: D8            ret  c	; y block > y snobee no danger
	;; danger: try to avoid the block (block has speed 3, snobee has speed 5 which is slower but can be enough to avoid the block in some cases)
	
snobee_tries_to_avoid_block_35C2:
35C2: DD 7E 9E      ld   a,(ix+ai_mode)
35C5: DD 77 35      ld   (ix+backup_ai_mode),a ; backup A.I. mode
35C8: DD 36 9E 28   ld   (ix+ai_mode),$00 ; set block avoidance mode
35CC: 3E 2D         ld   a,$05	; fast speed
35CE: DD 77 06      ld   (ix+instant_move_period),a ; set speed
35D1: DD 36 87 00   ld   (ix+current_period_counter),$00
35D5: E1            pop  hl
35D6: E1            pop  hl
35D7: C9            ret
	
snobee_threatened_by_moving_block_down_35D8:
35D8: FD 7E 00      ld   a,(iy+x_pos)
35DB: DD BE 80      cp   (ix+x_pos)
35DE: C0            ret  nz
35DF: FD 7E 29      ld   a,(iy+y_pos)
35E2: DD BE 81      cp   (ix+y_pos)
35E5: D0            ret  nc
35E6: 18 52         jr   snobee_tries_to_avoid_block_35C2
	
snobee_threatened_by_moving_block_left_35E8:
35E8: FD 7E 81      ld   a,(iy+y_pos)
35EB: DD BE 29      cp   (ix+y_pos)
35EE: C0            ret  nz
35EF: FD 7E 80      ld   a,(iy+x_pos)
35F2: DD BE 00      cp   (ix+x_pos)
35F5: D8            ret  c
35F6: 18 62         jr   snobee_tries_to_avoid_block_35C2
	
snobee_threatened_by_moving_block_right_35F8:
35F8: FD 7E 01      ld   a,(iy+y_pos)
35FB: DD BE 81      cp   (ix+y_pos)
35FE: C0            ret  nz
35FF: FD 7E 88      ld   a,(iy+x_pos)
3602: DD BE 00      cp   (ix+x_pos)
3605: D0            ret  nc
3606: 18 32         jr   snobee_tries_to_avoid_block_35C2

find_an_empty_space_3608:
3608: DD 36 10 88   ld   (ix+path_address_pointer_or_misc_flags),$00
360C: CD 50 3E      call get_div8_ix_coords_3E78
360F: CD 0F 39      call is_upper_grid_free_390F
3612: 20 8F         jr   nz,$361B
3614: DD CB 10 E6   set  4,(ix+path_address_pointer_or_misc_flags)
3618: DD 34 10      inc  (ix+path_address_pointer_or_misc_flags)
361B: CD 78 3E      call get_div8_ix_coords_3E78
361E: CD 9F 39      call is_lower_grid_free_3917
3621: 20 07         jr   nz,$362A
3623: DD CB 98 EE   set  5,(ix+path_address_pointer_or_misc_flags)
3627: DD 34 98      inc  (ix+path_address_pointer_or_misc_flags)
362A: CD 50 3E      call get_div8_ix_coords_3E78
362D: CD 33 11      call is_left_grid_free_391B
3630: 20 8F         jr   nz,$3639
3632: DD CB 10 F6   set  6,(ix+path_address_pointer_or_misc_flags)
3636: DD 34 10      inc  (ix+path_address_pointer_or_misc_flags)
3639: CD 78 3E      call get_div8_ix_coords_3E78
363C: CD 1E 39      call is_right_grid_free_391E
363F: 20 07         jr   nz,$3648
3641: DD CB 98 FE   set  7,(ix+path_address_pointer_or_misc_flags)
3645: DD 34 98      inc  (ix+path_address_pointer_or_misc_flags)
3648: C9            ret
	
_01_snobee_mode_roaming_3649:
3649: 3A BF A5      ld   a,(block_moving_flag_8DBF)
364C: FE 8A         cp   $02
364E: CC B7 35      call z,avoids_moving_block_359F
	;; update speed
3651: DD 7E 1C      ld   a,(ix+move_period)
3654: DD 77 06      ld   (ix+instant_move_period),a
3657: CD 08 BE      call find_an_empty_space_3608
365A: DD 7E 10      ld   a,(ix+path_address_pointer_or_misc_flags)
365D: E6 0F         and  $0F
365F: 11 4D 1E      ld   de,table_3665
3662: C3 A7 2D      jp   indirect_jump_2D8F
table_3665:
     dc.w	$366F 
	 dc.w	$3675  
	 dc.w	$36E0 
	 dc.w	$371D  
	 dc.w	$3752 
	
366F: DD 36 1E 02   ld   (ix+ai_mode),$02 ;  sets block breaking mode
3673: E1            pop  hl
3674: C9            ret

3675: DD 7E 98      ld   a,(ix+path_address_pointer_or_misc_flags)
3678: 06 8B         ld   b,$03
367A: 07            rlca
367B: 38 02         jr   c,$367F
367D: 10 FB         djnz $367A
367F: DD 70 8C      ld   (ix+facing_direction),b
3682: DD 34 15      inc  (ix+$15)
3685: DD 7E 9D      ld   a,(ix+$15)
3688: 11 A6 1E      ld   de,table_368E
368B: C3 A7 05      jp   indirect_jump_2D8F

table_368E:  
	 dc.w	$3696  
	 dc.w	$36A0  
	 dc.w	$36AA  
	 dc.w	$36BE 
 

3696: CD 78 3E      call get_div8_ix_coords_3E78
3699: DD 71 9E      ld   (ix+$16),c
369C: DD 70 17      ld   (ix+$17),b
369F: C9            ret

36A0: CD 50 3E      call get_div8_ix_coords_3E78
36A3: DD 71 90      ld   (ix+$18),c
36A6: DD 70 31      ld   (ix+$19),b
36A9: C9            ret

36AA: CD 50 3E      call get_div8_ix_coords_3E78
36AD: 69            ld   l,c
36AE: 60            ld   h,b
36AF: DD 5E 9E      ld   e,(ix+$16)
36B2: DD 56 17      ld   d,(ix+$17)
36B5: CD 99 2D      call compare_hl_to_de_2D99
36B8: C8            ret  z
36B9: DD 36 9D FF   ld   (ix+$15),$FF
36BD: C9            ret

36BE: CD 78 3E      call get_div8_ix_coords_3E78
36C1: 69            ld   l,c
36C2: 60            ld   h,b
36C3: DD 5E 90      ld   e,(ix+$18)
36C6: DD 56 31      ld   d,(ix+$19)
36C9: CD B1 05      call compare_hl_to_de_2D99
36CC: 28 8D         jr   z,$36D3
36CE: DD 36 15 77   ld   (ix+$15),$FF
36D2: C9            ret

36D3: DD 36 1B 02   ld   (ix+$1b),$02
36D7: DD 36 1E 02   ld   (ix+ai_mode),$02 ;  sets block breaking mode
36DB: DD 36 9D FF   ld   (ix+$15),$FF
36DF: C9            ret

36E0: CD 8E 1F      call $3706
36E3: CD DE 1E      call get_opposite_direction_36f6
36E6: DD E5         push ix
36E8: E1            pop  hl
36E9: 11 11 88      ld   de,$0011
36EC: 19            add  hl,de
36ED: BE            cp   (hl)
36EE: 20 89         jr   nz,$36F1
36F0: 23            inc  hl
36F1: 7E            ld   a,(hl)
36F2: DD 77 04      ld   (ix+facing_direction),a
36F5: C9            ret

get_opposite_direction_36f6:
36F6: DD 7E 04      ld   a,(ix+facing_direction)
36F9: 16 00         ld   d,$00
36FB: 5F            ld   e,a
36FC: 21 8A 37      ld   hl,table_3702
36FF: 19            add  hl,de
3700: 7E            ld   a,(hl)
3701: C9            ret

table_3702:
  01 00 03 02 
  
3706: DD 7E 90  	ld   a,(ix+path_address_pointer_or_misc_flags)                                     
3709: 06 84         ld   b,$04
370B: 0E 83         ld   c,$03
370D: DD E5         push ix
370F: E1            pop  hl
3710: 11 91 00      ld   de,$0011
3713: 19            add  hl,de
3714: 07            rlca
3715: 30 02         jr   nc,$3719
3717: 71            ld   (hl),c
3718: 23            inc  hl
3719: 0D            dec  c
371A: 10 78         djnz $3714
371C: C9            ret

371D: CD 06 9F      call $3706
; completely useless call, probably buggy
3720: CD F4 AD      call get_random_value_2D7C
3723: E6 83         and  $03
3725: FE 83         cp   $03
; test always succeeds, else it would loop????
3727: 30 77         jr   nc,$3720
3729: DD E5         push ix
372B: E1            pop  hl
372C: 1E 39         ld   e,$11
372E: 83            add  a,e
372F: 5F            ld   e,a
3730: 16 80         ld   d,$00
3732: 19            add  hl,de
3733: 7E            ld   a,(hl)
3734: F5            push af
3735: CD F6 9E      call get_opposite_direction_36f6
3738: 47            ld   b,a
3739: F1            pop  af
373A: B8            cp   b
373B: 28 E3         jr   z,$3720
373D: DD 46 84      ld   b,(ix+facing_direction)
3740: DD 77 84      ld   (ix+facing_direction),a
3743: B8            cp   b
3744: C8            ret  z
3745: DD 36 22 81   ld   (ix+stunned_push_block_counter),$01
3749: DD 36 21 8F   ld   (ix+$09),$0F
374D: DD 36 37 01   ld   (ix+char_state),$01
3751: C9            ret

3752: CD FC 2D      call get_random_value_2D7C
3755: E6 01         and  $01
3757: C8            ret  z
; 50% chance
3758: FD 21 80 25   ld   iy,pengo_struct_8D80
375C: DD 36 04 80   ld   (ix+facing_direction),$00
3760: DD 7E 80      ld   a,(ix+x_pos)
3763: FD 96 28      sub  (iy+x_pos)
3766: 30 2E         jr   nc,$376E
3768: DD CB 84 4E   set  0,(ix+facing_direction)
376C: ED 44         neg
376E: 47            ld   b,a
376F: DD 7E 81      ld   a,(ix+y_pos)
3772: FD 96 01      sub  (iy+y_pos)
3775: 30 06         jr   nc,$377D
3777: DD CB 84 CE   set  1,(ix+facing_direction)
377B: ED 44         neg
377D: 90            sub  b
377E: 30 85         jr   nc,$3785
3780: DD CB 84 46   set  1,(ix+facing_direction)
3784: C9            ret
3785: DD CB 2C BE   srl  (ix+facing_direction)
3789: C9            ret

	;; *** hunt mode 1 ***
	;; if same x, change y direction to follow pengo
	;; else
	;;    1 chance out of 8 to go (temporarily) in roaming mode
	;; if no roaming mode, then
	;;    if snobee x is near pengo x (next/previous column), change y direction too
	;;    else go (temporarily) in roaming mode
	
_03_snobee_mode_pengo_hunt_1_on_x_378A:
378A: FD 21 00 05   ld   iy,pengo_struct_8D80
378E: FD 7E 00      ld   a,(iy+x_pos) ; pengo X
3791: DD BE 80      cp   (ix+x_pos) ; same X as snobee?
3794: 28 B2         jr   z,change_vertical_direction_to_follow_pengo_37B0
3796: CD FC 2D      call get_random_value_2D7C
3799: E6 07         and  $07
	;; 1 chance out of 8 to go in roaming mode in this case
	;; (and thus avoids pushed blocks)
379B: CA 49 9E      jp   z,_01_snobee_mode_roaming_3649
	
379E: FD 7E 80      ld   a,(iy+x_pos)
37A1: D6 90         sub  $10
37A3: DD BE 28      cp   (ix+x_pos)
37A6: 28 20         jr   z,change_vertical_direction_to_follow_pengo_37B0
37A8: C6 A8         add  a,$20
37AA: DD BE 80      cp   (ix+x_pos)
	;; far from pengo (not in the next row): go roaming
37AD: C2 C9 BE      jp   nz,_01_snobee_mode_roaming_3649
	
	;; just one row above or one row below pengo
	;; change direction to up or down to try to get pengo
change_vertical_direction_to_follow_pengo_37B0:
37B0: 06 80         ld   b,$00
37B2: FD 7E 01      ld   a,(iy+y_pos)
37B5: DD BE 81      cp   (ix+y_pos)
37B8: 38 81         jr   c,$37BB
37BA: 04            inc  b
37BB: DD 70 84      ld   (ix+facing_direction),b
37BE: CD 56 B8      call $38D6
37C1: C9            ret

	;; *** hunt mode 2 ***
	;; if same y, change x direction to follow pengo
	;; else
	;;    1 chance out of 8 to go in roaming mode
	;; if no roaming mode, then
	;;    if snobee y is near pengo y (next/previous row), change x direction too
	;;    else go (temporarily) in roaming mode
		
_04_snobee_mode_pengo_hunt_2_on_y_37C2:
37C2: FD 21 00 05   ld   iy,pengo_struct_8D80
37C6: FD 7E 81      ld   a,(iy+y_pos)
37C9: DD BE 29      cp   (ix+y_pos)
37CC: 28 32         jr   z,change_lateral_direction_to_follow_pengo_37E8
37CE: CD F4 2D      call get_random_value_2D7C
37D1: E6 07         and  $07
37D3: CA 49 9E      jp   z,_01_snobee_mode_roaming_3649
37D6: FD 7E 01      ld   a,(iy+y_pos)
37D9: D6 10         sub  $10
37DB: DD BE 81      cp   (ix+y_pos)
37DE: 28 A0         jr   z,change_lateral_direction_to_follow_pengo_37E8
37E0: C6 A8         add  a,$20
37E2: DD BE 81      cp   (ix+y_pos)
37E5: C2 C9 BE      jp   nz,_01_snobee_mode_roaming_3649
	
change_lateral_direction_to_follow_pengo_37E8:
37E8: 06 2A         ld   b,$02
37EA: FD 7E 80      ld   a,(iy+x_pos)
37ED: DD BE 28      cp   (ix+x_pos)
37F0: 38 81         jr   c,$37F3 ; pengo x < snobee x ?
37F2: 04            inc  b
37F3: DD 70 84      ld   (ix+facing_direction),b ;  set left or right to be closer to pengo
37F6: CD 56 38      call $38D6
37F9: C9            ret

	;; *** hunt mode 3 ***
	;; if same x, change y direction to follow pengo
	;; else
	;;    1 chance out of 8 to go in roaming mode (and thus breaks the chase)
	;; if no roaming mode, then
	;;    if snobee x is near pengo x (next/previous column), change y direction too
	;; else if same y, change x direction to follow pengo
	;; else
	;;    1 chance out of 8 to go (temporarily) in roaming mode
	;; if no roaming mode, then
	;;    if snobee y is near pengo y (next/previous row), change x direction too
	;;    else go in roaming mode

_05_snobee_mode_pengo_hunt_3_37FA:
37FA: FD 21 80 25   ld   iy,pengo_struct_8D80
37FE: FD 7E 00      ld   a,(iy+x_pos)
3801: DD BE 88      cp   (ix+x_pos) ;  same X ?
3804: 28 22         jr   z,change_vertical_direction_to_follow_pengo_37B0
3806: CD 54 2D      call get_random_value_2D7C
3809: E6 07         and  $07
	;; 1 chance out of 8 to go in roaming mode in this case
	;; (and thus avoids pushed blocks)
380B: CA 61 1E      jp   z,_01_snobee_mode_roaming_3649
	
380E: FD 7E 00      ld   a,(iy+x_pos) ;  pengo X
3811: D6 10         sub  $10
3813: DD BE 88      cp   (ix+x_pos)
3816: 28 10         jr   z,change_vertical_direction_to_follow_pengo_37B0
3818: C6 A8         add  a,$20
381A: DD BE 00      cp   (ix+x_pos)
	;; near pengo (in the next column left or right): follow pengo
381D: 28 91         jr   z,change_vertical_direction_to_follow_pengo_37B0
	;; same y as pengo ??
381F: FD 7E 89      ld   a,(iy+y_pos)
3822: DD BE 01      cp   (ix+y_pos)
3825: 28 C1         jr   z,change_lateral_direction_to_follow_pengo_37E8
3827: CD 7C 05      call get_random_value_2D7C
382A: E6 8F         and  $07
382C: CA C1 1E      jp   z,_01_snobee_mode_roaming_3649
382F: FD 7E 89      ld   a,(iy+y_pos)
3832: D6 98         sub  $10
3834: DD BE 01      cp   (ix+y_pos)
3837: 28 AF         jr   z,change_lateral_direction_to_follow_pengo_37E8
3839: C6 20         add  a,$20
383B: DD BE 89      cp   (ix+y_pos)
383E: 28 20         jr   z,change_lateral_direction_to_follow_pengo_37E8
3840: C3 C1 1E      jp   _01_snobee_mode_roaming_3649

		;; block breaking mode
	;; avoids moving blocks
	
02_snobee_mode_block_eat_3843: 
3843: 3A BF A5      ld   a,(block_moving_flag_8DBF)
3846: FE 8A         cp   $02
3848: CC B7 1D      call z,avoids_moving_block_359F ; block is moving
	
384B: CD 7C 05      call	get_random_value_2D7C
384E: E6 89         and  $01
3850: 20 EA         jr   nz,$38B4 ;  1/2 chance
	
3852: FD 21 80 05   ld   iy,pengo_struct_8D80
3856: FD 7E 01      ld   a,(iy+y_pos)
3859: DD BE 89      cp   (ix+y_pos)
385C: 20 08         jr   nz,$3866
	;; if same y, 1 chance out of 8 to stop following pengo
385E: CD 7C 2D      call get_random_value_2D7C
3861: E6 07         and  $07
3863: CA 61 1E      jp   z,_01_snobee_mode_roaming_3649
3866: FD 7E 00      ld   a,(iy+x_pos)
3869: DD BE 88      cp   (ix+x_pos)
386C: 28 80         jr   z,$3876
	;; if not same x, 1 chance out of 8 to stop following pengo
386E: CD 54 2D      call get_random_value_2D7C
3871: E6 07         and  $07
3873: CA 49 BE      jp   z,_01_snobee_mode_roaming_3649
	
3876: FD 56 01      ld   d,(iy+y_pos)
3879: CD 7C 2D      call get_random_value_2D7C
387C: E6 98         and  $10
387E: 82            add  a,d
387F: 57            ld   d,a	; rand(16)+pengo_y
3880: FD 5E 00      ld   e,(iy+x_pos)
3883: CD 7C 05      call get_random_value_2D7C
3886: E6 98         and  $10
3888: 83            add  a,e
3889: 5F            ld   e,a	;  rand(16)+pengo_x
388A: DD 36 04 88   ld   (ix+facing_direction),$00 ; set direction up (clear)
388E: DD 7E 00      ld   a,(ix+x_pos)
3891: 93            sub  e
3892: 30 8E         jr   nc,$389A
3894: DD CB 04 C6   set  0,(ix+facing_direction) ; set direction down
3898: ED 44         neg
389A: 47            ld   b,a
389B: DD 7E 89      ld   a,(ix+y_pos)
389E: 92            sub  d
389F: 30 06         jr   nc,$38A7
38A1: DD CB 8C E6   set  1,(ix+facing_direction) ; set direction left or right (depends on above)
38A5: ED 44         neg
38A7: 90            sub  b
38A8: 30 8E         jr   nc,$38B0
38AA: DD CB 04 E6   set  1,(ix+facing_direction)
38AE: 18 8C         jr   $38B4
38B0: DD CB 04 3E   srl  (ix+facing_direction)
	
38B4: DD CB 1B 36   res  7,(ix+$1b)
38B8: CD D6 38      call $38D6
38BB: DD CB 1B 7E   bit  7,(ix+$1b)
38BF: C8            ret  z
38C0: DD 35 33      dec  (ix+$1b)
38C3: DD 7E 93      ld   a,(ix+$1b)
38C6: E6 57         and  $7F
38C8: C0            ret  nz
38C9: DD 36 96 01   ld   (ix+ai_mode),$01 ;  set A.I. mode to roaming mode
38CD: C9            ret
	
38CE: CD 54 2D      call get_random_value_2D7C
38D1: E6 03         and  $03
38D3: DD 77 8C      ld   (ix+facing_direction),a
	
38D6: DD 7E 1C      ld   a,(ix+move_period)
38D9: DD 77 8E      ld   (ix+instant_move_period),a ; set snobee speed to normal speed
38DC: CD 78 3E      call get_div8_ix_coords_3E78
38DF: DD 7E 8C      ld   a,(ix+facing_direction) ; direction
38E2: 11 29 43      ld   de,is_grid_free_jump_table_43A1
38E5: CD A7 05      call indirect_jump_2D8F
38E8: C8            ret  z
	;; there is a block in front the snobee way. which one?
38E9: FE 10         cp   $10
38EB: 38 03         jr   c,$38F0
38ED: FE 16         cp   $16
38EF: D8            ret  c
38F0: DD 7E 1C      ld   a,(ix+move_period)
38F3: C6 18         add  a,$18
38F5: DD 77 8E      ld   (ix+instant_move_period),a
38F8: CD 78 43      call move_snobee_current_direction_4378
38FB: CD 6F 29      call convert_coords_to_screen_address_296F
38FE: 3E 1C         ld   a,$1C
3900: BE            cp   (hl)
3901: 28 4B         jr   z,$38CE
3903: CD 8A B8      call look_for_hidden_egg_300A
3906: 38 4E         jr   c,$38CE
3908: DD CB 9B D6   set  7,(ix+$1b)
390C: C3 4E C2      jp   find_breaking_block_free_slot_42c6
	
is_upper_grid_free_390F:
390F: 05            dec  b
3910: CD EF 29      call convert_coords_to_screen_address_296F
3913: 7E            ld   a,(hl)
3914: FE 88         cp   $20
3916: C9            ret
	
is_lower_grid_free_3917:
3917: 04            inc  b
3918: 04            inc  b
3919: 18 F5         jr   $3910
is_left_grid_free_391B:
391B: 0D            dec  c
391C: 18 5A         jr   $3910
is_right_grid_free_391E:
391E: 0C            inc  c
391F: 0C            inc  c
3920: 18 C6         jr   $3910
	
snobee_try_to_move_up_3922: 
3922: DD 7E 81      ld   a,(ix+y_pos)
3925: FE 91         cp   $11
3927: D8            ret  c
3928: DD 35 81      dec  (ix+y_pos)
392B: C9            ret
	
snobee_try_to_move_down_392C: 
392C: DD 7E 81      ld   a,(ix+y_pos)
392F: FE F0         cp   $F0
3931: D0            ret  nc
3932: DD 34 01      inc  (ix+y_pos)
3935: C9            ret
	
snobee_try_to_move_left_3936: 
3936: DD 7E 00      ld   a,(ix+x_pos)
3939: FE 19         cp   $19
393B: D8            ret  c
393C: DD 35 00      dec  (ix+x_pos)
393F: C9            ret
	
snobee_try_to_move_right_3940: 
3940: DD 7E 80      ld   a,(ix+x_pos)
3943: FE 58         cp   $D8
3945: D0            ret  nc
3946: DD 34 80      inc  (ix+x_pos)
3949: C9            ret
	
animate_pengo_39A4: 
39A4: DD 7E 88      ld   a,(ix+$08)
394D: A7            and  a
394E: C8            ret  z	; returns if a == 0
394F: 3A 24 20      ld   a,(counter_lsb_8824)
3952: E6 B7         and  $1F
3954: C0            ret  nz	; returns if counter_lsb_8824 isn't dividable by 32?
	;; counter 1 out of 32 pengo animation moves
3955: 18 14         jr   $396B

animate_snobee_3957:
3957: DD 7E A0      ld   a,(ix+$08)
395A: A7            and  a
395B: C8            ret  z
395C: 3A 8C 88      ld   a,(counter_lsb_8824)
395F: E6 9F         and  $1F
3961: C0            ret  nz
	;; counter 1 out of 32 snobees animation moves
	; this selects snobee state: bouncing/walking/frightened
3962: DD 34 8C      inc  (ix+alive_walk_counter)
3965: DD 7E 24      ld   a,(ix+alive_walk_counter)
3968: E6 2B         and  $03
396A: C0            ret  nz
396B: 06 80         ld   b,$00
396D: DD 7E 2D      ld   a,(ix+char_id)
3970: FE 85         cp   $05
3972: 28 91         jr   z,base_frame_selected_3985
3974: 06 8E         ld   b,$26			; walking, up
3976: DD 7E 1E      ld   a,(ix+ai_mode)
3979: FE 02         cp   $02
397B: 28 08         jr   z,base_frame_selected_3985
397D: 06 2C         ld   b,$2C			; frightened, up
397F: FE 89         cp   $09
3981: 30 82         jr   nc,base_frame_selected_3985
3983: 06 92         ld   b,$12			; bouncing, up
; base frame is selected then adjust direction and animation
base_frame_selected_3985:
3985: DD 34 24      inc  (ix+alive_walk_counter)
3988: DD 7E 84      ld   a,(ix+facing_direction)
398B: FE 83         cp   $03
398D: 20 81         jr   nz,$3990
398F: 3D            dec  a
3990: 87            add  a,a
3991: DD CB A4 56   bit  2,(ix+alive_walk_counter)
3995: 20 01         jr   nz,$3998
3997: 3C            inc  a
3998: 80            add  a,b
3999: CB 27         sla  a			; shift character code
399B: CB 27         sla  a			; twice
399D: DD 77 82      ld   (ix+animation_frame),a
39A0: DD 7E 84      ld   a,(ix+facing_direction)
39A3: FE 83         cp   $03
39A5: 20 84         jr   nz,set_character_sprite_code_and_color_39AB
; enable X-flip bit
39A7: DD CB 2A 4E   set  1,(ix+animation_frame)
set_character_sprite_code_and_color_39AB:
39AB: DD 7E 2D      ld   a,(ix+char_id)
39AE: DD E5         push ix
39B0: E1            pop  hl
39B1: CD 8A 99      call set_character_sprite_code_and_color_318A
39B4: C9            ret
	
_04_snobee_stunned_39B5:
39B5: CD D1 B9      call $39D1
39B8: DD CB 09 C6   bit  0,(ix+$09)
39BC: CC 43 39      call z,$39C3
39BF: CD 0E BB      call $338E
39C2: C9            ret
	
39C3: DD 36 22 85   ld   (ix+stunned_push_block_counter),$05
39C7: DD 36 21 8F   ld   (ix+$09),$0F
39CB: 06 86         ld   b,$06
39CD: CD 47 30      call update_sound_18c7
39D0: C9            ret

39D1: 3A 24 20      ld   a,(counter_lsb_8824)
39D4: E6 FF         and  $7F
39D6: C0            ret  nz
	;; counter 1 out of 128 xxx
39D7: 3E 60         ld   a,$60
39D9: DD 34 A4      inc  (ix+alive_walk_counter)
39DC: DD CB 0C C6   bit  0,(ix+alive_walk_counter)
39E0: 20 2A         jr   nz,$39E4
39E2: 3E EC         ld   a,$64
39E4: DD CB 84 6E   bit  0,(ix+facing_direction)
39E8: 28 2A         jr   z,$39EC
39EA: CB CF         set  1,a
39EC: DD 77 82      ld   (ix+animation_frame),a
39EF: CD AB B9      call set_character_sprite_code_and_color_39AB
39F2: C9            ret
	
_05_snobee_blinking_stunned_39F3:
39F3: CD D1 B9      call $39D1
39F6: DD CB 09 C6   bit  0,(ix+$09)
39FA: CC 81 3A      call z,$3A01
39FD: CD 0A BA      call $3A0A
3A00: C9            ret
	
3A01: DD 36 82 20   ld   (ix+stunned_push_block_counter),$08
3A05: DD 36 81 27   ld   (ix+$09),$0F
3A09: C9            ret

3A0A: 3A 0C A0      ld   a,(counter_lsb_8824) ; count mask
3A0D: A7            and  a
3A0E: C0            ret  nz
3A0F: DD 7E 0A      ld   a,(ix+stunned_push_block_counter)
3A12: 3D            dec  a
3A13: 28 19         jr   z,$3A2E ;  end of stun
3A15: DD 77 0A      ld   (ix+stunned_push_block_counter),a
3A18: 06 09         ld   b,$09
3A1A: CB 47         bit  0,a
3A1C: 20 09         jr   nz,$3A27
3A1E: CD 07 28      call get_level_number_288F
3A21: 3D            dec  a
3A22: E6 8F         and  $07
3A24: C6 89         add  a,$01
3A26: 47            ld   b,a
3A27: DD 70 8B      ld   (ix+char_color),b
3A2A: CD 23 39      call set_character_sprite_code_and_color_39AB
3A2D: C9            ret
	;; no longer stunned
3A2E: DD 7E 00      ld   a,(ix+x_pos)
3A31: 06 03         ld   b,$03
3A33: FE 18         cp   $18
3A35: 28 1B         jr   z,$3A52
3A37: 06 02         ld   b,$02
3A39: FE D8         cp   $D8
3A3B: 28 15         jr   z,$3A52
3A3D: DD 7E 89      ld   a,(ix+y_pos)
3A40: 06 89         ld   b,$01
3A42: FE 98         cp   $10
3A44: 28 84         jr   z,$3A52
3A46: 06 88         ld   b,$00
3A48: FE 78         cp   $F0
3A4A: 28 8E         jr   z,$3A52
3A4C: CD 54 2D      call get_random_value_2D7C
3A4F: E6 03         and  $03
3A51: 47            ld   b,a
3A52: DD 70 04      ld   (ix+facing_direction),b
3A55: CD 8F 28      call get_level_number_288F
3A58: 3D            dec  a
3A59: E6 07         and  $07
3A5B: C6 01         add  a,$01
3A5D: DD 77 8B      ld   (ix+char_color),a
3A60: CD 23 39      call set_character_sprite_code_and_color_39AB
3A63: DD 36 96 02   ld   (ix+ai_mode),$02 ; wake up from "stunned" -> A.I. mode set to breaking block mode
3A67: DD 36 97 02   ld   (ix+char_state),$02 ; set state to "alive"
3A6B: C9            ret
	
_06_stunned_picked_3A6C:
3A6C: DD CB 21 CE   bit  0,(ix+$09)
3A70: CC FF 3A      call z,$3A77
3A73: CD 92 3A      call $3A92
3A76: C9            ret

3A77: DD 36 0A 08   ld   (ix+stunned_push_block_counter),$08
3A7B: DD 36 09 0F   ld   (ix+$09),$0F
3A7F: DD 36 8A 80   ld   (ix+animation_frame),$80
3A83: CD AB 11      call set_character_sprite_code_and_color_39AB
3A86: 11 82 00      ld   de,$000A
3A89: CD AF 00      call add_to_current_player_score_28AF
3A8C: 06 8A         ld   b,$02
3A8E: CD EF 18      call update_sound_18c7
3A91: C9            ret

3A92: 3A AC 88      ld   a,(counter_lsb_8824) ;  count mask
3A95: A7            and  a
3A96: C0            ret  nz
3A97: DD 7E 0A      ld   a,(ix+stunned_push_block_counter)
3A9A: 3D            dec  a
3A9B: 28 04         jr   z,$3AA1
3A9D: DD 77 0A      ld   (ix+stunned_push_block_counter),a
3AA0: C9            ret
3AA1: DD 36 81 00   ld   (ix+$09),$00
3AA5: DD 34 97      inc  (ix+char_state)
3AA8: 21 B0 A5      ld   hl,remaining_alive_snobees_8D98
3AAB: 35            dec  (hl)		; one snobee less
3AAC: C9            ret
	
_03_snobee_aligns_for_stunned_3AAD:
3AAD: DD 34 8F      inc  (ix+current_period_counter) ;  slow down
3AB0: DD 7E 07      ld   a,(ix+current_period_counter)
3AB3: DD BE 8E      cp   (ix+instant_move_period)
3AB6: D8            ret  c
3AB7: DD 36 8F 00   ld   (ix+current_period_counter),$00
3ABB: DD 7E 88      ld   a,(ix+x_pos)
3ABE: E6 0F         and  $0F
3AC0: FE 80         cp   $08
3AC2: 20 87         jr   nz,$3AD3
3AC4: DD 7E 01      ld   a,(ix+y_pos)
3AC7: E6 27         and  $0F
3AC9: 20 20         jr   nz,$3AD3
3ACB: DD 36 81 00   ld   (ix+$09),$00
3ACF: DD 34 1F      inc  (ix+char_state) ; next state (stunned)
3AD2: C9            ret
3AD3: CD B9 BB      call move_snobee_forward_33B9
3AD6: C9            ret

3AD7: ED 4B A0 8D   ld   bc,(moving_block_struct_8DA0)
3ADB: 3A A4 05      ld   a,(moving_block_struct_8DA0+4)
3ADE: 11 2A 3B      ld   de,jump_table_3B2A
3AE1: CD A7 05      call indirect_jump_2D8F
3AE4: DD 71 00      ld   (ix+x_pos),c
3AE7: DD 70 89      ld   (ix+y_pos),b
3AEA: 3A 2C A5      ld   a,(moving_block_struct_8DA0+4)
3AED: DD 77 8C      ld   (ix+facing_direction),a
3AF0: E6 8A         and  $02
3AF2: 47            ld   b,a
3AF3: 3A A4 05      ld   a,(moving_block_struct_8DA0+4)
3AF6: 2F            cpl
3AF7: E6 01         and  $01
3AF9: B0            or   b
3AFA: FE 8B         cp   $03
3AFC: 20 89         jr   nz,$3AFF
3AFE: 3D            dec  a
3AFF: 87            add  a,a
3B00: C6 3A         add  a,$12
3B02: 07            rlca
3B03: 07            rlca
3B04: DD 77 82      ld   (ix+animation_frame),a
3B07: DD 7E 2C      ld   a,(ix+facing_direction)
3B0A: FE 2A         cp   $02
3B0C: 20 2C         jr   nz,$3B12
3B0E: DD CB 02 66   set  1,(ix+animation_frame)
3B12: DD 36 06 83   ld   (ix+instant_move_period),$03
3B16: 3A 0F 8D      ld   a,(moving_block_struct_8DA0+7)
3B19: DD 77 87      ld   (ix+current_period_counter),a
3B1C: CD 66 33      call display_snobee_sprite_33CE
3B1F: CD 2B B1      call set_character_sprite_code_and_color_39AB
3B22: DD 36 89 28   ld   (ix+$09),$00
3B26: DD 34 9F      inc  (ix+char_state)
3B29: C9            ret
; jump table
jump_table_3B2A:
	dc.w	ice_block_hits_snobee_up_3B32
	dc.w	ice_block_hits_snobee_down_3B37
	dc.w	ice_block_hits_snobee_left_3B3C
	dc.w	ice_block_hits_snobee_right_3B41
	
ice_block_hits_snobee_up_3B32:
3B32: 78            ld   a,b
3B33: D6 10         sub  $10
3B35: 47            ld   b,a
3B36: C9            ret

ice_block_hits_snobee_down_3B37:
3B37: 78            ld   a,b
3B38: C6 90         add  a,$10
3B3A: 47            ld   b,a
3B3B: C9            ret

ice_block_hits_snobee_left_3B3C:
3B3C: 79            ld   a,c
3B3D: D6 10         sub  $10
3B3F: 4F            ld   c,a
3B40: C9            ret

ice_block_hits_snobee_right_3B41:
3B41: 79            ld   a,c
3B42: C6 38         add  a,$10
3B44: 4F            ld   c,a
3B45: C9            ret

3B46: DD 7E 88      ld   a,(ix+$08)
3B49: A7            and  a
3B4A: 28 3A         jr   z,$3B5E
3B4C: DD 34 87      inc  (ix+current_period_counter)
3B4F: DD 7E 87      ld   a,(ix+current_period_counter)
3B52: DD BE 06      cp   (ix+instant_move_period)
3B55: D8            ret  c
3B56: DD 36 07 80   ld   (ix+current_period_counter),$00
3B5A: CD 39 33      call move_snobee_forward_33B9
3B5D: C9            ret

3B5E: DD 7E 84      ld   a,(ix+facing_direction)
3B61: FE 83         cp   $03
3B63: 20 81         jr   nz,$3B66
3B65: 3D            dec  a
3B66: 87            add  a,a
3B67: C6 8C         add  a,$0C
3B69: 07            rlca
3B6A: 07            rlca
3B6B: DD 77 2A      ld   (ix+animation_frame),a
3B6E: DD 7E 04      ld   a,(ix+facing_direction)
3B71: FE 03         cp   $03
3B73: 20 04         jr   nz,$3B79
3B75: DD CB 82 CE   set  1,(ix+animation_frame)
3B79: CD AB B9      call set_character_sprite_code_and_color_39AB
3B7C: C9            ret
3B7D: DD CB A1 C6   bit  0,(ix+$09)
3B81: CC 08 B3      call z,$3B88
3B84: CD 06 B3      call $338E
3B87: C9            ret
3B88: DD 36 8A 29   ld   (ix+stunned_push_block_counter),$01
3B8C: DD 36 89 27   ld   (ix+$09),$0F
3B90: DD 7E 04      ld   a,(ix+facing_direction)
3B93: FE 03         cp   $03
3B95: 20 01         jr   nz,$3B98
3B97: 3D            dec  a
3B98: 87            add  a,a
3B99: 3C            inc  a
3B9A: C6 A4         add  a,$0C
3B9C: 07            rlca
3B9D: 07            rlca
3B9E: DD 77 82      ld   (ix+animation_frame),a
3BA1: DD 7E 2C      ld   a,(ix+facing_direction)
3BA4: FE 2B         cp   $03
3BA6: 20 2C         jr   nz,$3BAC
3BA8: DD CB 82 46   set  1,(ix+animation_frame)
3BAC: CD 83 B9      call set_character_sprite_code_and_color_39AB
3BAF: DD 36 A0 FF   ld   (ix+$08),$FF
3BB3: C9            ret
3BB4: DD CB 09 C6   bit  0,(ix+$09)
3BB8: CC 3F 3B      call z,$3BBF
3BBB: CD 22 BC      call $3C22
3BBE: C9            ret
3BBF: DD 36 22 84   ld   (ix+stunned_push_block_counter),$04
3BC3: DD 36 21 8F   ld   (ix+$09),$0F
3BC7: DD 7E 32      ld   a,(ix+$1a)
3BCA: A7            and  a
3BCB: 20 8C         jr   nz,$3BD9
3BCD: DD 36 28 00   ld   (ix+x_pos),$00
3BD1: DD 36 81 00   ld   (ix+y_pos),$00
3BD5: CD CE 9B      call display_snobee_sprite_33CE
3BD8: C9            ret
3BD9: CD EE BB      call $3BEE
3BDC: CD A1 3C      call $3C09
3BDF: DD 34 28      inc  (ix+x_pos)
3BE2: DD 34 81      inc  (ix+y_pos)
3BE5: CD F8 B6      call get_div8_ix_coords_3E78
3BE8: 3E 3B         ld   a,$13
3BEA: CD 4C CB      call set_2x2_tile_color_4BC4
3BED: C9            ret
3BEE: DD 7E 1A      ld   a,(ix+$1a)
3BF1: 3D            dec  a
3BF2: 87            add  a,a
3BF3: 16 00         ld   d,$00
3BF5: 5F            ld   e,a
3BF6: 21 81 3C      ld   hl,snobee_squash_score_table_3C01
3BF9: 19            add  hl,de
3BFA: 5E            ld   e,(hl)
3BFB: 23            inc  hl
3BFC: 56            ld   d,(hl)
3BFD: CD AF A8      call add_to_current_player_score_28AF
3C00: C9            ret

; 400,1600,3200,6400

snobee_squash_score_table_3C01:
  28 00 A0 00 40 01 80 02

3C09: DD 7E 92      ld   a,(ix+$1a)
3C0C: E6 8F         and  $07
3C0E: 3D            dec  a
3C0F: 16 00         ld   d,$00
3C11: 5F            ld   e,a
3C12: 21 1E 3C      ld   hl,table_3C1E
3C15: 19            add  hl,de
3C16: 7E            ld   a,(hl)
3C17: DD 77 8A      ld   (ix+animation_frame),a
3C1A: CD 23 39      call set_character_sprite_code_and_color_39AB
3C1D: C9            ret

table_3C1E:
  84 88 8C 90


3C22: 3A 0C A0      ld   a,(counter_lsb_8824) ;  count mask
3C25: A7            and  a
3C26: C0            ret  nz
3C27: DD 7E 82      ld   a,(ix+stunned_push_block_counter)
3C2A: 3D            dec  a
3C2B: 28 04         jr   z,$3C31
3C2D: DD 77 82      ld   (ix+stunned_push_block_counter),a
3C30: C9            ret
3C31: DD 36 09 00   ld   (ix+$09),$00
3C35: DD 34 1F      inc  (ix+char_state)
3C38: CD 78 3E      call get_div8_ix_coords_3E78
3C3B: CD D8 4B      call set_2x2_tile_color_09_4BD8
3C3E: 21 10 A5      ld   hl,remaining_alive_snobees_8D98
3C41: 35            dec  (hl)
3C42: 21 F7 A5      ld   hl,timer_16_bit_8DDE+1
3C45: 36 80         ld   (hl),$80
3C47: 2B            dec  hl
3C48: 36 80         ld   (hl),$08
3C4A: C9            ret
3C4B: 21 F5 A5      ld   hl,current_nb_eggs_to_hatch_8DDD
3C4E: 7E            ld   a,(hl)
3C4F: A7            and  a
3C50: 20 1A         jr   nz,$3C6C
3C52: DD 36 1F 88   ld   (ix+char_state),$00
3C56: CD 07 28      call get_level_number_288F
3C59: 3D            dec  a
3C5A: 0F            rrca
3C5B: 0F            rrca
3C5C: E6 8B         and  $03
3C5E: C6 8C         add  a,$04
3C60: 47            ld   b,a
3C61: 3A B0 A5      ld   a,(remaining_alive_snobees_8D98)
3C64: B8            cp   b
3C65: D0            ret  nc
3C66: 3E 8C         ld   a,$04
3C68: 32 33 A4      ld   (game_phase_8CBB),a
3C6B: C9            ret
	
3C6C: 35            dec  (hl)
3C6D: 21 C2 A5      ld   hl,egg_location_table_8DC2
3C70: 4E            ld   c,(hl)
3C71: 23            inc  hl
3C72: 46            ld   b,(hl)
3C73: 23            inc  hl
3C74: 78            ld   a,b
3C75: 81            add  a,c
3C76: 28 70         jr   z,$3C70
3C78: C5            push bc
3C79: CD C6 CA      call find_breaking_block_free_slot_42c6
3C7C: C1            pop  bc
3C7D: CD DE 3C      call $3CDE
3C80: DD 71 00      ld   (ix+x_pos),c
3C83: DD 70 89      ld   (ix+y_pos),b
3C86: CD E6 1B      call display_snobee_sprite_33CE
3C89: DD 36 8A F4   ld   (ix+animation_frame),$DC
3C8D: CD A7 00      call get_level_number_288F
3C90: 3D            dec  a
3C91: E6 07         and  $07
3C93: 3C            inc  a
3C94: DD 77 03      ld   (ix+char_color),a ;  sets color
3C97: CD AB 39      call set_character_sprite_code_and_color_39AB
3C9A: DD 7E 1C      ld   a,(ix+move_period)
3C9D: DD 77 8E      ld   (ix+instant_move_period),a
3CA0: DD 36 21 88   ld   (ix+$09),$00
3CA4: DD 36 23 8E   ld   (ix+intermission_dance_push_anim_counter),$06
3CA8: CD 54 2D      call get_random_value_2D7C
3CAB: E6 07         and  $07
3CAD: 3C            inc  a
	;; called when egg hatch
3CAE: DD 77 1E      ld   (ix+ai_mode),a ; sets A.I. mode at random from 1 to 8
3CB1: DD 36 1B 14   ld   (ix+$1b),$14
3CB5: DD 34 1F      inc  (ix+char_state)
3CB8: 06 8B         ld   b,$03
3CBA: CD C7 18      call update_sound_18c7
3CBD: 21 1E 05      ld   hl,snobee_1_struct_8D00+$1E	; A.I. mode
3CC0: 11 08 00      ld   de,$0020
3CC3: 06 04         ld   b,$04
3CC5: 3E 02         ld   a,$02
3CC7: BE            cp   (hl)
3CC8: C8            ret  z
	;; no snobee is in "block breaking mode"
3CC9: 19            add  hl,de
3CCA: 10 73         djnz $3CC7
3CCC: 21 97 A5      ld   hl,snobee_1_struct_8D00+$1F	; state
3CCF: 06 04         ld   b,$04
3CD1: 3E 02         ld   a,$02
3CD3: BE            cp   (hl)
3CD4: 28 8C         jr   z,$3CDA
3CD6: 19            add  hl,de
3CD7: 10 FA         djnz $3CD3
3CD9: C9            ret
3CDA: 2B            dec  hl
	;; change first alive snobee A.I. mode to "block breaking mode"
	;; when a new egg has hatched
3CDB: 36 02         ld   (hl),$02 ;  changes A.I. mode to block breaking mode
3CDD: C9            ret
3CDE: 78            ld   a,b
3CDF: 07            rlca
3CE0: 07            rlca
3CE1: 07            rlca
3CE2: 47            ld   b,a
3CE3: 79            ld   a,c
3CE4: C6 8A         add  a,$02
3CE6: 07            rlca
3CE7: 07            rlca
3CE8: 07            rlca
3CE9: 4F            ld   c,a
3CEA: C9            ret
3CEB: DD CB 81 46   bit  0,(ix+$09)
3CEF: CC F6 3C      call z,$3CF6
3CF2: CD 77 3C      call $3CFF
3CF5: C9            ret
3CF6: DD 36 0A 8C   ld   (ix+stunned_push_block_counter),$04
3CFA: DD 36 09 0F   ld   (ix+$09),$0F
3CFE: C9            ret
3CFF: 3A A4 00      ld   a,(counter_lsb_8824)
3D02: E6 B7         and  $3F
3D04: C0            ret  nz
	;; counter 1 out of 64 xxx
3D05: DD 7E 22      ld   a,(ix+stunned_push_block_counter)
3D08: 3D            dec  a
3D09: 28 84         jr   z,$3D0F
3D0B: DD 77 22      ld   (ix+stunned_push_block_counter),a
3D0E: C9            ret
3D0F: DD 7E A3      ld   a,(ix+intermission_dance_push_anim_counter)
3D12: 3D            dec  a
3D13: 28 13         jr   z,$3D28
3D15: DD 77 A3      ld   (ix+intermission_dance_push_anim_counter),a
3D18: DD 36 09 80   ld   (ix+$09),$00
3D1C: DD 7E 02      ld   a,(ix+animation_frame)
3D1F: D6 84         sub  $04
3D21: DD 77 2A      ld   (ix+animation_frame),a
3D24: CD 83 B9      call set_character_sprite_code_and_color_39AB
3D27: C9            ret
3D28: DD 34 9F      inc  (ix+char_state)
3D2B: C9            ret
3D2C: DD CB 89 6E   bit  0,(ix+$09)
3D30: CC 5E 3C      call z,$3CF6
3D33: CD 37 BD      call $3D37
3D36: C9            ret
3D37: 3A 24 20      ld   a,(counter_lsb_8824)
3D3A: E6 BF         and  $3F
3D3C: C0            ret  nz
	;; counter 1 out of 64 xxx
3D3D: DD 7E A2      ld   a,(ix+stunned_push_block_counter)
3D40: 3D            dec  a
3D41: 28 84         jr   z,$3D47
3D43: DD 77 22      ld   (ix+stunned_push_block_counter),a
3D46: C9            ret
3D47: DD 7E 23      ld   a,(ix+intermission_dance_push_anim_counter)
3D4A: 3D            dec  a
3D4B: 28 93         jr   z,$3D60
3D4D: DD 77 23      ld   (ix+intermission_dance_push_anim_counter),a
3D50: DD 36 09 80   ld   (ix+$09),$00
3D54: DD 7E 02      ld   a,(ix+animation_frame)
3D57: C6 04         add  a,$04
3D59: DD 77 82      ld   (ix+animation_frame),a
3D5C: CD 2B 39      call set_character_sprite_code_and_color_39AB
3D5F: C9            ret
3D60: DD 34 9F      inc  (ix+char_state)
3D63: 21 18 05      ld   hl,remaining_alive_snobees_8D98
3D66: 35            dec  (hl)
3D67: DD 36 28 80   ld   (ix+x_pos),$00
3D6B: DD 36 29 80   ld   (ix+y_pos),$00
3D6F: CD CE 9B      call display_snobee_sprite_33CE
3D72: C9            ret
	
pengo_moves_3D73:
3D73: DD 21 00 8D	ld   ix,pengo_struct_8D80
3D77: DD 7E B7      ld   a,(ix+char_state)
3D7A: 11 00 3D      ld   de,table_3D80
3D7D: C3 8F AD      jp   indirect_jump_2D8F

table_3D80:
	dc.w	do_nothing_3358
	dc.w	pengo_not_moving_3D90
	dc.w	pengo_nominal_move_3DBF
	dc.w	pengo_pushes_block_3FE9
	dc.w	pengo_breaks_block_4053
	dc.w	pengo_shakes_wall_409A
	dc.w	pengo_dies_3FB3
	dc.w	reset_state_to_default_3368
	
pengo_not_moving_3D90:
3D90: CD E2 39      call animate_pengo_39A4
3D93: DD CB A1 46   bit  0,(ix+$09)
3D97: CC 9E BD      call z,$3D9E
3D9A: CD 0F 3D      call $3DA7
3D9D: C9            ret
3D9E: DD 36 8A 2A   ld   (ix+stunned_push_block_counter),$02
3DA2: DD 36 89 27   ld   (ix+$09),$0F
3DA6: C9            ret
3DA7: 3A A4 00      ld   a,(counter_lsb_8824) ;  count mask
3DAA: A7            and  a
3DAB: C0            ret  nz
3DAC: DD 7E 8A      ld   a,(ix+stunned_push_block_counter)
3DAF: 3D            dec  a
3DB0: 28 84         jr   z,$3DB6
3DB2: DD 77 0A      ld   (ix+stunned_push_block_counter),a
3DB5: C9            ret
3DB6: DD 36 09 80   ld   (ix+$09),$00
3DBA: DD 36 1F 82   ld   (ix+char_state),$02
3DBE: C9            ret
	
pengo_nominal_move_3DBF:
3DBF: DD 21 08 0D   ld   ix,pengo_struct_8D80
3DC3: CD CA B1      call animate_pengo_39A4
3DC6: DD 34 87      inc  (ix+current_period_counter)
3DC9: DD 7E 2F      ld   a,(ix+current_period_counter)
3DCC: DD BE 86      cp   (ix+instant_move_period)
3DCF: D8            ret  c
	;; can move
3DD0: DD 36 07 80   ld   (ix+current_period_counter),$00
3DD4: CD 86 3E      call $3E06

move_character_according_to_direction_3DD7:
3DD7: 21 E4 BD      ld   hl,l_3de4
3DDA: E5            push hl
3DDB: DD 7E 84      ld   a,(ix+facing_direction)
3DDE: 11 6E BD      ld   de,jump_table_3DEE
3DE1: C3 0F A5      jp   indirect_jump_2D8F

l_3de4:
3DE4: DD 7E 85      ld   a,(ix+char_id)
3DE7: DD E5         push ix
3DE9: E1            pop  hl
3DEA: CD 7C B1      call set_character_sprite_position_3154
3DED: C9            ret

jump_table_3DEE:
	dc.w	pengo_goes_up_3DF6 
	dc.w	pengo_goes_down_3DFA
	dc.w	pengo_goes_left_3DFE 
	dc.w	pengo_goes_right_3E02

	;; movement table
	;; pengo go up
pengo_goes_up_3DF6:
3DF6: DD 35 01      dec  (ix+y_pos)
3DF9: C9            ret
;; pengo goes down
pengo_goes_down_3DFA:
3DFA: DD 34 01      inc  (ix+y_pos)
3DFD: C9            ret
;; pengo goes left
pengo_goes_left_3DFE:
3DFE: DD 35 00      dec  (ix+x_pos)
3E01: C9            ret
	;; pengo goes right
pengo_goes_right_3E02:
3E02: DD 34 00      inc  (ix+x_pos)
3E05: C9            ret
	
3E06: DD 7E 00      ld   a,(ix+x_pos)
3E09: E6 27         and  $0F
3E0B: FE 20         cp   $08
3E0D: 20 07         jr   nz,$3E16
3E0F: DD 7E 89      ld   a,(ix+y_pos)
3E12: E6 0F         and  $0F
3E14: 28 8C         jr   z,$3E1A
3E16: CD A6 3E      call $3EA6
3E19: C9            ret
3E1A: CD F4 3E      call $3EF4
3E1D: CD 80 3F      call $3F80
3E20: DD CB 20 CE   bit  0,(ix+$08)
3E24: CA D4 3E      jp   z,$3E5C
3E27: CD 78 16      call get_div8_ix_coords_3E78
3E2A: DD 7E 04      ld   a,(ix+facing_direction)
3E2D: 11 1E 16      ld   de,table_3E36
3E30: CD 07 2D      call indirect_jump_2D8F
3E33: C8 			ret  z   	; back to 3DE4                                           
3E34  E1			pop  hl     ; exit from function                                        
3E35  C9			ret                                                                                    CD 44 16

table_3E36:
  .word	pengo_moves_up_3E3E  
  .word	pengo_moves_down_3E5E  
  .word	pengo_moves_left_3E67  
  .word	pengo_moves_right_3E6F 

pengo_moves_up_3E3E:
3E3E: 05			dec  b                                              
3E3F: CD 44 16      call pengo_moves_xxx_3E44
3E42: C0            ret  nz
3E43: 0C            inc  c
pengo_moves_xxx_3E44:
3E44: CD 47 29      call convert_coords_to_screen_address_296F
3E47: 7E            ld   a,(hl)
3E48: FE 08         cp   $20
3E4A: C8            ret  z
3E4B: FE 80         cp   $80
3E4D: D8            ret  c
3E4E: FE B8         cp   $90
3E50: 38 08         jr   c,$3E5A
3E52: FE 10         cp   $98
3E54: D8            ret  c
3E55: FE 9C         cp   $9C
3E57: 38 01         jr   c,$3E5A
3E59: C9            ret
3E5A: BF            cp   a		; set Z flag
3E5B: C9            ret
; give up current call from 3D73 (hl doesn't matter)
; and return to 0A06
3E5C: E1            pop  hl
3E5D: C9            ret

pengo_moves_down_3E5E:
3E5E: 04            inc  b
3E5F: 04            inc  b
3E60: CD CC 3E      call pengo_moves_xxx_3E44
3E63: C0            ret  nz
3E64: 0C            inc  c
3E65: 18 F5         jr   pengo_moves_xxx_3E44

pengo_moves_left_3E67:
3E67: 0D            dec  c
3E68: CD CC 3E      call pengo_moves_xxx_3E44
3E6B: C0            ret  nz
3E6C: 04            inc  b
3E6D: 18 D5         jr   pengo_moves_xxx_3E44

pengo_moves_right_3E6F:
3E6F: 0C            inc  c
3E70: 0C            inc  c
3E71: CD 44 3E      call pengo_moves_xxx_3E44
3E74: C0            ret  nz
3E75: 04            inc  b
3E76: 18 44         jr   pengo_moves_xxx_3E44
	
get_div8_ix_coords_3E78:
3E78: DD 7E 00      ld   a,(ix+x_pos)
3E7B: CB 3F         srl  a
3E7D: CB 3F         srl  a
3E7F: CB 3F         srl  a
3E81: D6 02         sub  $02
3E83: 4F            ld   c,a
3E84: DD 7E 01      ld   a,(ix+y_pos)
3E87: CB 3F         srl  a
3E89: CB 3F         srl  a
3E8B: CB 3F         srl  a
3E8D: 47            ld   b,a
3E8E: C9            ret
	
get_div8_iy_coords_3E8F:
3E8F: FD 7E 88      ld   a,(iy+x_pos)
3E92: CB 3F         srl  a
3E94: CB 3F         srl  a
3E96: CB 3F         srl  a
3E98: D6 8A         sub  $02
3E9A: 4F            ld   c,a
3E9B: FD 7E 89      ld   a,(iy+y_pos)
3E9E: CB 3F         srl  a
3EA0: CB 3F         srl  a
3EA2: CB 3F         srl  a
3EA4: 47            ld   b,a
3EA5: C9            ret
	
; < ix: pengo structure
3EA6: 3A 91 A0      ld   a,(currently_playing_8819)
3EA9: A7            and  a
3EAA: C8            ret  z
3EAB: CD FB 02      call read_player_inputs_2AFB
3EAE: 2F            cpl			; negate bits
3EAF: E6 0F         and  $0F	; masks directions
3EB1: C8            ret  z		; returns if not moving
; check if one of the 4 bits are set
3EB2: 06 8C         ld   b,$04	; do it 4 times at most
3EB4: 0F            rrca		; shift right with carry
3EB5: 38 03         jr   c,$3EBA	; if bit is set, exit loop
3EB7: 10 FB         djnz $3EB4
3EB9: C9            ret				; no direction is pressed, end
; b contains the bit number/direction which is active
; B=2: left
; B=3: down
3EBA: 3E 8C         ld   a,$04
3EBC: 90            sub  b			; A = 4-first bit set
3EBD: DD BE 8C      cp   (ix+facing_direction)	; compare to facing direction???
3EC0: C8            ret  z			; same facing direction: return
3EC1: DD 7E 88      ld   a,(ix+x_pos)	; get X
3EC4: E6 87         and  $0F		; masks (modulo 16)
3EC6: FE 80         cp   $08		; is X aligned on 8?
3EC8: 28 9A         jr   z,$3EDC
3ECA: FE 8C         cp   $04
3ECC: D8            ret  c			; returns if X%16 < 4
3ECD: FE 24         cp   $0C
3ECF: D0            ret  nc			; returns if X%16 >= 12
3ED0: 06 8B         ld   b,$03
3ED2: FE 08         cp   $08
3ED4: 38 8A         jr   c,$3ED8
3ED6: 06 8A         ld   b,$02
3ED8: DD 70 04      ld   (ix+facing_direction),b		; update facing direction
3EDB: C9            ret
3EDC: DD 7E 01      ld   a,(ix+y_pos)
3EDF: E6 27         and  $0F
3EE1: FE 04         cp   $04
3EE3: 38 03         jr   c,$3EE8
3EE5: FE 24         cp   $0C
3EE7: D8            ret  c
3EE8: 06 89         ld   b,$01
3EEA: FE 80         cp   $08
3EEC: 30 8A         jr   nc,$3EF0
3EEE: 06 88         ld   b,$00
3EF0: DD 70 04      ld   (ix+facing_direction),b
3EF3: C9            ret
3EF4: 3A 19 88      ld   a,(currently_playing_8819)
3EF7: A7            and  a
3EF8: 28 2D         jr   z,$3F27
3EFA: AF            xor  a
3EFB: 32 F4 04      ld   (pengo_moving_direction_8CF4),a
3EFE: DD 36 88 28   ld   (ix+$08),$00
3F02: CD D3 AA      call read_player_inputs_2AFB
3F05: 2F            cpl
3F06: E6 27         and  $0F
3F08: C8            ret  z
3F09: DD 36 20 7F   ld   (ix+$08),$FF
3F0D: DD 46 2C      ld   b,(ix+facing_direction)
3F10: DD 70 10      ld   (ix+path_address_pointer_or_misc_flags),b
3F13: 06 04         ld   b,$04
3F15: 0F            rrca
3F16: 38 83         jr   c,$3F1B
3F18: 10 7B         djnz $3F15
3F1A: C9            ret
3F1B: 3E 04         ld   a,$04
3F1D: 90            sub  b
3F1E: DD 77 84      ld   (ix+facing_direction),a
3F21: CB DF         set  3,a
3F23: 32 74 04      ld   (pengo_moving_direction_8CF4),a
3F26: C9            ret
; game in demo mode (no human player)
3F27: 2A 72 04      ld   hl,(demo_move_table_pointer_8CF2)
3F2A: 11 DD 0C      ld   de,demo_mode_var_8CF5
3F2D: EB            ex   de,hl
3F2E: 1A            ld   a,(de)
3F2F: CB 46         bit  0,(hl)
3F31: 28 09         jr   z,$3F3C
3F33: 13            inc  de
; update pointer
3F34: ED 53 F2 24   ld   (demo_move_table_pointer_8CF2),de
3F38: 0F            rrca
3F39: 0F            rrca
3F3A: 0F            rrca
3F3B: 0F            rrca
3F3C: 34            inc  (hl)
3F3D: EB            ex   de,hl
3F3E: CB 57         bit  2,a
3F40: F5            push af
3F41: C4 1B B7      call nz,$3F9B
3F44: F1            pop  af
3F45: DD 36 20 80   ld   (ix+$08),$00
3F49: CB 5F         bit  3,a
3F4B: C8            ret  z
3F4C: E6 2B         and  $03
3F4E: DD 77 04      ld   (ix+$04),a
3F51: DD 36 A0 FF   ld   (ix+$08),$FF
3F55: C9            ret
; seems not reached
3F56: CD 7A 3E      call $3EFA
3F59: CD 85 BF      call $3F85
3F5C: 2A 5A 8C      ld   hl,(demo_move_table_pointer_8CF2)
3F5F: 11 75 04      ld   de,demo_mode_var_8CF5
3F62: EB            ex   de,hl
3F63: 3A 74 04      ld   a,(pengo_moving_direction_8CF4)
3F66: CB 46         bit  0,(hl)
3F68: 28 3B         jr   z,$3F7D
3F6A: 0F            rrca
3F6B: 0F            rrca
3F6C: 0F            rrca
3F6D: 0F            rrca
3F6E: E6 D8         and  $F0
3F70: 47            ld   b,a
3F71: 1A            ld   a,(de)
3F72: E6 A7         and  $0F
3F74: B0            or   b
3F75: 12            ld   (de),a
3F76: 13            inc  de
3F77: ED 53 5A 8C   ld   (demo_move_table_pointer_8CF2),de
3F7B: 34            inc  (hl)
3F7C: C9            ret
3F7D: 12            ld   (de),a
3F7E: 34            inc  (hl)
3F7F: C9            ret

3F80: 3A 31 08      ld   a,(currently_playing_8819)
3F83: A7            and  a
3F84: C8            ret  z
3F85: CD 7B A2      call read_player_inputs_2AFB
3F88: 2F            cpl
3F89: CB 7F         bit  7,a
3F8B: 28 A1         jr   z,$3FAE
3F8D: DD 7E 27      ld   a,(ix+$0f)
3F90: 3C            inc  a
3F91: C8            ret  z
3F92: DD 36 0F 7F   ld   (ix+$0f),$FF
3F96: 21 5C 8C      ld   hl,pengo_moving_direction_8CF4
3F99: CB D6         set  2,(hl)
3F9B: 3A BF 25      ld   a,(block_moving_flag_8DBF)
3F9E: A7            and  a
3F9F: C0            ret  nz
3FA0: 3E 29         ld   a,$01
3FA2: 32 97 0D      ld   (block_moving_flag_8DBF),a
3FA5: DD 36 37 83   ld   (ix+char_state),$03
3FA9: DD 36 23 80   ld   (ix+intermission_dance_push_anim_counter),$00
3FAD: C9            ret
3FAE: DD 36 0F 80   ld   (ix+$0f),$00
3FB2: C9            ret

pengo_dies_3FB3:
3FB3: 3E 1E         ld   a,$1E
3FB5: CD D1 A8      call delay_28D1
3FB8: CD 72 3F      call hide_snobee_sprites_3FDA
3FBB: 06 0C         ld   b,$0C
3FBD: 0E 1A         ld   c,$1A
3FBF: C5            push bc
3FC0: CB 40         bit  0,b
3FC2: 28 29         jr   z,$3FC5
3FC4: 0C            inc  c
3FC5: 79            ld   a,c
3FC6: 07            rlca
3FC7: 07            rlca
3FC8: DD 77 82      ld   (ix+animation_frame),a
3FCB: CD 2B B1      call set_character_sprite_code_and_color_39AB
3FCE: 3E 20         ld   a,$08
3FD0: CD 51 28      call delay_28D1
3FD3: C1            pop  bc
3FD4: 10 69         djnz $3FBF
3FD6: DD 34 1F      inc  (ix+char_state)
3FD9: C9            ret

hide_snobee_sprites_3FDA: 
3DFA: AF            xor  a
; set sprite colors to zero for snobeeds
3FDB: 21 F3 27      ld   hl,sprites_8FF2+1
3FDE: 11 82 80      ld   de,$0002
3FE1: 77            ld   (hl),a
3FE2: 19            add  hl,de
3FE3: 77            ld   (hl),a
3FE4: 19            add  hl,de
3FE5: 77            ld   (hl),a
3FE6: 19            add  hl,de
3FE7: 77            ld   (hl),a
3FE8: C9            ret

pengo_pushes_block_3FE9:
; 0->3: 3 max push pos
3FE9: DD 7E 23      ld   a,(ix+intermission_dance_push_anim_counter)
3FEC: 11 DA BF      ld   de,table_3FF2
3FEF: C3 8F AD      jp   indirect_jump_2D8F

table_3FF2:     
	 dc.w	block_pushed_3FFA  
	 dc.w	block_pushed_start_404E 
	 dc.w	block_pushed_401F  
	 dc.w	block_pushed_start_404E 

block_pushed_3FFA:
3FFA: 06 80         ld   b,$00
3FFC: DD 7E 04      ld   a,(ix+facing_direction)
3FFF: FE 2B         cp   $03
4001: 20 29         jr   nz,$4004
4003: 3D            dec  a
4004: 87            add  a,a
4005: C6 2E         add  a,$06
4007: 80            add  a,b
4008: 07            rlca
4009: 07            rlca
400A: DD 77 2A      ld   (ix+animation_frame),a
400D: DD 7E A4      ld   a,(ix+facing_direction)
4010: FE 23         cp   $03
4012: 20 24         jr   nz,$4018
4014: DD CB 02 EE   set  1,(ix+animation_frame)
4018: CD 8B 39      call set_character_sprite_code_and_color_39AB
401B: DD 34 A3      inc  (ix+intermission_dance_push_anim_counter)
401E: C9            ret

block_pushed_401F:
401F: 06 29         ld   b,$01
4021: 18 D9         jr   $3FFC

block_pushed_start_404E:
4023: DD CB 81 6E   bit  0,(ix+$09)
4027: CC A6 E0      call z,$402E
402A: CD 37 68      call $4037
402D: C9            ret

402E: DD 36 0A 21   ld   (ix+stunned_push_block_counter),$01
4032: DD 36 09 A7   ld   (ix+$09),$0F
4036: C9            ret
4037: 3A 24 A8      ld   a,(counter_lsb_8824) ; count mask
403A: A7            and  a
403B: C0            ret  nz
403C: DD 7E 0A      ld   a,(ix+stunned_push_block_counter)
403F: 3D            dec  a
4040: 28 A4         jr   z,$4046
4042: DD 77 AA      ld   (ix+stunned_push_block_counter),a
4045: C9            ret
4046: DD 36 A9 A0   ld   (ix+$09),$00
404A: DD 34 AB      inc  (ix+intermission_dance_push_anim_counter)
404D: C9            ret

block_pushed_start_404E:
404E: DD 36 1F 22   ld   (ix+char_state),$02
4052: C9            ret

pengo_breaks_block_4053:
4053: DD 7E A3      ld   a,(ix+intermission_dance_push_anim_counter)
4056: 11 F4 40      ld   de,table_405C
4059: C3 8F 85      jp   indirect_jump_2D8F
table_405C:
	dc.W	block_pushed_3FFA  
	dc.W	block_broken_406E  
	dc.W	block_pushed_401F  
	dc.W	block_broken_406E  
	dc.W	block_pushed_3FFA  
	dc.W	block_broken_406E  
	dc.W	block_pushed_401F  
	dc.W	block_broken_406E 
	dc.W	block_pushed_start_404E  

block_broken_406E:
406E: DD CB 09 66   bit  0,(ix+$09)
4072: CC D1 40      call z,$4079
4075: CD 82 60      call $4082
4078: C9            ret
4079: DD 36 A2 02   ld   (ix+stunned_push_block_counter),$02
407D: DD 36 A1 AF   ld   (ix+$09),$0F
4081: C9            ret
4082: 3A 24 88      ld   a,(counter_lsb_8824)
4085: E6 BF         and  $1F
4087: C0            ret  nz
	;; counter 1 out of 32 pengo breaks block facing left (also in "push start" screen)
4088: DD 7E AA      ld   a,(ix+stunned_push_block_counter)
408B: 3D            dec  a
408C: 28 A4         jr   z,$4092
408E: DD 77 0A      ld   (ix+stunned_push_block_counter),a
4091: C9            ret

4092: DD 36 09 20   ld   (ix+$09),$00
4096: DD 34 0B      inc  (ix+intermission_dance_push_anim_counter)
4099: C9            ret

pengo_shakes_wall_409A:
409A: DD 7E 0B      ld   a,(ix+intermission_dance_push_anim_counter)
409D: 11 A3 60      ld   de,jump_table_40A3
40A0: C3 8F A5      jp   indirect_jump_2D8F
 
jump_table_40A3:
	dc.w	wall_push_40B5 
	dc.w	block_broken_406E 
	dc.w	wall_push_40BC 
	dc.w	block_broken_406E 
	dc.w	wall_push_40B5 
	dc.w	block_broken_406E 
	dc.w	wall_push_40BC 
	dc.w	block_broken_406E 
	dc.w	wall_push_40C6 

wall_push_40B5:
40B5: CD D2 60      call $40D2
40B8: CD DA 3F      call block_pushed_3FFA
40BB: C9            ret

40BC: CD EE 40      call $40CE
40BF: CD BF E0      call block_pushed_401F
40C2: CD 67 69      call pengo_is_moving_a_wall_4167
40C5: C9            ret

40C6: CD 42 A6      call draw_borders_2E6A
40C9: DD 36 97 2A   ld   (ix+char_state),$02
40CD: C9            ret

40CE: 06 A1         ld   b,$01
40D0: 18 22         jr   $40D4
40D2: 06 20         ld   b,$00
40D4: DD 7E 04      ld   a,(ix+facing_direction)
40D7: 87            add  a,a
40D8: 80            add  a,b
40D9: 07            rlca
40DA: 07            rlca
40DB: 07            rlca
40DC: 16 20         ld   d,$00
40DE: 5F            ld   e,a
40DF: 21 27 E1      ld   hl,table_4127
40E2: 19            add  hl,de
40E3: 4E            ld   c,(hl)
40E4: 23            inc  hl
40E5: 46            ld   b,(hl)
40E6: 23            inc  hl
40E7: 56            ld   d,(hl)
40E8: 23            inc  hl
40E9: 5E            ld   e,(hl)
40EA: 23            inc  hl
40EB: 7E            ld   a,(hl)
40EC: DD 77 38      ld   (ix+path_address_pointer_or_misc_flags),a
40EF: D5            push de
40F0: CD C7 29      call convert_coords_to_screen_address_296F
40F3: D1            pop  de
40F4: D5            push de
40F5: DD CB 30 56   bit  2,(ix+path_address_pointer_or_misc_flags)
40F9: 28 01         jr   z,$40FC
40FB: 1C            inc  e
40FC: 73            ld   (hl),e
40FD: D1            pop  de
40FE: CD B0 E9      call $4118
4101: D5            push de
4102: CD EF 09      call convert_coords_to_screen_address_296F
4105: D1            pop  de
4106: D5            push de
4107: DD CB 90 FE   bit  2,(ix+path_address_pointer_or_misc_flags)
410B: 20 A9         jr   nz,$410E
410D: 1C            inc  e
410E: 73            ld   (hl),e
410F: D1            pop  de
4110: CD 90 41      call $4118
4113: 15            dec  d
4114: 15            dec  d
4115: 20 D8         jr   nz,$40EF
4117: C9            ret

4118: DD CB 10 E6   bit  0,(ix+path_address_pointer_or_misc_flags)
411C: 28 A1         jr   z,$411F
411E: 0C            inc  c
411F: DD CB 90 CE   bit  1,(ix+path_address_pointer_or_misc_flags)
4123: 28 A9         jr   z,$4126
4125: 04            inc  b
4126: C9            ret

table_4127:
  00 01 1C 14 01 00 00 00 00 01 1C 14 05 00 00 00
     4137  00 20 1C 14 01 00 00 00 00 20 1C 14 05 00 00 00
     4147  00 01 20 12 02 00 00 00 00 01 20 12 06 00 00 00
     4157  1B 01 20 12 02 00 00 00 1B 01 20 12 06 00 00 00

	;; perform those tests only when pengo moves the edge
pengo_is_moving_a_wall_4167:
4167: DD 21 80 85   ld   ix,snobee_1_struct_8D00
416B: CD A4 C1      call snobee_on_waving_edge_4184
416E: DD 21 20 8D   ld   ix,snobee_2_struct_8D20
4172: CD AC 41      call snobee_on_waving_edge_4184
4175: DD 21 E0 8D   ld   ix,snobee_3_struct_8D40
4179: CD 84 E1      call snobee_on_waving_edge_4184
417C: DD 21 60 8D   ld   ix,snobee_4_struct_8D60
4180: CD 04 E9      call snobee_on_waving_edge_4184
4183: C9            ret
	
snobee_on_waving_edge_4184: 
4184: DD 4E A8      ld   c,(ix+x_pos)
4187: DD 46 81      ld   b,(ix+y_pos)
418A: DD 7E 9F      ld   a,(ix+char_state)
418D: A7            and  a
418E: C8            ret  z
418F: FE 02         cp   $02
4191: C0            ret  nz
4192: 3A AC 8D      ld   a,(unknown_8D84)
4195: 11 9B E1      ld   de,table_419B
4198: C3 8F 2D      jp   indirect_jump_2D8F

table_419B:
     dc.w	$41A3 
	 dc.w	$41AC 
	 dc.w	$41B2 
	 dc.w	$41B8 

41A3: 3E B8         ld   a,$10
41A5: B8            cp   b
41A6: C0            ret  nz
41A7: DD 36 B7 AB   ld   (ix+char_state),$03
41AB: C9            ret

41AC: 3E 58         ld   a,$F0
41AE: B8            cp   b
41AF: C0            ret  nz
41B0: 18 7D         jr   $41A7

41B2: 3E 90         ld   a,$18
41B4: B9            cp   c
41B5: C0            ret  nz
41B6: 18 4F         jr   $41A7

41B8: 3E D8         ld   a,$D8
41BA: B9            cp   c
41BB: C0            ret  nz
41BC: 18 49         jr   $41A7
	
pengo_block_push_41BE:
41BE: DD 21 20 25   ld   ix,moving_block_struct_8DA0
41C2: 11 63 E9      ld   de,table_41CB
41C5: DD 7E B7      ld   a,(ix+char_state)
41C8: C3 27 0D      jp   indirect_jump_2D8F
table_41CB:
	dc.w	do_nothing_3358 
	dc.w	$41D9 
	dc.w	$43BD 
	dc.w	$44E9 
	dc.w	$4529 
	dc.w	disable_snobee_3359 
	dc.w	reset_state_to_default_3368 
 

41D9: DD E5         push ix
41DB: FD E1         pop  iy
41DD: DD 21 A8 85   ld   ix,pengo_struct_8D80
41E1: CD 58 BE      call get_div8_ix_coords_3E78
41E4: FD 36 98 80   ld   (iy+$18),$00
41E8: FD 36 99 80   ld   (iy+$19),$00
41EC: DD 7E AC      ld   a,(ix+facing_direction)
41EF: 11 1A E3      ld   de,table_431A
41F2: CD 8F 2D      call indirect_jump_2D8F
41F5: 20 75         jr   nz,$426C
41F7: CD 78 E3      call move_snobee_current_direction_4378
41FA: DD 7E 04      ld   a,(ix+facing_direction)
41FD: 11 A1 E3      ld   de,is_grid_free_jump_table_43A1
4200: CD 8F A5      call indirect_jump_2D8F
4203: 28 AA         jr   z,$420F
4205: FE 70         cp   $70
4207: DA 1C E2      jp   c,$4294
420A: FE A8         cp   $80
420C: D2 BC 6A      jp   nc,$4294
420F: CD 78 63      call move_snobee_current_direction_4378
4212: CD 89 43      call clear_2x2_tiles_at_current_pos_43A9
4215: FD CB B0 66   bit  4,(iy+$18)
4219: C4 F9 62      call nz,$42F9
421C: CD F6 42      call $425E
421F: CD F0 E3      call move_snobee_current_direction_4378
4222: 78            ld   a,b
4223: 07            rlca
4224: 07            rlca
4225: 07            rlca
4226: 47            ld   b,a
4227: 79            ld   a,c
4228: C6 A2         add  a,$02
422A: 07            rlca
422B: 07            rlca
422C: 07            rlca
422D: 4F            ld   c,a
422E: DD 7E 04      ld   a,(ix+facing_direction)
4231: FD E5         push iy
4233: DD E1         pop  ix
4235: DD 77 24      ld   (ix+facing_direction),a
4238: DD 71 00      ld   (ix+x_pos),c
423B: DD 70 21      ld   (ix+y_pos),b
423E: CD FB 6B      call $43DB
4241: DD 36 87 28   ld   (ix+$0f),$00
4245: 3E 70         ld   a,$70
4247: DD CB 90 66   bit  4,(ix+$18)
424B: 28 2A         jr   z,$424F
424D: 3E 74         ld   a,$74
424F: DD 77 22      ld   (ix+animation_frame),a
4252: CD 8B 39      call set_character_sprite_code_and_color_39AB
4255: DD 34 B7      inc  (ix+char_state)
4258: 06 25         ld   b,$05
425A: CD 8F 18      call sound_18AF
425D: C9            ret

425E: CD CF 6A      call $42EF
4261: D0            ret  nc
4262: 3A E8 8D      ld   a,(total_eggs_to_hatch_8DC0)
4265: 90            sub  b
4266: CB FF         set  7,a
4268: FD 77 B9      ld   (iy+$19),a
426B: C9            ret
426C: 3E B0         ld   a,$10
426E: BE            cp   (hl)
426F: 28 11         jr   z,$4282
4271: 3C            inc  a
4272: BE            cp   (hl)
4273: 28 0D         jr   z,$4282
4275: DD 36 B7 02   ld   (ix+char_state),$02
4279: FD E5         push iy
427B: DD E1         pop  ix
427D: DD 36 B7 28   ld   (ix+char_state),$00
4281: C9            ret
4282: DD 36 BF A5   ld   (ix+char_state),$05
4286: FD E5         push iy
4288: DD E1         pop  ix
428A: DD 36 BF A0   ld   (ix+char_state),$00
428E: 06 A3         ld   b,$03
4290: CD 8F 18      call sound_18AF
4293: C9            ret
4294: DD 36 1F 24   ld   (ix+char_state),$04
4298: FD CB 18 46   bit  4,(iy+$18)
429C: 28 25         jr   z,$42A3
429E: FD 36 BF A0   ld   (iy+$1f),$00
42A2: C9            ret

42A3: CD F0 E3      call move_snobee_current_direction_4378
42A6: FD E5         push iy
42A8: DD E1         pop  ix
42AA: DD 36 BF A0   ld   (ix+char_state),$00
42AE: C5            push bc
42AF: 06 02         ld   b,$02
42B1: CD AF B0      call sound_18AF
42B4: C1            pop  bc
42B5: CD C6 62      call find_breaking_block_free_slot_42c6
42B8: CB EE         set  5,(hl)
42BA: CB 76         bit  6,(hl)
42BC: C8            ret  z
; egg broken, decrease nb enemies and eggs
42BD: 21 98 AD      ld   hl,remaining_alive_snobees_8D98
42C0: 35            dec  (hl)
42C1: 21 DD 8D      ld   hl,current_nb_eggs_to_hatch_8DDD
42C4: 35            dec  (hl)
42C5: C9            ret

find_breaking_block_free_slot_42c6:
42C6: 21 E8 8C      ld   hl,breaking_block_slots_8CC0
42C9: 16 2D         ld   d,$05
42CB: CB 7E         bit  7,(hl)
42CD: 28 AA         jr   z,$42D9
42CF: 23            inc  hl
42D0: 23            inc  hl
42D1: 23            inc  hl
42D2: 23            inc  hl
42D3: 23            inc  hl
42D4: 23            inc  hl
42D5: 15            dec  d
42D6: 20 5B         jr   nz,$42CB
42D8: C9            ret
42D9: 36 80         ld   (hl),$80
42DB: E5            push hl
42DC: 23            inc  hl
42DD: 36 09         ld   (hl),$09
42DF: 23            inc  hl
42E0: 71            ld   (hl),c
42E1: 23            inc  hl
42E2: 70            ld   (hl),b
42E3: 23            inc  hl
42E4: 23            inc  hl
42E5: 36 29         ld   (hl),$01
42E7: CD C7 E2      call $42EF
42EA: E1            pop  hl
42EB: D0            ret  nc
42EC: 36 E8         ld   (hl),$C0
42EE: C9            ret
42EF: CD 0A 10      call look_for_hidden_egg_300A
42F2: D0            ret  nc
42F3: AF            xor  a
42F4: 77            ld   (hl),a
42F5: 23            inc  hl
42F6: 77            ld   (hl),a
42F7: 37            scf		; set carry flag
42F8: C9            ret
42F9: 60            ld   h,b
42FA: 69            ld   l,c
42FB: ED 5B 18 8D   ld   de,(diamond_block_1_xy_8DB0)
42FF: CD 91 AD      call compare_hl_to_de_2D99
4302: C8            ret  z
4303: FD 34 B0      inc  (iy+$18)
4306: ED 5B 32 25   ld   de,(diamond_block_2_xy_8DB2)
430A: CD 31 0D      call compare_hl_to_de_2D99
430D: C8            ret  z
430E: FD 34 18      inc  (iy+$18)
4311: ED 5B 3C 8D   ld   de,(diamond_block_3_xy_8DB4)
4315: CD 99 05      call compare_hl_to_de_2D99
4318: C8            ret  z
4319: C9            ret

table_431A:
	dc.w	$4322 
	dc.w	$4337 
	dc.w	$434D 
	dc.w	$4362  

4322: 05			dec  b                                              
4323: CD 4F A9		call $296F                                          
4326: 3E B2         ld   a,$1A
4328: BE            cp   (hl)
4329: C8            ret  z
432A: FD CB 98 4E   set  4,(iy+$18)
432E: 3E B6         ld   a,$1E
4330: BE            cp   (hl)
4331: C8            ret  z
4332: FD CB 18 2E   res  4,(iy+$18)
4336: C9            ret

4337: 04            inc  b
4338: 04            inc  b
4339: CD 6F 01      call convert_coords_to_screen_address_296F
433C: 3E 90         ld   a,$18
433E: BE            cp   (hl)
433F: C8            ret  z
4340: FD CB 98 4E   set  4,(iy+$18)
4344: 3E B4         ld   a,$1C
4346: BE            cp   (hl)
4347: C8            ret  z
4348: FD CB 98 0E   res  4,(iy+$18)
434C: C9            ret

434D: 0D            dec  c
434E: CD EF 29      call convert_coords_to_screen_address_296F
4351: 3E 19         ld   a,$19
4353: BE            cp   (hl)
4354: C8            ret  z
4355: FD CB 90 E6   set  4,(iy+$18)
4359: 3E 1D         ld   a,$1D
435B: BE            cp   (hl)
435C: C8            ret  z
435D: FD CB 90 26   res  4,(iy+$18)
4361: C9            ret

4362: 0C            inc  c
4363: 0C            inc  c
4364: CD EF 09      call convert_coords_to_screen_address_296F
4367: 3E 98         ld   a,$18
4369: BE            cp   (hl)
436A: C8            ret  z
436B: FD CB B0 66   set  4,(iy+$18)
436F: 3E 1C         ld   a,$1C
4371: BE            cp   (hl)
4372: C8            ret  z
4373: FD CB 90 A6   res  4,(iy+$18)
4377: C9            ret
	
; < BC: X,Y of snobee
move_snobee_current_direction_4378: 
4378: CD 50 3E      call get_div8_ix_coords_3E78
437B: DD 7E A4      ld   a,(ix+facing_direction)		; facing direction
437E: 11 AD EB      ld   de,table_4385
4381: CD 87 AD      call indirect_jump_2D8F
4384: C9            ret

table_4385:	
     dc.w	$438D 
	 dc.w	$4392 
	 dc.w	$4397 
	 dc.w	$439C
	 
438D: 78            ld   a,b
438E: D6 82         sub  $02
4390: 47            ld   b,a
4391: C9            ret

4392: 78            ld   a,b
4393: C6 02         add  a,$02
4395: 47            ld   b,a
4396: C9            ret

4397: 79            ld   a,c
4398: D6 A2         sub  $02
439A: 4F            ld   c,a
439B: C9            ret

439C: 79            ld   a,c
439D: C6 02         add  a,$02
439F: 4F            ld   c,a
43A0: C9            ret
	
is_grid_free_jump_table_43A1: 
	dc.w	is_upper_grid_free_390F
	dc.w	is_lower_grid_free_3917
	dc.w	is_left_grid_free_391B
	dc.w	is_right_grid_free_391E

clear_2x2_tiles_at_current_pos_43A9:
43A9: ED 43 80 80   ld   (cursor_x_8800),bc
43AD: CD A8 A9      call put_blank_at_current_pos_2900
43B0: CD A0 29      call put_blank_at_current_pos_2900
43B3: CD 1E 01      call move_cursor_2_291E
43B6: CD A0 29      call put_blank_at_current_pos_2900
43B9: CD 00 01      call put_blank_at_current_pos_2900
43BC: C9            ret

43BD: DD 34 A7      inc  (ix+current_period_counter)
43C0: DD 7E AF      ld   a,(ix+current_period_counter)
43C3: DD BE 86      cp   (ix+instant_move_period)
43C6: D8            ret  c
43C7: DD 36 87 A8   ld   (ix+current_period_counter),$00
43CB: CD 65 C3      call $43E5
43CE: 21 73 43      ld   hl,$43DB
43D1: E5            push hl
	;; move snobee in the current direction
43D2: DD 7E 04      ld   a,(ix+facing_direction)
43D5: 11 C6 33      ld   de,snobee_move_table_33C6
43D8: C3 8F 2D      jp   indirect_jump_2D8F

43DB: DD 7E A5      ld   a,(ix+char_id)
43DE: DD E5         push ix
43E0: E1            pop  hl
43E1: CD FC 99      call set_character_sprite_position_3154
43E4: C9            ret
	
43E5: DD 7E 80      ld   a,(ix+x_pos)
43E8: E6 A7         and  $0F
43EA: FE A0         cp   $08
43EC: C0            ret  nz
43ED: DD 7E 81      ld   a,(ix+y_pos)
43F0: E6 87         and  $0F
43F2: C0            ret  nz
43F3: CD 31 E4      call check_snobee_collisions_with_block_4431
43F6: CD 50 3E      call get_div8_ix_coords_3E78
43F9: DD 7E A4      ld   a,(ix+facing_direction)
43FC: 11 AD 43      ld   de,table_4385
43FF: CD 8F 05      call indirect_jump_2D8F
4402: DD 7E 2C      ld   a,(ix+facing_direction)
4405: 11 01 E3      ld   de,is_grid_free_jump_table_43A1
4408: CD 8F A5      call indirect_jump_2D8F
440B: C8            ret  z
440C: FE 70         cp   $70
440E: 38 A3         jr   c,$4413
4410: FE 28         cp   $80
4412: D8            ret  c
4413: DD 34 B7      inc  (ix+char_state)
4416: CD D0 3E      call get_div8_ix_coords_3E78
4419: DD 7E 24      ld   a,(ix+facing_direction)
441C: 11 2D 43      ld   de,table_4385
441F: CD 8F 05      call indirect_jump_2D8F
4422: 3E A0         ld   a,$00
4424: 32 A2 88      ld   (cursor_color_8802),a
4427: ED 43 A0 88   ld   (cursor_x_8800),bc
442B: 3E BC         ld   a,$1C
442D: CD 28 07      call set_2x2_tile_2F00
4430: C9            ret
	
check_snobee_collisions_with_block_4431:
4431: FD 21 20 8D   ld   iy,snobee_1_struct_8D00
4435: CD 4E 64      call snobee_collision_with_moving_block_test_444E
4438: FD 21 20 AD   ld   iy,snobee_2_struct_8D20
443C: CD E6 44      call snobee_collision_with_moving_block_test_444E
443F: FD 21 E0 8D   ld   iy,snobee_3_struct_8D40
4443: CD EE E4      call snobee_collision_with_moving_block_test_444E
4446: FD 21 60 8D   ld   iy,snobee_4_struct_8D60
444A: CD C6 6C      call snobee_collision_with_moving_block_test_444E
444D: C9            ret
	
snobee_collision_with_moving_block_test_444E:
444E: FD 7E 1F      ld   a,(iy+$1f)
4451: A7            and  a
4452: C8            ret  z
4453: FE 06         cp   $06	; state = 0 or >= 06? don't test anything
4455: D0            ret  nc
	
	;; state is "can collide with block"
4456: DD 7E 04      ld   a,(ix+facing_direction) ; moving block direction (ix contains block struct)
4459: 11 5F 64      ld   de,table_445F
445C: C3 AF 2D      jp   indirect_jump_2D8F
table_445F:
	dc.w	go_up_test_4467		; "go up" test
	dc.w	go_down_test_448E		; "go down" test
	dc.w	go_left_test_44A8		; "go left" test
	dc.w	go_right_test_44CF		; "go right" test

go_up_test_4467:
4467: CD F0 16      call get_div8_ix_coords_3E78
446A: 50            ld   d,b
446B: 59            ld   e,c
446C: CD 8F B6      call get_div8_iy_coords_3E8F
446F: 7A            ld   a,d
4470: B8            cp   b
4471: 28 0C         jr   z,$447F
4473: 3C            inc  a
4474: B8            cp   b
4475: 28 08         jr   z,$447F
4477: 3D            dec  a
4478: 3D            dec  a
4479: B8            cp   b
447A: 28 23         jr   z,$447F
447C: 3D            dec  a
447D: B8            cp   b
447E: C0            ret  nz
447F: 7B            ld   a,e
4480: B9            cp   c
4481: 28 2B         jr   z,$4486
4483: 3D            dec  a
4484: B9            cp   c
4485: C0            ret  nz
	;; snobee hit by block
4486: DD 34 AF      inc  (ix+$0f) ;  number of snobee hit by same block (for score)
4489: FD 36 97 A9   ld   (iy+$1f),$09 ; change snobee state to "pushed by block"
448D: C9            ret

go_down_test_448E:	
448E: CD 50 3E      call get_div8_ix_coords_3E78
4491: 50            ld   d,b
4492: 59            ld   e,c
4493: CD 8F 96      call get_div8_iy_coords_3E8F
4496: 7A            ld   a,d
4497: B8            cp   b
4498: 28 4D         jr   z,$447F
449A: 3D            dec  a
449B: B8            cp   b
449C: 28 49         jr   z,$447F
449E: 3C            inc  a
449F: 3C            inc  a
44A0: B8            cp   b
44A1: 28 DC         jr   z,$447F
44A3: 3C            inc  a
44A4: B8            cp   b
44A5: 28 D8         jr   z,$447F
44A7: C9            ret
	
go_left_test_44A8:
44A8: CD 50 B6      call get_div8_ix_coords_3E78
44AB: 50            ld   d,b
44AC: 59            ld   e,c
44AD: CD 8F 16      call get_div8_iy_coords_3E8F
44B0: 7B            ld   a,e
44B1: B9            cp   c
44B2: 28 A4         jr   z,$44C0
44B4: 3C            inc  a
44B5: B9            cp   c
44B6: 28 A0         jr   z,$44C0
44B8: 3D            dec  a
44B9: 3D            dec  a
44BA: B9            cp   c
44BB: 28 03         jr   z,$44C0
44BD: 3D            dec  a
44BE: B9            cp   c
44BF: C0            ret  nz
44C0: 7A            ld   a,d
44C1: B8            cp   b
44C2: 28 A3         jr   z,$44C7
44C4: 3D            dec  a
44C5: B8            cp   b
44C6: C0            ret  nz
	;; hit by block
44C7: DD 34 87      inc  (ix+$0f)
44CA: FD 36 BF 81   ld   (iy+$1f),$09
44CE: C9            ret

go_right_test_44CF:
44CF: CD 78 96      call get_div8_ix_coords_3E78
44D2: 50            ld   d,b
44D3: 59            ld   e,c
44D4: CD AF 3E      call get_div8_iy_coords_3E8F
44D7: 7B            ld   a,e
44D8: B9            cp   c
44D9: 28 E5         jr   z,$44C0
44DB: 3D            dec  a
44DC: B9            cp   c
44DD: 28 E1         jr   z,$44C0
44DF: 3C            inc  a
44E0: 3C            inc  a
44E1: B9            cp   c
44E2: 28 DC         jr   z,$44C0
44E4: 3C            inc  a
44E5: B9            cp   c
44E6: 28 D8         jr   z,$44C0
44E8: C9            ret
	
44E9: CD 85 12      call _03_snobee_aligns_for_stunned_3AAD
44EC: FD 21 28 8D   ld   iy,snobee_1_struct_8D00
44F0: FD 7E 1F      ld   a,(iy+$1f)
44F3: FE 0A         cp   $0A
44F5: 20 04         jr   nz,$44FB
44F7: FD 36 A0 00   ld   (iy+$08),$00
44FB: FD 21 00 8D   ld   iy,snobee_2_struct_8D20
44FF: FD 7E B7      ld   a,(iy+$1f) ; snobee state
4502: FE A2         cp   $0A
4504: 20 84         jr   nz,$450A
4506: FD 36 88 80   ld   (iy+$08),$00
450A: FD 21 E8 25   ld   iy,snobee_3_struct_8D40
450E: FD 7E 1F      ld   a,(iy+$1f)
4511: FE 0A         cp   $0A
4513: 20 04         jr   nz,$4519
4515: FD 36 80 00   ld   (iy+$08),$00
4519: FD 21 60 8D   ld   iy,snobee_4_struct_8D60
451D: FD 7E 97      ld   a,(iy+$1f)
4520: FE A2         cp   $0A
4522: 20 84         jr   nz,$4528
4524: FD 36 88 80   ld   (iy+$08),$00
4528: C9            ret
4529: CD 58 BE      call get_div8_ix_coords_3E78
452C: ED 43 A8 20   ld   (cursor_x_8800),bc
4530: DD CB 18 66   bit  4,(ix+$18)
4534: C2 1C 45      jp   nz,diamond_hits_obstacle_45bc
4537: DD 7E 91      ld   a,(ix+$19)
453A: CB 7F         bit  7,a
453C: 28 B1         jr   z,$454F
453E: E6 57         and  $7F
4540: 87            add  a,a
4541: 16 A8         ld   d,$00
4543: 5F            ld   e,a
4544: 21 42 85      ld   hl,egg_location_table_8DC2
4547: 19            add  hl,de
4548: 71            ld   (hl),c
4549: 23            inc  hl
454A: 70            ld   (hl),b
454B: DD 36 B1 A8   ld   (ix+$19),$00
454F: 3E 09         ld   a,$09
4551: 32 02 88      ld   (cursor_color_8802),a
4554: CD 5E 2E      call draw_ice_block_tile_2EFE
4557: DD 34 97      inc  (ix+char_state)
455A: 06 A4         ld   b,$04
455C: CD 0F 18      call sound_18AF
455F: DD 7E A7      ld   a,(ix+$0f)
4562: A7            and  a
4563: C8            ret  z
4564: 06 85         ld   b,$05
4566: CD 47 98      call update_sound_18c7
4569: 11 28 80      ld   de,$0020
456C: 3E A2         ld   a,$0A
456E: FD 21 00 8D   ld   iy,snobee_1_struct_8D00
4572: FD BE 1F      cp   (iy+$1f)
4575: 28 10         jr   z,$4587
4577: FD 19         add  iy,de
4579: FD BE 97      cp   (iy+$1f)
457C: 28 81         jr   z,$4587
457E: FD 19         add  iy,de
4580: FD BE 9F      cp   (iy+$1f)
4583: 28 AA         jr   z,$4587
4585: FD 19         add  iy,de
4587: DD 46 A7      ld   b,(ix+$0f)
458A: FD 70 9A      ld   (iy+$1a),b
458D: FD 34 B7      inc  (iy+$1f)
4590: FD 21 20 8D   ld   iy,snobee_2_struct_8D20
4594: FD BE 1F      cp   (iy+$1f)
4597: 20 07         jr   nz,$45A0
4599: FD 36 92 00   ld   (iy+$1a),$00
459D: FD 34 97      inc  (iy+$1f)
45A0: FD 19         add  iy,de
45A2: FD BE 9F      cp   (iy+$1f)
45A5: 20 AF         jr   nz,$45AE
45A7: FD 36 B2 A8   ld   (iy+$1a),$00
45AB: FD 34 B7      inc  (iy+$1f)
45AE: FD 19         add  iy,de
45B0: FD BE 1F      cp   (iy+$1f)
45B3: C0            ret  nz
45B4: FD 36 1A A0   ld   (iy+$1a),$00
45B8: FD 34 1F      inc  (iy+$1f)
45BB: C9            ret
; diamond hits a wall/another block
diamond_hits_obstacle_45bc:
45BC: DD 7E 18      ld   a,(ix+$18)
45BF: E6 8F         and  $0F
45C1: 87            add  a,a
45C2: 16 80         ld   d,$00
45C4: 5F            ld   e,a
45C5: 21 30 25      ld   hl,diamond_block_1_xy_8DB0
45C8: 19            add  hl,de
45C9: 71            ld   (hl),c
45CA: 23            inc  hl
45CB: 70            ld   (hl),b
45CC: 3E A1         ld   a,$09
45CE: 32 82 88      ld   (cursor_color_8802),a
45D1: CD A9 07      call set_diamond_position_2FA9
45D4: DD 36 00 A0   ld   (ix+x_pos),$00
45D8: DD 36 01 A0   ld   (ix+y_pos),$00
45DC: CD CE 33      call display_snobee_sprite_33CE
45DF: DD 34 B7      inc  (ix+char_state)
45E2: CD 6B ED      call $45EB
45E5: CD CA C6      call $464A
45E8: C3 F2 ED      jp   $455A
45EB: DD CB 96 5E   bit  7,(ix+$16)
45EF: C0            ret  nz
45F0: ED 4B B0 8D   ld   bc,(diamond_block_1_xy_8DB0)
45F4: CD D8 4B      call set_2x2_tile_color_09_4BD8
45F7: ED 4B 3A 8D   ld   bc,(diamond_block_2_xy_8DB2)
45FB: CD D8 C3      call set_2x2_tile_color_09_4BD8
45FE: ED 4B 14 8D   ld   bc,(diamond_block_3_xy_8DB4)
4602: CD D8 EB      call set_2x2_tile_color_09_4BD8
4605: DD 36 B7 28   ld   (ix+$17),$00
4609: CD 3A E6      call $4612
460C: C0            ret  nz
460D: DD 36 B7 FF   ld   (ix+$17),$FF
4611: C9            ret
4612: ED 4B B0 AD   ld   bc,(diamond_block_1_xy_8DB0)
4616: ED 5B B2 AD   ld   de,(diamond_block_2_xy_8DB2)
461A: CD 82 46      call $462A
461D: C8            ret  z
461E: ED 5B 14 8D   ld   de,(diamond_block_3_xy_8DB4)
4622: CD 02 6E      call $462A
4625: C8            ret  z
4626: ED 4B 12 8D   ld   bc,(diamond_block_2_xy_8DB2)
462A: 26 A0         ld   h,$00
462C: 78            ld   a,b
462D: C6 2A         add  a,$02
462F: 92            sub  d
4630: D8            ret  c
4631: FE 05         cp   $05
4633: D0            ret  nc
4634: D6 22         sub  $02
4636: 28 21         jr   z,$4639
4638: 24            inc  h
4639: 79            ld   a,c
463A: C6 22         add  a,$02
463C: 93            sub  e
463D: D8            ret  c
463E: FE 25         cp   $05
4640: D0            ret  nc
4641: D6 2A         sub  $02
4643: 28 29         jr   z,$4646
4645: 24            inc  h
4646: 3E A1         ld   a,$01
4648: 94            sub  h
4649: C9            ret
464A: DD CB 3E 56   bit  7,(ix+$16)
464E: C0            ret  nz
464F: CD 96 E0      call $4896
4652: 28 24         jr   z,$4658
4654: CD 43 48      call $4863
4657: C0            ret  nz
; diamonds are aligned
4658: DD 36 17 20   ld   (ix+$17),$00
465C: 06 23         ld   b,$03
465E: CD A9 B8      call play_sfx_1889		; diamond align music bonus
4661: 1E 21         ld   e,$21		; stars
4663: CD F2 06      call draw_borders_2E7A
4666: 06 E0         ld   b,$40
4668: C5            push bc
4669: 78            ld   a,b
466A: E6 A3         and  $03
466C: 11 9E 6F      ld   de,table_479E
466F: CD 8F 85      call indirect_jump_2D8F
4672: 3E 22         ld   a,$02
4674: CD 79 28      call delay_28D1
4677: C1            pop  bc
4678: C5            push bc
4679: 78            ld   a,b
467A: 3D            dec  a
467B: E6 07         and  $07
467D: 3C            inc  a
467E: CD DE 6F      call $47FE
4681: C1            pop  bc
4682: C5            push bc
4683: 48            ld   c,b
4684: CD B7 E8      call $4817
4687: 3E 2A         ld   a,$02
4689: CD 59 00      call delay_28D1
468C: C1            pop  bc
468D: 10 D9         djnz $4668
468F: CD B7 11      call clear_sprites_31B7
4692: CD B8 0F      call $0F98
4695: 21 6C 67      ld   hl,table_476C
4698: CD 86 0F      call erase_rectangular_char_zone_0F2E
469B: 21 79 67      ld   hl,table_476C+$79-$6C
469E: DD CB 3E 56   bit  7,(ix+$16)					; 10000
46A2: 28 A3         jr   z,$46A7
46A4: 21 88 6F      ld   hl,table_476C+$88-$6C		; 5000
46A7: CD 54 01      call print_line_typewriter_style_29F4
46AA: 21 71 6F      ld   hl,table_476C+$71-$6C		; bonus
46AD: CD 54 01      call print_line_typewriter_style_29F4
46B0: 21 29 47      ld   hl,table_476C+$81-$6C			; pts
46B3: CD F4 81      call print_line_typewriter_style_29F4
46B6: 3E 82         ld   a,$2A
46B8: CD 79 28      call delay_28D1
46BB: 06 07         ld   b,$07
46BD: CD C7 B0      call update_sound_18c7
46C0: 06 64         ld   b,$64
46C2: 21 48 2B      ld   hl,$03E8		; 1000
46C5: DD CB B6 F6   bit  7,(ix+$16)
46C9: 28 2D         jr   z,$46D0
46CB: 06 32         ld   b,$32
46CD: 21 54 A1      ld   hl,$01F4		; 500
46D0: C5            push bc
46D1: E5            push hl
46D2: 78            ld   a,b
46D3: E6 03         and  $03
46D5: CC 4F 67      call z,$474F
46D8: 11 A2 00      ld   de,$000A
46DB: CD AF 80      call add_to_current_player_score_28AF
46DE: E1            pop  hl
46DF: 11 AA A0      ld   de,$000A
46E2: AF            xor  a
46E3: ED 52         sbc  hl,de
46E5: E5            push hl
46E6: CD E0 A3      call convert_number_2B40
46E9: 26 3A         ld   h,$12
46EB: 2E AA         ld   l,$0A
46ED: 22 28 88      ld   (cursor_x_8800),hl
46F0: CD 74 2C      call write_5_digits_to_screen_2C54
46F3: 3E 02         ld   a,$02
46F5: CD D1 80      call delay_28D1
46F8: E1            pop  hl
46F9: C1            pop  bc
46FA: C5            push bc
46FB: E5            push hl
46FC: 48            ld   c,b
46FD: CD 17 E0      call $4817
4700: E1            pop  hl
4701: C1            pop  bc
4702: 10 64         djnz $46D0
4704: 06 7F         ld   b,$FF
4706: CD 47 98      call update_sound_18c7
4709: 06 88         ld   b,$08
470B: CD E7 B0      call update_sound_18c7
470E: 3E C0         ld   a,$40
4710: CD F9 28      call delay_28D1
4713: CD BA 87      call $0FBA
4716: DD 36 16 5F   ld   (ix+$16),$FF
471A: 3E 81         ld   a,$09
471C: CD 5E 47      call $47FE
471F: CD 4A AE      call draw_borders_2E6A
4722: DD E5         push ix
4724: DD 21 A8 25   ld   ix,snobee_1_struct_8D00
4728: CD 10 EF      call $4790
472B: DD 21 88 85   ld   ix,snobee_2_struct_8D20
472F: CD 90 E7      call $4790
4732: DD 21 40 8D   ld   ix,snobee_3_struct_8D40
4736: CD B8 47      call $4790
4739: DD 21 60 8D   ld   ix,snobee_4_struct_8D60
473D: CD 90 E7      call $4790
4740: DD 21 A0 25   ld   ix,pengo_struct_8D80
4744: CD 66 3B      call display_snobee_sprite_33CE
4747: 3E 28         ld   a,$20
4749: CD F1 A8      call delay_28D1
474C: DD E1         pop  ix
474E: C9            ret
474F: CB 50         bit  2,b
4751: 28 14         jr   z,$4767
4753: C5            push bc
4754: 0E 24         ld   c,$24
4756: 3E 83         ld   a,$0B
4758: 32 A2 88      ld   (cursor_color_8802),a
475B: CD 9E 00      call get_nb_lives_289E
475E: 3D            dec  a
475F: 28 AC         jr   z,$4765
4761: 47            ld   b,a
4762: CD 8E 0D      call $2D26
4765: C1            pop  bc
4766: C9            ret
4767: C5            push bc
4768: 0E A8         ld   c,$28
476A: 18 6A         jr   $4756

table_476C:
  09 10 10 0A 05 0A 11 18 42 4F 4E 55 D3 0B 12 10    .......BONUÓ...
 477C  31 30 30 30 B0 0E 13 19 50 54 53 BA 0B 12 10 20   1000°...PTSº...
 478C  35 30 30

4790: CD CE 33      call display_snobee_sprite_33CE
4793: 3E 02         ld   a,$02
4795: DD BE 97      cp   (ix+char_state)
4798: C0            ret  nz
4799: DD 36 97 03   ld   (ix+char_state),$03
479D: C9            ret
     
table_479E:
  dc.w	$47D2
  dc.w	$47E8
  dc.w	$47A6
  dc.w	$47BC


47A6: ED 4B 30 25   ld   bc,(diamond_block_1_xy_8DB0)
47AA: CD 70 CB      call set_2x2_tile_color_09_4BD8
47AD: ED 4B 1A 8D   ld   bc,(diamond_block_2_xy_8DB2)
47B1: CD C2 C3      call set_2x2_tile_color_0C_4BC2
47B4: ED 4B B4 8D   ld   bc,(diamond_block_3_xy_8DB4)
47B8: CD EA 4B      call set_2x2_tile_color_0C_4BC2
47BB: C9            ret

47BC: ED 4B B0 8D   ld   bc,(diamond_block_1_xy_8DB0)
47C0: CD 42 CB      call set_2x2_tile_color_0C_4BC2
47C3: ED 4B 1A 85   ld   bc,(diamond_block_2_xy_8DB2)
47C7: CD D0 E3      call set_2x2_tile_color_09_4BD8
47CA: ED 4B 34 25   ld   bc,(diamond_block_3_xy_8DB4)
47CE: CD 42 4B      call set_2x2_tile_color_0C_4BC2
47D1: C9            ret

47D2: ED 4B B0 8D   ld   bc,(diamond_block_1_xy_8DB0)
47D6: CD EA 4B      call set_2x2_tile_color_0C_4BC2
47D9: ED 4B 3A 8D   ld   bc,(diamond_block_2_xy_8DB2)
47DD: CD C2 C3      call set_2x2_tile_color_0C_4BC2
47E0: ED 4B 34 25   ld   bc,(diamond_block_3_xy_8DB4)
47E4: CD 70 CB      call set_2x2_tile_color_09_4BD8
47E7: C9            ret

47E8: ED 4B 30 25   ld   bc,(diamond_block_1_xy_8DB0)
47EC: CD 70 CB      call set_2x2_tile_color_09_4BD8
47EF: ED 4B 3A 8D   ld   bc,(diamond_block_2_xy_8DB2)
47F3: CD D8 C3      call set_2x2_tile_color_09_4BD8
47F6: ED 4B B4 8D   ld   bc,(diamond_block_3_xy_8DB4)
47FA: CD D8 4B      call set_2x2_tile_color_09_4BD8
47FD: C9            ret

47FE: 21 62 0C      ld   hl,$8462
4801: 11 63 AC      ld   de,$8463
4804: 06 92         ld   b,$1A
4806: C5            push bc
4807: 01 BD A0      ld   bc,$001D
480A: 77            ld   (hl),a
480B: ED B0         ldir
480D: 23            inc  hl
480E: 23            inc  hl
480F: 23            inc  hl
4810: 13            inc  de
4811: 13            inc  de
4812: 13            inc  de
4813: C1            pop  bc
4814: 10 58         djnz $4806
4816: C9            ret

4817: 21 A1 2F      ld   hl,$87A1
481A: 11 00 00      ld   de,$0020
481D: 06 0E         ld   b,$0E
481F: 79            ld   a,c
4820: E6 A7         and  $07
4822: C6 B6         add  a,$16
4824: 77            ld   (hl),a
4825: A7            and  a
4826: ED 52         sbc  hl,de
4828: 77            ld   (hl),a
4829: A7            and  a
482A: ED 52         sbc  hl,de
482C: 0C            inc  c
482D: 10 50         djnz $481F
482F: 21 42 2C      ld   hl,$8442
4832: 06 A7         ld   b,$0F
4834: 79            ld   a,c
4835: E6 07         and  $07
4837: C6 16         add  a,$16
4839: 77            ld   (hl),a
483A: 23            inc  hl
483B: 77            ld   (hl),a
483C: 23            inc  hl
483D: 0C            inc  c
483E: 10 5C         djnz $4834
4840: 21 A2 0C      ld   hl,$8402
4843: 06 AE         ld   b,$0E
4845: 79            ld   a,c
4846: E6 A7         and  $07
4848: C6 B6         add  a,$16
484A: 77            ld   (hl),a
484B: 23            inc  hl
484C: 77            ld   (hl),a
484D: 23            inc  hl
484E: 0C            inc  c
484F: 10 F4         djnz $4845
4851: 21 BF 2F      ld   hl,$87BF
4854: 06 A7         ld   b,$0F
4856: 79            ld   a,c
4857: E6 07         and  $07
4859: C6 16         add  a,$16
485B: 77            ld   (hl),a
485C: 2B            dec  hl
485D: 77            ld   (hl),a
485E: 2B            dec  hl
485F: 0C            inc  c
4860: 10 7C         djnz $4856
4862: C9            ret
4863: 21 10 8D      ld   hl,diamond_block_1_xy_8DB0
4866: 7E            ld   a,(hl)
4867: 23            inc  hl
4868: 23            inc  hl
4869: BE            cp   (hl)
486A: C0            ret  nz
486B: 23            inc  hl
486C: 23            inc  hl
486D: BE            cp   (hl)
486E: C0            ret  nz
486F: CD D0 E0      call $48D0
4872: 21 19 8D      ld   hl,moving_block_struct_8DA0+$11
4875: 11 02 20      ld   de,$0002
4878: 7E            ld   a,(hl)
4879: 19            add  hl,de
487A: 3D            dec  a
487B: 3D            dec  a
487C: BE            cp   (hl)
487D: C0            ret  nz
487E: 19            add  hl,de
487F: 3D            dec  a
4880: 3D            dec  a
4881: BE            cp   (hl)
4882: C0            ret  nz
4883: 3A 10 8D      ld   a,(diamond_block_1_xy_8DB0)
4886: FE A1         cp   $01
4888: 28 A6         jr   z,$4890
488A: FE 91         cp   $19
488C: 28 A2         jr   z,$4890
488E: AF            xor  a
488F: C9            ret
4890: DD 36 16 DF   ld   (ix+$16),$FF
4894: AF            xor  a
4895: C9            ret
4896: 21 19 8D      ld   hl,moving_block_struct_8DA0+$11
4899: 7E            ld   a,(hl)
489A: 23            inc  hl
489B: 23            inc  hl
489C: BE            cp   (hl)
489D: C0            ret  nz
489E: 23            inc  hl
489F: 23            inc  hl
48A0: BE            cp   (hl)
48A1: C0            ret  nz
48A2: CD EB E8      call $48C3
48A5: 21 10 8D      ld   hl,diamond_block_1_xy_8DB0
48A8: 11 A2 28      ld   de,$0002
48AB: 7E            ld   a,(hl)
48AC: 19            add  hl,de
48AD: 3D            dec  a
48AE: 3D            dec  a
48AF: BE            cp   (hl)
48B0: C0            ret  nz
48B1: 19            add  hl,de
48B2: 3D            dec  a
48B3: 3D            dec  a
48B4: BE            cp   (hl)
48B5: C0            ret  nz
48B6: 3A 19 8D      ld   a,(moving_block_struct_8DA0+$11)
48B9: FE 02         cp   $02
48BB: 28 D3         jr   z,$4890
48BD: FE 1E         cp   $1E
48BF: 28 CF         jr   z,$4890
48C1: AF            xor  a
48C2: C9            ret
48C3: 21 10 8D      ld   hl,diamond_block_1_xy_8DB0
48C6: 06 A2         ld   b,$02
48C8: C5            push bc
48C9: CD DD C0      call $48DD
48CC: C1            pop  bc
48CD: 10 D1         djnz $48C8
48CF: C9            ret
48D0: 21 18 8D      ld   hl,diamond_block_1_xy_8DB0
48D3: 06 02         ld   b,$02
48D5: C5            push bc
48D6: CD DB 48      call $48FB
48D9: C1            pop  bc
48DA: 10 D9         djnz $48D5
48DC: C9            ret
48DD: E5            push hl
48DE: 5E            ld   e,(hl)
48DF: 23            inc  hl
48E0: 56            ld   d,(hl)
48E1: 23            inc  hl
48E2: 7B            ld   a,e
48E3: BE            cp   (hl)
48E4: 38 82         jr   c,$48F0
48E6: 23            inc  hl
48E7: 23            inc  hl
48E8: 10 59         djnz $48E3
48EA: E1            pop  hl
48EB: 73            ld   (hl),e
48EC: 23            inc  hl
48ED: 72            ld   (hl),d
48EE: 23            inc  hl
48EF: C9            ret
48F0: 7E            ld   a,(hl)
48F1: 73            ld   (hl),e
48F2: 5F            ld   e,a
48F3: 23            inc  hl
48F4: 7E            ld   a,(hl)
48F5: 72            ld   (hl),d
48F6: 57            ld   d,a
48F7: 23            inc  hl
48F8: 7B            ld   a,e
48F9: 18 ED         jr   $48E8
48FB: E5            push hl
48FC: 5E            ld   e,(hl)
48FD: 23            inc  hl
48FE: 56            ld   d,(hl)
48FF: 23            inc  hl
4900: 7A            ld   a,d
4901: 23            inc  hl
4902: BE            cp   (hl)
4903: 38 89         jr   c,$490E
4905: 23            inc  hl
4906: 10 79         djnz $4901
4908: E1            pop  hl
4909: 73            ld   (hl),e
490A: 23            inc  hl
490B: 72            ld   (hl),d
490C: 23            inc  hl
490D: C9            ret
490E: 2B            dec  hl
490F: 7E            ld   a,(hl)
4910: 73            ld   (hl),e
4911: 5F            ld   e,a
4912: 23            inc  hl
4913: 7E            ld   a,(hl)
4914: 72            ld   (hl),d
4915: 57            ld   d,a
4916: 23            inc  hl
4917: 18 ED         jr   $4906

	
snobee_block_break_4919:
4919: DD 21 E8 8C   ld   ix,breaking_block_slots_8CC0
491D: 06 05         ld   b,$05
491F: C5            push bc
4920: DD CB A8 FE   bit  7,(ix+x_pos)
4924: C4 98 C9      call nz,$4930
4927: 11 AE 80      ld   de,$0006
492A: DD 19         add  ix,de
492C: C1            pop  bc
492D: 10 70         djnz $491F
492F: C9            ret
4930: DD 7E 05      ld   a,(ix+char_id)
4933: 11 39 C1      ld   de,table_4939
4936: C3 8F 2D      jp   indirect_jump_2D8F
table_4939:
	dc.w	do_nothing_3358 
	dc.w	$494D 
	dc.w	$4967 
	dc.w	$4972 
	dc.w	$4A17 
	dc.w	$4A22 
	dc.w	$4A77  
	dc.w	$4A82
	dc.w	$4AC6 
	dc.w	$4AE5 
	dc.w	$4B75  
	

494D: DD CB 80 76   bit  6,(ix+$00)
4951: 28 0D         jr   z,$4960
4953: 21 C1 8D      ld   hl,remaining_eggs_to_hatch_8DC1
4956: 7E            ld   a,(hl)
4957: DD 77 A4      ld   (ix+$04),a
495A: 35            dec  (hl)
495B: 06 04         ld   b,$04
495D: CD C7 90      call update_sound_18c7
4960: DD 34 AD      inc  (ix+$05)
4963: 21 DF 24      ld   hl,maze_data_8C20+$3F
4966: 35            dec  (hl)
4967: DD 7E 80      ld   a,(ix+$00)
496A: F6 82         or   $02
496C: DD 77 A8      ld   (ix+$00),a
496F: DD 34 A5      inc  (ix+$05)
4972: 3A 24 88      ld   a,(counter_lsb_8824)
4975: E6 1F         and  $1F
4977: C0            ret  nz
	;; counter 1 out of 32 broken block shatters
4978: DD 35 00      dec  (ix+$00)
497B: DD 7E A0      ld   a,(ix+$00)
497E: E6 A7         and  $07
4980: C0            ret  nz
4981: DD 7E 81      ld   a,(ix+$01)
4984: 3D            dec  a
4985: 28 E9         jr   z,$49C8
4987: DD 77 81      ld   (ix+$01),a
498A: DD 35 AD      dec  (ix+$05)
498D: 47            ld   b,a
498E: 3E A0         ld   a,$08
4990: 90            sub  b
4991: DD CB A0 76   bit  6,(ix+$00)
4995: 28 06         jr   z,$499D
4997: FE 06         cp   $06
4999: 38 02         jr   c,$499D
499B: 3E 08         ld   a,$08
499D: 87            add  a,a
499E: 87            add  a,a
499F: C6 68         add  a,$60
49A1: F5            push af
49A2: DD 4E AA      ld   c,(ix+$02)
49A5: DD 46 83      ld   b,(ix+$03)
49A8: ED 43 A8 20   ld   (cursor_x_8800),bc
49AC: CD EF 09      call convert_coords_to_screen_address_296F
49AF: 3E 1C         ld   a,$1C
49B1: BE            cp   (hl)
49B2: 28 82         jr   z,$49BE
49B4: 3E 81         ld   a,$09
49B6: 32 A2 88      ld   (cursor_color_8802),a
49B9: F1            pop  af
49BA: CD A0 2F      call set_2x2_tile_2F00
49BD: C9            ret
49BE: F1            pop  af
49BF: DD 36 80 A8   ld   (ix+$00),$00
49C3: DD 36 85 A8   ld   (ix+$05),$00
49C7: C9            ret
49C8: DD CB A8 DE   bit  6,(ix+$00)
49CC: 20 88         jr   nz,$49EE
49CE: DD 4E 02      ld   c,(ix+$02)
49D1: DD 46 A3      ld   b,(ix+$03)
49D4: CD 09 43      call clear_2x2_tiles_at_current_pos_43A9
49D7: DD CB A0 6E   bit  5,(ix+$00)
49DB: 11 03 A0      ld   de,$0003
49DE: DD E5         push ix
49E0: C4 2F 08      call nz,add_to_current_player_score_28AF
49E3: DD E1         pop  ix
49E5: DD 36 80 A8   ld   (ix+$00),$00
49E9: DD 36 85 A8   ld   (ix+$05),$00
49ED: C9            ret
49EE: 21 40 8D      ld   hl,total_eggs_to_hatch_8DC0
49F1: 7E            ld   a,(hl)
49F2: 47            ld   b,a
49F3: 3E 0C         ld   a,$0C
49F5: 90            sub  b
49F6: CB 3F         srl  a
49F8: C6 80         add  a,$08
49FA: 4F            ld   c,a
49FB: DD 7E A4      ld   a,(ix+$04)
49FE: 90            sub  b
49FF: ED 44         neg
4A01: 81            add  a,c
4A02: 26 A0         ld   h,$00
4A04: 6F            ld   l,a
4A05: 22 28 88      ld   (cursor_x_8800),hl
4A08: DD 74 29      ld   (ix+$01),h
4A0B: DD 75 A4      ld   (ix+$04),l
4A0E: 3E B7         ld   a,$17
4A10: CD 94 29      call set_tile_at_current_pos_293C
4A13: DD 34 25      inc  (ix+$05)
4A16: C9            ret
4A17: DD 7E 20      ld   a,(ix+$00)
4A1A: F6 A7         or   $0F
4A1C: DD 77 00      ld   (ix+$00),a
4A1F: DD 34 A5      inc  (ix+$05)
4A22: 3A 24 88      ld   a,(counter_lsb_8824)
4A25: E6 AF         and  $0F
4A27: C0            ret  nz
	;; counter 1 out of 16 eggs hatching
4A28: DD 46 2B      ld   b,(ix+$03)
4A2B: DD 4E A2      ld   c,(ix+$02)
4A2E: DD CB 00 66   bit  0,(ix+$00)
4A32: 28 27         jr   z,$4A3B
4A34: 3E 30         ld   a,$10
4A36: CD 6C 4B      call set_2x2_tile_color_4BC4
4A39: 18 05         jr   $4A40
4A3B: 3E 0C         ld   a,$0C
4A3D: CD C4 E3      call set_2x2_tile_color_4BC4
4A40: DD 35 28      dec  (ix+$00)
4A43: DD 7E A0      ld   a,(ix+$00)
4A46: E6 87         and  $0F
4A48: C0            ret  nz
4A49: DD 66 A1      ld   h,(ix+$01)
4A4C: DD 6E 2C      ld   l,(ix+$04)
4A4F: 22 00 A8      ld   (cursor_x_8800),hl
4A52: 3E 00         ld   a,$20
4A54: CD 94 29      call set_tile_at_current_pos_293C
4A57: DD CB 20 6E   bit  5,(ix+$00)
4A5B: 20 12         jr   nz,$4A6F
4A5D: DD 46 23      ld   b,(ix+$03)
4A60: DD 4E 2A      ld   c,(ix+$02)
4A63: CD 81 E3      call clear_2x2_tiles_at_current_pos_43A9
4A66: DD 36 28 A0   ld   (ix+$00),$00
4A6A: DD 36 2D A0   ld   (ix+$05),$00
4A6E: C9            ret
4A6F: DD 34 25      inc  (ix+$05)
4A72: DD 36 01 25   ld   (ix+$01),$05
4A76: C9            ret
4A77: DD 7E 20      ld   a,(ix+$00)
4A7A: F6 23         or   $03
4A7C: DD 77 00      ld   (ix+$00),a
4A7F: DD 34 A5      inc  (ix+$05)
4A82: 3A 24 88      ld   a,(counter_lsb_8824)
4A85: E6 BF         and  $1F
4A87: C0            ret  nz
	;; counter 1 out of 32 ???
4A88: DD 35 28      dec  (ix+$00)
4A8B: DD 7E A0      ld   a,(ix+$00)
4A8E: E6 A7         and  $07
4A90: C0            ret  nz
4A91: DD 7E 21      ld   a,(ix+$01)
4A94: 3D            dec  a
4A95: 28 2B         jr   z,$4AC2
4A97: DD 77 21      ld   (ix+$01),a
4A9A: DD 35 05      dec  (ix+$05)
4A9D: 47            ld   b,a
4A9E: 3E 24         ld   a,$04
4AA0: 90            sub  b
4AA1: 87            add  a,a
4AA2: 87            add  a,a
4AA3: C6 08         add  a,$80
4AA5: DD 4E A2      ld   c,(ix+$02)
4AA8: DD 46 2B      ld   b,(ix+$03)
4AAB: ED 43 A0 88   ld   (cursor_x_8800),bc
4AAF: F5            push af
4AB0: 3E 30         ld   a,$10
4AB2: DD CB 01 66   bit  0,(ix+$01)
4AB6: 28 22         jr   z,$4ABA
4AB8: 3E A4         ld   a,$0C
4ABA: 32 22 88      ld   (cursor_color_8802),a
4ABD: F1            pop  af
4ABE: CD 20 A7      call set_2x2_tile_2F00
4AC1: C9            ret
4AC2: DD 34 2D      inc  (ix+$05)
4AC5: C9            ret
4AC6: DD 7E 28      ld   a,(ix+$00)
4AC9: F6 A8         or   $08
4ACB: DD 77 A0      ld   (ix+$00),a
4ACE: DD 34 05      inc  (ix+$05)
4AD1: DD 4E 22      ld   c,(ix+$02)
4AD4: DD 46 03      ld   b,(ix+$03)
4AD7: ED 43 20 88   ld   (cursor_x_8800),bc
4ADB: 3E 10         ld   a,$10
4ADD: 32 02 A8      ld   (cursor_color_8802),a
4AE0: 3E 98         ld   a,$98
4AE2: CD A0 A7      call set_2x2_tile_2F00
4AE5: 3A 24 88      ld   a,(counter_lsb_8824)
4AE8: E6 17         and  $3F
4AEA: C0            ret  nz
	;; counter 1 out of 64
4AEB: DD 35 A0      dec  (ix+$00)
4AEE: DD 7E 00      ld   a,(ix+$00)
4AF1: E6 0F         and  $0F
4AF3: C0            ret  nz
4AF4: DD 4E 02      ld   c,(ix+$02)
4AF7: DD 46 23      ld   b,(ix+$03)
4AFA: CD 89 43      call clear_2x2_tiles_at_current_pos_43A9
4AFD: 11 32 20      ld   de,$0032
4B00: CD 2F 08      call add_to_current_player_score_28AF
4B03: DD 36 80 A8   ld   (ix+$00),$00
4B07: DD 36 85 A8   ld   (ix+$05),$00
4B0B: C9            ret

4B0C: DD 21 20 25   ld   ix,moving_block_struct_8DA0
4B10: DD CB 17 56   bit  7,(ix+$17)
4B14: C8            ret  z
4B15: 3A 24 88      ld   a,(counter_lsb_8824)
4B18: 47            ld   b,a
4B19: E6 3F         and  $3F
4B1B: C0            ret  nz
	;; counter 1 out of 64
4B1C: CB 70         bit  6,b
4B1E: 28 A6         jr   z,$4B26
4B20: 3E A1         ld   a,$09
4B22: CD AC CB      call $4B2C
4B25: C9            ret
4B26: 3E A4         ld   a,$0C
4B28: CD AC CB      call $4B2C
4B2B: C9            ret
4B2C: DD 4E B8      ld   c,(ix+$10)
4B2F: DD 46 B1      ld   b,(ix+$11)
4B32: CD EC 4B      call set_2x2_tile_color_4BC4
4B35: DD 4E B2      ld   c,(ix+$12)
4B38: DD 46 13      ld   b,(ix+$13)
4B3B: CD C4 C3      call set_2x2_tile_color_4BC4
4B3E: DD 4E BC      ld   c,(ix+$14)
4B41: DD 46 95      ld   b,(ix+$15)
4B44: CD 44 CB      call set_2x2_tile_color_4BC4
4B47: C9            ret
	
blink_on_egg_locations_4B48:
4B48: DD 21 E0 25   ld   ix,total_eggs_to_hatch_8DC0
4B4C: DD CB 9F FE   bit  7,(ix+$1f)
4B50: C8            ret  z	; no blink
	
4B51: DD CB 97 66   bit  4,(ix+$1f)
4B55: CC 5C C3      call z,$4B5C
4B58: CD 41 4B      call $4B69
4B5B: C9            ret
	
4B5C: DD 7E 1F      ld   a,(ix+$1f)
4B5F: F6 8E         or   $0E
4B61: DD 77 B7      ld   (ix+$1f),a
4B64: DD CB 9F 4E   set  4,(ix+$1f)
4B68: C9            ret
	
4B69: 3A 2C 20      ld   a,(counter_lsb_8824)
4B6C: E6 A7         and  $0F
4B6E: C0            ret  nz
	;; counter 1 out of 16:	egg blink
4B6F: DD 35 97      dec  (ix+$1f)
4B72: DD 7E 1F      ld   a,(ix+$1f)
4B75: E6 0F         and  $0F
4B77: C0            ret  nz
4B78: DD CB 1F 2E   res  4,(ix+$1f)
4B7C: DD 7E 1E      ld   a,(ix+$1e)
4B7F: 3D            dec  a
4B80: 28 87         jr   z,$4B89
4B82: DD 77 9E      ld   (ix+$1e),a
4B85: CD 93 E3      call $4B9B
4B88: C9            ret

4B89: DD 36 B7 A8   ld   (ix+$1f),$00
4B8D: 3A 36 25      ld   a,(moving_block_struct_8DA0+$16)
4B90: A7            and  a
4B91: C8            ret  z
4B92: DD 36 1F A8   ld   (ix+char_state),$80
4B96: DD 36 1E 80   ld   (ix+ai_mode),$08
4B9A: C9            ret
	
	;; blink loop routine (snobee color)
4B9B: DD 46 A0      ld   b,(ix+$00) ; total number
4B9E: 21 EA 85      ld   hl,egg_location_table_8DC2 ; egg location table
4BA1: C5            push bc
4BA2: E5            push hl
4BA3: 4E            ld   c,(hl)	; get x
4BA4: 23            inc  hl
4BA5: 46            ld   b,(hl)	; get y
4BA6: 78            ld   a,b
4BA7: 81            add  a,c
4BA8: 28 91         jr   z,$4BBB ; 0 -> not active anymore
	;; active
4BAA: 3A 83 85      ld   a,(snobee_1_struct_8D00+$03)
4BAD: DD CB B6 46   bit  0,(ix+$1e)
4BB1: CC C4 C3      call z,set_2x2_tile_color_4BC4
4BB4: DD CB 1E E6   bit  0,(ix+$1e)
4BB8: C4 D8 4B      call nz,set_2x2_tile_color_09_4BD8
4BBB: E1            pop  hl
4BBC: C1            pop  bc
4BBD: 23            inc  hl
4BBE: 23            inc  hl
4BBF: 10 60         djnz $4BA1
4BC1: C9            ret

set_2x2_tile_color_0C_4BC2:
4BC2: 3E A4         ld   a,$0C
set_2x2_tile_color_4BC4:
4BC4: CD 74 CB      call convert_coords_to_screen_attributes_address_4BDC
4BC7: 77            ld   (hl),a
4BC8: 0C            inc  c
4BC9: CD D4 E3      call convert_coords_to_screen_attributes_address_4BDC
4BCC: 77            ld   (hl),a
4BCD: 04            inc  b
4BCE: CD 74 4B      call convert_coords_to_screen_attributes_address_4BDC
4BD1: 77            ld   (hl),a
4BD2: 0D            dec  c
4BD3: CD DC C3      call convert_coords_to_screen_attributes_address_4BDC
4BD6: 77            ld   (hl),a
4BD7: C9            ret

set_2x2_tile_color_09_4BD8:
4BD8: 3E 81         ld   a,$09
4BDA: 18 48         jr   set_2x2_tile_color_4BC4

convert_coords_to_screen_attributes_address_4BDC:
4BDC: F5            push af
4BDD: CD 6F 01      call convert_coords_to_screen_address_296F
4BE0: 11 80 AC      ld   de,$0400
4BE3: 19            add  hl,de
4BE4: F1            pop  af
4BE5: C9            ret
	
handle_pengo_snobee_collisions_4BE6:
4BE6: DD 21 A0 25   ld   ix,pengo_struct_8D80
4BEA: DD 7E 9F      ld   a,(ix+char_state)
4BED: A7            and  a
4BEE: C8            ret  z
4BEF: FE 06         cp   $06
4BF1: D0            ret  nc
4BF2: CD 50 3E      call get_div8_ix_coords_3E78
4BF5: 60            ld   h,b
4BF6: 69            ld   l,c
4BF7: DD 21 A0 8D   ld   ix,snobee_1_struct_8D00
4BFB: CD 1C C4      call snobee_pengo_collision_test_4C1C
4BFE: 38 06         jr   c,snobee_collides_pengo_4C2E
4C00: DD 21 20 8D   ld   ix,snobee_2_struct_8D20
4C04: CD 94 EC      call snobee_pengo_collision_test_4C1C
4C07: 38 25         jr   c,snobee_collides_pengo_4C2E
4C09: DD 21 E0 8D   ld   ix,snobee_3_struct_8D40
4C0D: CD BC C4      call snobee_pengo_collision_test_4C1C
4C10: 38 B4         jr   c,snobee_collides_pengo_4C2E
4C12: DD 21 60 AD   ld   ix,snobee_4_struct_8D60
4C16: CD B4 4C      call snobee_pengo_collision_test_4C1C
4C19: 38 13         jr   c,snobee_collides_pengo_4C2E
4C1B: C9            ret

snobee_pengo_collision_test_4C1C:
4C1C: DD 7E 1F      ld   a,(ix+char_state)
4C1F: FE 2C         cp   $04
4C21: D0            ret  nc
4C22: CD 50 B6      call get_div8_ix_coords_3E78
4C25: 50            ld   d,b
4C26: 59            ld   e,c
4C27: CD 99 05      call compare_hl_to_de_2D99
4C2A: 37            scf		; set carry flag
4C2B: C8            ret  z
4C2C: 3F            ccf
4C2D: C9            ret
snobee_collides_pengo_4C2E:
4C2E: DD 21 80 AD   ld   ix,pengo_struct_8D80
4C32: DD 36 1F 20   ld   (ix+char_state),$00
4C36: DD 36 1E DF   ld   (ix+ai_mode),$FF
4C3A: 3E B2         ld   a,$1A
4C3C: 07            rlca
4C3D: 07            rlca
4C3E: DD 77 2A      ld   (ix+animation_frame),a
4C41: CD 83 11      call set_character_sprite_code_and_color_39AB
4C44: CD 9E A0      call get_nb_lives_289E
4C47: 3D            dec  a
4C48: C8            ret  z
4C49: 47            ld   b,a
4C4A: 3E 83         ld   a,$0B
4C4C: 32 A2 88      ld   (cursor_color_8802),a
4C4F: 0E 2C         ld   c,$2C
4C51: CD 26 85      call $2D26
4C54: C9            ret
	
handle_pengo_eats_stunned_snobees_4C55: 
4C55: DD 21 28 8D   ld   ix,pengo_struct_8D80
4C59: DD 7E B7      ld   a,(ix+char_state)
4C5C: A7            and  a
4C5D: C8            ret  z
4C5E: FE 26         cp   $06
4C60: D0            ret  nc
4C61: CD F0 16      call get_div8_ix_coords_3E78
4C64: 60            ld   h,b
4C65: 69            ld   l,c
4C66: DD 21 28 8D   ld   ix,snobee_1_struct_8D00
4C6A: CD AB EC      call $4C83
4C6D: DD 21 20 8D   ld   ix,snobee_2_struct_8D20
4C71: CD 83 E4      call $4C83
4C74: DD 21 40 AD   ld   ix,snobee_3_struct_8D40
4C78: CD 2B 4C      call $4C83
4C7B: DD 21 40 8D   ld   ix,snobee_4_struct_8D60
4C7F: CD 0B C4      call $4C83
4C82: C9            ret

4C83: DD 7E 97      ld   a,(ix+char_state)
4C86: FE A4         cp   $04
4C88: 28 A3         jr   z,$4C8D
4C8A: FE A5         cp   $05
4C8C: C0            ret  nz
4C8D: CD F0 16      call get_div8_ix_coords_3E78
4C90: 50            ld   d,b
4C91: 59            ld   e,c
4C92: CD B9 2D      call compare_hl_to_de_2D99
4C95: C0            ret  nz
4C96: DD 36 09 20   ld   (ix+$09),$00
4C9A: DD 36 1F 26   ld   (ix+char_state),$06
4C9E: C9            ret

ice_pack_tiles_6000:
     6000  00 00 00 00 00 00 00 00 A7 00 00 00 00 00 00 00
     6010  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
     6020  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
     6030  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
     6040  02 02 02 02 02 02 02 02 02 2B 00 3F 00 00 00 00
     6050  00 00 62 00 00 00 00 E5 92 02 02 02 02 02 02 00
     6060  02 02 02 02 02 02 02 02 12 2A 00 3F 00 00 00 00
     6070  00 00 61 70 00 00 00 86 8F 02 02 02 02 02 02 A6
     6080  02 02 02 02 02 02 02 02 02 29 00 3F 00 00 00 00
     6090  00 00 00 6F 00 00 00 6A 91 02 02 02 02 02 02 02
     60A0  02 02 02 02 02 02 02 02 11 28 3E 40 4F 00 00 00
     60B0  00 00 00 6E 00 00 00 6A 8A 02 02 02 02 02 02 02
     60C0  02 02 02 02 02 02 02 02 10 27 3D 40 4E 55 50 00
     60D0  00 00 00 3F 00 00 00 69 8A 02 02 02 02 02 02 02
     60E0  B8 BD 02 02 02 02 02 E1 0F 26 00 40 4D 54 50 00
     60F0  00 00 00 6D 00 00 00 6A 8A 02 02 02 02 02 02 02
     6100  04 04 C3 C9 C9 C9 D8 E0 0E 25 00 41 4C 53 50 00
     6110  00 00 00 6C 00 00 00 69 90 02 02 02 02 02 02 02
     6120  04 04 04 04 CD D4 D7 DF E4 24 00 41 4B 00 4E 00
     6130  00 00 00 6C 74 00 00 85 8F 02 02 02 02 02 02 A5
     6140  B7 B7 B7 C8 01 01 C2 BC 0D 00 00 41 00 00 4E 00
     6150  00 00 00 6B 73 00 00 E5 8E 02 02 02 02 02 02 00
     6160  01 01 01 01 C2 BC 03 CC 0C 23 3C 45 4A 00 4E 00
     6170  00 00 00 6A 02 00 00 84 8D 02 02 02 02 02 02 00
     6180  01 01 C2 BC 03 03 CC DE 0B 22 3B 44 49 00 4C 00
     6190  00 00 00 69 02 7A 00 83 8C 02 02 02 02 02 A4 00
     61A0  B6 BC 03 03 03 CC D6 DD 0A 21 3A 43 48 00 57 00
     61B0  00 00 00 69 02 79 00 01 02 02 02 02 02 02 A3 00
     61C0  03 03 03 03 CC 00 D5 D2 E3 20 39 42 47 00 56 00
     61D0  00 00 00 68 02 78 00 82 02 02 02 02 02 02 A2 00
     61E0  03 03 C1 C7 00 C0 D3 01 E2 1F 00 41 46 50 00 00
     61F0  00 5D 00 68 02 02 7D 81 02 02 02 02 02 02 00 00
     6200  B5 BB 00 00 C0 03 D2 D1 DB 1E 38 41 46 4E 00 00
     6210  00 5C 00 67 72 02 02 02 02 02 02 02 02 02 00 00
     6220  00 00 00 C0 03 D3 01 D0 DA 1D 37 41 00 52 00 00
     6230  00 5C 00 66 69 77 02 02 02 02 02 9B 9D A1 00 00
     6240  00 00 C0 03 03 D2 D1 04 D9 02 36 41 00 51 00 00
     6250  00 41 00 65 71 76 02 02 02 02 02 9A 9C A0 00 00..
     6260  B4 B0 03 03 BA 01 D0 DC 02 1C 35 41 00 4C 00 00
     6270  00 5F 00 64 00 75 7C 02 02 02 02 99 00 9F 00 00
     6280  03 03 03 BA 01 D1 04 DB 02 1B 34 41 00 4C 00 00
     6290  00 5E 00 64 00 00 7B 80 02 02 98 00 00 9E 00 00
     62A0  03 03 BA 01 01 D0 04 DA 09 1A 33 41 00 4C 00 00
     62B0  00 50 00 5C 00 00 00 7F 8B 02 13 00 00 00 00 00
     62C0  03 BA 01 01 CB 04 04 D9 08 19 00 41 00 4E 00 00
     62D0  5D 00 5D 41 00 00 00 4C 8A 02 13 00 00 00 00 00
     62E0  B3 01 01 C6 CA 04 CF 02 07 18 32 41 00 4E 00 00
     62F0  5C 00 60 63 00 00 00 68 8A 02 97 00 00 00 00 00
     6300  01 01 01 C5 04 04 CE 02 02 17 31 41 00 50 00 00
     6310  5B 00 00 00 00 00 00 7E 8A 02 97 00 00 00 00 00
     6320  01 01 BF 04 04 CF 02 02 06 00 30 40 00 00 00 00
     6330  5A 00 00 00 00 00 00 00 89 02 96 00 00 00 00 00
     6340  A8 AE 04 04 04 CE 02 02 05 16 2F 40 00 00 00 00
     6350  59 00 00 00 00 00 00 00 88 94 41 00 00 00 00 00
     6360  04 04 04 04 C4 02 02 02 02 15 2E 3F 00 00 00 00
     6370  58 00 00 00 00 00 00 00 4C 93 95 00 00 00 00 00
     6380  04 04 04 C4 02 02 02 02 02 14 2D 3F 00 00 00 00
     6390  00 00 00 00 00 00 00 00 87 00 00 00 00 00 00 00
     63A0  04 B9 BE 02 02 02 02 02 02 13 2C 3F 00 00 00 00
     63B0  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
     63C0  00 00 02 02 02 AD 04 04 04 04 AC 01 01 AB 03 03
     63D0  03 00 00 00 AA 03 03 A9 01 01 01 A8 04 04 00 00
     63E0  00 00 02 02 02 02 AD 04 04 04 B2 01 01 AB 03 03
     63F0  B1 00 00 00 B0 03 03 AF 01 01 01 AE 04 04 00 00


move_table_6400:
     6400  AA AA AA AA AA AA AE 00 00 00 00 00 00 00 00 00
     6410  00 00 00 00 A0 CA B8 BB BB 90 8B BC CB A8 AA AE¨ª®
     6420  9A 99 99 9D 99 80 BB 88 AA 88 AA 99 99 88 DA 00
     6430  99 99 99 99 99 99 99 09 9B B9 BB BB BB BB BB BB
     6440  BB BB BB BB BB BB BB BB BB BB BB BB BB BB BB BB
     6450  BB BB BB BB BB BB BB BB BB BB BB BB BB BB BB BB
     6460  BB BB BB BB BB BB BB BB BB BB BB BB FB BB A8 AE
     6470  0A A8 8A 88 B8 C8 BB 09 80 DA 99 99 99 00 88 08
     6480  AA 9D 99 89 B8 BB BB BB 9B B9 BB BB BB BB BB BB
     6490  BF 9B AA AA AA AA 90 9A A9 9A 99 99 99 99 99 99
     64A0  99 09 9B B9 BB 0B B8 8B 88 AA AA AA BE BB BB 80
     64B0  88 8C 88 88 88 88 88 88 88 88 88 88 88 88 C8 88
     64C0  88 AE 09 BB BB BB BB BB FB BB 0B 99 9D 09 B0 AA
     64D0  99 B9 BB BB 80 E8 AA AA 80 A8 AA AA AA 9A D9 B0
     64E0  9B B9 88 BB B9 8B AC 99 9B 0A D9 99 99 B0 BB BB
     64F0  90 BB 8B 08 AA AA AA AA 90 BB BB BB BB 80 BB BB
     6500  BB BB BB BB BB 90 99 09 00 88 BB BB 8F 99 A0 BA º
     6510  88 88 88 88 0A 88 88 0B BB 0B 00 AA 9A 99 99 B0
     6520  00 88 88 88 99 99 99 88 BB 9D 99 BB 99 AA AA AE
     6530  EA AA AA AA AA AA A9 BC 9B 99 A9 AA 0A A8 9D 99
     6540  99 99 99 99 99 99 99 99 99 99 99 99 99 99 99 99
     6550  99 09 8A 88 88 88 88 C8 00 00 00 00 00 00 00 00
     6560  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
     6570  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
     6580  00 99 BB 99 A9 3B 00 3B FF FF FF FF FF FF FF FF
     6590  FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF
     65A0  FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF
     65B0  FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF
     65C0  FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF
     65D0  FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF
     65E0  FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF
     65F0  FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF

move_table_6600:
     6600  AA AA AA AA AA AA AA AA AA AA AA AA AA AA AE 8A
     6610  88 88 88 88 08 B0 88 88 88 C8 B0 BB BB BB FB 8B
     6620  BB BB BB BB BB 80 BB BB BB BB BB BB BB BB BB BB
     6630  BB BB BB BB BB BB BB BB BB BB BB BB BB BB BB BB
     6640  BB BB BB BB BB BB BB BB FB 90 99 B0 BB BF BB BB
     6650  0B 99 D9 BB BB BB BB 00 99 99 99 99 99 99 99 99
     6660  99 99 99 9B 99 BB BB BF BB BB BB BB BB BB 80 88
     6670  88 88 88 88 88 88 88 88 88 88 88 88 88 88 88 08
     6680  A0 AA 99 99 99 99 99 99 99 99 99 09 9B 99 99 99...
     6690  A0 9A B9 C8 08 90 99 99 99 99 99 09 B0 BB BB BB»»»
     66A0  BB 0B B9 BB BB BB 80 88 88 8A C8 B8 08 A0 AA AAªª
     66B0  AA AA 88 AA AA AA 0A A9 88 C8 A9 99 B9 BB BF 99
     66C0  99 09 9B AA AA EA BA 99 99 99 99 99 9D 99 BD 8B
     66D0  88 AE 9A AA EA AA AA 0A 88 8C 88 AA AA AA AA AA
     66E0  AA 8E 88 88 88 A8 00 99 F9 88 88 B0 BB BB BB BB
     66F0  BB BF BB BB BF BB BB BB BB BB BB BB BB BB BB BB
     6700  BB BB BB BF BB BB BB BB BB BB 0B 99 FB FB BB BB
     6710  BB BB BB BB BB BB BB BB BB BB BB BB BB BB BB 90
     6720  99 99 D9 99 AA CA BB 9B BF BB BB BB BB BB BB BB
     6730  BB 90 8A A8 80 88 88 88 88 88 88 88 00 AA 88 BB
     6740  BB 99 AA AE 0A 00 00 00 00 00 00 00 00 00 AA 88
     6750  88 88 B0 88 88 C8 88 88 88 88 88 88 88 88 88 88
     6760  88 88 88 88 88 88 9A 99 99 9D 99 3B 00 3B 00 3B
     6770  FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF
     6780  FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF
     6790  FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF
     67A0  FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF
     67B0  FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF
     67C0  FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF
     67D0  FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF
     67E0  FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF
     67F0  FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF

misc_table_6800:
     6800  57 8F 03 03 03 03 03 03 03 06 03 03 03 03 03 03
     6810  03 03 03 03 03 03 03 03 06 03 8E 03 03 03 03 03
     6820  03 03 03 06 03 03 03 03 03 03 03 8D 03 03 03 03
     6830  03 03 03 06 03 03 03 03 03 03 06 03 03 03 03 03
     6840  03 03 06 03 03 03 03 03 03 06 03 03 03 03 03 03
     6850  06 03 03 03 56 03 06 8E 03 03 03 06 03 03 03 06
     6860  03 03 06 03 06 03 03 06 55 8F 06 06 06 06 06 01
     6870  06 01 01 01 54 01 01 01 01 01 01 01 07 53 01 01
     6880  07 01 07 07 07 07 8E 07 5F 02 07 02 02 07 8D 02
     6890  02 02 02 07 02 02 02 02 07 02 02 02 8C 02 02 07
     68A0  02 02 02 02 07 02 02 02 02 07 02 02 02 5E 02 07
     68B0  02 02 02 02 07 02 02 02 02 07 8A 02 02 02 07 02
     68C0  02 02 02 02 07 02 02 02 02 02 02 02 07 02 02 8B
     68D0  02 02 02 02 02 02 02 02 07 02 02 02 02 02 02 02
     68E0  8C 02 02 02 07 02 02 02 02 8D 02 02 02 02 8E 02
     68F0  02 02 02 52 8F 01 C0 01 01 01 01 01 01 01 01 01
     6900  8F 47 07 02 02 07 02 02 07 02 02 07 02 02 07 02
     6910  02 07 02 07 02 07 02 46 07 02 07 02 07 01 06 03
     6920  8C 03 06 03 03 03 06 03 03 06 03 03 03 03 03 45
     6930  06 03 03 03 03 06 03 03 03 03 03 06 03 03 03 03
     6940  06 03 8F 06 03 06 03 06 44 01 01 07 07 02 07 02
     6950  8E 02 07 02 02 02 07 02 02 02 02 07 8C 02 02 02
     6960  07 4F 02 02 07 02 02 02 07 02 02 07 02 07 02 02
     6970  02 07 02 8B 07 02 02 07 02 07 02 02 07 02 07 02
     6980  07 02 02 07 02 02 07 02 02 02 07 02 8A 02 07 02
     6990  07 4E 02 02 07 02 02 07 02 02 07 02 02 07 02 07
     69A0  02 07 02 07 02 07 8B 02 07 02 07 02 07 02 07 8C
     69B0  07 07 07 07 4D 07 07 07 07 8D 07 07 07 07 07 41
     69C0  01 07 07 8E 07 07 01 07 01 07 07 01 07 01 01 07
     69D0  01 07 01 01 01 07 01 01 01 01 01 01 01 01 01 01
     69E0  01 01 01 01 01 01 01 01 40 01 01 01 01 01 06 01
     69F0  01 8D 01 01 06 01 06 01 06 01 6C 06 06 06 06 06
     6A00  06 03 06 8C 03 03 03 06 03 03 03 03 03 03 03 03
     6A10  03 03 03 03 03 03 03 03 40 00 01 00 01 00 01 C0
     6A20  8F 47 01 01 01 02 02 02 02 02 02 02 02 02 02 02
     6A30  02 02 02 02 02 02 02 02 02 07 07 02 02 02 02 02
     6A40  02 02 02 02 02 02 02 02 02 02 02 02 02 02 02 02
     6A50  02 02 02 07 07 02 02 07 02 02 07 46 02 02 02 02
     6A60  02 02 02 02 02 02 07 07 07 02 02 02 02 02 02 02
     6A70  02 02 02 02 02 07 02 02 02 07 07 07 45 07 07 07
     6A80  02 07 07 07 02 07 07 02 02 07 44 07 07 07 07 07
     6A90  07 07 07 43 07 07 01 01 07 01 01 07 01 01 01 01
     6AA0  03 06 01 01 42 06 06 06 06 06 06 06 06 06 06 06
     6AB0  06 06 06 06 06 41 06 06 06 06 06 06 06 06 06 06
     6AC0  06 06 06 06 06 06 03 03 01 03 03 01 03 03 01 03
     6AD0  03 01 03 03 01 03 03 01 03 03 01 03 03 01 6D 03
     6AE0  03 03 03 03 03 03 03 41 C0 01 01 01 01 01 01 01
     6AF0  01 00 01 00 01 00 01 00 01 00 01 00 01 00 01 00
     6B00  8F 47 02 07 02 02 02 02 07 02 02 02 02 02 07 02
     6B10  02 02 02 07 02 02 02 02 07 02 02 02 02 07 02 02
     6B20  02 02 07 02 02 02 8E 46 07 02 02 07 02 02 02 07
     6B30  02 02 02 07 02 02 07 02 02 07 02 02 07 02 02 07
     6B40  02 02 8D 45 07 02 02 07 02 02 07 02 07 02 02 07
     6B50  02 07 02 07 02 07 8C 44 07 02 07 07 01 06 06 03
     6B60  03 06 03 03 03 03 06 03 03 03 03 03 03 03 03 03
     6B70  03 8B 6F 06 03 03 03 03 03 03 03 03 06 03 03 03
     6B80  03 03 03 03 03 06 03 03 03 03 03 03 06 03 03 03
     6B90  03 06 03 03 03 03 03 06 03 03 03 03 06 03 03 03
     6BA0  03 03 06 03 03 03 03 03 06 03 03 03 03 03 03 03
     6BB0  06 03 03 03 03 03 06 03 03 03 03 03 03 03 06 03
     6BC0  03 03 03 03 03 03 06 03 03 03 03 03 03 06 03 03
     6BD0  03 03 06 03 03 03 03 06 03 03 03 03 8A 6E 06 03
     6BE0  03 03 03 06 03 03 03 03 06 03 03 03 03 06 03 03
     6BF0  03 03 03 03 06 03 03 03 03 06 03 03 03 03 06 03
     6C00  03 03 06 03 03 42 C0 01 01 01 01 01 01 01 01 01
     6C10  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01
     6C20  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01
     6C30  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01
     6C40  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01
     6C50  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01
     6C60  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01
     6C70  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01
     6C80  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01
     6C90  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01
     6CA0  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01
     6CB0  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01
     6CC0  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01
     6CD0  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01
     6CE0  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01
     6CF0  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01
     6D00  8F 57 03 03 03 06 03 03 03 03 03 06 03 03 03 03
     6D10  03 06 03 03 03 03 03 03 06 03 03 03 06 03 03 03
     6D20  06 03 06 03 8E 56 06 03 06 03 06 03 06 06 06 06
     6D30  03 06 8D 55 06 03 06 03 06 03 06 06 03 06 03 03
     6D40  06 03 03 06 03 03 8C 54 06 03 03 06 03 03 03 06
     6D50  03 03 06 03 06 03 06 03 06 06 8B 53 06 01 06 01
     6D60  06 06 06 06 01 06 01 01 06 01 01 01 8A 52 06 01
     6D70  01 01 06 01 01 01 06 01 01 01 06 06 89 5E 06 06
     6D80  06 03 06 03 03 03 06 03 03 06 08 08 51 06 06 01
     6D90  01 01 07 01 01 07 07 07 07 87 5D 07 02 07 02 07
     6DA0  02 02 02 07 02 02 02 02 02 02 02 02 07 02 02 02
     6DB0  02 02 02 02 02 02 02 02 02 02 02 02 02 02 02 02
     6DC0  02 07 02 02 02 02 02 02 02 02 07 02 02 02 02 02
     6DD0  02 02 02 02 07 02 02 02 02 02 02 02 51 C0 00 01
     6DE0  00 01 00 01 00 01 00 01 00 01 00 01 00 01 00 01
     6DF0  00 01 00 01 00 01 00 01 00 01 00 01 00 01 00 01
     6E00  8F 47 01 07 07 01 07 01 07 8F 46 07 07 07 07 07
     6E10  01 07 07 8F 45 07 07 07 07 07 07 01 07 8F 44 07
     6E20  07 07 07 07 02 07 07 07 8F 43 07 07 02 07 07 07
     6E30  07 07 07 07 02 07 07 07 07 02 07 02 07 07 8F 42
     6E40  07 07 07 02 07 07 07 07 07 02 07 07 07 07 07 07
     6E50  07 07 07 8F 41 07 07 07 07 07 07 07 07 07 07 07
     6E60  07 07 07 07 07 07 07 07 07 07 07 07 07 07 07 01
     6E70  07 07 07 01 07 07 07 07 01 07 01 07 01 07 01 07
     6E80  01 01 01 01 01 8F 40 01 01 01 01 01 01 01 01 06
     6E90  01 01 06 01 01 06 01 06 01 06 06 01 06 06 01 06
     6EA0  06 06 06 06 06 06 06 8D 6C 06 06 03 06 06 06 06
     6EB0  06 03 06 03 06 03 06 03 03 06 03 03 03 03 06 03
     6EC0  03 03 03 06 03 03 03 03 03 03 03 03 03 03 03 03
     6ED0  03 06 03 03 03 03 03 03 03 03 03 03 03 03 03 03
     6EE0  03 03 03 03 06 03 03 03 03 03 03 03 03 03 03 03
     6EF0  03 06 03 03 03 03 03 03 03 03 03 03 03 03 03 03
     6F00  C0 03 03 03 03 03 01 01 40 C0 01 01 01 01 01 01
     6F10  01 C0 00 01 00 01 00 01 00 01 00 01 00 01 00 01
     6F20  00 01 00 01 00 01 00 01 00 01 00 01 00 01 00 01
     6F30  00 01 00 01 00 01 00 01 00 01 00 01 00 01 00 01
     6F40  00 01 00 01 00 01 00 01 00 01 00 01 00 01 00 01
     6F50  00 01 00 01 00 01 00 01 00 01 00 01 00 01 00 01
     6F60  00 01 00 01 00 01 00 01 00 01 00 01 00 01 00 01
     6F70  00 01 00 01 00 01 00 01 00 01 00 01 00 01 00 01
     6F80  00 01 00 01 00 01 00 01 00 01 00 01 00 01 00 01
     6F90  00 01 00 01 00 01 00 01 00 01 00 01 00 01 00 01
     6FA0  00 01 00 01 00 01 00 01 00 01 00 01 00 01 00 01
     6FB0  00 01 00 01 00 01 00 01 00 01 00 01 00 01 00 01
     6FC0  00 01 00 01 00 01 00 01 00 01 00 01 00 01 00 01
     6FD0  00 01 00 01 00 01 00 01 00 01 00 01 00 01 00 01
     6FE0  00 01 00 01 00 01 00 01 00 01 00 01 00 01 00 01
     6FF0  00 01 00 01 00 01 00 01 66 01 A6 01 EB 01 EA C0
     7000  E0 70 00 74 00 7D 80 72 80 77 80 74 FF 70 80 75
