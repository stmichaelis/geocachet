/*
CC BY-NC-SA 3.0

Copyright (c) 2011 [Stefan Michaelis](http://www.stefan-michaelis.name)

This software is licensed under the terms of the Creative
Commons "Attribution Non-Commercial Share Alike" license, version
3.0, which grants the limited right to use or modify it NON-
COMMERCIALLY, so long as appropriate credit is given and
derivative works are licensed under the IDENTICAL TERMS.  For
license details see

  http://creativecommons.org/licenses/by-nc-sa/3.0/

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#include <Streaming.h>
#include <EEPROM.h>
#include <TinyGPS.h>
#include <NewSoftSerial.h>
#include <Servo.h>
#include <math.h>


/** Testdefinition. If this is uncommented, use testing data without actual GPS measurements */
/*#ifndef __GPS_TESTING__
#define __GPS_TESTING__
#endif
*/

#ifdef __GPS_TESTING__
const float test_latlons[] = {51.12345f, 7.12345f,
                51.234523f, 6.345345f, 51.234565f, 7.123456f,
                51.453456f, 7.123541f};
#endif

/* *** Quest Config *** */
// TODO: Target coordinates. 
const float target_latlons[] = {51.234545f, 7.234546f,
                51.605220f, 7.234556f,
                51.345654f, 7.234456f,
                51.456785f, 7.345567f,
                51.345567f, 6.345678f,
                51.345578f, 7.345678f};
// TODO: Max deviation around each target in m. One for each target.
const int target_dev[] = {100, 80, 200, 30, 30, 30};

// Maximum number of tries before box is locked
const int MAX_TRIES = 50;

/* *** System Config *** */
const byte POLOLU_PIN = 5;
const byte LCD_PIN = 8;
const byte GPS_IN_PIN = 3;
const byte GPS_OUT_PIN = 10;
const byte SERVO_PIN = 9;

const int ADDR_TRIES = 0;
const int ADDR_STAGE = 1;
const int ADDR_STARTCOORDS = 2;

const float EARTH_RADIUS = 6378.388f;
const float MY_DEG_TO_RAD = 0.0174532925f;

// TODO: If around these coordinates, the box will reset to the beginning of the quest. 
const float HOME_LAT = 51.234859f;
const float HOME_LON = 7.234563f;

// Switch off, if no signal after this time
const unsigned long GPS_DELAY_MS= 120000;

enum Phase {INIT,SEARCH_GPS,EVAL_POS,DISPLAY_TRIES,UNLOCK,SEAL,SHUTDOWN,SEND_COORDS,NO_GPS};
Phase currentPhase = INIT;

float current_latlon[] = {0.0f, 0.0f};

// Input, Output
NewSoftSerial lcdSerial(0, LCD_PIN);
TinyGPS gps;
NewSoftSerial gpsSerial(GPS_IN_PIN, GPS_OUT_PIN);

Servo servo;

unsigned long starttime = 0;

/***************** Methods ************************/

void lcdclear()
{
  lcdSerial.print(0xFE, BYTE);
  lcdSerial.print(0x01, BYTE);
}

void lcdpos(byte x, byte y){
  lcdSerial.print(254, BYTE);
  lcdSerial.print(128+x+64*y, BYTE);
}

void blink_on(){
  // Blinking cursor on
  lcdSerial.print(0xFE, BYTE);
  lcdSerial.print(0x0D, BYTE);
}

void shutdown()
{
  lcdclear();
  lcdSerial.print( "  Schalte ab...");
  delay(3000);
  digitalWrite( POLOLU_PIN, HIGH );
  currentPhase = SEND_COORDS; 
}

/*
 * Distance calculation.
 */
float gcd(float lat_a, float lon_a, float lat_b, float lon_b)
{
  // Haversine
  float a = sin((lat_a-lat_b)/2);
  float b = sin((lon_a-lon_b)/2);
  
  float d = 2*asin(sqrt(a*a+cos(lat_a)*cos(lat_b)*b*b));
  return fabs(EARTH_RADIUS * d);
}

void lock(){
  servo.attach(SERVO_PIN);
  servo.write(0);
  delay(2000);
  servo.detach();
}

boolean check_seal(){
  byte tries = EEPROM.read(ADDR_TRIES);
  if (tries >= MAX_TRIES){
    currentPhase = SEAL;
    return true;
  }
  return false;
}

void unlock(){
  lcdclear();
  lcdSerial << " Letzte Station";
  lcdpos(0,1);
  lcdSerial << "    erreicht";
  delay(5000);
  lcdclear();
  lcdSerial << "Fach ";
  lcdSerial.print(239, BYTE);
  lcdSerial << "ffnet";
  lcdpos(0,1);
  lcdSerial << "in 5s";
  blink_on();
  delay(3000);
  servo.attach(SERVO_PIN);
  servo.write(80);
  delay(3000);
  servo.detach();
}

void reset_box(){
  lcdclear();
  lcdSerial << "Setze Box zur";
  lcdSerial.print(245, BYTE);
  lcdSerial << "ck";
  EEPROM.write(ADDR_TRIES, 0);
  EEPROM.write(ADDR_STAGE, 0);
  delay(3000);
  unlock();
  delay(20000);
  lock();
  shutdown();
}

// Read from Serial, reset box in case reset command retrieved
void wait_for_reset(){
  const int MAX_MESSAGE_LEN = 128;
  const int LINE_FEED = 13;
  char message_text[MAX_MESSAGE_LEN];
  int index = 0;
  
  Serial << "Waiting for reset-Command.\n";
  
  while (true){
    if (Serial.available() > 0) {
      int current_char = Serial.read();
      if (current_char == LINE_FEED || index == MAX_MESSAGE_LEN - 1) {
        message_text[index] = 0;
        index = 0;
        // Reset Command?
        Serial.println(message_text);
        if (strcmp(message_text,"reset") == 0){
          reset_box();
        }
      } else {
        message_text[index++] = current_char;
      }
    }
  }
}

void welcome(){
  // Check, that Latlon-Arraylength = dev-Arraylength. If not, check array definitions above
  if (sizeof(target_latlons)/8 != sizeof(target_dev)/2){
    lcdSerial << "Fehlkonfiguration der Ziele";
    delay(5000);
  }
  lcdSerial << "  Willkommen!   ";
  byte stage = EEPROM.read(ADDR_STAGE);
  delay(2000);
  if (stage >= sizeof(target_latlons)/8){
    currentPhase = UNLOCK;
    return;
  }
  if (check_seal()){
    return;
  }
  byte tries = EEPROM.read(ADDR_TRIES);
  
  lcdclear();
  lcdSerial << "Wir sind bei";
  lcdpos(0,1); 
  lcdSerial << "Station " << stage+1 << " von " << sizeof(target_latlons)/8;
  delay(5000);
  lcdclear();
  lcdSerial << "und Versuch ";
  lcdpos(0,1);
  lcdSerial << tries+1 << " von " << MAX_TRIES << ".";
  // Increase used tries
  EEPROM.write(ADDR_TRIES,++tries);
  delay(5000);
  currentPhase = SEARCH_GPS;
}

template <class T> int EEPROM_writeAnything(int ee, const T& value)
{
    const byte* p = (const byte*)(const void*)&value;
    int i;
    for (i = 0; i < sizeof(value); i++)
	  EEPROM.write(ee++, *p++);
    return i;
}

template <class T> int EEPROM_readAnything(int ee, T& value)
{
    byte* p = (byte*)(void*)&value;
    int i;
    for (i = 0; i < sizeof(value); i++)
	  *p++ = EEPROM.read(ee++);
    return i;
}

void save_coords(){
  byte tries = EEPROM.read(ADDR_TRIES);
  EEPROM_writeAnything(ADDR_STARTCOORDS + (tries-1)*sizeof(current_latlon), 
    current_latlon);
}


void seal(){
  lcdclear();
  lcdSerial << " Box versiegelt";
  delay(5000);
  lcdclear();
  lcdSerial << "  Bitte zur";
  lcdSerial.print(245, BYTE);
  lcdSerial << "ck";
  lcdpos(0,1);
  lcdSerial << "  zum Absender";
  delay(5000);
}

void displaytries(){
  lcdclear();
  byte tries = EEPROM.read(ADDR_TRIES);
  String versuche = " Versuche";
  if (MAX_TRIES-tries == 1){
    versuche = " Versuch";
  }
  lcdSerial << "Noch " << MAX_TRIES-tries << versuche;
  lcdpos(0,1);
  lcdSerial.print(245, BYTE);
  lcdSerial << "brig.";
  delay(5000);
}

void no_gps(){
    currentPhase = DISPLAY_TRIES;
    lcdclear();
    lcdSerial << "Konnte kein";
    lcdpos(0,1);
    lcdSerial << "Signal finden.";
    delay(5000); 
}

void evalpos(){
  // Compare to home coordinates
  float dist = 1000.0f*gcd( current_latlon[0] * MY_DEG_TO_RAD, current_latlon[1] * MY_DEG_TO_RAD, 
    HOME_LAT * MY_DEG_TO_RAD, HOME_LON * MY_DEG_TO_RAD );
  if (dist < 200){
    // Near home? => Reset box
    reset_box();
  }
  
  byte stage = EEPROM.read(ADDR_STAGE);
  dist = 1000.0f*gcd( current_latlon[0] * MY_DEG_TO_RAD, current_latlon[1] * MY_DEG_TO_RAD, 
    target_latlons[stage*2] * MY_DEG_TO_RAD, target_latlons[stage*2+1] * MY_DEG_TO_RAD );
  
  // Debug
  Serial << "Lat current: ";
  Serial.print(current_latlon[0], 6);
  Serial << " Lon current: ";
  Serial.println(current_latlon[1], 6); 
  Serial << "Lat target: ";
  Serial.print(target_latlons[stage*2], 6);
  Serial << " Lon target: ";
  Serial.println(target_latlons[stage*2+1], 6); 
  Serial << "Current distance: " << dist << " m\n";
  
  lcdclear();
  if (dist < target_dev[stage]){
    lcdSerial << "Station " << stage+1;
    lcdpos(0,1);
    lcdSerial << "erreicht.";
    delay(5000);
    EEPROM.write(ADDR_STAGE, ++stage);
    if (stage >= sizeof(target_latlons) / 8){
      // Last target reached
      currentPhase = UNLOCK;
    } else {
      // Current target reached, but more to go
      lcdclear();
      String stationen = " Stationen";
      if ((sizeof(target_latlons)/8) - stage == 1){
        stationen = " Station";
      }
      lcdSerial << "Noch " << (sizeof(target_latlons)/8) - stage << stationen;
      lcdpos(0,1);
      lcdSerial << "bis zum Ziel.";
      delay(5000);
      currentPhase = EVAL_POS;
    }
  } else {
    // Target missed
    lcdSerial << "Entfernung zur ";
    lcdpos(0,1);
    lcdSerial << "n";
    lcdSerial.print(225, BYTE);
    lcdSerial << "chsten Station";
    delay(5000);
    lcdclear();
    if (dist > 5000){
      lcdSerial << dist/1000.0f << " km.";
    }else{
      lcdSerial << dist << " m.";
    }
    delay(5000);
    lcdclear();
    lcdSerial << "     Zugriff";
    lcdpos(0,1);
    lcdSerial << "   verweigert.";
    delay(3000);
    currentPhase = DISPLAY_TRIES;
  }
}

void searchgps(){
  lcdclear();
  blink_on();
  
  lcdSerial << "Suche GPS-Signal";
  delay(3000);
  // Brightness 30%
  lcdSerial.print(0x7C, BYTE);
  lcdSerial.print(137, BYTE);
  
  int numFixes = 0;
  unsigned long waitUntil = millis()+GPS_DELAY_MS;
  boolean signalfound = false;
  while ( (millis() < waitUntil) && (!signalfound) )
  {
 #ifndef __GPS_TESTING__
    if (gpsSerial.available())
    {
       // Debug
      //char c = gpsSerial.read();
      //Serial.print(c);
      if (gps.encode(gpsSerial.read()))
      {
        unsigned long fix_age;
        float flat,flon;
        gps.f_get_position(&flat, &flon, &fix_age);
        if ( (fix_age > 5000) || (fix_age == TinyGPS::GPS_INVALID_AGE) ) continue;
        if ( numFixes < 5 )
        {
          numFixes++;
          lcdSerial << ".";
          // Debug
          Serial << "Fix" << flat << ", " << flon << ", " << fix_age << "\n";
          continue;
        }
        current_latlon[0] = fabs(flat);
        current_latlon[1] = fabs(flon);

        signalfound = true;
      }
    }
 #else
   // GPS Testing
   delay(10000);
   randomSeed(analogRead(0));
   long result = random(0, sizeof(test_latlons)/8);
   Serial.println(result);
   current_latlon[0] = test_latlons[result*2];
   current_latlon[1] = test_latlons[result*2+1];
   signalfound = true;
 #endif
  }
  
  // Debug: GPS-Stats printing
  unsigned long chars;
  unsigned short sentences;
  unsigned short failed_cs;
  gps.stats(&chars, &sentences, &failed_cs);
  Serial.println("GPS-Stats:");
  Serial << "Number of chars: " << chars << "\n";
  Serial << "Number of sentences: " << sentences << "\n";
  Serial << "Checksum errors: " << failed_cs << "\n";
  
  // Blinking cursor on
  lcdSerial.print(0xFE, BYTE);
  lcdSerial.print(0x0C, BYTE);
  // Brightness 100%
  lcdSerial.print(0x7C, BYTE);
  lcdSerial.print(157, BYTE);
  
  if (signalfound){
    currentPhase = EVAL_POS;
  } else {
    currentPhase = NO_GPS;
  }
  save_coords();
}

// Send history of activation positions via serial
void send_coords(){
  Serial << "Coordinates: \n";
  byte tries = EEPROM.read(ADDR_TRIES);
  for (byte i = 0; i < tries; i++){
    EEPROM_readAnything(ADDR_STARTCOORDS + i*sizeof(current_latlon), 
      current_latlon);
    Serial.print(current_latlon[0], 6);
    Serial << ",";
    Serial.println(current_latlon[1], 6); 
  }
}

void setup() {
  pinMode(LCD_PIN, OUTPUT);
  pinMode(GPS_OUT_PIN, OUTPUT); 
  pinMode(POLOLU_PIN, OUTPUT);
  pinMode(SERVO_PIN, OUTPUT);
  
  Serial.begin(9600);
  gpsSerial.begin(4800);
  lcdSerial.begin(9600);
  lcdclear();
  
  starttime = millis();
}

void loop() {
  switch(currentPhase){
    case INIT:
      welcome();
      break;
    case SEARCH_GPS: 
      searchgps();
      break;
    case EVAL_POS:
      evalpos();
      break;
    case SHUTDOWN: 
      shutdown();
      break;
    case DISPLAY_TRIES:
      displaytries();
      currentPhase = SHUTDOWN;
      check_seal();
      break;
    case UNLOCK:
      unlock();
      currentPhase = SHUTDOWN;
      break;
    case SEAL:
      seal();
      currentPhase = SHUTDOWN; 
      break;
    case NO_GPS:
      no_gps();
      break;
    case SEND_COORDS:
      send_coords(); 
      delay(1000);
      wait_for_reset();
      break;
    default: shutdown(); 
  }
  
  // Emergy switch off after 10 min if something fails
  if (millis() > starttime + 600000){
    lcdclear();
    lcdSerial << "Notabschaltung";
    delay(5000);
    digitalWrite( POLOLU_PIN, HIGH );
  }
} // end loop
