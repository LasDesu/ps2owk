.ifdef DEVKIT

.message "Compiling ATmega328P based development kit version"
.include "m328Pdef.inc"

.equ	KBD_PORT	= PORTB
.equ	KBD_DDR		= DDRB
.equ	KBD_PIN		= PINB0

.equ	PS_PORT		= PORTC
.equ	PS_DDR		= DDRC
.equ	PS_PINS		= PINC
.equ	PS_Data		= PINC0
.equ	PS_Clock	= PINC1

.equ	LED_PORT	= PORTC
.equ	LED_PIN		= PINC5

.else

.message "Compiling ATtiny13 based final device version"
.include "tn13def.inc"

.equ	KBD_PORT	= PORTB
.equ	KBD_DDR		= DDRB
.equ	KBD_PIN		= PINB3

.equ	PS_PORT		= PORTB
.equ	PS_DDR		= DDRB
.equ	PS_PINS		= PINB
.equ	PS_Data		= PINB0
.equ	PS_Clock	= PINB1

.equ	LED_PORT	= PORTB
.equ	LED_PIN		= PINB4

.endif

.def	tmp		= r16
.def	tmph	= r17
.def	tmp2	= r18

.def	m_timer_l	= r28
.def	m_timer_h	= r29

.def	m_flags			= r5
.equ	KBDF_ZENKAKU	= 0
.equ	KBDF_KANA		= 1
.equ	KBDF_CAPS		= 2
.equ	KBDF_BREAK		= 3
.equ	KBDF_EXT		= 4
.equ	TMRF_OVF		= 5

.def	s_store		= r6
.def	uart_val0	= r8
.def	uart_val1	= r9
.def	m_tmp		= r10

.def	ps2_tmp = r16
.def	ps2_tmp2 = r17
.def	ps2_accum = r18
.def	ps2_cksum = r19

.equ	sys_freq	= 8000000

.equ	kbd_clk		= 20800
.equ	prescale	= 8
.equ	kbd_div = sys_freq / kbd_clk / prescale

.equ	kbd_buf		= SRAM_START

.CSEG ; ROM
	.org 0
		rjmp	reset
	
	.org OC0Aaddr
		rjmp	uart_next

;	.org INT_VECTORS_SIZE
reset:
		cli
		
		; set stack
	.ifdef SPH
		ldi		tmp, high(RAMEND)
		out		SPH, tmp
	.endif
		ldi		tmp, low(RAMEND)
		out		SPL, tmp
		
		; set I/O
	.ifdef DEVKIT
		ldi		tmp, (0 << LED_PIN) | (0 << PS_Data) | (0 << PS_Clock)
		out		PORTC, tmp
		ldi		tmp, (1 << KBD_PIN)
		out		PORTB, tmp
		ldi		tmp, (1 << LED_PIN) | (0 << PS_Data) | (0 << PS_Clock)
		out		DDRC, tmp
		ldi		tmp, (1 << KBD_PIN)
		out		DDRB, tmp
	.else
		ldi		tmp, (1 << KBD_PIN) | (0 << LED_PIN) | (0 << PS_Data) | (0 << PS_Clock)
		out		PORTB, tmp
		ldi		tmp, (1 << KBD_PIN) | (1 << LED_PIN) | (0 << PS_Data) | (0 << PS_Clock)
		out		DDRB, tmp
	.endif
		
		; setup keyboard timer period
		ldi		tmp, kbd_div
		out		OCR0A, tmp
		; clear on compare match
		ldi		tmp, (2<<WGM00)
		out		TCCR0A, tmp
		; 8x prescaler
		ldi		tmp, (2<<CS00)
		out		TCCR0B, tmp
		; enable overflow interrupt
		ldi		tmp, (1<<OCIE0A)
	.if TIMSK0 < 0x40
		out		TIMSK0, tmp
	.else
		sts		TIMSK0, tmp
	.endif
		
		; fill keyboard buffer
		ldi		ZH, high(kbd_buf)
		ldi		ZL, low(kbd_buf)
		
		ser		tmp
		ldi		tmph, 0xE
fill_buf:
		st		Z+, tmp
		dec		tmph
		brne	fill_buf
		ldi		tmp, 0x7F
		st		Z, tmp
		
		; set variables
		clr		m_flags
		clr		m_timer_l
		clr		m_timer_h
		ser		tmp
		mov		uart_val0, tmp
		mov		uart_val1, tmp

		sei

		; debug
;		rcall	key_event
;		ldi		ps2_accum, 0x58
;		rcall	process_ps2
;		ldi		ps2_accum, 0x58
;		rcall	process_ps2
;		ldi		ps2_accum, 0x3A
;		rcall	process_ps2
		; debug
		
		rcall	reset_ps2

main_loop:
		; wait for data and process it
		rcall	get_ps2_new
		brcs	main_loop
		
		cbi		LED_PORT, LED_PIN
		rcall	process_ps2
		
		; repeat
		rjmp	main_loop
		
uart_next:
		in		s_store, SREG
		push	tmp

		; update pin state
		bst		uart_val0, 0
		in		tmp, KBD_PORT
		bld		tmp, KBD_PIN
		out		KBD_PORT, tmp
		
		; shift bits
		sec
		ror		uart_val1
		ror		uart_val0
		
		; process timer
		adiw	m_timer_l, 1
		brne	_leave_uart
		ldi		tmp, (1 << TMRF_OVF)
		or		m_flags, tmp

_leave_uart:
		pop		tmp
		out		SREG, s_store
		
		reti

; =============== S U B R O U T I N E =======================================

delay_500ms:
		ldi		tmp, 25
		mov		r4, tmp

loop_500ms:
		rcall	delay_20ms
		dec		r4
		brne	loop_500ms
		ret

delay_20ms:
		ldi		tmp, 200
		mov		r3, tmp

loop_20ms:
		rcall	delay_100us
		dec		r3
		brne	loop_20ms
		ret

delay_100us:
		ldi		tmp, 100
		rjmp	loop_5us

delay_5us:
		ldi		tmp, 5

loop_5us:
		nop
		rjmp	loop_5us_1

loop_5us_1:
		rjmp	loop_5us_2

loop_5us_2:
		dec		tmp
		brne	loop_5us
		ret

; =============== S U B R O U T I N E =======================================

timeout_2ms:
		; 42 - FFD6
		ldi		tmp, 0xD6
		ldi		tmph, 0xFF 
		rjmp	set_timer

timeout_4ms:
		; 83 - FFAD
		ldi		tmp, 0xAD
		ldi		tmph, 0xFF 
		rjmp	set_timer

timeout_30ms:
		; 624 - FD90
		ldi		tmp, 0x90
		ldi		tmph, 0xFD 
		rjmp	set_timer

timeout_40ms:
		; 832 - FCC0
		ldi		tmp, 0xC0
		ldi		tmph, 0xFC 
		rjmp	set_timer
		
timeout_max:
		; 00 - 256
		clr		tmp
		clr		tmph

set_timer:
		movw	m_timer_l, tmp
		; clear timer overflow flag
		ldi		tmp, ~(1 << TMRF_OVF)
		and		m_flags, tmp
		ret

.include "iface_ps2.inc"

key_event:
		mov		m_tmp, tmp
		
		; get row address
		mov		tmp, m_tmp
		swap	tmp
		andi	tmp, 0xF
		ldi		ZH, high(kbd_buf)
		ldi		ZL, low(kbd_buf)
		add		ZL, tmp
		clr		tmp
		adc		ZL, tmp
		
		; get bit mask
		mov		tmp, m_tmp
		andi	tmp, 7
		inc		tmp
		
		clr		tmph
		sec
get_mask:
		rol		tmph
		dec		tmp
		brne	get_mask
		
		; load current state
		ld		tmp, Z

		; make or break key
		sbrs	m_tmp, 3
		rjmp	key_make
		
		or		tmp, tmph
		rjmp	store_keys

key_make:
		com		tmph
		and		tmp, tmph
		
store_keys:
		; save new state
		st		Z, tmp

send_row_data:
		; prepare data for transmit
		; row
		mov		tmph, m_tmp
		swap	tmph
		andi	tmph, 0xF
		mov		m_tmp, tmph
		
		; mask
		swap	tmp
		mov		tmph, tmp
		andi	tmph, 0x0F
		andi	tmp, 0xF0
		or		tmp, m_tmp
		
		; calculate parity
		clr 	m_tmp
		ldi		tmp2, 16
		clc
calc_parity:
		ror		tmph
		ror		tmp
		brcc	parity_zero
		inc		m_tmp
parity_zero:
		dec		tmp2
		brne	calc_parity
		; put last bit back 
		ror		tmph
		ror		tmp
		
		;com		m_tmp	; for odd
		bst		m_tmp, 0
		bld		tmph, 12-8
		
		; make start/stop bits
		clc
		rol		tmp
		rol		tmph
		ori		tmph, 0xC0
		
		; set buffer
		cli
		mov		uart_val0, tmp
		mov		uart_val1, tmph
		sei

		ret

; tmp - scancode
process_ps2:
		; check if break
		cpi		ps2_accum, 0xF0
		breq	scan_break

		cpi		ps2_accum, 0xE0
		breq	scan_ext
		
		sbrc	m_flags, KBDF_EXT
		rjmp	scan_pref_e0
		
		ldi		tmp, KEY_F7
		cpi		ps2_accum, 0xB8	; F7
		breq	process_key88
		
		cpi		ps2_accum, 0x80
		brsh	scan_done

		; default keymap
		ldi		ZH, high(keymap_default << 1)
		ldi		ZL, low(keymap_default << 1)
		rjmp	get_keycode

scan_pref_e0:
		cpi		ps2_accum, 0x68
		brlo	scan_pref_e0_extra
		
		cpi		ps2_accum, 0x80
		brsh	scan_done

load_map_e0:
		subi	ps2_accum, 0x68
		ldi		ZH, high(keymap_e0 << 1)
		ldi		ZL, low(keymap_e0 << 1)
		rjmp	get_keycode

scan_pref_e0_extra:
		ldi		tmp, KEY_RRETURN
		cpi		ps2_accum, 0x5A	; kp enter
		breq	process_key88
		
		ldi		tmp, KEY_KP_DIV
		cpi		ps2_accum, 0x4A	; kp /
		breq	process_key88
		
		ldi		tmp, KEY_GRPH
		cpi		ps2_accum, 0x11	; ralt
		breq	process_key88
		
		ldi		tmp, KEY_ZENKAKU
		cpi		ps2_accum, 0x14	; rctrl
		breq	process_key88
		
		ldi		tmp, KEY_PC
		cpi		ps2_accum, 0x12	; printscreen
		breq	process_key88
		
		rjmp	scan_done
		
scan_ext:
		; mark next scancode as extended
		ldi		tmp, (1 << KBDF_EXT)
		or		m_flags, tmp
		ret

scan_break:
		; mark next scancode as break
		ldi		tmp, (1 << KBDF_BREAK)
		or		m_flags, tmp
		ret

scan_done:
		; clear flags
		ldi		tmp, ~((1 << KBDF_BREAK) | (1 << KBDF_EXT))
		and		m_flags, tmp
		sbi		LED_PORT, LED_PIN
		ret

get_keycode:
		; get PC88 keycode from keymap
		add		ZL, ps2_accum
		clr		tmp
		adc		ZH, tmp
		lpm		tmp, Z

.macro send_corrected
		bst		m_flags, KBDF_BREAK
		bld		tmp, 3
		rcall	key_event
		rcall	timeout_2ms
.endm
	
.macro send_paused
_wait_pre_pause:
		sbrs	m_flags, TMRF_OVF
		rjmp	_wait_pre_pause
		
		send_corrected
		
_wait_post_pause:
		sbrs	m_flags, TMRF_OVF
		rjmp	_wait_post_pause
.endm

; tmp - PC-88 key code
process_key88:
		cpi		tmp, KEY_NONE
		breq	scan_done
		
		sbrs	tmp, 3
		rjmp	_check_basic	; conventional codes
		
		; extended codes
		push	tmp
		send_paused
		pop		tmp
		
		cpi		tmp, KEY_BACKSPACE
		brsh	_check_insdels
		
		; F6-F10
		subi	tmp, (KEY_F6 - KEY_F1)
		push	tmp
		
		; send SHIFT on make, F1-F5 on break
		sbrs	m_flags, KBDF_BREAK
		ldi		tmp, KEY_SHIFT
		send_paused
		
		; send F1-F5 on make, SHIFT on break
		pop		tmp
		sbrc	m_flags, KBDF_BREAK
		ldi		tmp, KEY_SHIFT
		rjmp	_send_last
		
_check_insdels:
		cpi		tmp, KEY_HENKAN
		brsh	_check_spaces
		
		cpi		tmp, KEY_INS
		ldi		tmp, KEY_INSDEL
		brne	_send_last
		
		; INS
		ldi		tmp, KEY_SHIFT
		send_paused

		ldi		tmp, KEY_INSDEL
		rjmp	_send_last
		
_check_spaces:
		cpi		tmp, KEY_LRETURN
		brsh	_check_returns
		ldi		tmp, KEY_SPACE
		rjmp	_send_last
		
_check_returns:
		cpi		tmp, KEY_LSHIFT
		brsh	_check_shifts
		ldi		tmp, KEY_RETURN
		rjmp	_send_last

_check_shifts:
		ldi		tmp, KEY_SHIFT
		
_send_last:
		send_corrected
_process_leave:
		rjmp	scan_done

_check_basic:
		; check for sticky keys 
		ldi		tmph, (1 << KBDF_CAPS)
		cpi		tmp, KEY_CAPS
		breq	_update_switches
		
		ldi		tmph, (1 << KBDF_KANA)
		cpi		tmp, KEY_KANA
		breq	_update_switches

		ldi		tmph, (1 << KBDF_ZENKAKU)
		cpi		tmp, KEY_ZENKAKU
		brne	_send_last
		
_update_switches:
		sbrc	m_flags, KBDF_BREAK
		rjmp	scan_done
		
		cbr		tmp, 0x08
		
		; flip switch
		eor		m_flags, tmph
		and		tmph, m_flags
		brne	_switch_send
		sbr		tmp, 0x08
		
_switch_send:
		rcall	key_event
		
		; send Set/Reset Status Indicators (ED) command
		ldi		ps2_accum, 0xED
		rcall	ps2_send_command
		brcs	_process_leave
		; update keyboard leds
		mov		ps2_accum, m_flags
		andi	ps2_accum, 0x7
		rcall	ps2_send_command

		rjmp	_process_leave

.equ KEY_NONE		= 0xFF
.equ KEY_EXT		= 0x08

.equ KEY_RETURN		= 0x17
.equ KEY_AT			= 0x20
.equ KEY_A			= 0x21
.equ KEY_B			= 0x22
.equ KEY_C			= 0x23
.equ KEY_D			= 0x24
.equ KEY_E			= 0x25
.equ KEY_F			= 0x26
.equ KEY_G			= 0x27
.equ KEY_H			= 0x30
.equ KEY_I			= 0x31
.equ KEY_J			= 0x32
.equ KEY_K			= 0x33
.equ KEY_L			= 0x34
.equ KEY_M			= 0x35
.equ KEY_N			= 0x36
.equ KEY_O			= 0x37
.equ KEY_P			= 0x40
.equ KEY_Q			= 0x41
.equ KEY_R			= 0x42
.equ KEY_S			= 0x43
.equ KEY_T			= 0x44
.equ KEY_U			= 0x45
.equ KEY_V			= 0x46
.equ KEY_W			= 0x47
.equ KEY_X			= 0x50
.equ KEY_Y			= 0x51
.equ KEY_Z			= 0x52
.equ KEY_BRL		= 0x53
.equ KEY_YEN		= 0x54
.equ KEY_BRR		= 0x55
.equ KEY_TILDE		= 0x56
.equ KEY_MINUS		= 0x57
.equ KEY_0			= 0x60
.equ KEY_1			= 0x61
.equ KEY_2			= 0x62
.equ KEY_3			= 0x63
.equ KEY_4			= 0x64
.equ KEY_5			= 0x65
.equ KEY_6			= 0x66
.equ KEY_7			= 0x67
.equ KEY_8			= 0x70
.equ KEY_9			= 0x71
.equ KEY_COLON		= 0x72
.equ KEY_SEMICOLON	= 0x73
.equ KEY_COMMA		= 0x74
.equ KEY_PERIOD		= 0x75
.equ KEY_SLASH		= 0x76
.equ KEY_UNDERSCORE	= 0x77
.equ KEY_HOMECLR	= 0x80
.equ KEY_UP			= 0x81
.equ KEY_RIGHT		= 0x82
.equ KEY_INSDEL		= 0x83
.equ KEY_GRPH		= 0x84
.equ KEY_KANA		= 0x85
.equ KEY_SHIFT		= 0x86
.equ KEY_CTRL		= 0x87
.equ KEY_STOP		= 0x90
.equ KEY_F1			= 0x91
.equ KEY_F2			= 0x92
.equ KEY_F3			= 0x93
.equ KEY_F4			= 0x94
.equ KEY_F5			= 0x95
.equ KEY_SPACE		= 0x96
.equ KEY_ESC		= 0x97
.equ KEY_TAB		= 0xA0
.equ KEY_DOWN		= 0xA1
.equ KEY_LEFT		= 0xA2
.equ KEY_HELP		= 0xA3
.equ KEY_COPY		= 0xA4
.equ KEY_CAPS		= 0xA7
.equ KEY_ROLLUP		= 0xB0
.equ KEY_ROLLDOWN	= 0xB1

.equ KEY_KP_0		= 0x00
.equ KEY_KP_1		= 0x01
.equ KEY_KP_2		= 0x02
.equ KEY_KP_3		= 0x03
.equ KEY_KP_4		= 0x04
.equ KEY_KP_5		= 0x05
.equ KEY_KP_6		= 0x06
.equ KEY_KP_7		= 0x07
.equ KEY_KP_8		= 0x10
.equ KEY_KP_9		= 0x11
.equ KEY_KP_MUL		= 0x12
.equ KEY_KP_PLUS	= 0x13
.equ KEY_KP_EQUAL	= 0x14
.equ KEY_KP_COMMA	= 0x15
.equ KEY_KP_PERIOD	= 0x16
.equ KEY_KP_MINUS	= 0xA5
.equ KEY_KP_DIV		= 0xA6

.equ KEY_F6			= (0xC0 | KEY_EXT)
.equ KEY_F7			= (0xC1 | KEY_EXT)
.equ KEY_F8			= (0xC2 | KEY_EXT)
.equ KEY_F9			= (0xC3 | KEY_EXT)
.equ KEY_F10		= (0xC4 | KEY_EXT)
.equ KEY_BACKSPACE	= (0xC5 | KEY_EXT)
.equ KEY_INS		= (0xC6 | KEY_EXT)
.equ KEY_DEL		= (0xC7 | KEY_EXT)
.equ KEY_HENKAN		= (0xD0 | KEY_EXT)
.equ KEY_KETTEI		= (0xD1 | KEY_EXT)
.equ KEY_PC			= 0xD2
.equ KEY_ZENKAKU	= 0xD3	; half-width
.equ KEY_LRETURN	= (0xE0 | KEY_EXT)
.equ KEY_RRETURN	= (0xE1 | KEY_EXT)
.equ KEY_LSHIFT		= (0xE2 | KEY_EXT)
.equ KEY_RSHIFT		= (0xE3 | KEY_EXT)

keymap_default:
;				0				1				2				3				4				5				6				7
;				8				9				A				B				C				D				E				F
	.db		KEY_NONE,		KEY_F9,			KEY_NONE,		KEY_F5,			KEY_F3,			KEY_F1,			KEY_F2,			KEY_COPY		; 00
	.db		KEY_NONE,		KEY_F10,		KEY_F8,			KEY_F6,			KEY_F4,			KEY_TAB,		KEY_AT,			KEY_NONE		; 08
	
	.db		KEY_NONE,		KEY_KANA,		KEY_LSHIFT,		KEY_NONE,		KEY_CTRL,		KEY_Q,			KEY_1,			KEY_NONE		; 10
	.db		KEY_NONE,		KEY_NONE,		KEY_Z,			KEY_S,			KEY_A,			KEY_W,			KEY_2,			KEY_NONE		; 18
	
	.db		KEY_NONE,		KEY_C,			KEY_X,			KEY_D,			KEY_E,			KEY_4,			KEY_3,			KEY_NONE		; 20
	.db		KEY_NONE,		KEY_SPACE,		KEY_V,			KEY_F,			KEY_T,			KEY_R,			KEY_5,			KEY_NONE		; 28
	
	.db		KEY_NONE,		KEY_N,			KEY_B,			KEY_H,			KEY_G,			KEY_Y,			KEY_6,			KEY_NONE		; 30
	.db		KEY_NONE,		KEY_NONE,		KEY_M,			KEY_J,			KEY_U,			KEY_7,			KEY_8,			KEY_NONE		; 38
	
	.db		KEY_NONE,		KEY_COMMA,		KEY_K,			KEY_I,			KEY_O,			KEY_0,			KEY_9,			KEY_NONE		; 40
	.db		KEY_NONE,		KEY_PERIOD,		KEY_SLASH,		KEY_L,			KEY_SEMICOLON,	KEY_P,			KEY_MINUS,		KEY_NONE		; 48
	
	.db		KEY_NONE,		KEY_NONE,		KEY_COLON,		KEY_NONE,		KEY_BRL,		KEY_TILDE,		KEY_NONE,		KEY_NONE		; 50
	.db		KEY_CAPS,		KEY_RSHIFT,		KEY_LRETURN,	KEY_BRR,		KEY_NONE,		KEY_YEN,		KEY_NONE,		KEY_NONE		; 58
	
	.db		KEY_NONE,		KEY_NONE,		KEY_NONE,		KEY_NONE,		KEY_NONE,		KEY_NONE,		KEY_BACKSPACE,	KEY_NONE		; 60
	.db		KEY_NONE,		KEY_KP_1,		KEY_NONE,		KEY_KP_4,		KEY_KP_7,		KEY_NONE,		KEY_NONE,		KEY_NONE		; 68
	
	.db		KEY_KP_0,		KEY_KP_PERIOD,	KEY_KP_2,		KEY_KP_5,		KEY_KP_6,		KEY_KP_8,		KEY_ESC,		KEY_KP_EQUAL	; 70
	.db		KEY_STOP,		KEY_KP_PLUS,	KEY_KP_3,		KEY_KP_MINUS,	KEY_KP_MUL,		KEY_KP_9,		KEY_NONE,		KEY_NONE		; 78
	
	;.db		KEY_NONE,		KEY_NONE,		KEY_NONE,		KEY_F7,			KEY_NONE,		KEY_NONE,		KEY_NONE,		KEY_NONE		; 80

keymap_e0:
;				0				1				2				3				4				5				6				7
;				8				9				A				B				C				D				E				F
	.db		KEY_NONE,		KEY_HELP,		KEY_NONE,		KEY_LEFT,		KEY_HOMECLR,	KEY_NONE,		KEY_NONE,		KEY_NONE		; 68
	.db		KEY_INS,		KEY_DEL,		KEY_DOWN,		KEY_NONE,		KEY_RIGHT,		KEY_UP,			KEY_NONE,		KEY_NONE		; 70
	.db		KEY_NONE,		KEY_NONE,		KEY_ROLLDOWN,	KEY_NONE,		KEY_NONE,		KEY_ROLLUP,		KEY_NONE,		KEY_NONE		; 78
