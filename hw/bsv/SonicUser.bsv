
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

import Clocks::*;
import FIFO::*;
import FIFOF::*;
import Vector::*;
import Pipe::*;
import GetPut::*;
import Probe::*;

typedef struct {
   Bit#(8) port_no;
   Bit#(64) data;
} BufData deriving (Bits, Eq);

interface DtpIfc;
   interface PipeIn#(Bit#(128)) timestamp; // streaming time counter from NetTop.
   interface Vector#(4, PipeOut#(Bit#(53))) fromHost;
   interface Vector#(4, PipeIn#(Bit#(53)))  toHost;
   interface Vector#(4, PipeIn#(Bit#(32)))  delay;
   interface Vector#(4, PipeIn#(Bit#(32)))  state;
   interface Vector#(4, PipeIn#(Bit#(64)))  jumpCount;
   interface Reset rst;
endinterface

interface SonicUserRequest;
   method Action dtp_read_version();
   method Action dtp_reset(Bit#(8) port_no);
   method Action dtp_set_cnt(Bit#(8) port_no, Bit#(64) c);
   method Action dtp_read_delay(Bit#(8) port_no);
   method Action dtp_read_state(Bit#(8) port_no);
   method Action dtp_read_error(Bit#(8) port_no);
   method Action dtp_read_cnt(Bit#(8) cmd);
   method Action dtp_logger_write_cnt(Bit#(8) port_no, Bit#(64) local_cnt);
   method Action dtp_logger_read_cnt(Bit#(8) port_no);
endinterface

interface SonicUserIndication;
   method Action dtp_read_version_resp(Bit#(32) version);
   method Action dtp_read_delay_resp(Bit#(8) port_no, Bit#(32) delay);
   method Action dtp_read_state_resp(Bit#(8) port_no, Bit#(32) state);
   method Action dtp_read_error_resp(Bit#(8) port_no, Bit#(64) jumpc);
   method Action dtp_read_cnt_resp(Bit#(64) val);
   method Action dtp_logger_read_cnt_resp(Bit#(8) port_no, Bit#(64) localc, Bit#(64) msg1, Bit#(64) msg2);
endinterface

interface SonicUser;
   interface SonicUserRequest request;
   interface DtpIfc           dtp;
endinterface

module mkSonicUser#(SonicUserIndication indication)(SonicUser);
   let verbose = False;
   Clock defaultClock <- exposeCurrentClock();

   Reg#(Bit#(64))  cycle_count <- mkReg(0);
   Reg#(Bit#(64))  last_count  <- mkReg(0);

   FIFOF#(Bit#(128)) cntFifo <- mkFIFOF();
   Reg#(Bit#(128))   ts_reg <- mkReg(0);

   Vector#(4, FIFOF#(Bit#(53))) fromHostFifo <- replicateM(mkSizedFIFOF(4));
   Vector#(4, FIFOF#(Bit#(53))) toHostFifo   <- replicateM(mkSizedFIFOF(4));
   Vector#(4, FIFOF#(Bit#(32))) delayFifo    <- replicateM(mkSizedFIFOF(4));
   Vector#(4, FIFOF#(Bit#(32))) stateFifo    <- replicateM(mkSizedFIFOF(4));
   Vector#(4, FIFOF#(Bit#(64))) jumpCountFifo <- replicateM(mkSizedFIFOF(4));

   Reg#(Bit#(8))  lwrite_port <- mkReg(0);
   FIFOF#(BufData) lwrite_data_cycle1 <- mkSizedFIFOF(8);
   FIFOF#(BufData) lwrite_data_cycle2 <- mkSizedFIFOF(8);
   FIFOF#(void) log_write_cf <- mkFIFOF;

   Vector#(4, FIFOF#(BufData)) lread_data_cycle1 <- replicateM(mkSizedFIFOF(8));
   Vector#(4, FIFOF#(BufData)) lread_data_cycle2 <- replicateM(mkSizedFIFOF(8));

   Reg#(Bit#(5)) dtp_rst_cntr <- mkReg(0);
   MakeResetIfc dtpResetOut <- mkResetSync(0, False, defaultClock);

   rule count;
      cycle_count <= cycle_count + 1;
   endrule

   // clear all fifo on reset
   rule clearOnReset(dtpResetOut.isAsserted);
      for (Integer i=0; i<4; i=i+1) begin
         fromHostFifo[i].clear();
         toHostFifo[i].clear();
         delayFifo[i].clear();
         stateFifo[i].clear();
         jumpCountFifo[i].clear();
         lread_data_cycle1[i].clear();
         lread_data_cycle2[i].clear();
      end
      cntFifo.clear();
      lwrite_data_cycle1.clear();
      lwrite_data_cycle2.clear();
      log_write_cf.clear();
   endrule

   // dtp_read_cnt
   rule snapshot_dtp_timestamp;
      let v <- toGet(cntFifo).get;
      ts_reg <= v;
   endrule

   // dtp_read_delay
   Vector#(4, Reg#(Bit#(32))) delay_reg <- replicateM(mkReg(0));
   for (Integer i=0; i<4; i=i+1) begin
      rule snapshot_delay;
         let v <- toGet(delayFifo[i]).get;
         delay_reg[i] <= v;
      endrule
   end

   // dtp_read_state
   Vector#(4, Reg#(Bit#(32))) state_reg <- replicateM(mkReg(0));
   for (Integer i=0; i<4; i=i+1) begin
      rule snapshot_state;
         let v <- toGet(stateFifo[i]).get;
         state_reg[i] <= v;
      endrule
   end

   // dtp_read_error
   Vector#(4, Reg#(Bit#(64))) jumpc_reg <- replicateM(mkReg(0));
   for (Integer i=0; i<4; i=i+1) begin
      rule snapshot_jumpc;
         let v <- toGet(jumpCountFifo[i]).get;
         jumpc_reg[i] <= v;
      endrule
   end

   // dtp_logger_write_cnt
   rule log_from_host_cycle1;
      let v = lwrite_data_cycle1.first;
      if (fromHostFifo[v.port_no].notFull) begin
         fromHostFifo[v.port_no].enq({1'b0, truncate(v.data)});
         log_write_cf.enq(?);
         lwrite_data_cycle1.deq;
      end
   endrule
   rule log_from_host_cycle2 (log_write_cf.notEmpty);
      let v = lwrite_data_cycle2.first;
      if (fromHostFifo[v.port_no].notFull) begin
         fromHostFifo[v.port_no].enq({1'b1, truncate(v.data)});
         lwrite_data_cycle2.deq;
         log_write_cf.deq;
      end
   endrule

   for (Integer i=0; i<4; i=i+1) begin
      rule save_host_data (toHostFifo[i].notEmpty);
         Bit#(53) v = toHostFifo[i].first;
         toHostFifo[i].deq;
         case (v[52]) matches
            0: lread_data_cycle1[i].enq(BufData{port_no:fromInteger(i), data:zeroExtend(v[51:0])});
            1: lread_data_cycle2[i].enq(BufData{port_no:fromInteger(i), data:zeroExtend(v[51:0])});
         endcase
      endrule
   end

   rule assert_reset (dtp_rst_cntr != 0);
      dtp_rst_cntr <= dtp_rst_cntr - 1;
      dtpResetOut.assertReset;
   endrule

   // Interface to external modules.
   interface dtp = (interface DtpIfc;
      interface timestamp = toPipeIn(cntFifo);
      interface delay     = map(toPipeIn, delayFifo);
      interface state     = map(toPipeIn, stateFifo);
      interface jumpCount = map(toPipeIn, jumpCountFifo);
      interface toHost    = map(toPipeIn, toHostFifo);
      interface fromHost  = map(toPipeOut, fromHostFifo);
      interface rst       = dtpResetOut.new_rst;
   endinterface);

   // API implementation
   interface SonicUserRequest request;
   method Action dtp_read_version();
      let v = `DtpVersion; //Defined in Makefile as time of compilation.
      indication.dtp_read_version_resp(v);
   endmethod
   method Action dtp_reset(Bit#(8) port_no);
      dtp_rst_cntr <= 5'h1f;
   endmethod
   method Action dtp_set_cnt(Bit#(8) port_no, Bit#(64) c);
      //
   endmethod
   method Action dtp_read_delay(Bit#(8) port_no);
      if (port_no < 4) begin
         indication.dtp_read_delay_resp(port_no, truncate(delay_reg[port_no]));
      end
   endmethod
   method Action dtp_read_state(Bit#(8) port_no);
      if (port_no < 4) begin
         indication.dtp_read_state_resp(port_no, state_reg[port_no]);
      end
   endmethod
   method Action dtp_read_error(Bit#(8) port_no);
      if (port_no < 4) begin
         indication.dtp_read_error_resp(port_no, jumpc_reg[port_no]);
      end
   endmethod
   method Action dtp_read_cnt(Bit#(8) port_no);
      indication.dtp_read_cnt_resp(truncate(ts_reg));
   endmethod
   method Action dtp_logger_write_cnt(Bit#(8) port_no, Bit#(64) host_timestamp);
      // Check valid port No.
      if (port_no < 4) begin
         lwrite_data_cycle1.enq(BufData{port_no: port_no, data: host_timestamp});
         lwrite_data_cycle2.enq(BufData{port_no: port_no, data: truncate(ts_reg)});
      end
   endmethod
   method Action dtp_logger_read_cnt(Bit#(8) port_no);
      if (port_no < 4) begin
         if (lread_data_cycle1[port_no].notEmpty && lread_data_cycle2[port_no].notEmpty) begin
            Bit#(64) remote_message1 = lread_data_cycle1[port_no].first.data;
            Bit#(64) remote_message2 = lread_data_cycle2[port_no].first.data;
            indication.dtp_logger_read_cnt_resp(port_no,
                                                truncate(ts_reg),
                                                zeroExtend(remote_message1),
                                                zeroExtend(remote_message2));
            lread_data_cycle1[port_no].deq;
            lread_data_cycle2[port_no].deq;
         end
      end
   endmethod
   endinterface
endmodule

