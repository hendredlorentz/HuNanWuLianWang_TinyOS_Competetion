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
