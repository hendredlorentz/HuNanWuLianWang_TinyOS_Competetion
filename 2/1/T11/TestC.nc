#include <Timer.h>
#include "Test.h"
#include<printf.h>

module TestC {
  uses interface Boot;
  uses interface Leds;
  
  uses interface Timer<TMilli> as Timer0;
  uses interface Timer<TMilli> as Timer1;
  
  uses interface SplitControl as RadioControl;
  uses interface Packet;
  uses interface AMSend as Send;
  uses interface Receive;

}

implementation {

  message_t packet;
  message_t copy_packet;
  uint16_t data = 0;
  uint16_t flag = 1;

  event void Boot.booted() {
    call RadioControl.start();
  }

  event void RadioControl.startDone(error_t err) {
    if (err != SUCCESS) 
      call RadioControl.start();
  }
  
  



  event void RadioControl.stopDone(error_t err) {}
  

  event void Timer0.fired() {
      
  }
  
  event void Timer1.fired() {
      call Send.send(0xFFFF, &copy_packet, sizeof(test_radio_msg_t));
  }


  
  event message_t*                                                               
             Receive.receive(message_t* buffer, void* payload, uint8_t len) {
             
       
            test_radio_msg_t* rcm = (test_radio_msg_t*)payload;
            test_radio_msg_t* msg = (test_radio_msg_t *)call Send.getPayload(&copy_packet, sizeof(test_radio_msg_t));
            if(flag == 1){
                printf("Data %u\n", rcm -> data);
                printfflush();
                flag = 0;
                msg -> data = rcm -> data;
                call Send.send(0xFFFF,&copy_packet,sizeof(test_radio_msg_t));
            }
     
        return buffer;
     }


  event void Send.sendDone(message_t* bufPtr, error_t err) {}
  
 

 
}
