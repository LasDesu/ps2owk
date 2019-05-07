
.message "Compiling ATtiny13 based final device version"
.include "tn13def.inc"

.equ	sys_freq	= 9600000

.equ	KBD_PORT	= DDRB
.equ	KBD_PIN		= PINB3

.equ	PS_PORT		= PORTB
.equ	PS_DDR		= DDRB
.equ	PS_PINS		= PINB
.equ	PS_Data		= PINB0
.equ	PS_Clock	= PINB1

.equ	LED_PORT	= PORTB
.equ	LED_PIN		= PINB4


.def	tmp		= r16
.def	tmph	= r17
.def	tmp2	= r18

.def	m_timer_l	= r26
.def	m_timer_h	= r27

.def	m_tmp		= r5
.def	m_flags		= r6
.equ	KBDF_BREAK	= 5
.equ	KBDF_EXT	= 6
.equ	TMRF_OVF	= 7

.def	s_store		= r7

.def	m_tmp2		= r8

.def	ps2_tmp = r16
.def	ps2_tmp2 = r17
.def	ps2_accum = r18
.def	ps2_cksum = r19

.equ	kbd_clk		= 10500
.equ	prescale	= 8
.equ	kbd_div = sys_freq / kbd_clk / prescale

.equ	KBDBUF_SIZE	= 10

.CSEG ; ROM
	.org 0
		rjmp	reset

	.org OC0Aaddr
		rjmp	kbd_next

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
		ldi		tmp, (0 << KBD_PIN) | (0 << LED_PIN) | (0 << PS_Data) | (0 << PS_Clock)
		out		PORTB, tmp
		ldi		tmp, (0 << KBD_PIN) | (1 << LED_PIN) | (0 << PS_Data) | (0 << PS_Clock)
		out		DDRB, tmp

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
		ldi		YH, high(kbd_buf + KBDBUF_SIZE)
		ldi		YL, low(kbd_buf + KBDBUF_SIZE)
		clr		tmp
		ldi		tmph, KBDBUF_SIZE
_prefill_buf:
		st		-Y, tmp
		dec		tmph
		brne	_prefill_buf

		; set variables
		clr		m_flags
		clr		m_timer_l
		clr		m_timer_h
		clr		tmp
		sts		manch_code, tmp
		sts		scan_bit, tmp
		sts		immediate_scan, tmp
		sts		key_index, tmp

		sei

		; debug
;		ldi		tmp, FMKEY_B
;		sts		immediate_scan, tmp
		; debug

		rcall	reset_ps2

main_loop:
		sbi		LED_PORT, LED_PIN

packet_loop:
		; wait for data and process it
		;rcall	get_ps2_new
		rcall	timeout_20ms
		rcall	get_ps2
		brcs	main_loop

		cbi		LED_PORT, LED_PIN
		rcall	process_ps2

		; repeat
		rjmp	packet_loop

kbd_next:
		in		s_store, SREG
		push	tmp

		; process timer
		adiw	m_timer_l, 1
		brne	_timer_noovf
		ldi		tmp, (1 << TMRF_OVF)
		or		m_flags, tmp
_timer_noovf:

		; check if manchester buffer is empty
		lds		tmp, manch_code
		cpi		tmp, 0x02
		brsh 	_send_manch

		; check timeout
		lds		tmp, scan_timeout
		tst		tmp
		brne	_tick_scan_timeout

		; form new manchester code
		lds		tmp, scan_bit
		tst		tmp
		breq	_next_scan_code
		dec		tmp
		sts		scan_bit, tmp

		; next scancode bit
		lds		tmp, kbd_scan
		sec		; set one for stop bit
		rol		tmp
		sts		kbd_scan, tmp

		; set appropriate manchester code in buffer
		ldi		tmp, 0x10 | 9	; zero
		brcc	_send_manch
		ldi		tmp, 0x10 | 6	; one

_send_manch:
		; update pin state
		bst		tmp, 0

		; shift bits
		clc
		ror		tmp
		sts		manch_code, tmp

		; set pin state
		in		tmp, KBD_PORT
		bld		tmp, KBD_PIN
		out		KBD_PORT, tmp

_leave_kbd_proc:
		pop		tmp
		out		SREG, s_store

		reti

_tick_scan_timeout:
		dec		tmp
		sts		scan_timeout, tmp
		breq	_set_start_bits

		rjmp	_leave_kbd_proc

_next_scan_code:
		; check for data in immediate buffer
		lds		tmp, immediate_scan
		tst		tmp
		brne	_set_new_scan

		; check for data in main buffer
		rcall	buffer_get_keycode
		brcc	_set_new_scan

		; no keycodes to send, remember that
		clr		tmp
		sts		manch_code, tmp
		sts		scan_timeout, tmp

		rjmp	_leave_kbd_proc

_set_new_scan:
		sts		kbd_scan, tmp
		ldi		tmp, 8+1	; 8 data bits + stop bit
		sts		scan_bit, tmp
		clr		tmp			; clear immediate buffer
		sts		immediate_scan, tmp

		; send immediately if packet start
		lds		tmp, manch_code
		tst		tmp
		breq	_set_start_bits

		; set ~20ms timeout
		ldi		tmp, 21 * kbd_clk / 1000
		sts		scan_timeout, tmp

		rjmp	_leave_kbd_proc

_set_start_bits:
		; start bits
		ldi		tmp, (0x1A | (1 << 6)) ; (0x25 | (1 << 6)) noninverted
		rjmp	_send_manch


; =============== S U B R O U T I N E =======================================

; for transmitter interrupt handler
buffer_get_keycode:
		push	tmph
		push	tmp2

		ldi		tmph, key_index
		ldi		tmp2, KBDBUF_SIZE

_get_check_next_entry:
		cpi		tmph, KBDBUF_SIZE
		brlo	_get_check_entry

		; jump to start of buffer if overflow
		ldi		YH, high(kbd_buf)
		ldi		YL, low(kbd_buf)
		clr		tmph

_get_check_entry:
		ld		tmp, Y+
		inc		tmph
		tst		tmp
		brne	_get_process_scancode

		dec		tmp2
		brne	_get_check_next_entry

		; no scan codes found
		pop		tmp2
		pop		tmph
		sec
		ret

_get_process_scancode:
		; just return if make code
		sbrs	tmp, 7
		rjmp	_save_new_index

		; clear break code
		sbiw	r28, 1	; Y = r28,r29
		clr		tmp2
		st		Y+, tmp2

_save_new_index:
		sts		key_index, tmph

		pop		tmp2
		pop		tmph
		clc
		ret

; for receiver
store_keycode:
		mov		m_tmp, tmp	; store original code
		clr		m_tmp2

		ldi		ZH, high(kbd_buf)
		ldi		ZL, low(kbd_buf)
		ldi		tmp2, KBDBUF_SIZE

		andi	tmp, 0x7F	; mask make/break

_store_next_scan:
		ld		tmph, Z+
		andi	tmph, 0x7F
		breq	_store_mark_free_slot
		cp		tmph, tmp
		breq	_store_put_keycode

_store_iterate_scan:
		dec		tmp2
		brne	_store_next_scan

		tst		m_tmp2
		breq	_store_no_space

		ldi		ZH, high(kbd_buf + KBDBUF_SIZE)
		ldi		ZL, low(kbd_buf + KBDBUF_SIZE)
		sub		ZL, m_tmp2
		sbci	ZH, 0
		st		Z, m_tmp

_store_no_space:
		ret

_store_mark_free_slot:
		mov		m_tmp2, tmp2
		rjmp	_store_iterate_scan

_store_put_keycode:
		st		-Z, m_tmp
		ret

; delay subroutines for PS/2 handler
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

.equ	timer_ovf_2ms = 0x10000 - (2*kbd_clk/1000)
timeout_2ms:
		ldi		tmp, low(timer_ovf_2ms)
		ldi		tmph, high(timer_ovf_2ms)
		rjmp	set_timer

.equ	timer_ovf_4ms = 0x10000 - (4*kbd_clk/1000)
timeout_4ms:
		; 83 - FFAD
		ldi		tmp, low(timer_ovf_4ms)
		ldi		tmph, high(timer_ovf_4ms)
		rjmp	set_timer

.equ	timer_ovf_20ms = 0x10000 - (20*kbd_clk/1000)
timeout_20ms:
		; 624 - FD90
		ldi		tmp, low(timer_ovf_20ms)
		ldi		tmph, high(timer_ovf_20ms)
		rjmp	set_timer

.equ	timer_ovf_30ms = 0x10000 - (30*kbd_clk/1000)
timeout_30ms:
		; 624 - FD90
		ldi		tmp, low(timer_ovf_30ms)
		ldi		tmph, high(timer_ovf_30ms)
		rjmp	set_timer

.equ	timer_ovf_40ms = 0x10000 - (40*kbd_clk/1000)
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
		ldi		tmp, low( ~(1 << TMRF_OVF) )
		and		m_flags, tmp
		ret

.include "iface_ps2.inc"


; tmp - scancode
process_ps2:
		; check if break
		cpi		ps2_accum, 0xF0
		breq	scan_break

		cpi		ps2_accum, 0xE0
		breq	scan_ext

		sbrs	m_flags, KBDF_EXT
		rjmp	_scan_no_pref

		cpi		ps2_accum, 0x68
		brsh	_scan_pref_off68

		cpi		ps2_accum, 0x14	; right Ctrl
		ldi		tmp, FMKEY_KANA
		breq	set_keycode

_scan_no_pref:
		cpi		ps2_accum, 0x88
		brsh	scan_done

		; default keymap
		ldi		ZH, high(keymap_base << 1)
		ldi		ZL, low(keymap_base << 1)
		rjmp	get_keycode

_scan_pref_off68:
		cpi		ps2_accum, 0x68
		brlo	_load_map_e0

		cpi		ps2_accum, 0x80
		brsh	scan_done

_load_map_e0:
		subi	ps2_accum, 0x68
		ldi		ZH, high(keymap_e0_off68 << 1)
		ldi		ZL, low(keymap_e0_off68 << 1)
		rjmp	get_keycode

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

get_keycode:
		; get keycode from keymap
		add		ZL, ps2_accum
		clr		tmp
		adc		ZH, tmp
		lpm		tmp, Z

set_keycode:
		; update break flag
		bst		m_flags, KBDF_BREAK
		bld		tmp, 7

		;sts		immediate_scan, tmp
		rcall		store_keycode

scan_done:
		; clear flags
		ldi		tmp, ~((1 << KBDF_BREAK) | (1 << KBDF_EXT))
		and		m_flags, tmp
		ret

.include "keymap.inc"

.DSEG

immediate_scan:	.byte 1
kbd_scan:		.byte 1
scan_bit:		.byte 1
manch_code: 	.byte 1

scan_timeout:	.byte 1
key_index:		.byte 1
kbd_buf:		.byte KBDBUF_SIZE
