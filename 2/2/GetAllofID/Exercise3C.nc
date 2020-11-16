#include "Timer.h"
#include "Exercise3.h"
#include "printf.h"
 
module Exercise3C @safe() {
  uses {
    interface Leds;
    interface Boot;
	interface Timer<TMilli> as Timer0;
    interface Timer<TMilli> as Timer1;

    //interface Timer<TMilli> as Timer1;  
	
	//radio
	interface SplitControl as RadioControl;
    interface Receive as RadioReceive;
    interface AMSend as RadioSend;
    interface Packet as RadioPacket;
  }
}

implementation {

  message_t radiopacket;

  uint16_t node[12];
  
  int count_send=0;
  int count_node=1;
  bool sendBusy = FALSE;  //发完一个包之后才会发下一个包
  bool had_flag = FALSE;  //是否已保存结点，TRUE表示已保存该结点，FALSE表示没有
  event void Boot.booted() {
    //开启无线通信
    call RadioControl.start();
  }
 
  //开启无线通信成功
  event void RadioControl.startDone(error_t err) {
    if (err != SUCCESS){
		call RadioControl.start();
    }else{
	    
        //初始化数组里的第一个数据为自己的结点号，其他数据为300 
		int i=0;
        node[0]=TOS_NODE_ID;
		for(i=1;i<12;i++){
			node[i]=300;
		}
        call Timer0.startPeriodic(4000+TOS_NODE_ID*20);  //每个结点发送一次包
        if(TOS_NODE_ID == 0)
         call Timer1.startOneShot(9000);
        
		//call Timer1.startOneShot(10000);  //计时10s
	}
  }
  
  event void RadioControl.stopDone(error_t err) {
    // do nothing
  }
  
  void sendMsg(){
      int i=0;
      radio_msg_t* rcm_send = (radio_msg_t*)call RadioPacket.getPayload(&radiopacket, sizeof(radio_msg_t));
      
      for(i=0;i<12;i++)
          rcm_send->node[i]=node[i];
      
      if (call RadioSend.send(AM_BROADCAST_ADDR, &radiopacket, sizeof(radio_msg_t)) == SUCCESS) {
                  count_send++;
                  // 等来判断一波
                  call Leds.led2On();
                  sendBusy = TRUE;
      }
  }
  
  event void Timer0.fired() {
      sendMsg();
  }
event void Timer1.fired(){
            int i;
            if(TOS_NODE_ID == 0){
                printf("ID");
                // printfflush();
                for(i=1;i<12;i++){
                    printf(" %u",node[i]);
                }
                printf("\n");
                printfflush();
            }
            
}
  
  //发送无线通信数据包结束
  event void RadioSend.sendDone(message_t* bufPtr, error_t error) {
      if (error == SUCCESS) {  
          sendBusy = FALSE;     
    }
  }

  event message_t* RadioReceive.receive(message_t* bufPtr, void* payload, uint8_t len) {
    if (len != sizeof(radio_msg_t)) {return bufPtr;}
    else {        
        
		int i=0,j=0,temp=0;
		radio_msg_t* rcm_receive = (radio_msg_t*)payload;
        
        radio_msg_t* rcm_send = (radio_msg_t*)call RadioPacket.getPayload(&radiopacket, sizeof(radio_msg_t));
       
        call Leds.led1On();

        temp=0;//临时计数  
        for(i=0;i<12;i++){
           //加了这个判断
           if(rcm_receive->node[i]==300){
                    break;
            }
            had_flag=FALSE;
            for(j=0;j<count_node;j++){
                if(rcm_receive->node[i]==node[j]){
                    had_flag=TRUE;
                    break;
                }
            }
            
            if(!had_flag){
                temp++;
                node[count_node-1+temp]=rcm_receive->node[i];
                break;
            }
        }

        if(temp>0){
            
            count_node+=temp;
            
            for(i=0;i<12;i++)
                rcm_send->node[i]=node[i];
            
            if (call RadioSend.send(AM_BROADCAST_ADDR, &radiopacket, sizeof(radio_msg_t)) == SUCCESS) {
                  count_send++;
                  //printf("from node %u,packet count:%u\n",TOS_NODE_ID,count_send);
                  //printfflush();

                  call Leds.led0On();

          }
        }
        if(TOS_NODE_ID == 0){
         if(count_node==12){
            printf("ID");
            // printfflush();
            for(i=1;i<12;i++){
			    printf(" %u",node[i]);
		    }
            printf("\n");
            printfflush();
            count_node++;
        }
        }
      
    }   
    return bufPtr;
  }

}




