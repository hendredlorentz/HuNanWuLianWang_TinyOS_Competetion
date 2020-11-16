#include "Timer.h"
#include "Exercise3.h"
#include "printf.h"
 
module Exercise3C @safe() {
  uses {
    interface Leds;
    interface Boot;
	interface Timer<TMilli> as Timer0;
    interface Timer<TMilli> as Timer1;  
	
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
  int start_send=0;
  
  //bool trans_flag=FALSE;  //是否转发包的标志
  bool sendBusy = FALSE;  //发完一个包之后才会发下一个包
  bool had_flag = FALSE;  //是否已保存结点，TRUE表示已保存该结点，FALSE表示没有
  bool had_print=FALSE;
  
  void sendMsg();

  event void Boot.booted() {
    //开启无线通信
    call RadioControl.start();
  }
 
  //开启无线通信成功
  event void RadioControl.startDone(error_t err) {
    if (err != SUCCESS){
		call RadioControl.start();
    }else{
	    
        //初始化数组里的第一个数据为自己的结点号，其他数据为-1  
		int i=0;
        node[0]=TOS_NODE_ID;
		for(i=1;i<12;i++){
			node[i]=300;
		}
        call Timer0.startOneShot(2500+TOS_NODE_ID*20);  //每个结点发送一次包
        call Timer0.startOneShot(3500+TOS_NODE_ID*20); 
        //call Timer0.startPeriodic(2000+TOS_NODE_ID*10);  //每个结点发送一次包
        //if(TOS_NODE_ID==0){
            //call Timer1.startOneShot(6000 +TOS_NODE_ID*20);
         call Timer1.startOneShot(9000);
        //}
	}
  }
  
  event void RadioControl.stopDone(error_t err) {
    // do nothing
  }
  
  event void Timer0.fired() {
      //sendMsg();
      //if(start_send<5){
          int i=0;
          radio_msg_t* rcm_send = (radio_msg_t*)call RadioPacket.getPayload(&radiopacket, sizeof(radio_msg_t));

          for(i=0;i<12;i++)
              rcm_send->node[i]=node[i];

          if (call RadioSend.send(AM_BROADCAST_ADDR, &radiopacket, sizeof(radio_msg_t)) == SUCCESS) {
                      count_send++;                 
                      call Leds.led2On();
                      sendBusy = TRUE;
          }
          
          //start_send++;
      //}
      
  }
  
  event void Timer1.fired() {
      int i=0,j=0,temp;
      //printf("timer1\n,%u",count_node);
      //printfflush();
      //if(count_node==12&&TOS_NODE_ID==0){
/*            printf("Data");
            //printfflush();
            for(i=0;i<12;i++){
                printf(" %u",node[i]);
		    }
            printf("\n");
            printfflush();
            count_node++;
            printf("node: %u,send_count:%u\n",TOS_NODE_ID,count_send);
            printfflush();*/
            
/*            for(i=0;i<12;i++){
                  if(node[i]>max){
                      max=node[i];
                  }
                  if(node[i]!=0&&node[i]<min){
                      min=node[i];
                  }
              }*/
              
              /*printf("max:%u,min:%u\n",max,min);
              printfflush();*/
              if(!had_print){
                      for(i=0;i<12;i++){
                          for(j=i+1;j<12;j++){
                              if(node[i]>node[j]){
                                  temp=node[i];
                                  node[i]=node[j];
                                  node[j]=temp;
                              }
                          }
                       }

    /*              if(TOS_NODE_ID==0){
                      printf("ID0 %u %u %u\n",node[9],node[10],node[11]);
                      printfflush();
                  }
                  if(TOS_NODE_ID==1){
                      printf("ID1 %u %u %u\n",node[2],node[3],node[4]);
                      printfflush();
                  }*/
                  //printf("max:%u,min:%u\n",node[11],node[1]);
                  printf("MAXID %u\n",node[count_node-1]);
                  printfflush();

/*                 printf("ID");
                 for(i=1;i<12;i++){
                      printf(" %u",node[i]);
                  }
                  printf("\n");
                  printfflush();*/

                  count_node++;
              }
              
        //}
  }
  
/*  void sendMsg(){

  }*/
  
  //发送无线通信数据包结束
  event void RadioSend.sendDone(message_t* bufPtr, error_t error) {
      if (error == SUCCESS) {  
          sendBusy = FALSE;     
    }
   }

  //接收到无线通信数据包
  /*
  接收到无线通信数据包，判断里面是否有未保存的数据结点
  如果有就设置转发包的flag为TRUE，保存数据完毕后，将自己结点保存的数组作为包数据发出去
  如果没有则不转发包
  */
  event message_t* RadioReceive.receive(message_t* bufPtr, void* payload, uint8_t len) {
    if (len != sizeof(radio_msg_t)) {return bufPtr;}
    else {        
        
		int i=0,j=0,temp=0;
		radio_msg_t* rcm_receive = (radio_msg_t*)payload;
        
        radio_msg_t* rcm_send = (radio_msg_t*)call RadioPacket.getPayload(&radiopacket, sizeof(radio_msg_t));
       
        call Leds.led1On();
        
        //trans_flag=FALSE;
        temp=0;//临时计数，收到包中有几个不一样的结点值
        
        for(i=0;i<12;i++){
           
           if(rcm_receive->node[i]==300){
                    break;
            }
            had_flag=FALSE;
            for(j=0;j<count_node;j++){
                if(rcm_receive->node[i]==node[j]){   //!!!这里，应该是在这个是数组里找有没有相同的，而不是判断不同
                    had_flag=TRUE;
                    break;
                }
            }
            
            if(!had_flag){
                //trans_flag=TRUE;  //设置转发包的标志位为TRUE
                temp++;  //临时计数，对收到包中 存在没有保存的 结点号的计数
                node[count_node-1+temp]=rcm_receive->node[i];  //将没有保存的结点号保存在自己的数组中
                break;
            }
        }
        
        //如果转发标志位为真，进行发包操作
        //if(trans_flag){
        if(temp>0){
            
            count_node+=temp;
            
            for(i=0;i<12;i++)
                rcm_send->node[i]=node[i];
            
            if (call RadioSend.send(AM_BROADCAST_ADDR, &radiopacket, sizeof(radio_msg_t)) == SUCCESS) {
                  count_send++;
                  call Leds.led0On();
          }
        }
        
        if(count_node==12){
            for(i=0;i<12;i++){
                  for(j=i+1;j<12;j++){
                      if(node[i]>node[j]){
                          temp=node[i];
                          node[i]=node[j];
                          node[j]=temp;
                      }
                  }
             }
                           
/*             printf("ID");
             for(i=1;i<12;i++){
                  printf(" %u",node[i]);
              }
              printf("\n");
              printfflush();*/
              printf("MAXID %u\n",node[11]);
              printfflush();
              
              count_node++;
              had_print=TRUE;
        }
        
        return bufPtr;
    }   
    
  }

}




