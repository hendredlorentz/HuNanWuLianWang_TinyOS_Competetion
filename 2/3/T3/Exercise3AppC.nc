#include "printf.h"
#include "Exercise3.h"

/*
 *需要用到的模块：
 *-----无线通信：
 *无线通信发包（所有结点）
 *无线通信收包（所有结点）
 */

configuration Exercise3AppC {}
implementation {
  
  //main
  components MainC, Exercise3C as App, LedsC;
  App.Boot -> MainC.Boot;
  App.Leds -> LedsC;
  
  //timer
  components new TimerMilliC() as Timer0;
  components new TimerMilliC() as Timer1;
  App.Timer0 -> Timer0;
  App.Timer1 -> Timer1;
  
  //radio：无线通信
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


