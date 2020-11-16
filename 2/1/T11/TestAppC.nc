#include<printf.h>
#include "Test.h"

configuration TestAppC {}

implementation {
  components TestC as App;

  components MainC;
  App.Boot -> MainC;

  components LedsC;
  App.Leds -> LedsC;

  components new TimerMilliC() as Timer0;
  components new TimerMilliC() as Timer1;
  
  App.Timer0 -> Timer0;
  App.Timer1 -> Timer1;
  
 
   //radio
  
  components new AMSenderC(6);
  components new AMReceiverC(6);
  components ActiveMessageC;
    
  App.RadioControl -> ActiveMessageC;
  App.Receive -> AMReceiverC;		//0x89	通道
  App.Send -> AMSenderC;
  App.Packet -> ActiveMessageC;  
  

  components PrintfC;
  components SerialStartC;
}

