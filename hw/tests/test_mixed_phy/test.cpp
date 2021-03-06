#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>
#include <fstream>
#include <sstream>
#include <iostream>
#include <string>

#include "MemServerRequest.h"
#include "TestRequest.h"
#include "TestIndication.h"
#include "GeneratedTypes.h"
#include "lutils.h"
#include "lpcap.h"

using namespace std;

#define ITERATION 100

sem_t test_sem;
static TestRequestProxy *device=0;

void device_writePacketData(uint64_t* data, uint8_t* mask, int sop, int eop) {
    device->writePacketData(data, mask, sop, eop);
}

class TestIndication : public TestIndicationWrapper {
public:
  virtual void done(uint32_t v){
      sem_post(&test_sem);
  }
  TestIndication(int id) : TestIndicationWrapper(id){}
};

void usage (const char *program_name) {
    printf("%s: p4fpga tester\n"
     "usage: %s [OPTIONS] \n",
     program_name, program_name);
    printf("\nOther options:\n"
    " -b, --shared-buffer              demo shared buffer\n");
}

struct arg_info {
    double rate;
    int tracelen;
};

static void 
parse_options(int argc, char *argv[], char **pcap_file, struct arg_info* info) {
    int c, option_index;

    static struct option long_options [] = {
        {"help",                no_argument, 0, 'h'},
        {"parser-test",         required_argument, 0, 'p'},
        {"pktgen-rate",         required_argument, 0, 'r'},
        {"pktgen-count",        required_argument, 0, 'n'},
        {0, 0, 0, 0}
    };

    static string short_options
        (long_options_to_short_options(long_options));

    for (;;) {
        c = getopt_long(argc, argv, short_options.c_str(), long_options, &option_index);

        if (c == -1)
            break;

        switch (c) {
            case 'h':
                usage(get_exe_name(argv[0]));
                break;
            case 'p':
                *pcap_file = optarg;
                break;
            case 'r':
                info->rate = strtod(optarg, NULL);
                break;
            case 'n':
                info->tracelen = strtol(optarg, NULL, 0);
                break;
            default:
                break;
        }
    }
}


int main(int argc, char **argv)
{
    char *pcap_file=NULL;
    struct arg_info arguments = {0, 0};
    struct pcap_trace_info pcap_info = {0, 0};

    TestIndication echoIndication(IfcNames_TestIndicationH2S);
    device = new TestRequestProxy(IfcNames_TestRequestS2H);

    parse_options(argc, argv, &pcap_file, &arguments);

    if (pcap_file) {
        fprintf(stderr, "Attempts to read pcap file %s\n", pcap_file);
        load_pcap_file(pcap_file, &pcap_info);
    }

    while (1) sleep(1);
    return 0;
}

