
; based on "MSX-mouse PS/2 adapter v.2.0." by Kamil Karimov

; =============== S U B R O U T I N E =======================================

reset_ps2:
		; blink LED
		sbi		LED_PORT, LED_PIN
		rcall	delay_500ms
		cbi		LED_PORT, LED_PIN
		rcall	delay_500ms
		
		; send Reset (FF) command
		ser		ps2_accum
		rcall	ps2_send_command
		brcs	reset_ps2
		
		rcall	timeout_max
		
		; skip Self-test passed
		rcall	get_ps2
		brcs	reset_ps2
		
		; send Set Default (F6) command
		ldi		ps2_accum, 0xF6
		rcall	ps2_send_command
		brcs	reset_ps2
		
		; send Enable (F4) command
		ldi		ps2_accum, 0xF4
		rcall	ps2_send_command
		brcs	reset_ps2
		
		; send Set/Reset Status Indicators (ED) command
		ldi		ps2_accum, 0xED
		rcall	ps2_send_command
		brcs	reset_ps2
		; Turn off all LEDs
		ldi		ps2_accum, 0x00
		rcall	ps2_send_command
		brcs	reset_ps2
		
		; lightup LED
		sbi		LED_PORT, LED_PIN
		ret
; End of function reset_ps2


; =============== S U B R O U T I N E =======================================

; loads into ps2_accum
get_ps2_new:
		; set timeout
		rcall	timeout_40ms

get_ps2:
		; data and clk = in
		cbi		PS_DDR, PS_Data
		cbi		PS_DDR, PS_Clock

		; wait for data line to go low
psget_wait_data_lo:
		; check for Timer overflow
		sbrc	m_flags, TMRF_OVF
		rjmp	psget_timeout	; timedout
		sbic	PS_PINS, PS_Data
		rjmp	psget_wait_data_lo

		rcall	timeout_4ms
		rcall	wait_psclk_lo
		brcs	psget_timeout
		rcall	wait_psclk_hi
		brcs	psget_timeout
		
		ldi		ps2_tmp2, 8
psget_next_bit:
		rcall	wait_psclk_lo
		brcs	psget_timeout
		
		; read bit
		sbic	PS_PINS, PS_Data
		sec
		ror		ps2_accum
		
		rcall	wait_psclk_hi
		brcs	psget_timeout
		
		; move to next bit
		dec		ps2_tmp2
		brne	psget_next_bit
		
		; parity bit - skip
		rcall	wait_psclk_lo
		brcs	psget_timeout
		rcall	wait_psclk_hi
		brcs	psget_timeout
		; stop bit - skip
		rcall	wait_psclk_lo
		brcs	psget_timeout
		rcall	wait_psclk_hi
		brcs	psget_timeout
		
		; clk = out
		sbi		PS_DDR, PS_Clock
		ret

psget_timeout:
		; data = in, clk = out
		cbi		PS_DDR, PS_Data
		sbi		PS_DDR, PS_Clock
		sec
		ret
; End of function get_ps2

; ---------------------------------------------------------------------------
; START	OF FUNCTION CHUNK FOR ps2_send_command

ps2_resend_command:
		pop		ps2_accum
ps2_send_command:
		push	ps2_accum
		
		rcall	send_ps2
		brcs	pscommand_timeout
		
		rcall	get_ps2_new
		brcs	pscommand_timeout
		
		; check for "resend" - why?
		cpi		ps2_accum, 0xFE
		breq	ps2_resend_command
		
		; check for acknowledge
		cpi		ps2_accum, 0xFA 

pscommand_timeout:
		pop		ps2_tmp
		ret


; =============== S U B R O U T I N E =======================================

; sends from ps2_accum
send_ps2:
		sbi		PS_DDR, PS_Clock	; clk = out
		rcall	delay_100us
		sbi		PS_DDR, PS_Data	; data = out
		rcall	delay_5us
		cbi		PS_DDR, PS_Clock	; clk = in
		rcall	delay_5us
		
		; wait for clk to go low
		rcall	timeout_30ms
		rcall	wait_psclk_lo
		brcs	pssend_timeout
		
		; start data transfer
		rcall	timeout_4ms
		ldi		ps2_tmp2, 8
		clr		ps2_cksum	; clear checksum
		rjmp	pssend_start

pssend_new_bit:
		rcall	wait_psclk_lo
		brcs	pssend_timeout

pssend_start:
		; get bit
		ror		ps2_accum
		
		; setup data
		brcs	pssend_bit_zero
		sbi		PS_DDR, PS_Data	; set 1 on data line
		rjmp	pssend_bit_done
pssend_bit_zero:
		cbi		PS_DDR, PS_Data	; set 0 on data line
		inc		ps2_cksum	; inc checksum

pssend_bit_done:
		; wait for clk to go high
		rcall	wait_psclk_hi
		brcs	pssend_timeout
		; move to next bit
		dec		ps2_tmp2
		brne	pssend_new_bit
		
		; wait for clk to go low
		rcall	wait_psclk_lo
		brcs	pssend_timeout
		
		; parity bit
		cbi		PS_DDR, PS_Data
		sbrc	ps2_cksum, 0
		sbi		PS_DDR, PS_Data
		
		; wait for clk to go high
		rcall	wait_psclk_hi
		brcs	pssend_timeout
		; wait for clk to go low
		rcall	wait_psclk_lo
		brcs	pssend_timeout
		
		; stop bit
		cbi		PS_DDR, PS_Data
		; wait one more clk pulse
		rcall	wait_psclk_hi
		brcs	pssend_timeout
		
		rcall	wait_psclk_lo
		brcs	pssend_timeout
		; acknowledge
		sbic	PS_DDR, PS_Data
		brcs	pssend_timeout	; no acknowledge
		rcall	wait_psclk_hi
		brcs	pssend_timeout
		
		; wait for mouse to release data line
		rcall	timeout_4ms
pssend_wait_data_hi:
		; check for Timer1 overflow
		sbrc	m_flags, TMRF_OVF
		rjmp	pssend_timeout	; timedout
		sbis	PS_PINS, PS_Data
		rjmp	pssend_wait_data_hi
		
		cbi		PS_DDR, PS_Data
		sbi		PS_DDR, PS_Clock
		ret
		
pssend_timeout:
		; data = in, clk = out
		cbi		PS_DDR, PS_Data
		sbi		PS_DDR, PS_Clock
		sec
		ret


; =============== S U B R O U T I N E =======================================

wait_psclk_hi:
		; check for timer overflow
		sbrc	m_flags, TMRF_OVF
		rjmp	wait_psclk_timeout	; timeout
		sbis	PS_PINS, PS_Clock
		rjmp	wait_psclk_hi
		clc	; clk hi, clear carry
		ret
		
wait_psclk_lo:
		; check for timer overflow
		sbrc	m_flags, TMRF_OVF
		rjmp	wait_psclk_timeout	; timeout
		sbic	PS_PINS, PS_Clock
		rjmp	wait_psclk_lo
		clc	; clk lo, clear carry
		ret

wait_psclk_timeout:
		sec	; wait timeout, set carry
		ret
