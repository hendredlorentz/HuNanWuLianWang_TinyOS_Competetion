#include "printf.h"
#include "Exercise3.h"
configuration Exercise3AppC {}
implementation {
  
  //main
  components MainC, Exercise3C as App, LedsC;
  App.Boot -> MainC.Boot;
  App.Leds -> LedsC;
  
  //timer
  components new TimerMilliC();
  App.Timer0 -> TimerMilliC;
    App.Timer1 -> TimerMilliC;

  //radio
  
  components ActiveMessageC;
  components new AMSenderC(AM_RADIO_COUNT_MSG);
  components new AMReceiverC(AM_RADIO_COUNT_MSG);
  App.RadioPacket -> AMSenderC;
  App.RadioReceive -> AMReceiverC;
  App.RadioSend -> AMSenderC;
  App.RadioControl -> ActiveMessageC;
 
  //printf
  components PrintfC;
  components SerialStartC;
}


