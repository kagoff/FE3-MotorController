; PARAMETER_ENTRY "Program"
;		TYPE		PROGRAM
;		Level		0
;	END
; PARAMETER_ENTRY "UCDFRStateData"
;		TYPE		Monitor
;		Level		1
;	END
; parameter_entry "State"
; 	type Monitor
; 	width 16bit
; 	address user4
; 	units @
; end
; parameter_entry "SetInterlock"
; 	type Monitor
; 	width 16bit
; 	address User_bit4
; 	units @
; end

; Formula Racing UCD
; Curtis 1239E Motor Controller Code
; Zhening (Sirius) Zhang

VCL_App_Ver = 100 	;Set VCL software revision

;--------------------
; I/O Requirements
;--------------------
;	For functions to work properly:
;       Used CAN message for controll 
;
;		Drive1 connected to PWM1
;		Drive2 connected to PWM2
;		Drive3 connected to PWM3 

Drive1			equals	PWM1             
Drive2			equals	PWM2
Drive3			equals	PWM3  
Drive4          equals  PWM4

HV				equals	User_bit1
DriveRequest	equals	User_bit2         
NEUTRAL			equals	User_bit3
SetInterlock	equals	User_bit4

PDO1			equals	User1
PDO2			equals	User2
PDO3			equals	User3
State			equals	User4
N_MASK			equals	User5
DV_MASK			equals	User6
HV_MASK			equals	User7

DisplayState 	equals  User8
temp            equals	User9

throttle1		equals	User10
throttle2		equals	User11

Node0_Temp		equals	User12  		
Node1_Temp		equals	User13
Node2_Temp		equals	User14	 
Node3_Temp		equals	User15
Node4_Temp		equals	User16  
Node5_Temp	 	equals	User17
Index_Highest	equals	User    
Highest_Temp	

;---------------- Initialization ----------------------------

SetInterlock = 0
VCL_Throttle = 0
VCL_Brake = 0
state = 0
DisplayState = 1


N_MASK=0x01 //netural is the first bit
DV_MASK=0x02  // Drive is the second bit
HV_MASK=0x04  // High voltage request is the thrid bit

;---------------- CAN Variables -----------------------------	
pdoSend equals can1
pdoRecv equals can2
debug   equals can3
pdoAck	equals can4
BMS_Status equals can5
BMS_Volt   equals can6
BMS_Temp   equals can7


Entry1	equals Main_State
Entry2	equals Capacitor_Voltage
Entry3	equals Nominal_Voltage //out
Entry4	equals ABS_Mapped_Throttle
Entry5	equals ABS_Motor_RPM
Entry6	equals MotorSpeedA //out
Entry7  equals MotorSpeedB //out
Entry8  equals Motor_Temperature

test1	equals VCL_Throttle
test2	equals VCL_Brake

;------------ Setup mailboxes ----------------------------
disable_mailbox(pdoSend)
Shutdown_CAN_Cyclic()

Setup_Mailbox(pdoSend, 0, 0, 0x566, C_CYCLIC, C_XMT, 0, 0)
Setup_Mailbox_Data(pdoSend,8,
					;@Entry1,		
                    @Entry2 + USEHB,
					@Entry2,			 
					@Entry5 + USEHB,	 
					@Entry5,		  
					@Entry8 + USEHB,	 
					@Entry8,	   
					@Entry4 + USEHB,
					@Entry4)	

enable_mailbox(pdoSend)



Setup_Mailbox(debug, 0, 0, 0x466, C_CYCLIC, C_XMT, 0, 0)
Setup_Mailbox_Data(debug,8,
					@SetInterlock,		
                    @HV,
                    ;@Status3,
					@state,			 
					@PWM1_Output,	 
					@PWM2_Output,		  
					@PWM3_Output,	 
					@test1,	   
					@test2)	

enable_mailbox(debug)

Setup_Mailbox(pdoRecv, 0, 0, 0x766, C_EVENT, C_RCV, 0, pdoAck)
Setup_Mailbox_Data(pdoRecv,8,
					@SetInterlock,	  		
                    @throttle1,
					@throttle2,			 
					0,
					0,		  
					0,	 
					0,	   
					0)	

;enable_mailbox(pdoRecv)

Setup_Mailbox(pdoAck, 0, 0, 0x666, C_EVENT, C_XMT, 0, 0)
Setup_Mailbox_Data(pdoAck,8,
					0xFF,	  		
                    0,
					0,			 
					0,
					0,		  
					0,	 
					0,	   
					0)	

;enable_mailbox(pdoAck)

Setup_Mailbox(BMS_Status, 0, 0, 0x188, C_EVENT, C_RCV, 0, 0)
Setup_Mailbox_Data(BMSPackStatus,8,
					0,	  		
                    @SOC_percent,
					0,			 
					0,
					0,		  
					0,	 
					0,	   
					0)	

;enable_mailbox(pdoAck)

Setup_Mailbox(BMS_Volt, 0, 0, 0x388, C_EVENT, C_RCV, 0, 0)
Setup_Mailbox_Data(pdoAck,8,
					@Min_Volt_1,	  		
                    @Min_Volt_0,
					@Max_Volt_1,			 
					@Max_Volt_0,
					@Pack_Volt_3,		  
					@Pack_Volt_2,	 
					@Pack_Volt_1,	   
					@Pack_Volt_0)	

;enable_mailbox(pdoAck)

Setup_Mailbox(BMS_Temp, 0, 0, 0x488, C_EVENT, C_RCV, 0, 0)
Setup_Mailbox_Data(pdoAck,8,
					@Node0_Temp,	  		
                    @Node1_Temp,
					@Node2_Temp,			 
					@Node3_Temp,
					@Node4_Temp,		  
					@Node5_Temp,	 
					@Index_Highest,	   
					@Highest_Temp)	

;enable_mailbox(pdoAck)

Startup_CAN()
CAN_Set_Cyclic_Rate( 30 );actually 120ms 		
Setup_NMT_State(ENTER_OPERATIONAL)			;Set NMT state so we can detect global NMT commands
Startup_CAN_Cyclic()


Mainloop:

;--------------- Mirror driver 1-> driver 5 -----------------
;--------------- and driver 3 -> driver 4 -------------------

	if(PWM3_Output > 0){
		put_pwm(PWM4, 0x7fff)
	}
	else{
		put_pwm(PWM4, 0x0)
	}

	if(PWM1_Output > 0){
		put_pwm(PWM5, 0x7fff)
	}
	else{
		put_pwm(PWM5, 0)
	}

;---------------- Interlock State Machine --------------------	

	if(state = 0)		; Interlock OFF
	{
		Clear_interlock()
		put_pwm(PWM2,0)
		
		if(SetInterlock > 0)	; if interlock request observed, go to interlock state
		{
			state = 1
		}
	
	}
	else if(state = 1)	; Interlock ON, requested by CAN message
	{
		put_pwm(PWM2,32767)
		Set_interlock()

		VCL_Throttle = throttle1*255 + throttle2
		
		if(SetInterlock = 0)	; if interlock request is not observed, go back to pre-interlock state
		{
			state = 0
		}

		if(Status3 > 0)
		{
			state = 2
		}
		;if(Status3 = 2)
		;{
		;	state = 2
		;}

		;if(Status3=4)
		;{
		;	state = 2
		;}

		;if(Status3=6)
		;{
		;	state = 2
		;}

		;if(Status3=8)
		;{
		;	state = 2
		;}

		;if(Status3=10)
		;{
		;	state = 2
		;}

		;if(Status3=14)
		;{
		;	state = 2
		;}

		;if(Status3=12)
		;{
		;	state = 2
		;}


	}	
	else if(state = 2)	; Trap state. No exit conditions
	{
		Clear_interlock()
		put_pwm(PWM2, 0)
	}

goto Mainloop