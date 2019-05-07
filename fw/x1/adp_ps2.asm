; based on info from http://kyouichisato.blogspot.com/2014/07/sharp-x1-ps2.html
; and previous project: http://zxdesu.byethost32.com/2018/02/13/pc-8801-keyboard-adapter/

.ifdef DEVKIT

.message "Compiling ATmega328P based development kit version"
.include "m328Pdef.inc"

.equ	sys_freq	= 8000000

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

.message "Compiling ATtiny25 based final device version"
.include "tn25def.inc"

.equ	sys_freq	= 9600000

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

.def	s_store		= r5

.def	m_flags			= r6
.equ	KBDF_CTRL		= 0
.equ	KBDF_SHIFT		= 1
.equ	KBDF_KANA		= 2	; locked
.equ	KBDF_CAPS		= 3	; locked
.equ	KBDF_GRAPH		= 4
.equ	TMRF_OVF		= 5
.equ	PS2F_BREAK		= 6
.equ	PS2F_EXT		= 7

.def	m_flags2		= r7

.def	kbd_val_l	= r26
.def	kbd_val_h	= r27
.def	kbd_pos		= r25

.def	m_timer_l	= r8
.def	m_timer_h	= r9
.def	m_timer_inc	= r10

;.def	m_tmp		= r15

.def	ps2_tmp = r16
.def	ps2_tmp2 = r17
.def	ps2_accum = r18
.def	ps2_cksum = r19

.equ	prescale = 1024
.equ	kbd_clk = sys_freq / prescale
.equ	kbd_250u = 250000 / kbd_clk
.equ	kbd_700u = 700000 / kbd_clk
.equ	kbd_750u = 750000 / kbd_clk
.equ	kbd_1000u = 1000000 / kbd_clk
.equ	kbd_1750u = 1750000 / kbd_clk
.equ	kbd_pkt_len = 1 + 16 * 2 + 2


.CSEG ; ROM
	.org 0
		rjmp	reset
	
	.org OC0Aaddr
		rjmp	x1kbd_next

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
		ser		tmp
		out		OCR0A, tmp
		; clear on compare match
		ldi		tmp, (2<<WGM00)
		out		TCCR0A, tmp
		; 1024x prescaler
		ldi		tmp, (5<<CS00)
		out		TCCR0B, tmp
		; enable overflow interrupt
		ldi		tmp, (1<<OCIE0A)
	.ifdef DEVKIT
		sts		TIMSK0, tmp
	.else
		out		TIMSK, tmp
	.endif
		
		; set variables
		ldi		tmp, 0x5F
		mov		m_flags, tmp
		clr		m_timer_l
		clr		m_timer_h
		clr		kbd_pos
		ser		tmp
		mov		kbd_val_l, tmp
		mov		kbd_val_h, tmp
				
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
		sbi		LED_PORT, LED_PIN

packet_loop:
		; wait for data and process it
		rcall	get_ps2_new
		brcs	main_loop
		
		cbi		LED_PORT, LED_PIN
		rcall	process_ps2
		
		; repeat
		rjmp	packet_loop
		
x1kbd_next:
		in		s_store, SREG
		push	tmp
		
		; update timer
		clr		tmp
		add		m_timer_l, m_timer_inc
		adc		m_timer_h, tmp
		brcc	_process_kbd
		ldi		tmp, (1 << TMRF_OVF)
		or		m_flags, tmp
		
_process_kbd:
		tst		kbd_pos
		breq	_leave_x1kbd

		; update pin state
		bst		kbd_pos, 0
		in		tmp, KBD_PORT
		bld		tmp, KBD_PIN
		out		KBD_PORT, tmp
		
		cpi		kbd_pos, kbd_pkt_len
		ldi		tmp, kbd_700u	; start bit
		ldi 	tmph, 700/50
		brsh	_load_timer_val
		
		ldi		tmp, kbd_250u	; data impulse
		ldi 	tmph, 250/50
		sbrs	kbd_pos, 0
		rjmp	_load_timer_val
		
		; shift bits
		sec
		rol		kbd_val_l
		rol		kbd_val_h
		ldi		tmp, kbd_750u	; zero
		ldi 	tmph, 750/50
		brcc	_load_timer_val
		ldi		tmp, kbd_1750u	; one
		ldi 	tmph, 1750/50
		
_load_timer_val:
		out		OCR0A, tmp
		mov		m_timer_inc, tmph
		
		dec		kbd_pos
		brne	_leave_x1kbd
		
		; set 1ms timer updater
		ldi		tmp, kbd_1000u
		out		TCCR0B, tmp
		
_leave_x1kbd:
		pop		tmp
		out		SREG, s_store
		
		reti

x1kbd_send:
		ldi		kbd_pos, kbd_pkt_len
		
		cbi		KBD_PORT, KBD_PIN
		
		ldi		tmp, kbd_1000u
		out		OCR0A, tmp
		clr		tmp
		out		TCNT0, tmp
		
		ret

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

.equ	timer_ovf_2ms = 0x10000 - (2000/50)
timeout_2ms:
		ldi		tmp, low(timer_ovf_2ms)
		ldi		tmph, high(timer_ovf_2ms)
		rjmp	set_timer

.equ	timer_ovf_4ms = 0x10000 - (4000/50)
timeout_4ms:
		; 83 - FFAD
		ldi		tmp, low(timer_ovf_4ms)
		ldi		tmph, high(timer_ovf_4ms)
		rjmp	set_timer

.equ	timer_ovf_30ms = 0x10000 - (30000/50)
timeout_30ms:
		; 624 - FD90
		ldi		tmp, low(timer_ovf_30ms)
		ldi		tmph, high(timer_ovf_30ms)
		rjmp	set_timer

.equ	timer_ovf_40ms = 0x10000 - (40000/50)
timeout_40ms:
		; 832 - FCC0
		ldi		tmp, low(timer_ovf_40ms)
		ldi		tmph, high(timer_ovf_40ms)
		rjmp	set_timer
		
timeout_max:
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
		
		
		; set buffer
		cli
		mov		kbd_val_l, tmp
		mov		kbd_val_h, tmph
		sei

		ret

; tmp - scancode
process_ps2:
		; check if break
		cpi		ps2_accum, 0xF0
		breq	scan_break

		cpi		ps2_accum, 0xE0
		breq	scan_ext
		
		sbrs	m_flags, PS2F_EXT
		rjmp	load_map_base
		
		cpi		ps2_accum, 0x68
		brsh	load_map_ext

load_map_base:
		cpi		ps2_accum, 0x88
		brsh	scan_done

		; default keymap
		ldi		ZH, high(keymap_base << 1)
		ldi		ZL, low(keymap_base << 1)
		rjmp	get_keycode

load_map_ext:
		cpi		ps2_accum, 0x80
		brsh	scan_done
		
		subi	ps2_accum, 0x68
		ldi		ZH, high(keymap_e0_off68 << 1)
		ldi		ZL, low(keymap_e0_off68 << 1)
		rjmp	get_keycode

scan_ext:
		; mark next scancode as extended
		ldi		tmp, (1 << PS2F_EXT)
		or		m_flags, tmp
		ret

scan_break:
		; mark next scancode as break
		ldi		tmp, (1 << PS2F_BREAK)
		or		m_flags, tmp
		ret

scan_done:
		; clear flags
		ldi		tmp, ~((1 << PS2F_BREAK) | (1 << PS2F_EXT))
		and		m_flags, tmp
		ret

get_keycode:
		; get keycode from keymap
		add		ZL, ps2_accum
		clr		tmp
		adc		ZH, tmp
		lpm		tmp2, Z
		
		ldi		tmp, KBDF_SHIFT
		cpi		tmp2, KEY_LSHIFT
		breq	_set_mod_flags
		cpi		tmp2, KEY_RSHIFT
		breq	_set_mod_flags
		
		ldi		tmp, KBDF_CTRL
		cpi		tmp2, KEY_CTRL
		breq	_set_mod_flags
		
		ldi		tmp, KBDF_GRAPH
		cpi		tmp2, KEY_ALT
		sbrs	m_flags, PS2F_EXT
		breq	_set_mod_flags
		
		ldi		tmp, KBDF_CAPS
		cpi		tmp2, KEY_CAPS
		breq	_toggle_mod_flags
		
		ldi		tmp, KBDF_KANA
		cpi		tmp2, KEY_ALT
		sbrc	m_flags, PS2F_EXT
		breq	_toggle_mod_flags
		
		rjmp	_get_shjis_code

_toggle_mod_flags:
		sbrs	m_flags, PS2F_BREAK
		eor		m_flags, tmp
		clr		kbd_val_l
		rjmp	send_keycode

_set_mod_flags:
		and		m_flags, tmp
		sbrc	m_flags, PS2F_BREAK
		or		m_flags, tmp
		clr		kbd_val_l
		rjmp	send_keycode
		
_get_shjis_code:
		
		rjmp	send_keycode
		
send_keycode:
		mov		tmph, m_flags
		andi	tmph, 0x5F
		com		tmph
		mov		kbd_val_h, tmph
		rcall	x1kbd_send
		rjmp	scan_done


.include "ps2_keymap.inc"
.include "x1_keymap.inc"
