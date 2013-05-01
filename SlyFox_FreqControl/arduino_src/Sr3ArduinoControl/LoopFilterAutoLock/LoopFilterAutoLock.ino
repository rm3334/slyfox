/*
Arduino Code to Control Slow Loop Filter

Language: Arduino language.
Environment: Arduino 1.0

Copyright (C) 2013 by Ben Bloom
MIT License

Ver: 0.1
*/
#define pinLED 13 //
//#define pinINT1 2 //Locked Int - Needs to be here, because it is an interrupt pin 
//#define pinINT2 3 //Needs to be here, because it is an interrupt pin
//#define readINT1() PIND & 0b00000100

#define isTransHigh() PINC & 0b00000001

//#define pinSWEEP A1 //triggers sweeper
#define setPinSWEEP_HIGH() PORTC |= 0b00000010
#define setPinSWEEP_LOW() PORTC &= 0b11111101
// pins for reading out Mode dial PORTB
#define modeReadMask 0b00011111
#define readCurrentMode() PINB &= modeReadMask

#define modeSetMask 0b11111000
#define setModeAcq() PORTD = (PORTD & ~modeSetMask) | (0b00001000 & modeSetMask)
#define setModeProp() PORTD = (PORTD & ~modeSetMask) | (0b00011000 & modeSetMask)
#define setMode6dB() PORTD = (PORTD & ~modeSetMask) | (0b00111000 & modeSetMask)
#define setMode6dBP() PORTD = (PORTD & ~modeSetMask) | (0b01111000 & modeSetMask)
#define setMode9dB() PORTD = (PORTD & ~modeSetMask) | (0b11111000 & modeSetMask)
#define setModeSearch() PORTD = (PORTD & ~modeSetMask) | (0b11100000 & modeSetMask) //for sweeping to find a fringe

byte isLocked;
byte previousIsLocked;
byte isAcquiring;
byte currentModeSwitch;
byte setMode;
byte currentALmode;
byte transmission;
byte prevTransmission;
byte searching;
unsigned long time;

void setup(){
  pinMode(pinLED, OUTPUT);
  pinMode(A0, INPUT);
  pinMode(A1, OUTPUT);
  digitalWrite(A1, LOW);
  DDRB &= 0b11100000; // Sets the pins for reading current mode
  PORTB |= 0b00011111; // Sets pullup resistors for current mode rotary switch
  
  DDRD &= 0b11111000; // Sets the pins for WRITING current mode
  setMode = 0;
  searching = 0;
  Serial.begin(9600);
}

void loop(){
  while(1)
  {
    transmission = isTransHigh();
    currentALmode = (prevTransmission << 1) | transmission;
    if(setMode == 15)
    {
      if (currentALmode = 1) //Just passed a fringe!
      {
        setMode9dB();
        setMode = 15;
      }
      else if (currentALmode = 2) //Just fell out of lock
      {
        searching = 1;
        setModeSearch();
      }
      else if (currentALmode = 0) //Out of lock
      {
        if (searching == 0)
        {
          searching = 1;
          setModeSearch();
        }
        setPinSWEEP_LOW();
        setPinSWEEP_HIGH();
      }
      else { // lock is working!
            setPinSWEEP_LOW();
            searching = 0;
      }
    }
    currentModeSwitch = readCurrentMode();
    if (setMode != currentModeSwitch)
    {
      switch (currentModeSwitch)
      {
        case 30: 
          setModeAcq();
          break;
        case 29:
          setModeProp();
          break;
        case 27:
          setMode6dB();
          break;
        case 23:
          setMode6dBP();
          break;
        case 15:
          setMode9dB();
          break;
        default:
          break;
      }
      setMode = currentModeSwitch;
    }

    PORTB |= 0b00011111; //Don't know why I have to constantly reset this?
    prevTransmission = transmission;
  }
}
