### 第四届国赛题目A：寻找最大最小结点

#### 题目内容

给定 12 个传感器节点，除左下角 0 号节点外，其余 11 个节点，每一个节点会被随机分配到一个数字作为其 ID，参赛者编写程序，找出所有节点中 ID 最大和 ID 最小的节点，并将其 ID 通过左下角 0号节点发送到 PC 端打印出最大最小结点，将所有结点号按从小到大顺序打印出来。

- ==题目编写12个结点的代码，且12个结点号随机==；
- ==0号结点打印最大最小结点，从小到大打印所有结点号==；

#### 解题思路

- 每个结点设置一个数组保存已收到的结点号数据，数组第0位保存自己的结点号；

- 每个结点初始的时候会发送1次包，之后的发包数根据收到的包进行判断是否转发；

- 每个结点发送的数据包中包含一个数组，数组内容是该结点已收到的结点号信息；

- 结点收到数据包后进行判断，收到的数据包中是否存在自己未保存的结点号，如果有则会进行发包，并保存未保存的结点号；如果没有则不进行发包

- 对结点收到的结点号进行计数count_node，初始值为1（因为保存自己的结点号在0号位），设置定时器，如果count_node==12,打印出最大最小ID和按降序排列的结点号。

#### 重要代码实现

- 所有结点初始发送一个包

  ```nesc
  //1.开启无线通信成功触发
    event void RadioControl.startDone(error_t err) {
      if (err != SUCCESS){
  		call RadioControl.start();
      }else{
  	    
          //初始化数组里的第一个数据为自己的结点号，其他数据为-1  
  		int i=0;
          node[0]=TOS_NODE_ID;
  		for(i=1;i<12;i++){
  			node[i]=101;
  		}
          call Timer0.startPeriodic(5000+TOS_NODE_ID*20);  //每个结点初始发送一次包
  	}
    }
    
    event void RadioControl.stopDone(error_t err) {
    }
    
  //2.定时器Timer0触发事件
    event void Timer0.fired() {
        sendMsg();
    }
    
  //3.发送无线通信数据包
    void sendMsg(){
        int i=0;
        //创建无线通信数据包
        radio_msg_t* rcm_send = (radio_msg_t*)call RadioPacket.getPayload(&radiopacket, sizeof(radio_msg_t));
        
        //为包里的数据赋值
        for(i=0;i<12;i++)
            rcm_send->node[i]=node[i];
        
        //发送无线通信数据包
        if (call RadioSend.send(AM_BROADCAST_ADDR, &radiopacket, sizeof(radio_msg_t)) == SUCCESS) {
             count_send++;
             call Leds.led2On();
             sendBusy = TRUE;
        }
    }
  ```

- 结点收到包，判断数据包中是否有未保存的结点号，如果存在未保存的结点号，进行发包；

  ```nesc
  event message_t* RadioReceive.receive(message_t* bufPtr, void* payload, uint8_t len) {
      if (len != sizeof(radio_msg_t)) {return bufPtr;}
      else {        
          //变量定义
  		int i=0,j=0,temp=0;
  		radio_msg_t* rcm_receive = (radio_msg_t*)payload;
          
          radio_msg_t* rcm_send = (radio_msg_t*)call RadioPacket.getPayload(&radiopacket, sizeof(radio_msg_t));
          
          //收到无线通信数据包，灯0亮
          call Leds.led1On();
          
          temp=0;//临时计数，收到包中有几个不一样的结点值
          
          //收到的包中的12个结点号与已收到结点号作比较，
          for(i=0;i<12;i++){
             
             if(rcm_receive->node[i]==101){
                      break;
              }
              had_flag=FALSE;
              for(j=0;j<count_node;j++){
                  //如果已经保存过该结点，设置had_flag为TRUE，跳出循环
                  if(rcm_receive->node[i]==node[j]){  
                      had_flag=TRUE;
                      break;
                  }
              }
              
              //如果没有被保存过
              if(!had_flag){
                  temp++;  //临时计数，对收到包中 存在没有保存的 结点号的计数
                  node[count_node-1+temp]=rcm_receive->node[i];  //将没有保存的结点号保存在自己的数组中
                  break;
              }
          }
          
          //如果存在没有保存过的结点，进行包的转发
          if(temp>0){
              
              count_node+=temp;
              
              for(i=0;i<12;i++)
                  rcm_send->node[i]=node[i];
              
              if (call RadioSend.send(AM_BROADCAST_ADDR, &radiopacket, sizeof(radio_msg_t)) == SUCCESS) {
                    count_send++;
  
                    call Leds.led0On();}
          }
      }   
      return bufPtr;
    }
  ```

#### 结果展示

#### 源码

- Makefile

  ```
  COMPONENT=Exercise3AppC
  CFLAGS += -DCC2420_DEF_CHANNEL=14
            -DCC2420_DEF_RFPOWER=31
  
  CFLAGS += -I$(TOSDIR)/lib/printf
  
  include $(MAKERULES)
  ```

- Exercise3.h

  ```
  #include "printf.h"
  
  #ifndef RADIO_COUNT_TO_LEDS_H
  #define RADIO_COUNT_TO_LEDS_H
  
  //无线通信包
  typedef nx_struct radio_msg {
    nx_uint16_t node[12];
  }radio_msg_t;
  
  enum {
    AM_RADIO_COUNT_MSG = 6,
  };
  
  #endif
  ```

- Exercise3App.nc

  ```
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
  ```

- Exercise3C.nc

  ```
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
    
    bool sendBusy = FALSE;  //发完一个包之后才会发下一个包
    bool had_flag = FALSE;  //是否已保存结点，TRUE表示已保存该结点，FALSE表示没有
    
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
  			node[i]=101;
  		}
          call Timer0.startOneShot(5000+TOS_NODE_ID*20);  //每个结点初始只发送一次包
          
          if(TOS_NODE_ID==0){
              //定时打印结点数据
              call Timer1.startOneShot(7000 +TOS_NODE_ID*20);
          }
  	}
    }
    
    event void RadioControl.stopDone(error_t err) {
    }
    
    event void Timer0.fired() {
        sendMsg();
    }
    
    event void Timer1.fired() {
        int i=0,j=0,temp;
  
        if(count_node==12){
                
                //对结点排序
                for(i=0;i<12;i++){
                    for(j=i+1;j<12;j++){
                        if(node[i]>node[j]){
                            temp=node[i];
                            node[i]=node[j];
                            node[j]=temp;
                        }
                    }
                }
                
                //打印出最大最小结点
                printf("max:%u,min:%u\n",node[11],node[1]);
                printfflush();
                
                //按降序打印所有结点号
                for(i=1;i<12;i++){
                    printf("%u ",node[i]);
                }
                printf("\n");
                printfflush();
                
                //保证只打印一次
                count_node++;
          }
    }
    
    void sendMsg(){
        int i=0;
        radio_msg_t* rcm_send = (radio_msg_t*)call RadioPacket.getPayload(&radiopacket, sizeof(radio_msg_t));
        
        for(i=0;i<12;i++)
            rcm_send->node[i]=node[i];
        
        if (call RadioSend.send(AM_BROADCAST_ADDR, &radiopacket, sizeof(radio_msg_t)) == SUCCESS) {
                    count_send++;                 
                    call Leds.led2On();
                    sendBusy = TRUE;
        }
    }
    
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
          //变量定义
  		int i=0,j=0,temp=0;
  		radio_msg_t* rcm_receive = (radio_msg_t*)payload;
          
          radio_msg_t* rcm_send = (radio_msg_t*)call RadioPacket.getPayload(&radiopacket, sizeof(radio_msg_t));
          
          //收到无线通信数据包，灯0亮
          call Leds.led1On();
          
          temp=0;//临时计数，收到包中有几个不一样的结点值
          
          //收到的包中的12个结点号与已收到结点号作比较，
          for(i=0;i<12;i++){
             
             if(rcm_receive->node[i]==101){
                      break;
              }
              had_flag=FALSE;
              for(j=0;j<count_node;j++){
                  //如果已经保存过该结点，设置had_flag为TRUE，跳出循环
                  if(rcm_receive->node[i]==node[j]){  
                      had_flag=TRUE;
                      break;
                  }
              }
              
              //如果没有被保存过
              if(!had_flag){
                  temp++;  //临时计数，对收到包中 存在没有保存的 结点号的计数
                  node[count_node-1+temp]=rcm_receive->node[i];  //将没有保存的结点号保存在自己的数组中
                  break;
              }
          }
          
          //如果存在没有保存过的结点，进行包的转发
          if(temp>0){
              
              count_node+=temp;
              
              for(i=0;i<12;i++)
                  rcm_send->node[i]=node[i];
              
              if (call RadioSend.send(AM_BROADCAST_ADDR, &radiopacket, sizeof(radio_msg_t)) == SUCCESS) {
                    count_send++;
  
                    call Leds.led0On();}
          }
      }   
      return bufPtr;
    }
  }
  
  ```
  
  