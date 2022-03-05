;Jomari Francisco 61090544
;Jayden Guo 52089281
;Frank Jin 39925508

$NOLIST
$MODLP51
$LIST

CLK           EQU 22118400 ; Microcontroller system crystal frequency in Hz
TIMER0_RATE   EQU 4000    ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RATE2  EQU 4200 
TIMER0_RELOAD EQU ((65536-(CLK/TIMER0_RATE)))
TIMER0_RELOAD2 EQU ((65536-(CLK/TIMER0_RATE2)))

C6  EQU ((65536-(CLK/1046*2)))
D6  EQU ((65536-(CLK/1175*2)))
Ef6 EQU ((65536-(CLK/1244*2)))
F6  EQU ((65536-(CLK/1397*2)))
G6  EQU ((65536-(CLK/1568*2)))
Af6 EQU ((65536-(CLK/1661*2)))


;Buttons
START_BUTTON equ P2.4
SOUND_OUT 	 equ P1.1
SEED_BUTTON  equ P4.5
RESET_BUTTON equ P2.2

org 0000H
   ljmp MyProgram

org 0x000B
	ljmp Timer0_ISR

; Timer/Counter 2 overflow interrupt vector
org 0x002B
	ljmp Timer2_ISR

cseg
; These 'equ' must match the hardware wiring
LCD_RS equ P3.2
;LCD_RW equ PX.X ; Not used in this code, connect the pin to GND
LCD_E  equ P3.3
LCD_D4 equ P3.4
LCD_D5 equ P3.5
LCD_D6 equ P3.6
LCD_D7 equ P3.7

$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$LIST

DSEG at 0x30

Period_A: ds 3
Period_B: ds 3
T2ov:     ds 1

;math32 variables
x:   ds 4
y:   ds 4
bcd: ds 5

Seed: ds 4 ;Used for the random number generation

;Counter for the points
Player_1_Counter: ds 1
Player_2_Counter: ds 1

BSEG
mf: dbit 1
start_finish_flag: dbit 1 ;Used to check which mode we are in
high_low_flag: dbit 1 ;Used to track if playing 2000 Hz or 2100 Hz
winner_flag1: dbit 1
winner_flag2: dbit 1

$NOLIST
$include(math32.inc)
$LIST

CSEG
;                      1234567890123456    <- This helps determine the location of the counter
Initial_Message1:  db 'Period A:       ', 0
Initial_Message2:  db 'Period B:       ', 0
winner_message:    db 'Winner!', 0
player1win:        db 'Player 1 Wins!  ', 0
player2win:        db 'Player 2 Wins!  ', 0
clear_message:     db '                ', 0
Player_1:		   db 'Player 1:     ', 0
Player_2:		   db 'Player 2:     ', 0
Initial_Message:   db 'Welcome!       ', 0

;------------;
;Timer 0 Init;
;------------;
;Initialize Timer 0 for the speaker for 2000 Hz
Timer0_Init:

	mov a, TMOD
	anl a, #0xf0 ; Clear the bits for timer 0
	orl a, #0x01 ; Configure timer 0 as 16-timer
	mov TMOD, a
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
	; Set autoreload value
	mov RH0, #high(TIMER0_RELOAD)
	mov RL0, #low(TIMER0_RELOAD)
	; Enable the timer and interrupts
    setb ET0  ; Enable timer 0 interrupt
    setb TR0  ; Start timer 0

	ret

;For 2100 Hz
Timer0_Init2:

	mov a, TMOD
	anl a, #0xf0 ; Clear the bits for timer 0
	orl a, #0x01 ; Configure timer 0 as 16-timer
	mov TMOD, a
	mov TH0, #high(TIMER0_RELOAD2)
	mov TL0, #low(TIMER0_RELOAD2)
	; Set autoreload value
	mov RH0, #high(TIMER0_RELOAD2)
	mov RL0, #low(TIMER0_RELOAD2)
	; Enable the timer and interrupts
    setb ET0  ; Enable timer 0 interrupt
    setb TR0  ; Start timer 0

	ret

Timer0_ISR:
	;clr TF0  ; According to the data sheet this is done for us already.
	cpl SOUND_OUT ; Connect speaker to P0.0
	reti

;---------------------------------;
; ISR for timer 2                 ;
;---------------------------------;
Timer2_ISR:
	clr TF2  ; Timer 2 doesn't clear TF2 automatically. Do it in ISR.
	inc T2ov
	reti

Init_Seed:
	setb TR2
	jb SEED_BUTTON, $
	clr TR2
	mov Seed+0, TH2
	mov Seed+1, #0x01
	mov Seed+2, #0x87
	mov Seed+3, TL2
	ret

; When using a 22.1184MHz crystal in fast mode
; one cycle takes 1.0/22.1184MHz = 45.21123 ns
; (tuned manually to get as close to 1s as possible)
Wait1s:
    mov R2, #176
X3: mov R1, #250
X2: mov R0, #166
X1: djnz R0, X1 ; 3 cycles->3*45.21123ns*166=22.51519us
    djnz R1, X2 ; 22.51519us*250=5.629ms
    djnz R2, X3 ; 5.629ms*176=1.0s (approximately)
    ret

WaitQuarSec:
    mov R2, #22
O3: mov R1, #250
O2: mov R0, #166
O1: djnz R0, O1 ; 3 cycles->3*45.21123ns*166=22.51519us
    djnz R1, O2 ; 22.51519us*250=5.629ms
    djnz R2, O3 ; 5.629ms*89=0.5s (approximately)
    ret

eigthnote:
    lcall WaitQuarSec
    setb ET0
    lcall WaitQuarSec
    clr ET0
    ret

rest_eightnote:
    lcall WaitQuarSec
    clr ET0
    lcall WaitQuarSec
    ret

;Initializes timer/counter 2 as a 16-bit timer
InitTimer2:
	mov T2CON, #0b_0000_0000 ; Stop timer/counter.  Set as timer (clock input is pin 22.1184MHz).
	; Set the reload value on overflow to zero (just in case is not zero)
	mov RCAP2H, #0
	mov RCAP2L, #0
	setb ET2  ; Enable timer 2 interrupt to count overflow
    ret

;Converts the hex number in T2ov-TH2 to BCD in R2-R1-R0
hex2bcdtwo:
	clr a
    mov R0, #0  ;Set BCD result to 00000000 
    mov R1, #0
    mov R2, #0
    mov R3, #16 ;Loop counter.

hex2bcd_loop:
    mov a, TH2 ;Shift T2ov-TH2 left through carry
    rlc a
    mov TH2, a
    
    mov a, T2ov
    rlc a
    mov T2ov, a
      
	; Perform bcd + bcd + carry
	; using BCD numbers
	mov a, R0
	addc a, R0
	da a
	mov R0, a
	
	mov a, R1
	addc a, R1
	da a
	mov R1, a
	
	mov a, R2
	addc a, R2
	da a
	mov R2, a
	
	djnz R3, hex2bcd_loop
	ret

Display_10_digit_BCD:
	Display_BCD(bcd+4)
	Display_BCD(bcd+3)
	Display_BCD(bcd+2)
	Display_BCD(bcd+1)
	Display_BCD(bcd+0)
	ret

; Dumps the 5-digit packed BCD number in R2-R1-R0 into the LCD
DisplayBCD_LCD:
	; 5th digit:
    mov a, R2
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 4th digit:
    mov a, R1
    swap a
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 3rd digit:
    mov a, R1
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 2nd digit:
    mov a, R0
    swap a
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 1st digit:
    mov a, R0
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
    
    ret

;---------------------------------;
; Hardware initialization         ;
;---------------------------------;
Initialize_All:
    lcall InitTimer2
    lcall LCD_4BIT ; Initialize LCD
    lcall Init_Seed
    lcall Timer0_Init
    setb EA ; enable interrupts
	ret

;---------------------------------;
; Main program loop               ;
;---------------------------------;
MyProgram:
    ; Initialize the hardware:
    mov SP, #7FH
    lcall Initialize_All
    ; Make sure the two input pins are configure for input
    setb P2.0 ; Pin is used as input
    setb P2.1 ; Pin is used as input

    mov Player_1_Counter, #0x00
	mov Player_2_Counter, #0x00
	clr start_finish_flag ;when it is 0 we go back to the welcome screen 1 we show the points
	clr high_low_flag
	setb ET0
    clr winner_flag1
    clr winner_flag2



button_check:

	jb START_BUTTON, setting_display_bridge
	Wait_Milli_Seconds(#50)
	jb START_BUTTON, setting_display_bridge
	jnb START_BUTTON, $
continue_welcome_check:
	cpl start_finish_flag
    sjmp setting_display_bridge

setting_display_bridge:
	ljmp setting_display

winner_flag_checker:
    jnb winner_flag1, check_winner_2 ;Check if someone has won the game
    ljmp winner1_flag_on
check_winner_2:
    jnb winner_flag2, forever_bridge
    ljmp winner2_flag_on
    ;If someone has won then wait until button press occurs

forever_bridge:
    ljmp forever

loop_winner_until_reset:

    jb RESET_BUTTON, winner_flag_checker
    Wait_Milli_Seconds(#50)
    jb RESET_BUTTON, winner_flag_checker
    jnb RESET_BUTTON, $
    cpl start_finish_flag
    clr winner_flag1
    clr winner_flag2
    mov Player_1_Counter, #0x00
    mov Player_2_Counter, #0x00

    ljmp button_check

winner1_flag_on:
    Set_Cursor(1,1)
    Send_Constant_String(#player1win)
    Set_Cursor(2,1)
    Send_Constant_String(#clear_message)
    ljmp loop_winner_until_reset

winner2_flag_on:
    Set_Cursor(2,1)
    Send_Constant_String(#player2win)
    Set_Cursor(1,1)
    Send_Constant_String(#clear_message)
    ljmp loop_winner_until_reset



    
forever:

    lcall Wait_Random
    lcall Randomize_Tone
    jb high_low_flag, high_sound

;-------------;
;Speaker Pitch;
;-------------;
low_sound:
	lcall Timer0_Init
	sjmp checking
high_sound:
	lcall Timer0_Init2
	sjmp checking

checking:
    setb ET0
    mov r5, #0x14

decrement_r5:
    djnz r5, start_calculation
    clr ET0 
    ljmp button_check


start_calculation:
    ; Measure the period applied to pin P2.0
    clr TR2 ; Stop counter 2
    mov TL2, #0
    mov TH2, #0
    mov T2ov, #0
    jb P2.0, $
    jnb P2.0, $
    mov R0, #0 ; 0 means repeat 256 times
    setb TR2 ; Start counter 0
meas_loop1:
    jb P2.0, $
    jnb P2.0, $
    djnz R0, meas_loop1 ; Measure the time of 100 periods
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.0 for later use
    mov Period_A+0, TL2
    mov Period_A+1, TH2
    mov Period_A+2, T2ov

    mov x+0, Period_A+0
    mov x+1, Period_A+1
    mov x+2, Period_A+2
    mov x+3, #0x0

    Load_y(1159000)
    lcall x_gt_y

	; Convert the result to BCD and display on LCD
	;Set_Cursor(1, 1)
    ;lcall hex2bcd
    ;lcall Display_10_digit_BCD
    ;sjmp continue

    jnb mf, continue
    lcall timer_1_check
    mov r5, #0x01
    ljmp decrement_r5

continue:
    ; Measure the period applied to pin P2.1
    clr TR2 ; Stop counter 2
    mov TL2, #0
    mov TH2, #0
    mov T2ov, #0
    jb P2.1, $
    jnb P2.1, $
    mov R0, #0 ; 0 means repeat 256 times
    setb TR2 ; Start counter 0
meas_loop2:
    jb P2.1, $
    jnb P2.1, $
    djnz R0, meas_loop2 ; Measure the time of 100 periods
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.1 for later use
    mov Period_B+0, TL2
    mov Period_B+1, TH2
    mov Period_B+2, T2ov

    mov x+0, Period_B+0
    mov x+1, Period_B+1
    mov x+2, Period_B+2
    mov x+3, #0x0

    Load_y(1189000)
    lcall x_gt_y

    

	; Convert the result to BCD and display on LCD
	;Set_Cursor(2, 1)
    ;lcall hex2bcd
    ;lcall Display_10_digit_BCD
    ;ljmp start_calculation

    jnb mf, decrement_r5_bridge
    lcall timer_2_check
    mov r5, #0x01
    
    ljmp decrement_r5
    
decrement_r5_bridge:
    ljmp decrement_r5 ; Repeat! 


;-----------------------------------------------;
;												;			
;				Added Functions					;
;												;
;-----------------------------------------------;

setting_display:
	jb start_finish_flag, start_off_display
	Set_Cursor(1,1)
	;Send_Constant_String(#clear_message)
	Set_Cursor(2,1)
	Send_Constant_String(#clear_message)
	Set_Cursor(1,1)
	Send_Constant_String(#Initial_Message)
    
    lcall kahoot

	ljmp button_check

start_off_display:


	Set_Cursor(1,1)
	Send_Constant_String(#Player_1)
	Set_Cursor(2,1)
	Send_Constant_String(#Player_2)

	
	Set_Cursor(1, 15)
	Display_BCD(Player_1_Counter)

	Set_Cursor(2, 15)
	Display_BCD(Player_2_Counter)
	ljmp winner_flag_checker

;---------------------;
;Random Seed Generator;
;---------------------;

Random:

	mov x+0, Seed+0
	mov x+1, Seed+1
	mov x+2, Seed+2
	mov x+3, Seed+3
	Load_y(214013)
	lcall mul32
	Load_y(2531011)
	lcall add32
	mov Seed+0, x+0
	mov Seed+1, x+1
	mov Seed+2, x+2
	mov Seed+3, x+3

	ret

;------------;
;Tone to play;
;------------;
Randomize_Tone:
	lcall Random
	mov a, Seed+1
	mov c, acc.3
	mov high_low_flag, c
	
	ret

;--------------------;
;Randomized Wait Time;
;--------------------;
Wait_Random:
	Wait_Milli_Seconds(Seed+0)
	Wait_Milli_Seconds(Seed+1)
	Wait_Milli_Seconds(Seed+2)
	Wait_Milli_Seconds(Seed+3)

	ret

;---------------------;
;Check if valid input ;
;Increments the points;
;---------------------;
timer_1_check:

    jnb high_low_flag, decrement_1 ;Checks if it was a valid input
    sjmp give_point_player1

timer_2_check:

    jnb high_low_flag, decrement_2
    sjmp give_point_player2

give_point_player1:
    mov a, Player_1_Counter
    add a, #0x01
    da a
    cjne a, #0x05, mov_to_counter1
    ljmp display_winner_player1

mov_to_counter1:
    mov Player_1_Counter, a
    Set_Cursor(1, 15)
	Display_BCD(Player_1_Counter)
	clr mf; reset the mf flag
    ret
    ;Once we've validated the input, the new sound should play
    ;Don't need to check the input of the other timer anymore, it would just be redundant calculations

give_point_player2:
    mov a, Player_2_Counter
    add a, #0x01
    da a
    cjne a, #0x05, mov_to_counter2
    ljmp display_winner_player2

mov_to_counter2:
    mov Player_2_Counter, a
    Set_Cursor(2, 15)
	Display_BCD(Player_2_Counter)
	clr mf; reset the mf flag
    ret

;Decrements player 1 if pressed on the wrong tone
decrement_1:
    mov a, Player_1_Counter
    cjne a, #0x00, add_99_1
    sjmp decrement_1_end

add_99_1:
    add a, #0x99
    da a

decrement_1_end:
    sjmp mov_to_counter1

;Decrements player 1 if pressed on the wrong tone
decrement_2:
    mov a, Player_2_Counter
    cjne a, #0x00, add_99_2
    sjmp decrement_1_end

add_99_2:
    add a, #0x99
    da a

decrement_2_end:
    sjmp mov_to_counter2


display_winner_player1:
    Set_Cursor(1,1)
    Send_Constant_String(#player1win)
    Set_Cursor(2,1)
    Send_Constant_String(#clear_message)
    setb winner_flag1
    ret ;Might want to change this to MyProgram later because we want to reset the game after winning

display_winner_player2:
    Set_Cursor(2,1)
    Send_Constant_String(#player2win)
    Set_Cursor(1,1)
    Send_Constant_String(#clear_message)
    setb winner_flag2
    ret

c_note:

    clr TR0
	mov RH0, #high(C6)
	mov RL0, #low(C6)
	setb TR0
    ret

d_note:

    clr TR0
	mov RH0, #high(D6)
	mov RL0, #low(D6)
	setb TR0
    ret

e_flat_note:

    clr TR0
	mov RH0, #high(Ef6)
	mov RL0, #low(Ef6)
	setb TR0
    ret

f_note:

    clr TR0
	mov RH0, #high(F6)
	mov RL0, #low(F6)
	setb TR0
    ret

g_note:

    clr TR0
	mov RH0, #high(G6)
	mov RL0, #low(G6)
	setb TR0
    ret

a_flat_note:

    clr TR0
	mov RH0, #high(Af6)
	mov RL0, #low(Af6)
	setb TR0
    ret

checking_welcome_button:
	jb START_BUTTON, returner
	Wait_Milli_Seconds(#50)
	jb START_BUTTON, returner
	jnb START_BUTTON, $
	ljmp continue_welcome_check

returner:
    ret

kahoot:
    
    lcall c_note

    lcall checking_welcome_button

    lcall eigthnote
    lcall c_note

    
    lcall checking_welcome_button

    lcall eigthnote
    lcall f_note
    
    lcall checking_welcome_button

    lcall eigthnote
    lcall f_note
    
    lcall checking_welcome_button

    lcall eigthnote
    lcall a_flat_note
    
    lcall checking_welcome_button

    lcall eigthnote
    lcall a_flat_note
    
    lcall checking_welcome_button

    lcall eigthnote
    lcall f_note
    
    lcall checking_welcome_button

    lcall eigthnote
    lcall f_note
    
    lcall checking_welcome_button
   
    lcall eigthnote
    lcall rest_eightnote
    
    lcall checking_welcome_button

    lcall rest_eightnote
    
    lcall checking_welcome_button

    lcall eigthnote
    lcall f_note
    
    lcall checking_welcome_button

    lcall eigthnote
    lcall f_note

    lcall checking_welcome_button

    lcall rest_eightnote
    lcall rest_eightnote

    
    lcall checking_welcome_button

    lcall eigthnote
    lcall f_note

    
    lcall checking_welcome_button

    lcall eigthnote
    lcall f_note

    lcall checking_welcome_button
    ;lcall eigthnote
    lcall g_note

    lcall checking_welcome_button

    lcall eigthnote
    lcall g_note

    
    lcall checking_welcome_button
    

    lcall eigthnote
    lcall d_note
    
    lcall checking_welcome_button
    

    lcall eigthnote
    lcall d_note

    lcall checking_welcome_button
    
    lcall eigthnote
    lcall e_flat_note

    lcall checking_welcome_button
    
    lcall eigthnote
    lcall e_flat_note

    lcall checking_welcome_button
    
    lcall eigthnote
    lcall c_note

    lcall checking_welcome_button
    
    lcall eigthnote
    lcall c_note

    lcall checking_welcome_button
    
    lcall eigthnote
    lcall rest_eightnote
    
    lcall checking_welcome_button
    
    lcall rest_eightnote

    lcall checking_welcome_button
    
    lcall eigthnote
    lcall c_note

    lcall checking_welcome_button
    
    lcall eigthnote
    lcall c_note

    lcall checking_welcome_button
    
    lcall rest_eightnote
    
    lcall checking_welcome_button
    
    lcall rest_eightnote

    lcall checking_welcome_button
    
    lcall eigthnote
    lcall c_note
    
    lcall checking_welcome_button
    

    lcall eigthnote
    lcall c_note
    
    lcall checking_welcome_button
    

    ret
    ljmp button_check

end
