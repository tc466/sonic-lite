/* Copyright (c) 2015 Cornell University
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

#include <stdio.h>
#include <assert.h>

#include "SonicUserRequest.h"
#include "SonicUserIndication.h"

#define NUMBER_OF_TESTS 1

class SonicUser : public SonicUserIndicationWrapper
{
public:
  uint32_t cnt;
  void incr_cnt(){
    if (++cnt == NUMBER_OF_TESTS)
      exit(0);
  }
  virtual void read_timestamp_resp(uint64_t a) {
    fprintf(stderr, "readCycleCount(%ld)\n", a);
    incr_cnt();
  }
  virtual void log_read_resp(uint8_t a, uint64_t b, uint64_t c) {
	fprintf(stderr, "read from port(%d) local_cnt(%ld) global_cnt(%ld)\n", a, b, c);
	incr_cnt();
  }
  virtual void debug_probe(uint8_t a, uint64_t b, uint64_t c) {
  }
  SonicUser(unsigned int id) : SonicUserIndicationWrapper(id), cnt(0){}
};

int main(int argc, const char **argv)
{
  SonicUser *indication = new SonicUser(IfcNames_SonicUserIndicationH2S);
  SonicUserRequestProxy *device = new SonicUserRequestProxy(IfcNames_SonicUserRequestS2H);
  device->pint.busyType = BUSY_SPIN;   /* spin until request portal 'notFull' */

  portalExec_start();

  uint64_t count = 0;
  for (int i=0; i<10; i++) {
    count = portalCycleCount();
    fprintf(stderr, "%lx\n", count);
  }

  fprintf(stderr, "Main::about to go to sleep\n");
  while(true){sleep(2);}
}
