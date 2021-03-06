
// Copyright (c) 2014 Cornell University.

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

package Scrambler;

import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;

import Pipe::*;

interface Scrambler;
   interface PipeIn#(Bit#(66)) scramblerIn;
   interface PipeOut#(Bit#(66)) scrambledOut;
   (* always_ready, always_enabled *)
   method Action tx_ready(Bool v);
endinterface

// Scrambler poly G(x) = 1 + x^39 + x^58;
//(* synthesize *)
module mkScrambler#(Integer id)(Scrambler);

   let verbose = False;

   Reg#(Bit#(32)) cycle <- mkReg(0);
   Reg#(Bit#(58)) scram_state <- mkReg(58'h3ff_ffff_ffff_ffff);
   FIFOF#(Bit#(122)) cfFifo <- mkBypassFIFOF;
   FIFOF#(Bit#(66)) fifo_in <- mkFIFOF;
   FIFOF#(Bit#(66)) fifo_out <- mkBypassFIFOF;
   FIFOF#(Bit#(2)) shFifo <- mkBypassFIFOF;
   Wire#(Bool) tx_ready_wire <- mkDWire(False);

   rule cyc;
      cycle <= cycle + 1;
   endrule

   rule scramble(tx_ready_wire);
      let v <- toGet(fifo_in).get;
      Bit#(64) pre_scramble = v[65:2];
      Bit#(2) sync_hdr      = v[1:0];
      Vector#(122, Bit#(1)) scram_history;

      if(verbose) $display("%d: scrambler%d %h input=%h synchdr=%h", cycle, id, v, pre_scramble, v[1:0]);

      for(Integer i=0; i<58; i=i+1) begin
         scram_history[i] = scram_state[i];
      end

      for (Integer i=58; i<122; i=i+1) begin
         scram_history[i] = scram_history[i-58] ^ scram_history[i-39] ^ pre_scramble[i-58];
      end

      if(verbose) $display("%d: scrambler%d scram_history=%h", cycle, id, scram_history);

      cfFifo.enq(pack(scram_history));
      shFifo.enq(sync_hdr);
   endrule

   rule save_output;
      Bit#(66) dataout;
      let v = cfFifo.first;
      cfFifo.deq;
      let sh = shFifo.first;
      shFifo.deq;
      scram_state <= v[121:64];
      dataout = {v[121:58], sh};
      fifo_out.enq(dataout);
      if(verbose) $display("%d: scrambler%d dataout = %h", cycle, id, v[121:58]);
      if(verbose) $display("%d: scrambler%d history=%h synchdr=%h", cycle, id, v, sh);
   endrule

   method Action tx_ready (Bool v);
      tx_ready_wire <= v;
   endmethod
   interface scramblerIn = toPipeIn(fifo_in);
   interface scrambledOut = toPipeOut(fifo_out);
endmodule

endpackage
