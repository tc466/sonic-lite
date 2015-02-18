// Copyright (c) 2015 Cornell University.

// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Clocks ::*;
import Leds   ::*;
import ConfigCounter ::*;

(* always_ready, always_enabled *)
interface LedTopIfc;
   interface LEDS leds;
endinterface

(* synthesize *)
module mkLedTop#(Clock pcie_refclk_p, Reset pcie_perst_n)(LedTopIfc);

   Reg#(Bit#(1)) led_o <- mkReg(0, clocked_by pcie_refclk_p, reset_by pcie_perst_n);
   ConfigCounter#(26) pcie_led   <- mkConfigCounter(0, clocked_by pcie_refclk_p, reset_by pcie_perst_n);

   rule pcie_led_cross;
      pcie_led.increment(1);
      led_o <= pack(pcie_led.read())[25];
   endrule

   interface leds = (interface LEDS;
      method Bit#(LedsWidth) leds;
         return zeroExtend(led_o);
      endmethod
   endinterface);
endmodule