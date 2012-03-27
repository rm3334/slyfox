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

#define pinINT1 2 //Needs to be here, because it is an interrupt pin - Used for Initiating Communication with Computer
#define pinINT2 3 //Needs to be here, because it is an interrupt pin - Used for Initiating Clock Pulse
#define pinLCWaveplate 6 // High voltage corresponds to V2 on LC Waveplate Controller
#define pinTTL_IN1 7 //Reads this TTL In

#define pinTTL_OUT1 5 //Depending on state either mirrors TTL_IN1 or is held low.
#define setPinTTL_OUT1_HIGH() PORTD |= 0b00100000;
#define setPinTTL_OUT1_LOW() PORTD &= 0b11011111;

#define pinClockTTL 8 //Used when arduino is used to supply clock AOM TTL

#define pinLED 13 



#define SERIAL_IDLE 0
#define SERIAL_RECEIVING 1
#define DATA_NOT_READY 0
#define DATA_READY 1

const int numPulses = 5;
const int pulseLength = 2000;
int incomingByte;  // for incoming serial data
byte serialStatus;  //idle or receiving
byte dataStatus;  //ready or not ready
byte serialInputCount; //how many bytes received
volatile boolean startCOM = false;
volatile char Command[3];
volatile int cmdIDX; // for building Command list
volatile unsigned long Val0; // for Command[0]
volatile unsigned long Val1; // for Command[1]
volatile unsigned long Val2; // for Command[2]

volatile unsigned long clockDelayTime = 0;
volatile unsigned long clockPulseTime = 80000;

volatile int cycleNum = 666;
volatile boolean mirrorTTL1 = true;

void setup(){
  Serial_Init();
  pinMode(pinLED, OUTPUT);
  pinMode(pinINT1, INPUT);
  pinMode(pinINT2, INPUT);
  pinMode(pinLCWaveplate, OUTPUT);
  pinMode(pinTTL_IN1, INPUT);
  pinMode(pinTTL_OUT1, OUTPUT);
  pinMode(pinClockTTL, OUTPUT);
  attachInterrupt(0, changeStartCOM, RISING);
  attachInterrupt(1, advanceCycleNum, RISING);
}

void loop(){
  if (mirrorTTL1)
  {
    if(digitalRead(pinTTL_IN1)){
      setPinTTL_OUT1_HIGH();
    }else
    {
      setPinTTL_OUT1_LOW();
    }
  }
  else
  {
    setPinTTL_OUT1_LOW();
  }
  
  switch (cycleNum){
    case 0:
      digitalWrite(pinLCWaveplate, HIGH);
      digitalWrite(pinLED, HIGH);
      break;
    case 1:
      digitalWrite(pinLCWaveplate, HIGH);
      digitalWrite(pinLED, HIGH);
      break;
    case 2:
      digitalWrite(pinLCWaveplate, LOW);
      digitalWrite(pinLED, LOW);
      break;
    case 3:
      digitalWrite(pinLCWaveplate, LOW);
      digitalWrite(pinLED, LOW);
      break;
  }
  if (startCOM) {
    ComputerCom();
    startCOM = !startCOM;
  }
}

void advanceCycleNum(){
    cycleNum++;
    cycleNum %= 4;
    
    switch (cycleNum){
      case 0:
        mirrorTTL1 = false;
        break;
      case 1:
        mirrorTTL1 = false;
        break;
      case 2:
        mirrorTTL1 = true;
        break;
      case 3:
        mirrorTTL1 = true;
        break;
    }
}

void changeStartCOM(){
  startCOM = !startCOM;
  Serial.println(startCOM);
}
void ComputerCom(){
    Serial.println("Ready");
    digitalWrite(pinLED, HIGH);
    cmdIDX = -1;
    Val0 = 0;
    Val1 = 0;
    Val2 = 0;
    while (Serial.available() > 0) {
      // read the incoming byte:
        incomingByte = Serial.read();
        if (incomingByte==';') {
          serialInputCount=0;
          serialStatus=SERIAL_RECEIVING;
          cmdIDX++;
          Serial.println("Semi-Colon");
        }
        else {
          if (serialInputCount==0) {
            Command[cmdIDX]=char(incomingByte);
            serialInputCount++;
            Serial.println(char(incomingByte));
          }
          else{
            switch (cmdIDX) {
              case 0:
                Val0 = (Val0 * 10) + (incomingByte - '0');
              break;
              
              case 1:
                Val1 = (Val1 * 10) + (incomingByte - '0');
              break;
              
              case 2:
                Val2 = (Val2 * 10) + (incomingByte - '0');
              break;
            }
            serialInputCount++;
          }
        }
    }
    if (cmdIDX > -1) {
      for (int x = 0; x<3; x++){ //For now I am just forcing commands in the order 'c' 'd' 't'
        switch (Command[x]) {
          case 'c':
            cycleNum = Val0; 
          break;
          
          case 'd':
            clockDelayTime = Val1;
          break;
          
          case 't':
            clockPulseTime = Val2;
          break;
        }
      }
    }
      digitalWrite(pinLED, LOW);
      //Serial.println(cycleNum);
}

void Serial_Init(void) {
  Serial.begin(57600);
}
