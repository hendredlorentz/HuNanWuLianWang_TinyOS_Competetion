# 寻找最大节点和最小节点

## 题目描述



如图所示，平台10个节点ID号随机，左上角，右下角节点已知，左上角，右下角节点作为数据接受节点，参赛队需编写其他12个节点的代码，左上角节点打印最大的三个节点，右下角节点打印（`printf`）最小的三个节点。



## 问题解析



本题主要使用CTP节点技术，因为是0号节点与1号节点进行数据接收节点，因此第一想到的应该就是CTP协议，同时CTP协议中包含数据分发协议，分发协议也是必须的，本题主要使用这两个协议。



#### .h代码解析

>对于此题肯定是需要一个数组进行对所有的节点进行数据保存的，同时还是需要一个count记录到底收集了多少个节点（肯定应该是10个）

~~~c
#ifndef TEST_SERIAL_H
#define TEST_SERIAL_H

typedef nx_struct test_serial_msg {
  nx_uint16_t id[12];
  nx_uint16_t count;
} test_serial_msg_t;

#endif
~~~



#### nc代码解析

>1. 对于最主要的nc代码，首先全局变量应该为一个全局的包作为ID的存储同时不断更新发包，定义一个只存在id的包结构，一个flag数组记录

```c
  message_t packet;
  int i,j;//循环变量
  nx_uint16_t t; // 赋值变量（目的是进行排序）
  // 定义flag数组确保id数组里面不存在重复节点
  nx_uint16_t flag[300]={0,};  
  test_serial_msg_t ID; // .h定义的全局包
  // 一个包（ID）其中内容为其本身的ID
  typedef nx_struct EasyCollectionMsg {
    nx_uint16_t nodeid;
  } EasyCollectionMsg;


```

>2. 在第二个方面是接口的实现，在此阶段需要在对题目进行一定的判断，因为0号节点与11号节点是需要打印的节点，因此一定需要***一个定时器***去触发打印函数，同时是使用CTP进行协议通信，那么对于CTP的收集节点可以选用0号节点或者11号节点都是可以的（因为CTP协议用在此题里面只是为了收集到所有的节点编号，同时进行排序得到一个排好序的数组，对排好序的数组直接进行打印即可），那么代码编写如下

```c
// 主函数启动
  event void Boot.booted() {
    call RadioControl.start();
  }
  event void RadioControl.startDone(error_t err) {
    if (err != SUCCESS){
      call RadioControl.start();
    }
    else {
	  // ctp协议开启(其余所有节点)
      call DisseminationControl.start();
      call RoutingControl.start();
	  // 特殊节点需要触发的函数
      if (TOS_NODE_ID == 0 ) {
		//数据收集点
	    call RootControl.setRoot();
        call Timer2.startOneShot(8000);
      }

      if (TOS_NODE_ID == 0 ||TOS_NODE_ID == 11 ) {
        //打印函数
        call Timer1.startOneShot(8500);
      }
	  // 其余的节点都会触发的函数，为了防止包的冲突，使用ID*10的方式进行发包
	    else call Timer0.startOneShot(3000+TOS_NODE_ID*10);
    }
  }
```

>3. 其他的代码即为逻辑代码，为每个的定时器编写相应的函数，进行数据包的传送，以此得到ID号，同时进行更新等

```c
  // 其他（除收集节点）的所有的节点进行发包
  void sendMessage() {
    EasyCollectionMsg* msg=(EasyCollectionMsg*)call Send.getPayload(&packet, sizeof(EasyCollectionMsg));
    msg-> nodeid = TOS_NODE_ID; // 把id放入包里面发出去
    call Send.send(&packet, sizeof(EasyCollectionMsg)); // 把包发出去
  }
  
  event void Send.sendDone(message_t* m, error_t err) 	{
      // do nothing
  }
  
  
  // 除了收集节点外每个节点都会发送其自身的ID号
  event void Timer0.fired() {
      sendMessage();
  }
  
  event void Timer2.fired() {
      // 0点改变ID包后直接进行分发，记得这个ID包是全局变量
      call Update.change(&ID);
  }
	
	//所有节点收到改变包通知
  event void Value.changed() {
	//call value.get拿到新值，同时直接进行更新
    const test_serial_msg_t* newVal = call Value.get();
    ID = *newVal;
  }


	// 只有0号节点触发（收包）
  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
    // 包长度进行判断（符合才进行判断）
    if (len == sizeof(EasyCollectionMsg)) 
      {
          // 收到的包（负载拿出来）
          EasyCollectionMsg*btrpkt= (EasyCollectionMsg*)payload;
           // 一开始都是0，直接对ID包里面的id数组进行循环赋值
           // 那么这个flag数组的目的为了防止已经录入的节点再次进行录入
              if(flag[btrpkt->nodeid]==0){
                  // 在全局包中的id数组进行赋值（这样全局包里面的id数组里面就会全部都是所有的节点号码）
                  ID.id[ID.count]=btrpkt->nodeid;
                  // count自增，实现对数组循环赋值
                  ID.count++;
				  // 同时flag直接记录收到的节点id
                  flag[btrpkt->nodeid]=1;
              }

     }
     return msg;
 }  



   event void Timer1.fired() {
   //排序
     for(i=0;i<ID.count-1;i++){
         for(j=0;j<ID.count-1-i;j++)
         {
             // 从大到小排序
             if(ID.id[j]<ID.id[j+1]){
                 t=ID.id[j];
                 ID.id[j]=ID.id[j+1];
                 ID.id[j+1]=t;
             }
         }

     }
      printf("data: ");
       // 打印最大的三个节点
      if(TOS_NODE_ID == 0){
          i = 0;
          for(;i<3;i++){
          printf(" %u",ID.id[i]);
          }
      }
		// 打印最小的三个节点
      else if(TOS_NODE_ID == 11 ){
          i = ID.count-1;
          for(;i>ID.count-3;i--){
          printf(" %u",ID.id[i]);
          }
      }
      printf("\n");
      printfflush();
  }
```

#### AppC代码解析

```c
#include<printf.h>
#include"EasyCollection.h"

configuration EasyCollectionAppC {}
implementation {
  // timer
  components EasyCollectionC, MainC, LedsC;
  components new TimerMilliC() as Timer0;
  components new TimerMilliC() as Timer1;
  components new TimerMilliC() as Timer2;

  EasyCollectionC.Boot -> MainC;
  EasyCollectionC.Timer0 -> Timer0;
  EasyCollectionC.Timer1 -> Timer1;
  EasyCollectionC.Timer2 -> Timer2;
  EasyCollectionC.Leds -> LedsC;
  
  //radio
  components  ActiveMessageC;
  EasyCollectionC.RadioControl -> ActiveMessageC;
  EasyCollectionC.RadioPacket -> ActiveMessageC;
  EasyCollectionC.AMPacket -> ActiveMessageC;
   
  //printf
  components PrintfC;
  components SerialStartC;
  
  //ctp1
  components CollectionC as Collector;
  components new CollectionSenderC(0xee);
  EasyCollectionC.RoutingControl -> Collector;
  EasyCollectionC.Send -> CollectionSenderC;
  EasyCollectionC.RootControl -> Collector;
  EasyCollectionC.Receive -> Collector.Receive[0xee];
    
  //dis
  components DisseminationC;
  EasyCollectionC.DisseminationControl ->DisseminationC;
    
  //dis(ctp)
  components new DisseminatorC(test_serial_msg_t, 0x1234) as Diss16C;
  EasyCollectionC.Value -> Diss16C;
  EasyCollectionC.Update -> Diss16C;
}
```



*****

对于寻找最大最小节点都可以使用此种方法，对于打印只打印最大节点与最小节点，只需要加一个if判断进行打印条件（只让0号节点打印），同时对于循环则更加简单，完全不需要循环，最后ID.id数组排序完后直接打印id[0]和id[ID.count-1]即可，其余与上题完全相似。