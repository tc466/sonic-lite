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

/* DO NOT MODIFY, AUTO GENERATED BY P4 COMPILER */

import BuildVector::*;
import Connectable::*;
import DefaultValue::*;
import FIFO::*;
import FIFOF::*;
import FShow::*;
import GetPut::*;
import List::*;
import Pipe::*;
import StmtFSM::*;
import SpecialFIFOs::*;
import Vector::*;

import Ethernet::*;
import Types::*;

interface Parser;
   // derive parseReset from start of packet
   method Action parserReset();
   interface PipeIn#(EtherData) frameIn;
   interface PipeOut#(void) parseDone;
   interface PipeOut#(PHV_port_mapping) phvOut;
   interface PipeOut#(Bit#(128)) payloadOut;
endinterface

interface ParseEthernet;
   interface PipeIn#(Bit#(128)) packetIn;
   interface PipeOut#(Ethernet_t) parsedOut;
   interface PipeOut#(Bit#(16)) unparsedOutIpv4; // number is parse state id
   interface PipeOut#(Bit#(16)) unparsedOutVlan; // number is parse state id
   interface PipeOut#(ParserState) nextState;
   method Action init;
   method Action clear;
endinterface

interface ParseVlan;
   interface PipeIn#(Bit#(128)) packetIn;
   interface PipeIn#(Bit#(16)) unparsedIn;
   interface PipeOut#(Vlan_tag_t) parsedOut;
   interface PipeOut#(Bit#(112)) unparsedOutVlan0;
   interface PipeOut#(Bit#(80)) unparsedOutVlan1;
   interface PipeOut#(ParserState) nextState;
   method Action init;
   method Action clear;
endinterface

interface ParseIpv4;
   interface PipeIn#(Bit#(128)) packetIn;
   interface PipeIn#(Bit#(16)) unparsedIn;
   interface PipeOut#(Ipv4_t) parsedOut;
   interface PipeIn#(Bit#(112)) unparsedInVlan0;
   interface PipeIn#(Bit#(80)) unparsedInVlan1;
   interface PipeOut#(Bit#(112)) unparsedOut;
   interface PipeOut#(ParserState) nextState;
   method Action init;
   method Action clear;
endinterface

typedef enum {S0, S1, S2, S3, S4} ParserState deriving (Bits, Eq);
instance FShow#(ParserState);
   function Fmt fshow (ParserState state);
      return $format(" State %x", state);
   endfunction
endinstance

module mkParseEthernet(ParseEthernet);
   FIFOF#(Bit#(128)) packet_in_fifo <- mkBypassFIFOF;
   FIFOF#(Ethernet_t) parsed_out_fifo <- mkSizedFIFOF(1);
   FIFOF#(Bit#(16))  unparsed_out_parse_ipv4_fifo <- mkSizedFIFOF(1);
   FIFOF#(Bit#(16))  unparsed_out_parse_vlan_fifo <- mkSizedFIFOF(1);
   FIFOF#(ParserState) next_state_fifo <- mkBypassFIFOF;

   let verbose = True;
   Reg#(Cycle_t) cycle <- mkReg(defaultValue);
   rule cycleRule if (verbose);
      cycle.cnt <= cycle.cnt + 1;
   endrule

   Stmt parse_ethernet =
   seq
   action // parse_ethernet
      let data <- toGet(packet_in_fifo).get;
      Vector#(128, Bit#(1)) dataVec = unpack(data);
      let ethernet = extrace_ethernet(pack(takeAt(0, dataVec)));
      Vector#(16, Bit#(1)) unparsed = takeAt(112, dataVec);
      if (verbose) $display(fshow(cycle)
                            +fshow(" ether.dstAddr=")+fshow(ethernet.dstAddr)
                            +fshow(" ether.srcAddr=")+fshow(ethernet.srcAddr)
                            +fshow(" ether.etherType=")+fshow(ethernet.etherType));
      ParserState nextState = S0;
      case (byteSwap2B(ethernet.etherType)) matches
         'h_8100: begin
            unparsed_out_parse_vlan_fifo.enq(pack(unparsed));
            nextState = S2;
         end
         'h_9100: begin
            nextState = S2;
         end
         'h_0800: begin
            unparsed_out_parse_ipv4_fifo.enq(pack(unparsed));
            nextState = S3;
         end
         default: begin
            $display("null");
         end
      endcase
      next_state_fifo.enq(nextState);
   endaction
   endseq;

   FSM fsm_parse_ethernet <- mkFSMWithPred(parse_ethernet, True);
   Once once_parse_ethernet <- mkOnce(fsm_parse_ethernet.start);

   method Action init = once_parse_ethernet.start;
   method Action clear = once_parse_ethernet.clear;
   interface packetIn = toPipeIn(packet_in_fifo);
   interface unparsedOutIpv4 = toPipeOut(unparsed_out_parse_ipv4_fifo);
   interface unparsedOutVlan = toPipeOut(unparsed_out_parse_vlan_fifo);
   interface parsedOut = toPipeOut(parsed_out_fifo);
   interface nextState = toPipeOut(next_state_fifo);
endmodule

// Parse second VLAN
module mkParseVlan(ParseVlan);
   FIFOF#(Bit#(128)) packet_in_fifo <- mkBypassFIFOF;
   FIFOF#(Bit#(16)) unparsed_in_fifo <- mkBypassFIFOF;
   FIFOF#(Vlan_tag_t) parsed_out_fifo <- mkSizedFIFOF(1);
   FIFOF#(Bit#(112)) unparsed_out_parse_vlan0_fifo <- mkSizedFIFOF(1);
   FIFOF#(Bit#(80)) unparsed_out_parse_vlan1_fifo <- mkSizedFIFOF(1);
   FIFOF#(ParserState) next_state_fifo <- mkBypassFIFOF;

   let verbose = True;
   Reg#(Cycle_t) cycle <- mkReg(defaultValue);
   rule every if (verbose);
      cycle.cnt <= cycle.cnt + 1;
   endrule

   function ParserState compute_next_state(Bit#(16) etherType);
      ParserState nextState = S0;
      case (byteSwap2B(etherType)) matches
         'h_8100: begin
            nextState = S2;
         end
         'h_9100: begin
            nextState = S2;
         end
         'h_0800: begin
            nextState = S3;
         end
      endcase
      return nextState;
   endfunction

   Stmt parse_vlan =
   par
      // VLAN
      seq
      action
         let data_current <- toGet(packet_in_fifo).get;
         let data_delayed <- toGet(unparsed_in_fifo).get;
         Bit#(144) data = {data_current, data_delayed};
         Vector#(144, Bit#(1)) dataVec = unpack(data);
         let vlan0 = extract_vlan(pack(takeAt(0, dataVec)));
         let nextState0 = compute_next_state(vlan0.etherType);
         let residue0 = takeAt(32, dataVec);
         let vlan1 = extract_vlan(pack(takeAt(32, dataVec)));
         let nextState1 = compute_next_state(vlan1.etherType);
         let residue1 = takeAt(64, dataVec);

         if (verbose) $display(fshow(cycle) + fshow("Vlan etherType=") + fshow(vlan0.etherType));
         if (verbose) $display(fshow(cycle) + fshow("Vlan etherType=") + fshow(vlan1.etherType));
         case (nextState0) matches
            S2: begin
               unparsed_out_parse_vlan1_fifo.enq(pack(residue1));
               next_state_fifo.enq(nextState1);
            end
            S3: begin
               unparsed_out_parse_vlan0_fifo.enq(pack(residue0));
               next_state_fifo.enq(nextState0);
            end
         endcase
      endaction
      endseq
   endpar;

   FSM fsm_parse_vlan <- mkFSMWithPred(parse_vlan, packet_in_fifo.notEmpty);
   Once once_parse_vlan <- mkOnce(fsm_parse_vlan.start);

   method Action init = once_parse_vlan.start;
   method Action clear = once_parse_vlan.clear;
   interface packetIn = toPipeIn(packet_in_fifo);
   interface unparsedIn = toPipeIn(unparsed_in_fifo);
   interface unparsedOutVlan0 = toPipeOut(unparsed_out_parse_vlan0_fifo);
   interface unparsedOutVlan1 = toPipeOut(unparsed_out_parse_vlan1_fifo);
   interface parsedOut = toPipeOut(parsed_out_fifo);
   interface nextState = toPipeOut(next_state_fifo);
endmodule

module mkParseIpv4(ParseIpv4);
   FIFOF#(Bit#(128)) packet_in_fifo <- mkBypassFIFOF;

   FIFOF#(Ipv4_t) parsed_out_fifo <- mkSizedFIFOF(1);
   FIFOF#(Bit#(16)) unparsed_in_fifo <- mkBypassFIFOF;
   FIFOF#(Bit#(112)) unparsed_in_vlan0_fifo <- mkBypassFIFOF;
   FIFOF#(Bit#(80)) unparsed_in_vlan1_fifo <- mkBypassFIFOF;
   FIFOF#(Bit#(112)) unparsed_out_fifo <- mkSizedFIFOF(1);
   FIFOF#(Bit#(144)) internal_fifo <- mkSizedFIFOF(1);

   FIFOF#(ParserState) next_state_fifo <- mkBypassFIFOF;

   Wire#(Bit#(128)) packet_in_wire <- mkDWire(0);

   let verbose = True;
   Reg#(Cycle_t) cycle <- mkReg(defaultValue);
   rule every if (verbose);
      cycle.cnt <= cycle.cnt + 1;
   endrule

   rule load_packet_in;
      let data_current <- toGet(packet_in_fifo).get;
      packet_in_wire <= data_current;
   endrule

   // We need a collection for fields to extract. not all fields are required
   Stmt parse_ipv4 =
   par
   // IP
   seq
   action // parse_ipv4
      let residue_last <- toGet(unparsed_in_fifo).get; // 16-bit
      let data_current = packet_in_wire;
      Bit#(144) data = {data_current, residue_last};
      Vector#(144, Bit#(1)) dataVec = unpack(data);
      internal_fifo.enq(data);
      if (verbose) $display(fshow(cycle) + fshow("wait one cycle!"));
   endaction
   action // parse_ipv4 0
      let data_delayed <- toGet(internal_fifo).get;
      let data_current = packet_in_wire;
      Bit#(272) data = {data_current, data_delayed};
      Vector#(272, Bit#(1)) dataVec = unpack(data);
      Vector#(112, Bit#(1)) residue = takeAt(160, dataVec);
      let ipv4 = extract_ipv4(data[159:0]);
      if (verbose) $display(fshow(cycle)+
                            $format(" ipv4.srcAddr=%x", ipv4.srcAddr)+
                            $format(" ipv4.dstAddr=%x", ipv4.dstAddr));
      next_state_fifo.enq(S4);
   endaction
   endseq
   // VLAN|IP
   seq
   action
      let residue_last <- toGet(unparsed_in_vlan0_fifo).get; // 112-bit;
      let data_current = packet_in_wire;
      Bit#(240) data = {data_current, residue_last};
      Vector#(240, Bit#(1)) dataVec = unpack(data);
      Vector#(80, Bit#(1)) residue = takeAt(160, dataVec);
      let ipv4 = extract_ipv4(data[159:0]);
      if (verbose) $display(fshow(cycle)+
                            $format(" ipv4.srcAddr=%x", ipv4.srcAddr)+
                            $format(" ipv4.dstAddr=%x", ipv4.dstAddr));
      next_state_fifo.enq(S4);
   endaction
   endseq
   // VLAN|VLAN|IP
   seq
   action
      let residue_last <- toGet(unparsed_in_vlan1_fifo).get; // 112-bit;
      let data_current = packet_in_wire;
      Bit#(208) data = {data_current, residue_last};
      Vector#(208, Bit#(1)) dataVec = unpack(data);
      Vector#(48, Bit#(1)) residue = takeAt(160, dataVec);
      let ipv4 = extract_ipv4(data[159:0]);
      if (verbose) $display(fshow(cycle)+
                            $format(" ipv4.srcAddr=%x", ipv4.srcAddr)+
                            $format(" ipv4.dstAddr=%x", ipv4.dstAddr));
      next_state_fifo.enq(S4);
   endaction
   endseq
   endpar;

   FSM fsm_parse_ipv4 <- mkFSMWithPred(parse_ipv4, True);
   Once once_parse_ipv4 <- mkOnce(fsm_parse_ipv4.start);

   method Action init = once_parse_ipv4.start;
   method Action clear = once_parse_ipv4.clear;
   interface packetIn = toPipeIn(packet_in_fifo);
   interface unparsedIn = toPipeIn(unparsed_in_fifo);
   interface unparsedInVlan0 = toPipeIn(unparsed_in_vlan0_fifo);
   interface unparsedInVlan1 = toPipeIn(unparsed_in_vlan1_fifo);
   interface unparsedOut = toPipeOut(unparsed_out_fifo);
   interface parsedOut = toPipeOut(parsed_out_fifo);
   interface nextState = toPipeOut(next_state_fifo);
endmodule

(* synthesize *)
module mkParser(Parser);
   FIFOF#(EtherData) data_in_fifo <- mkSizedBypassFIFOF(4);
   FIFOF#(void) parse_done_fifo <- mkSizedFIFOF(1);

   ParseEthernet parse_ethernet <- mkParseEthernet();
   ParseVlan parse_vlan <- mkParseVlan();
   ParseIpv4 parse_ipv4 <- mkParseIpv4();

   List#(Reg#(Vlan_tag_t)) vlan_tag_stack <- List::replicateM(2, mkReg(defaultValue));

   mkConnection(parse_ethernet.unparsedOutIpv4, parse_ipv4.unparsedIn);
   mkConnection(parse_ethernet.unparsedOutVlan, parse_vlan.unparsedIn);
   mkConnection(parse_vlan.unparsedOutVlan0, parse_ipv4.unparsedInVlan0);
   mkConnection(parse_vlan.unparsedOutVlan1, parse_ipv4.unparsedInVlan1);

   let verbose = True;
   Reg#(Cycle_t) cycle <- mkReg(defaultValue);
   rule every if (verbose);
      cycle.cnt <= cycle.cnt + 1;
   endrule

   Reg#(ParserState) curr_state <- mkReg(S0);

   // Parsing Graph
   (* fire_when_enabled *)
   rule state_S0 (curr_state == S0 && data_in_fifo.notEmpty);
      let v = data_in_fifo.first;
      if (v.sop) begin
         curr_state <= S1;
         parse_ethernet.init;
         parse_vlan.init;
         parse_ipv4.init;
         if (verbose) $display(fshow(cycle) + fshow("Done with") + fshow(curr_state));
      end
      else begin
         data_in_fifo.deq;
      end
   endrule
   (* fire_when_enabled *)
   rule state_S1 (curr_state == S1);
      let v <- toGet(parse_ethernet.nextState).get;
      curr_state <= v;
      if (verbose) $display(fshow(cycle) + fshow("Done with") + fshow(curr_state));
   endrule
   (* fire_when_enabled *)
   rule state_S2 (curr_state == S2);
      let v <- toGet(parse_vlan.nextState).get;
      curr_state <= v;
      if (verbose) $display(fshow(cycle) + fshow("Done with") + fshow(curr_state));
   endrule
   (* fire_when_enabled *)
   rule state_S3 (curr_state == S3);
      let v <- toGet(parse_ipv4.nextState).get;
      curr_state <= v;
      if (verbose) $display(fshow(cycle) + fshow("Done with") + fshow(curr_state));
   endrule
   (* fire_when_enabled *)
   rule state_S4 (curr_state == S4);
      let v <- toGet(data_in_fifo).get;
      if (v.eop) begin
         curr_state <= S0;
         parse_ethernet.clear;
         parse_ipv4.clear;
         if (verbose) $display(fshow(cycle) + fshow("Done with") + fshow(curr_state));
      end
   endrule

   // Data dispatcher.
   rule state_S1_input (curr_state == S1);
      let v <- toGet(data_in_fifo).get;
      parse_ethernet.packetIn.enq(v.data);
      if (verbose) $display(fshow(cycle) + fshow("parse_ethernet enqueue ")+ fshow(v));
   endrule
   rule state_S2_input (curr_state == S2);
      let v <- toGet(data_in_fifo).get;
      parse_vlan.packetIn.enq(v.data);
      if (verbose) $display(fshow(cycle) + fshow("parse_vlan enqueue ")+ fshow(v));
   endrule
   rule state_S3_input (curr_state == S3);
      let v <- toGet(data_in_fifo).get;
      parse_ipv4.packetIn.enq(v.data);
      if (verbose) $display(fshow(cycle) + fshow("parse_ipv4 enqueue ") + fshow(v));
   endrule

   // derive parse done from state machine
   interface frameIn = toPipeIn(data_in_fifo);
   interface parseDone = toPipeOut(parse_done_fifo);
endmodule

