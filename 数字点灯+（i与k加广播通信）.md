# 国赛题2 --- 数字接龙

## 题目描述

给定12个传感器节点，节点位置已知，参赛着根据指定信息分别点亮12个传感器节点上不同颜色的LED灯，形成不同颜色的图形。如

```c
//1 表示
uint8_t ids0[12] = {1,1,1,1,1,0,0,1,1,1,1,1};	
// 0 要打开灯的节点为 0，1，2，3，4，7，8，9，10，11
uint8_t ids1[12] = {1,0,0,0,1,0,0,0,1,0,0,0};
// 1 要打开灯的节点为 0，4，8
uint8_t ids2[12] = {1,1,1,0,0,1,0,0,1,1,1,0};
// 2 要打开灯的节点为 0，1，2，5，8，9，10，11
uint8_t ids3[12] = {1,1,1,0,0,1,1,0,1,1,1,0};
// 3 要打开灯的节点为 0，1，2，5，6，8，9，10
uint8_t ids4[12] = {1,1,0,0,1,1,1,0,0,1,0,0};
// 4 要打开灯的节点为 0，1，4，5，6，9
```

通过串口通信模拟大赛0号节点的发送数据。串口数据类型为00 FF FF 00 00 02 00 89 **03 02** 节点通过串口接受到数据进行分析 03 表示要显示的数字，02表示要显示的灯号

## 分发汇聚实现

### 按顺序点灯

- 使用的数据结构

```c
#ifndef TEST_H
#define TEST_H
#include <AM.h>
typedef nx_struct test_fy_msg {			//分发包的数据结构
    nx_uint8_t flag;		//该节点是否亮灯
    nx_uint8_t count;		//发包顺序 0 - 12 也是需要点灯的节点号
    nx_uint8_t data;		//灯的序号 同 下文的 data 一样
} test_fy_msg_t;

typedef nx_struct test_serial_msg {		//串口通信包的数据结构
  nx_uint8_t id;					//显示的数字的id号 00 表示 0 01 表示 。。
  nx_uint8_t data;					//显示的灯号
} test_serial_msg_t;

enum {
 AM_TESTNETWORKMSG = 0x05,
 SAMPLE_RATE_KEY = 0x1,
 CL_TEST = 0xee,
 TEST_NETWORK_QUEUE_SIZE = 8,
};

#endif
```

- 使用的组件 --- 分发，无线通信，`LedsC`亮灯模块

```
#include<printf.h>
#include "Test.h"

configuration TestAppC {}

implementation {
  components TestC as App;
  components MainC;
  App.Boot -> MainC;

  components ActiveMessageC;		//基于CTP分发的无线通信模块
  App.RadioControl -> ActiveMessageC;
	
  components DisseminationC;		//分发模块
  App.DisseminationControl -> DisseminationC;

  components new DisseminatorC(test_fy_msg_t, 0x1234) as Diss16C;
  App.Value -> Diss16C;
  App.Update -> Diss16C;

  components LedsC;			//led灯的模块
  App.Leds -> LedsC;

  components new TimerMilliC() as Timer0;		//定时器模块
  components new TimerMilliC() as Timer1;
  
  App.Timer0 -> Timer0;
  App.Timer1 -> Timer1;
  
  //serial	串口通信的模块
  components SerialActiveMessageC as AM;
  
  App.Control -> AM;
  App.uartReceive -> AM.Receive[0x89];		//0x89	通道
  App.uartSend -> AM.AMSend[0x89];  
  App.uartPacket -> AM;
  
  components PrintfC;		//printf模块
  components SerialStartC;
}
```

- 主要逻辑，鉴于有可能赛题方可能要求按顺序亮灯，使用使用分发时不是分发一个整个数组，而是一个一个节点的发送，这样可以确保亮灯顺序按照我们所想的执行。

```
#include <Timer.h>
#include "Test.h"
#include<printf.h>

module TestC {
  uses interface Boot;
  uses interface SplitControl as RadioControl;
  uses interface StdControl as DisseminationControl;
  uses interface DisseminationValue<test_fy_msg_t> as Value;
  uses interface DisseminationUpdate<test_fy_msg_t> as Update;
  uses interface Leds;
  uses interface Timer<TMilli> as Timer0;
  uses interface Timer<TMilli> as Timer1;
  
  uses interface SplitControl as Control; 
  uses interface AMSend as uartSend;
  uses interface Receive as uartReceive;
  uses interface Packet as uartPacket;
}

implementation {

  uint8_t data = 0;
  
  //需要分发的节点数据
  uint8_t ids [12]; 
 
  //存储所需要数字的亮灯情况
  uint8_t ids0[12] = {1,1,1,1,1,0,0,1,1,1,1,1};
  uint8_t ids1[12] = {1,0,0,0,1,0,0,0,1,0,0,0};
  uint8_t ids2[12] = {1,1,1,0,0,1,0,0,1,1,1,0};
  uint8_t ids3[12] = {1,1,1,0,0,1,1,0,1,1,1,0};
  uint8_t ids4[12] = {1,1,0,0,1,1,1,0,0,1,0,0};
  
  uint8_t i = 0;
  uint8_t count = 0;	//发包顺序 0 - 12 也是需要点灯的节点号
  uint8_t flag = 0;		//是否亮灯
  test_fy_msg_t p;		//分发的数据包
  
  event void Boot.booted() {
    call RadioControl.start();
  }

  event void RadioControl.startDone(error_t err) {
    if (err != SUCCESS) 
      call RadioControl.start();
    else {
      call Control.start();      
    }
  }
    
  event void Control.startDone(error_t err) {
      if (err != SUCCESS) 
          call Control.start();
      else {
          call DisseminationControl.start();
      }
  }
  
  event void Control.stopDone(error_t err) {}

  event void RadioControl.stopDone(error_t err) {}

  event void Timer0.fired() {		//串口收到包之后泛洪出去
      //printf("i send a packet");
      //printfflush();
      p.flag = ids[count];		//该count节点是否亮灯
      p.count = count;			//count -> 发包顺序 0 - 12 也是需要点灯的节点号
      p.data = data;			//灯的序号
      call Update.change(&p);	//分发 	
      count++;					//发送下一个
  }
  
  event void Timer1.fired() {	//关灯以及初始化行为
      call Leds.led1Off();		
      call Leds.led2Off();
      call Leds.led0Off();
      call Timer0.stop();
      count = 0;
  }

  event message_t* uartReceive.receive(message_t* bufPtr, 
                   void* payload, uint8_t len) {
    if (len != sizeof(test_serial_msg_t)) {return bufPtr;}
    else {
	  //串口收包，进行ids的初始化操作
      test_serial_msg_t* rcm = (test_serial_msg_t*)payload;
      count = 0;
      //printf("%u",rcm -> id);
      //printfflush();
      //将需要输出ids 通过ids0，ids1,ids2,ids3,ids4,ids5的值赋给ids
      if(rcm -> id == 1){
          for(i = 0; i < 12; i++){
              ids[i] = ids1[i];
          }
      }
      if(rcm -> id == 2){
          for(i = 0; i < 12; i++){
              ids[i] = ids2[i];
          }
      }
      if(rcm -> id == 3){
          for(i = 0; i < 12; i++){
              ids[i] = ids3[i];
          }
      }
      if(rcm -> id == 4){
          for(i = 0; i < 12; i++){
              ids[i] = ids4[i];
          }
      }
      data = rcm -> data;
      call Timer0.startPeriodic(1000);  	//每隔一秒发送一此
      return bufPtr;
    }
  }  
  
  event void uartSend.sendDone(message_t* bufPtr, error_t error) {}

  event void Value.changed() {		//收到包之后，进行一系列判断，判断自身是否需要开灯，开什么灯
    const test_fy_msg_t * rcm = call Value.get();	
       if(TOS_NODE_ID == rcm -> count){
               if(rcm -> flag == 1){
                   if(rcm -> data == 0){
                   call Leds.led0On();
               }
               if(rcm -> data == 1){
                   call Leds.led1On();
               }
               if(rcm -> data == 2){
                   call Leds.led2On();
               }
           }
           call Timer1.startOneShot(12000 - TOS_NODE_ID * 1000 );
       }
    }
}

```

- 遇到的坑

```
 event void Timer1.fired() {	//关灯以及初始化行为
      call Leds.led1Off();		
      call Leds.led2Off();
      call Leds.led0Off();
      call Timer0.stop();
      count = 0;	//count = 0; 此时需要赋给count初始值，这样才能二次发包成功
  }
```

### 一起点灯

一起点灯，即不按顺序进行点灯，此时我们只需要发一个包即可，该包包含12个节点的亮灯情况。





## 泛洪实现

逻辑：节点收到数据源节点的包，只发一次之后，停止发送无线通信的包。

- 代码主逻辑

```
#include "Timer.h"
#include "Test.h"
#include "printf.h"

module TestC @safe()
{
    uses interface Timer<TMilli> as Timer0;
    uses interface Timer<TMilli> as Timer1;
    uses interface Timer<TMilli> as Timer2;
    uses interface Leds;
    uses interface Boot;
     
     
    uses interface SplitControl as RadioControl;
    uses interface Packet;
    uses interface AMSend as Send;
    uses interface Receive;
    
    
    uses interface SplitControl as Control; 
    uses interface AMSend as uartSend;
    uses interface Receive as uartReceive;
    uses interface Packet as uartPacket;
    
}
implementation
{ 
    message_t packet;
    message_t copy_packet;
      
    uint16_t flag = 1;
    uint16_t i = 0;
    uint16_t data;
    uint8_t ids[12];
    uint8_t ids0[12] = {1,1,1,1,1,0,0,1,1,1,1,1};
    uint8_t ids1[12] = {1,0,0,0,1,0,0,0,1,0,0,0};
    uint8_t ids2[12] = {1,1,1,0,0,1,0,0,1,1,1,0};
    uint8_t ids3[12] = {1,1,1,0,0,1,1,0,1,1,1,0};
    uint8_t ids4[12] = {1,1,0,0,1,1,1,0,0,1,0,0};

    event void Boot.booted()
    { 
       call RadioControl.start();   //开启无线通信
    }
    
    
    event void RadioControl.startDone(error_t err) {
        if (err != SUCCESS) {
          call RadioControl.start(); 
        }
        else {                                  
          call Control.start();         //串口通信模块 
        }
    }


    event void Control.startDone(error_t err){
       if (err == SUCCESS) {    
       }
   }
	
	//串口收到包之后泛洪发出去
   event void Timer0.fired() {
        test_radio_msg_t* msg = (test_radio_msg_t *)call Send.getPayload(&packet, sizeof(test_radio_msg_t));
        
        for(i = 0; i < 12; i++){
            msg -> ids[i] = ids[i];
        }
        msg -> data = data;
        
        call Send.send(0xFFFF,&packet, sizeof(test_radio_msg_t));         
   }   
   
   
   event void Timer1.fired() { 
       
   } 

   //灭灯操作以及初始化操作
   event void Timer2.fired() { 
       call Leds.led1Off();
       call Leds.led2Off();
       call Leds.led0Off();
       flag = 1;		//灭灯之后初始化
   } 

   event void RadioControl.stopDone(error_t err) {}
   event void Control.stopDone(error_t err) {}
   event message_t* uartReceive.receive(message_t* bufPtr, 
                   void* payload, uint8_t len) {
    if (len != sizeof(test_serial_msg_t)) {return bufPtr;}
    else {

      test_serial_msg_t* rcm = (test_serial_msg_t*)payload;
      
      //printf("i send a packet");
      //printfflush();
      //将数组保证在ids中
      if(rcm -> id == 0){
          for(i = 0; i < 12; i++){
              ids[i] = ids0[i];
          }
      }
      if(rcm -> id == 1){
          for(i = 0; i < 12; i++){
              ids[i] = ids1[i];
          }
      }
      if(rcm -> id == 2){
          for(i = 0; i < 12; i++){
              ids[i] = ids2[i];
          }
      }
      if(rcm -> id == 3){
          for(i = 0; i < 12; i++){
              ids[i] = ids3[i];
          }
      }
      if(rcm -> id == 4){
          for(i = 0; i < 12; i++){
              ids[i] = ids4[i];
          }
      }
      
      data = rcm -> data;
       
      call Timer0.startOneShot(1000);  //无线发包
      return bufPtr;
    }
  }  
     
      event message_t*                                                               
             Receive.receive(message_t* buffer, void* payload, uint8_t len) {
             
        test_radio_msg_t* rcm = (test_radio_msg_t*)payload;
 
        test_radio_msg_t* msg = (test_radio_msg_t*)call Send.getPayload(&copy_packet, sizeof(test_radio_msg_t));
        
        if(flag == 1){		//是否收到过包的判断
            //printf("i receive a packet");
            //printfflush();
            //printf("data: ");
            
            for(i = 0; i < 12; i++){
                msg -> ids[i] = rcm -> ids[i];
                printf("%u ",rcm -> ids[i]);
                if(rcm -> ids[TOS_NODE_ID] == 1 ){
                    //printf("i open the leds");
                    //printfflush();
                    if(rcm -> data == 0){
                        call Leds.led0On();
                    }
                    if(rcm -> data == 1){
                        call Leds.led1On();
                    }
                    if(rcm -> data == 2){
                        call Leds.led2On();
                    }            
                    call Timer2.startOneShot(3000);
                 }
            }
            printfflush();   
            msg -> data = rcm -> data;
            flag = 0;  		//收到包之后，将标志位归零
            call Send.send(0xFFFF,&copy_packet, sizeof(test_radio_msg_t)); //发包         
        }
        
        return buffer;
     }


    event void Send.sendDone(message_t* bufPtr, error_t err) {}
    event void uartSend.sendDone(message_t* bufPtr, error_t error) {}
    
}
```

- 坑

标志位是否重新赋值，标志位在什么时候赋值，我们要在写题目之前就要有答案。每次灭灯意味着一次操作的结束，另外一个操作的开始，此时flag必须赋值为1，不然再次操作时，因为flag为0，节点收到包，但是不会进行点灯操作，导致亮灯失败

- 泛洪的优化

由于我们只需要收到一个包即可，那么每个节点收到一个包，转发一次就行了，这样就只需要发12个包即可。

# 国赛题3 --- 任务发包

## 题目描述

给定 12个传感器节点（如图 2 所示），参赛团队需对除 0 号节点以外的 11 个节点进行编程，设计一个路由协议，通过单跳或多跳完成数据的转发，实现网络中任意节点之间的通信。大赛组委会将 0 号节点作为数据源节点发送任务数据包给任意某节点 `i`（数据包格式见注 3），参赛队需将获取到的任务编号发送到节点 `k`。`i `和` k` 号节点从 1-100 号随机选取。参赛队需将 `k `号节点从` i` 号节点收到的任务编号通过串口打印出来，从而表明完成了
对应的任务（即能实现` i`到 `k` 的路由）。

模拟： 由于没有0号节点的程序，所有使用串口通信来模拟一号程序的发包。

过程：将三个信息（起始点 `i` ，结束点 `k`，任务数据 `data`） 发送给 0号节点，然后0号节点通过无线通信发送给节点`i` ，节点 `i` 通过无线通信发送到节点`k` 节点`k`收到之后打印出数据 `data`。

进阶：将路径打印出来，要求起点必须是`i`，终点必须是`k`。

## 分发实现

- 使用的数据结构

```
#ifndef TEST_H
#define TEST_H
#include <AM.h>

typedef nx_struct test_fy_msg {		//分发的数据包
    nx_uint16_t begin_id;
    nx_uint16_t end_id;
    nx_uint16_t data;
} test_fy_msg_t;

typedef nx_struct test_serial_msg {			//串口的数据包
   nx_uint16_t begin_id;
   nx_uint16_t end_id;
   nx_uint16_t data;
} test_serial_msg_t;

typedef nx_struct test_radio_msg {			//无线通信的数据包
   nx_uint16_t begin_id;
   nx_uint16_t end_id;
   nx_uint16_t data;
} test_radio_msg_t;

enum {
 AM_RADIO_COUNT_MSG = 6,
 AM_TESTNETWORKMSG = 0x05,
 SAMPLE_RATE_KEY = 0x1,
 CL_TEST = 0xee,
 TEST_NETWORK_QUEUE_SIZE = 8,
};

#endif
```

- 使用的组件 --- 分发，无线通信，串口通信

```
#include<printf.h>
#include "Test.h"

configuration TestAppC {}

implementation {
  components TestC as App;
  components MainC;
  App.Boot -> MainC;

  //radio	
  components new AMSenderC(AM_RADIO_COUNT_MSG);
  components new AMReceiverC(AM_RADIO_COUNT_MSG);
  components ActiveMessageC;
  App.RadioControl -> ActiveMessageC;
  App.Receive -> AMReceiverC;		//0x89	通道
  App.Send -> AMSenderC;
  App.Packet -> ActiveMessageC;  

  //分发
  components DisseminationC;
  App.DisseminationControl -> DisseminationC;
  components new DisseminatorC(test_fy_msg_t, 0x1234) as Diss16C;
  App.Value -> Diss16C;
  App.Update -> Diss16C;

  components LedsC;
  App.Leds -> LedsC;

  components new TimerMilliC() as Timer0;
  components new TimerMilliC() as Timer1;
  App.Timer0 -> Timer0;
  App.Timer1 -> Timer1;
  
  //serial
  components SerialActiveMessageC as AM;
  App.Control -> AM;
  App.uartReceive -> AM.Receive[0x89];		//0x89	通道
  App.uartSend -> AM.AMSend[0x89];  
  App.uartPacket -> AM;
  
  components PrintfC;
  components SerialStartC;
}
```

- 逻辑：将三个信息（起始点 `i` ，结束点 `k`，任务数据 `data`） 发送给 0号节点，然后0号节点通过无线通信发送给节点`i` ，节点 `i` 通过分发使得所有节点都能收到数据包，判断收到的节点是否是结束点`k`如果是，则打印任务数据`data`

```
#include <Timer.h>
#include "Test.h"
#include<printf.h>

module TestC {
  uses interface Boot;
  uses interface StdControl as DisseminationControl;
  uses interface DisseminationValue<test_fy_msg_t> as Value;
  uses interface DisseminationUpdate<test_fy_msg_t> as Update;
  
  uses interface Leds;
  uses interface Timer<TMilli> as Timer0;
  uses interface Timer<TMilli> as Timer1;
  
  uses interface SplitControl as RadioControl;
  uses interface Packet;
  uses interface AMSend as Send;
  uses interface Receive;
  
  uses interface SplitControl as Control; 
  uses interface AMSend as uartSend;
  uses interface Receive as uartReceive;
  uses interface Packet as uartPacket;
}

implementation {

  message_t packet;
  
  uint16_t data = 0;
  uint16_t i = 0;
  uint16_t count = 0;
  uint16_t begin_id;		//起始点的id号
  test_fy_msg_t p;
  
  event void Boot.booted() {
    call RadioControl.start();
  }

  event void RadioControl.startDone(error_t err) {
    if (err != SUCCESS) 
      call RadioControl.start();
    else {
      call Control.start();      
    }
  }
  
  
  event void Control.startDone(error_t err) {
      if (err != SUCCESS) 
          call Control.start();
      else {
          call DisseminationControl.start();
      }
  }
  
  
  
  event void Control.stopDone(error_t err) {}

  event void RadioControl.stopDone(error_t err) {}

  //发送给节点i 即begin_id	
  event void Timer0.fired() {
      call Send.send(begin_id,&packet, sizeof(test_radio_msg_t));
  }
  
  event void Timer1.fired() {
  
  }

  //串口收到包之后，设置定时器发送给节点i
  event message_t* uartReceive.receive(message_t* bufPtr, 
                   void* payload, uint8_t len) {
    if (len != sizeof(test_serial_msg_t)) {
        //printf("i receive a error packet");
        //printfflush(); 
        return bufPtr;  
    }
    else {

      test_serial_msg_t* rcm = (test_serial_msg_t*)payload;
     
      test_radio_msg_t* msg = (test_radio_msg_t *)call Send.getPayload(&packet, sizeof(test_radio_msg_t));
     
      //printf("i receive a packet");
      //printfflush();
      
      //赋值操作
      msg -> data = rcm -> data;
      begin_id = msg -> begin_id = rcm -> begin_id;
      msg -> end_id = rcm -> end_id;

      call Timer0.startOneShot(1000);  
      return bufPtr;
    }
  }  
  
  //节点i 收到数据之后进行分发
  event message_t*                                                               
             Receive.receive(message_t* buffer, void* payload, uint8_t len) {
             
        test_radio_msg_t* rcm = (test_radio_msg_t*)payload;
        
        p.data = rcm -> data;
        p.begin_id = rcm -> begin_id;
        p.end_id = rcm -> end_id;

       //printf("i receive a radio packet");
        //printfflush();
        
        //使用分发发送结构体
        call Update.change(&p);
       
        return buffer;
     }


    event void Send.sendDone(message_t* bufPtr, error_t err) {}
  
  
   event void uartSend.sendDone(message_t* bufPtr, error_t error) {}

 //其他的节点收到分发的包之后，解析包的内容，判断自身节点是否是 k,即end_id
  event void Value.changed() {
    const test_fy_msg_t * rcm = call Value.get();
       if(TOS_NODE_ID == rcm -> end_id){
           printf("Data: %u", rcm -> data);
           printfflush();
       }
    }   
}

```

## 无线通信实现 --- 进阶打印 `i` 到 `k` 的路径

无线通信与分发最大的区别，就是如何控制泛洪的次数，如何将发包数量降到最少

- 使用的组件

```
#ifndef TEST_H
#define TEST_H
#include <AM.h>

typedef nx_struct test_radio_msg1 {			//从i 泛洪 到 k 使用的包的结构
    nx_uint16_t path[12];
    nx_uint16_t count;
    nx_uint16_t begin_id;
    nx_uint16_t end_id;
    nx_uint16_t data;
} test_radio_msg1_t;

typedef nx_struct test_radio_msg {			//从0 发到 i 使用的包的结构
    nx_uint16_t begin_id;
    nx_uint16_t end_id;
    nx_uint16_t data;
} test_radio_msg_t;

typedef nx_struct test_serial_msg {			//串口通信的包
   nx_uint16_t begin_id;
   nx_uint16_t end_id;
   nx_uint16_t data;
} test_serial_msg_t;

enum {
 AM_RADIO_COUNT_MSG = 6,
 AM_TESTNETWORKMSG = 0x05,
 SAMPLE_RATE_KEY = 0x1,
 CL_TEST = 0xee,
 TEST_NETWORK_QUEUE_SIZE = 8,
};

#endif
```

- 主要逻辑：通过串口发送给`0`号起始`id`，终点`id`，以及任务数据data，然后通过无线通信发送给起始节点`i`，然后节点`i`通过泛洪发送给节点`k`，然后节点`k`打印出任务数据，并打印出无线通信的路径。

```
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
  
  uses interface SplitControl as Control; 
  uses interface AMSend as uartSend;
  uses interface Receive as uartReceive;
  uses interface Packet as uartPacket;
}

implementation {

  message_t packet;
  message_t copy_packet;
  uint16_t data = 0;
  
  uint16_t i = 0;	
  uint16_t count = 0;
  uint16_t begin_id;
  uint16_t flag = 1;

  event void Boot.booted() {
    call RadioControl.start();
  }

  event void RadioControl.startDone(error_t err) {
    if (err != SUCCESS) 
      call RadioControl.start();
    else {
      call Control.start();      
    }
  }
  
  event void Control.startDone(error_t err) {
      if (err != SUCCESS) 
          call Control.start();
  }
  
  event void Control.stopDone(error_t err) {}

  event void RadioControl.stopDone(error_t err) {}
  
  //0号节点收到数据通过无线通信发送给节点i
  event void Timer0.fired() {
      //printf("serial send a packet");
      //printfflush();
      call Send.send(begin_id,&packet, sizeof(test_radio_msg_t));
  }
  
  //节点i通过泛洪发包
  event void Timer1.fired() {
      call Send.send(0xFFFF, &copy_packet, sizeof(test_radio_msg1_t));
  }

  //串口收包	
  event message_t* uartReceive.receive(message_t* bufPtr, 
                   void* payload, uint8_t len) {
    if (len != sizeof(test_serial_msg_t)) {
        return bufPtr;  
    }
    else {

      test_serial_msg_t* rcm = (test_serial_msg_t*)payload;
     
      test_radio_msg_t* msg = (test_radio_msg_t *)call Send.getPayload(&packet, sizeof(test_radio_msg_t));
      // 将串口数据转换为无线通信的数据并发送给节点i
      msg -> data = rcm -> data;
      begin_id = msg -> begin_id = rcm -> begin_id;
      msg -> end_id = rcm -> end_id;
      
      call Timer0.startOneShot(1000);  
      return bufPtr;
    }
  }  
  
  //无线通信收包，无线通信会收到两种包，一种是0号节点发送给节点i的包 为test_radio_msg_t
  //另外一种包为节点i泛洪发出去的包 为test_radio_msg1_t
  
  event message_t*                                                               
             Receive.receive(message_t* buffer, void* payload, uint8_t len) {
             
        if(len == sizeof(test_radio_msg_t)){		//收到第一种包的操作
            test_radio_msg_t* rcm = (test_radio_msg_t*)payload;
            test_radio_msg1_t* msg = (test_radio_msg1_t *)call Send.getPayload(&copy_packet, sizeof(test_radio_msg1_t));
            //初始化数据
            if(rcm -> begin_id == TOS_NODE_ID){
                 //printf("i receive a packet and send a packet");
                 //printfflush();
                 msg -> count = 0;
                 msg -> begin_id = rcm -> begin_id;
                 msg -> end_id = rcm -> end_id;
                 msg -> data = rcm -> data;
                 
                 for(i = 0; i < 12; i++){
                     msg -> path[i] = 300;
                 }
                 //msg -> count = 0; 使数组的开头都是begin_id
                 msg -> path[msg -> count] = TOS_NODE_ID;
                 call Send.send(0xFFFF, &copy_packet, sizeof(test_radio_msg1_t));
            }      
        }else if(len == sizeof(test_radio_msg1_t)){   //收到第二种吧      
            test_radio_msg1_t* rcm = (test_radio_msg1_t*)payload;
            test_radio_msg1_t* msg = (test_radio_msg1_t *)call Send.getPayload(&copy_packet, sizeof(test_radio_msg1_t));
            
            //将rcm 的数据复制到rcm上，注意每个变量都需要复杂，变量有点多
            //初始化flag ,flag = 1意味着该节点没有收到这个包，需要将节点id保存到数组中
            flag = 1;
            msg -> begin_id = rcm -> begin_id;
            msg -> end_id = rcm -> end_id;
            msg -> data = rcm -> data;
            msg -> count = rcm -> count;
            
            //printf("%u ",rcm -> path[0]);
            //printfflush();
            
            // 判断这个包之前是否该节点已经接受过这个包
            // 分别判断这个包的起始节点是否是begin_id  以及数组里面是否包含这个节点id
            
            for(i = 0; i < 12; i++){
                msg -> path[i] = rcm -> path[i];
            }
            if(rcm -> path[0] != msg -> begin_id){
                 flag = 0;
            } 
            for(i = 0; i < 12; i++){
                if(rcm -> path[i] == TOS_NODE_ID){
                    flag = 0;
                }
                msg -> path[i] = rcm -> path[i];
                //msg -> path[i] = msg -> path[i];
            }
            
            //printf(" i receive %u \n",flag);
           // printfflush();
			
			//如果该节点没有收到过这个包，则需要将自身id赋值给msg->path[++msg -> count];
			
            if(flag == 1){
                //printf(" i send a packet count: %u\n",msg -> count);
                //printfflush();
                msg -> count++;
                msg -> path[msg -> count] = TOS_NODE_ID;
                //printf("count: %u  data: %u", msg -> count,msg -> path[msg -> count]);
                //printfflush();
                //printf("Data: ");
                for(i = 0; i <= msg -> count; i++){
                    //printf("%u ",msg-> path[i]);
                } 
                
                //如果这个包传到了end_id 意味着这个包到了终点
                //我们需要打印出任务包data以及路径
                if(TOS_NODE_ID == msg -> end_id){
                    //printf("i receive a packet");
                    //printfflush();
                    if(msg -> path[msg -> count] == TOS_NODE_ID){
                        printf("Data: %u",msg -> data);
                        printf(" Path:");
                        for(i = 0; i <= msg -> count; i++){
                           printf(" %u",msg -> path[i]);
                        }
                        printfflush();
                    }                 
                }
                
                //泛洪发包
                call Timer1.startOneShot(100 + TOS_NODE_ID * 10);
            }
        }
        return buffer;
     }
   event void Send.sendDone(message_t* bufPtr, error_t err) {}
   event void uartSend.sendDone(message_t* bufPtr, error_t error) {}
}
```

- 坑

在泛洪的时候，我们一定要将所有的数据复制到`msg`包中！！！ 在`receive`操作的数据也是`msg`而不是`rcm`，要清楚`msg`包与`rcm`包的区别，count比`rcm`多1，msg -> path[count] 赋值过了，而`rcm -> path[count] = 300` 是初始值的状态。

- 泛洪的控制

由于节点只转发自身节点没有收到过的包，并且这个包的起始节点是begin_id，这样发包能控制在100以内。

