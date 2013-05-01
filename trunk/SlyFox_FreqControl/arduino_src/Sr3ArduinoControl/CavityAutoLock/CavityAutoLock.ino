/*
Arduino code to control three Experimental Parameters.
  1. Setting of the Liquid Crystal Waveplate.
  2. One TTL Passthrough (Either Always low or passthrough).
  3. Execute a Pulse after an interrupt, given a delay time, and a pulse time.
    (Say for example a clock pulse).

Language: Arduino language.
Environment: Arduino 0022

Copyright (C) 2012 by Ben Bloom
MIT License

Ver: 0.2
*/
#define pinLED 13 //
#define pinINT1 2 //Locked Int - Needs to be here, because it is an interrupt pin 
#define pinINT2 3 //Needs to be here, because it is an interrupt pin
#define readINT1() PIND & 0b00000100

#define pinERRsignal 12 //chooses what goes into Slow Loop Filter
#define setPinERRsignal_HIGH() PORTB |= 0b00010000
#define setPinERRsignal_LOW() PORTB &= 0b11101111


#define pinSWEEP A1 //triggers sweeper
#define setPinSWEEP_HIGH() PORTC |= 0b00000010
#define setPinSWEEP_LOW() PORTC &= 0b11111101

#define mask 0b11110000
#define setModeAcq() PORTD = (PORTD & ~mask) | (0b11100000 & mask)
#define setModeProp() PORTD = (PORTD & ~mask) | (0b11010000 & mask)
#define setMode6dB() PORTD = (PORTD & ~mask) | (0b10110000 & mask)
#define setMode6dBP() PORTD = (PORTD & ~mask) | (0b01110000 & mask)
#define setMode9dB() PORTD = (PORTD & ~mask) | (0b11110000 & mask)

byte isLocked;
byte previousIsLocked;
byte isAcquiring;
byte currentState;
unsigned long time;

void setup(){
  pinMode(pinLED, OUTPUT);
  pinMode(pinINT1, INPUT);
  pinMode(pinINT2, INPUT);
  pinMode(pinERRsignal, OUTPUT);
  pinMode(pinSWEEP, OUTPUT);
  pinMode(4, OUTPUT);
  pinMode(5, OUTPUT);
  pinMode(6, OUTPUT);
  pinMode(7, OUTPUT);
  setPinERRsignal_LOW();
  setPinSWEEP_LOW();
  setMode9dB();
  isLocked = digitalRead(pinERRsignal);
  previousIsLocked = isLocked;
//  attachInterrupt(0, lockAcquire, RISING);
//  attachInterrupt(0, lockSearch, FALLING);
}

void loop(){
  while(1)
  {
    isLocked = readINT1();
    currentState = (isLocked >> 1) | (previousIsLocked >> 2);
    if (currentState == 2) //Acquiring
    {
      setPinERRsignal_LOW();
      setMode6dB();
      delayMicroseconds(50);
      setMode6dBP();
      delayMicroseconds(50);
      setMode9dB();
      setPinSWEEP_LOW();
    }
    else if (currentState == 1) //FallingOut
    {
      setModeProp();
      setPinERRsignal_HIGH();
      setPinSWEEP_LOW();
      setPinSWEEP_HIGH();
    }
    else if (currentState == 0) //Searching
    {
      setPinSWEEP_LOW(); //retrigger if necessary
      setPinSWEEP_HIGH();
    }
    else //currentState = 3, Locked
    {
    }
    previousIsLocked = isLocked;
  }
}

void lockAcquire()
{
  setPinERRsignal_LOW();
  setPinSWEEP_LOW();
}

void lockSearch()
{
  setPinERRsignal_HIGH();
  setPinSWEEP_HIGH();
}
