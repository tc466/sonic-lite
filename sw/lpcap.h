#ifndef _SONIC_PCAP_H_
#define _SONIC_PCAP_H_

#include <assert.h>
#include <fcntl.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>
#include <sys/mman.h>
#include <stdio.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <sys/time.h>
#include <getopt.h>
#include <errno.h>
#include <cstring>
#include <stdint.h>
#include <pcap.h>

#include "lutils.h"

struct pcap_trace_info {
    unsigned long packet_count;
    unsigned long long byte_count;
};

/* mem_copy must be provided by each test */
void mem_copy(const void *buff, int length);
int read_pcap_file(const char* filename, void** buffer, long *length);
int parse_pcap_file(void *buffer, long length);
void load_pcap_file(const char *filename, struct pcap_trace_info *);
const char* get_exe_name(const char* argv0);
int compute_idle (const struct pcap_trace_info *info, double rate, double link_speed);

#endif
