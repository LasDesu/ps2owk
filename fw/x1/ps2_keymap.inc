.equ KEY_NONE		= 0x00

.equ KEY_1			= 0x02
.equ KEY_2			= 0x03
.equ KEY_3			= 0x04
.equ KEY_4			= 0x05
.equ KEY_5			= 0x06
.equ KEY_6			= 0x07
.equ KEY_7			= 0x08
.equ KEY_8			= 0x09
.equ KEY_9			= 0x0A
.equ KEY_0			= 0x0B

.equ KEY_Q			= 0x10
.equ KEY_W			= 0x11
.equ KEY_E			= 0x12
.equ KEY_R			= 0x13
.equ KEY_T			= 0x14
.equ KEY_Y			= 0x15
.equ KEY_U			= 0x16
.equ KEY_I			= 0x17
.equ KEY_O			= 0x18
.equ KEY_P			= 0x19

.equ KEY_A			= 0x1E
.equ KEY_S			= 0x1F
.equ KEY_D			= 0x20
.equ KEY_F			= 0x21
.equ KEY_G			= 0x22
.equ KEY_H			= 0x23
.equ KEY_J			= 0x24
.equ KEY_K			= 0x25
.equ KEY_L			= 0x26

.equ KEY_Z			= 0x2C
.equ KEY_X			= 0x2D
.equ KEY_C			= 0x2E
.equ KEY_V			= 0x2F
.equ KEY_B			= 0x30
.equ KEY_N			= 0x31
.equ KEY_M			= 0x32

.equ KEY_COMMA		= 0x33
.equ KEY_PERIOD		= 0x34
.equ KEY_TILDE		= 0x1A
.equ KEY_MINUS		= 0x0C
.equ KEY_EQUAL		= 0x0D
.equ KEY_BRL		= 0x1B
.equ KEY_BRR		= 0x2B
.equ KEY_SEMICOLON	= 0x27
.equ KEY_APOS		= 0x28
.equ KEY_SLASH		= 0x35
.equ KEY_BSLASH		= 0x5A

.equ KEY_ENTER		= 0x1C
.equ KEY_ESC		= 0x01
.equ KEY_SPACE		= 0x39
.equ KEY_BACKSPACE	= 0x0E
.equ KEY_TAB		= 0x0F
.equ KEY_INSERT		= 0xD2
.equ KEY_DELETE		= 0xD3

.equ KEY_F1			= 0x3B
.equ KEY_F2			= 0x3C
.equ KEY_F3			= 0x3D
.equ KEY_F4			= 0x3E
.equ KEY_F5			= 0x3F
.equ KEY_F6			= 0x40
.equ KEY_F7			= 0x41
.equ KEY_F8			= 0x42
.equ KEY_F9			= 0x43
.equ KEY_F10		= 0x44
.equ KEY_F11		= 0x57
.equ KEY_F12		= 0x58

.equ KEY_CTRL		= 0x1D
.equ KEY_LSHIFT		= 0x2A
.equ KEY_RSHIFT		= 0x35
.equ KEY_ALT		= 0x38
.equ KEY_CAPS		= 0x3A
.equ KEY_LGUI		= KEY_NONE
.equ KEY_RGUI		= KEY_NONE
.equ KEY_APPS		= KEY_NONE

.equ KEY_UP			= 0xC8
.equ KEY_DOWN		= 0xD0
.equ KEY_LEFT		= 0xCB
.equ KEY_RIGHT		= 0xCD
.equ KEY_HOME		= 0xC7
.equ KEY_END		= 0x5F
.equ KEY_PAGEUP		= 0x5C
.equ KEY_PAGEDOWN	= 0x5B

.equ KEY_NUMLOCK	= KEY_NONE
.equ KEY_KP_0		= 0x52
.equ KEY_KP_1		= 0x4F
.equ KEY_KP_2		= 0x50
.equ KEY_KP_3		= 0x51
.equ KEY_KP_4		= 0x4B
.equ KEY_KP_5		= 0x4C
.equ KEY_KP_6		= 0x4D
.equ KEY_KP_7		= 0x47
.equ KEY_KP_8		= 0x48
.equ KEY_KP_9		= 0x49
.equ KEY_KP_DOT		= 0x53
.equ KEY_KP_MUL		= 0x37
.equ KEY_KP_PLUS	= 0x4E
.equ KEY_KP_MINUS	= 0x4A
.equ KEY_KP_DIV		= 0x35


keymap_base:
;				0				1				2				3				4				5				6				7
;				8				9				A				B				C				D				E				F
	.db		KEY_NONE,		KEY_F9,			KEY_NONE,		KEY_F5,			KEY_F3,			KEY_F1,			KEY_F2,			KEY_F12			; 00
	.db		KEY_NONE,		KEY_F10,		KEY_F8,			KEY_F6,			KEY_F4,			KEY_TAB,		KEY_TILDE,		KEY_NONE		; 08
	
	.db		KEY_NONE,		KEY_ALT,		KEY_LSHIFT,		KEY_NONE,		KEY_CTRL,		KEY_Q,			KEY_1,			KEY_NONE		; 10
	.db		KEY_NONE,		KEY_NONE,		KEY_Z,			KEY_S,			KEY_A,			KEY_W,			KEY_2,			KEY_LGUI		; 18
	
	.db		KEY_NONE,		KEY_C,			KEY_X,			KEY_D,			KEY_E,			KEY_4,			KEY_3,			KEY_RGUI		; 20
	.db		KEY_NONE,		KEY_SPACE,		KEY_V,			KEY_F,			KEY_T,			KEY_R,			KEY_5,			KEY_APPS		; 28
	
	.db		KEY_NONE,		KEY_N,			KEY_B,			KEY_H,			KEY_G,			KEY_Y,			KEY_6,			KEY_NONE		; 30
	.db		KEY_NONE,		KEY_NONE,		KEY_M,			KEY_J,			KEY_U,			KEY_7,			KEY_8,			KEY_NONE		; 38
	
	.db		KEY_NONE,		KEY_COMMA,		KEY_K,			KEY_I,			KEY_O,			KEY_0,			KEY_9,			KEY_NONE		; 40
	.db		KEY_NONE,		KEY_PERIOD,		KEY_SLASH,		KEY_L,			KEY_SEMICOLON,	KEY_P,			KEY_MINUS,		KEY_NONE		; 48
	
	.db		KEY_NONE,		KEY_NONE,		KEY_APOS,		KEY_NONE,		KEY_BRL,		KEY_EQUAL,		KEY_NONE,		KEY_NONE		; 50
	.db		KEY_CAPS,		KEY_RSHIFT,		KEY_ENTER,		KEY_BRR,		KEY_NONE,		KEY_BSLASH,		KEY_NONE,		KEY_NONE		; 58
	
	.db		KEY_NONE,		KEY_NONE,		KEY_NONE,		KEY_NONE,		KEY_NONE,		KEY_NONE,		KEY_BACKSPACE,	KEY_NONE		; 60
	.db		KEY_NONE,		KEY_KP_1,		KEY_NONE,		KEY_KP_4,		KEY_KP_7,		KEY_NONE,		KEY_NONE,		KEY_NONE		; 68
	
	.db		KEY_KP_0,		KEY_KP_DOT,		KEY_KP_2,		KEY_KP_5,		KEY_KP_6,		KEY_KP_8,		KEY_ESC,		KEY_NUMLOCK		; 70
	.db		KEY_F11,		KEY_KP_PLUS,	KEY_KP_3,		KEY_KP_MINUS,	KEY_KP_MUL,		KEY_KP_9,		KEY_NONE,		KEY_NONE		; 78
	
	.db		KEY_NONE,		KEY_NONE,		KEY_NONE,		KEY_F7,			KEY_NONE,		KEY_NONE,		KEY_NONE,		KEY_NONE		; 80

keymap_e0_off68:
;				0				1				2				3				4				5				6				7
;				8				9				A				B				C				D				E				F
	.db		KEY_NONE,		KEY_END,		KEY_NONE,		KEY_LEFT,		KEY_HOME,		KEY_NONE,		KEY_NONE,		KEY_NONE		; 68
	.db		KEY_INSERT,		KEY_DELETE,		KEY_DOWN,		KEY_NONE,		KEY_RIGHT,		KEY_UP,			KEY_NONE,		KEY_NONE		; 70
	.db		KEY_NONE,		KEY_NONE,		KEY_PAGEDOWN,	KEY_NONE,		KEY_NONE,		KEY_PAGEUP,		KEY_NONE,		KEY_NONE		; 78
