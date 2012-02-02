/*
Arduino code to parse TTL Pulses 

Language: Arduino language.
Environment: Arduino 0022

Copyright (C) 2011 by Ben Bloom
MIT License

Ver: 0.1
*/

#define pinTTL1 2 //Needs to be here, because it is an interrupt pin
#define pinTTL2 6
#define pinTTLout 5

#define pinLED 13

const int numPulses = 5;
const int pulseLength = 2000;
volatile int currentPulse = 1;
volatile int prevPulse = 0;
int incomingByte;  // for incoming serial data

void setup(){
  Serial_Init();
  pinMode(pinLED, OUTPUT);
  pinMode(pinTTL1, INPUT);
  pinMode(pinTTL2, INPUT);
  pinMode(pinTTLout, OUTPUT);
  attachInterrupt(0, TTL_1Trigger, RISING);
}

void loop(){
   if (Serial.available() > 0) {
    // read the incoming byte:
    incomingByte = Serial.read();
    if (incomingByte=='H')
    {
     digitalWrite(pinTTLout, HIGH);
     digitalWrite(pinLED, HIGH);
     //Serial.println("Roger That! High");
    }
    else if(incomingByte=='L')
    {
      digitalWrite(pinTTLout, LOW);
      digitalWrite(pinLED, LOW);
      //Serial.println("Roger That! Low");
    }
  //digitalWrite(pinTTLout, LOW);
  delay(50);
  }
}

void TTL_1Trigger(){
  if(!digitalRead(pinTTL2))
  {
    prevPulse = 0;
  }
  if(currentPulse-prevPulse == 1)
  {
    digitalWrite(pinTTLout, HIGH);
    delayMicroseconds(pulseLength);
    digitalWrite(pinTTLout, LOW);
    currentPulse++;
    prevPulse++;
  }
  else
  {
    prevPulse++;
  }
  if (currentPulse > numPulses)
  {
    currentPulse = 1;
  }
  
}

void Serial_Init(void) {
  Serial.begin(9600);
}
