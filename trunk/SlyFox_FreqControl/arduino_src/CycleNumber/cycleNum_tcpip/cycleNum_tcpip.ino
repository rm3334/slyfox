/* CycleNum_tcpip
 
 Used to keep track of the cycle number so both Strontium experiments can sync up their data.
 Ben Bloom
 last updated 03/14/12 17:15:00
 */
/* 
 "Debounce" is used to keep track of TTL 
 
 Each time the input pin goes from LOW to HIGH (e.g. because of a push-button
 press), the output pin is toggled from LOW to HIGH or HIGH to LOW.  There's
 a minimum delay between toggles to debounce the circuit (i.e. to ignore
 noise).  
 
 created 21 November 2006
 by David A. Mellis
 modified 30 Aug 2011
 by Limor Fried
 
 This example code is in the public domain.
 
 http://www.arduino.cc/en/Tutorial/Debounce
 */
#include <SPI.h>
#include <Ethernet.h>

// network configuration.  gateway and subnet are optional.

// the media access control (ethernet hardware) address for the shield:
byte mac[] = { 
  0x90, 0xA2, 0xDA, 0x00, 0xA4, 0x6D };  
//the IP address for the shield:
byte ip[] = { 
  128, 138, 107, 208 };    
// the router's gateway address:
byte gateway[] = { 
  128, 138, 107, 1 };
// the subnet:
byte subnet[] = { 
  255, 255, 255, 0 };

// telnet defaults to port 23
EthernetServer server = EthernetServer(3001);
// constants won't change. They're used here to 
// set pin numbers:
const int ttlPin = 2;     // the number of the pushbutton pin
const int ledPin = 13;
// Variables will change:
int ledState = HIGH;         // the current state of the output pin
int ttlState;             // the current reading from the input pin
int lastTTLState = LOW;   // the previous reading from the input pin
volatile unsigned int cycleNum = 0;
boolean hasChanged = true;

// the following variables are long's because the time, measured in miliseconds,
// will quickly become a bigger number than can be stored in an int.
long lastDebounceTime = 0;  // the last time the output pin was toggled
long debounceDelay = 3;    // the debounce time; increase if the output flickers

void setup() {
  pinMode(ttlPin, INPUT);
  Serial.begin(9600);
  
    // initialize the ethernet device
    Ethernet.begin(mac, ip, gateway, subnet);

  // start listening for clients
  server.begin();
}


void loop() {
  // read the state of the switch into a local variable:
  int reading = digitalRead(ttlPin);

  // check to see if you just pressed the button 
  // (i.e. the input went from LOW to HIGH),  and you've waited 
  // long enough since the last press to ignore any noise:  

  // If the switch changed, due to noise or pressing:
  if (reading != lastTTLState) {
    // reset the debouncing timer
    lastDebounceTime = millis();
    hasChanged = true;
  } 

  if ((millis() - lastDebounceTime) > debounceDelay && reading && hasChanged) {
    // whatever the reading is at, it's been there for longer
    // than the debounce delay, so take it as the actual current state:
    ttlState = reading;
    hasChanged = false;
    cycleNum++;
    //Serial.println(cycleNum);
  }

  //

  // save the reading.  Next time through the loop,
  // it'll be the lastButtonState:
  lastTTLState = reading;

  // if an incoming client connects, there will be bytes available to read:
  EthernetClient client = server.available();
  if (client == true) {
    // read bytes from the incoming client and write them back
    // to any clients connected to the server:
    if ('c' == client.read()){
      server.println(cycleNum);
      client.stop();
    }
  }
}


