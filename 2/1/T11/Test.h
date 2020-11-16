#ifndef TEST_H
#define TEST_H



typedef nx_struct test_radio_msg {
    nx_uint8_t data;
} test_radio_msg_t;


enum {
 AM_RADIO_COUNT_MSG = 6,
 AM_TESTNETWORKMSG = 0x05,
 SAMPLE_RATE_KEY = 0x1,
 CL_TEST = 0xee,
 TEST_NETWORK_QUEUE_SIZE = 8,
};

#endif
