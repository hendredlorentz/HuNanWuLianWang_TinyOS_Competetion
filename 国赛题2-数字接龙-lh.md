# 国赛题2-数字接龙

## 题目描述

节点已知，0节点串口收到数据，包含数字和颜色信息；让节点亮灯，一定时间后关灯，能重复收到亮灯。

#### 思路

定义显示数字的数组在本地；
所有节点开启无线通信；
只有节点0开启串口通信；
串口接收，只有节点0触发uartReceive.receive
		拿到串口包的负载；
		数据保存到本地；
		call 无线发包一次；
节点0无线发包TimerRadioSend.fired()
		定义一个无线包；
		用本地数据给无线包赋值；
		广播发无线包；
接收无线包radioReceive.receive
		拿到无线包负载btrpkt；
		定义新的无线包rcm;
		如果之前从未收到过包（receive==0）
				receive=1;
				亮灯；
				关灯（包括恢复receive初值，不然只能用一次）；
				转发无线包；（放在这里面就是只转发一次）；

### Makefile

```nesC
COMPONENT=BlinkAppC
CFLAGS += -DCC2420_DEF_CHANNEL=14
CFLAGS += -$(TOSDIR)/lib/printf
include $(MAKERULES)
```

### AppC.nc

```
/*写数字，制定数字和颜色*/
#include <Timer.h>
#include "Blink.h"
#include "printf.h"

configuration BlinkAppC
{
}
implementation
{
    //main leds
    components MainC;
    components BlinkC as App;
    components LedsC;
    App.Boot -> MainC;
    App.Leds -> LedsC;
    
    //radio 无线
    components new AMSenderC(AM_BLINKTORADIO);
    components new AMReceiverC(AM_BLINKTORADIO);
    components ActiveMessageC;
    App.radioReceive -> AMReceiverC;
    App.AMSend -> AMSenderC;
    App.AMControl -> ActiveMessageC;
    App.Packet -> AMSenderC;
    App.AMPacket -> AMSenderC;
    
    //serial 串口通信
    components SerialActiveMessageC as AM;
    App.uartControl -> AM;
    App.uartReceive -> AM.Receive[0x89];
    App.uartAMSend -> AM.AMSend[0x89];
    App.uartPacket -> AM;
    
    //打印
    components PrintfC;
    components SerialStartC;
  
    //timer
    components new TimerMilliC() as TimerOff;
    components new TimerMilliC() as TimerRadioSend;
    App.TimerOff -> TimerOff;
    App.TimerRadioSend -> TimerRadioSend;
  
}
```

### .h

```
/*写数字，制定数字和颜色*/
#ifndef BLINK_H
#define BLINK_H

enum {
  AM_BLINKTORADIO = 6, 
  TIMER_PERIOD_MILLI = 250
};

//无线通信包
typedef nx_struct RadioMsg {
    nx_uint8_t number;
    nx_uint8_t color;
    nx_uint8_t data[12];
  
} RadioMsg;

//串口通信包
typedef nx_struct serial_msg_t {
    nx_uint8_t number;
    nx_uint8_t color;
} serial_msg_t;

#endif
```

### C.nc

```
/*写数字，制定数字和颜色*/
#include "Timer.h"
#include "Blink.h"
#include "printf.h"

module BlinkC @safe()
{
  uses interface Boot;
  uses interface Leds;
  uses interface Timer<TMilli> as TimerRadioSend;
  uses interface Packet;
  uses interface AMPacket;
  uses interface AMSend;
  uses interface Receive as radioReceive;
  uses interface SplitControl as AMControl;
  
  uses interface SplitControl as uartControl;
  uses  interface Receive as uartReceive;
  uses  interface AMSend as uartAMSend;
  uses  interface Packet as uartPacket;

  uses interface Timer<TMilli> as TimerOff;
}


implementation {
    int receive=0;    //0是没收到过，1是收到过了
    //以下面一行为例，0表示数字0，数组内容表示每个对应的节点是否亮灯，1亮0不亮
    uint8_t array0[12]={1,1,1,1,1,0,0,1,1,1,1,1};
    uint8_t array1[12]={1,0,0,0,1,0,0,0,1,0,0,0};
    uint8_t array2[12]={1,1,1,0,0,1,0,0,1,1,1,0};
    uint8_t array3[12]={1,1,1,0,0,1,1,0,1,1,1,0};
    uint8_t array4[12]={1,1,0,0,1,1,1,0,0,1,0,0};
    
    uint8_t number;
    uint8_t color;
    uint8_t data[12];
  
    message_t radioMsg;    //定义无线包
    message_t uartMsg;    //定义串口包
   
    bool busy = FALSE;

    event void Boot.booted() 
    {
        call AMControl.start();    //1.开启无线通信
    }

    event void AMControl.startDone(error_t err) 
    {
        if (err == SUCCESS) 
        {
            if(TOS_NODE_ID == 0)
                call uartControl.start();    //2.节点0开启串口通信
        }
        else 
        {
            call AMControl.start();
        }
    }
    event void AMControl.stopDone(error_t err) {}

    event void uartControl.startDone(error_t err) {    //error_t err 这是它的结果
        if (err != SUCCESS) {
            call uartControl.start();
        }
    }
    event void uartControl.stopDone(error_t err) { }

    //3.【接收 串口】只有节点0触发
    event message_t* uartReceive.receive(message_t* bufPtr,  void* payload, uint8_t len) {
        serial_msg_t* uartRcm = (serial_msg_t*)payload;
        int i;
        
        printf("uartReceive");
        printfflush();
        
        //保存数据到本地
        number=uartRcm->number;
        color=uartRcm->color;
        if(number==0)
        {
            for(i=0;i<12;i++)
            {
                data[i]=array0[i];
            }
        }
        else if(number==1){
            for(i=0;i<12;i++)
            {
                data[i]=array1[i];
            }
        }
        else if(number==2){
            for(i=0;i<12;i++)
            {
                data[i]=array2[i];
            }
        }
        else if(number==3){
            for(i=0;i<12;i++)
            {
                data[i]=array3[i];
            }
        }
        else if(number==4){
            for(i=0;i<12;i++)
            {
                data[i]=array4[i];
            }
        }
        
        call TimerRadioSend.startOneShot(1000); 
        return bufPtr;
    }
    
    //4.定时器触发 这里发无线包
    event void TimerRadioSend.fired() {
        RadioMsg* rcm=(RadioMsg*)(call Packet.getPayload(&radioMsg, sizeof(RadioMsg)));
        int i;
        printf("TimerRadioSend");
        printfflush();
        if (rcm == NULL) {
            return;
        }
        
        //5.发送无线数据包
        rcm->number=number;
        rcm->color=color;
        for(i=0;i<12;i++)
        {
            rcm->data[i]=data[i];
        }
        call AMSend.send(0xFFFF,  &radioMsg, sizeof(RadioMsg));   
    } 

    
    
    //【接收 无线包】r1 接收无线数据包
    event message_t* radioReceive.receive(message_t* msg, void* payload, uint8_t len){
        int i;
        printf("radioReceive");
        printfflush();
        if ( len == sizeof(RadioMsg)) {
            //r2.拿到收到的包的负载
            RadioMsg* btrpkt = (RadioMsg*)payload;
            RadioMsg* rcm = (RadioMsg*)call uartPacket.getPayload(&radioMsg, sizeof(RadioMsg));
  
            printf("number=%u\n",btrpkt->number);
            printfflush();
            
            if(receive==0)
            {
                receive=1;
                
                //亮灯
                if(btrpkt->color==0)
                {
                    for(i=0;i<12;i++)
                    {
                        if(TOS_NODE_ID==i && btrpkt->data[i]==1)
                        {
                            call Leds.led0On();
                        }
                    }
                }
                else if(btrpkt->color==1)
                {
                    for(i=0;i<12;i++)
                    {
                        if(TOS_NODE_ID==i && btrpkt->data[i]==1)
                        {
                            call Leds.led1On();
                        }
                    }
                }
                else if(btrpkt->color==2)
                {
                    for(i=0;i<12;i++)
                    {
                        if(TOS_NODE_ID==i && btrpkt->data[i]==1)
                        {
                            call Leds.led2On();
                        }
                    }
                }
                
                call TimerOff.startOneShot(4000);
                
                //转发
                rcm->number=btrpkt->number;
                rcm->color=btrpkt->color;
                for(i=0;i<12;i++)
                {
                    rcm->data[i]=btrpkt->data[i];
                }
                call AMSend.send(0xFFFF,  &radioMsg, sizeof(RadioMsg));   
            }
        }
        return msg;
    }
    
    event void AMSend.sendDone(message_t* msg, error_t err) {
        if (&radioMsg == msg) {
            busy = FALSE;
        }
    }
    
    //串口发送完成触发该事件，message_t* bufPtr 包， error_t error 结果
    event void uartAMSend.sendDone(message_t* bufPtr, error_t error) {}
    
    //熄灯
    event void TimerOff.fired()
    {
        call Leds.led0Off();
        call Leds.led1Off();
        call Leds.led2Off();
        receive=0;
    }
}

```

##### 注意点：

- 注意包的赋值，是拿到的负载，还是新定义的，还是本地数据赋值等；
- 要多次的话记得一次结束后恢复初值，这里就是关灯和receive=0.