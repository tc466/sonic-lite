import FIFO::*;
import FIFOF::*;
import DefaultValue::*;
import Vector::*;
import BuildVector::*;
import GetPut::*;
import ClientServer::*;
import Connectable::*;
import Clocks::*;
import Gearbox::*;
import LedController::*;

import HostInterface::*;
import ConnectalXilinxCells::*;
import Pipe::*;
import MemTypes::*;
import Ethernet::*;
import PacketBuffer::*;
import XilinxMacWrap::*;
import XilinxEthPhy::*;
import EthMac::*;
import StoreAndForward::*;
import NfsumePins::*;

interface TestIndication;
   method Action done(Bit#(32) matchCount);
endinterface

interface TestRequest;
   method Action writePacketData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
endinterface

interface Test;
   interface TestRequest request;
   interface `PinType pins;
endinterface

module mkTest#(HostInterface host, TestIndication indication) (Test);
   let verbose = True;
   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();

   Clock mgmtClock = host.tsys_clk_200mhz_buf;
   Reset mgmtReset <- mkSyncReset(2, defaultReset, mgmtClock);

`ifndef SIMULATION
   EthPhyIfc phys <- mkXilinxEthPhy(mgmtClock);
   Clock txClock = phys.tx_clkout;
   Reset txReset <- mkSyncReset(2, defaultReset, txClock);
   Vector#(4, EthMacIfc) mac = newVector;
   for (Integer i=0; i<4; i=i+1) begin
      mac[i] <- mkEthMac(mgmtClock, txClock, phys.rx_clkout[i], txReset, clocked_by txClock, reset_by txReset);
   end
   function Get#(Bit#(72)) getTx(EthMacIfc _mac); return _mac.tx; endfunction
   function Put#(Bit#(72)) getRx(EthMacIfc _mac); return _mac.rx; endfunction
   mapM(uncurry(mkConnection), zip(map(getTx, mac), phys.tx));
   mapM(uncurry(mkConnection), zip(phys.rx, map(getRx, mac)));
   NfsumeLeds leds <- mkNfsumeLeds(mgmtClock, txClock);
   NfsumeSfpCtrl sfpctrl <- mkNfsumeSfpCtrl(phys);
`endif

   PacketBuffer buff <- mkPacketBuffer();
   StoreAndFwdFromRingToMac ringToMac <- mkStoreAndFwdFromRingToMac(txClock, txReset);
   mkConnection(ringToMac.readClient, buff.readServer);
   mkConnection(ringToMac.macTx, mac[0].packet_tx);

   interface TestRequest request;
      method Action writePacketData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
         EtherData beat = defaultValue;
         beat.data = pack(reverse(data));
         beat.mask = pack(reverse(mask));
         beat.sop = unpack(sop);
         beat.eop = unpack(eop);
         buff.writeServer.writeData.put(beat);
      endmethod
   endinterface
`ifndef SIMULATION
   interface `PinType pins;
      method Action sfp(Bit#(1) refclk_p, Bit#(1) refclk_n);
         phys.refclk(refclk_p, refclk_n);
      endmethod
      method serial_tx_p = pack(phys.serial_tx_p);
      method serial_tx_n = pack(phys.serial_tx_n);
      method serial_rx_p = phys.serial_rx_p;
      method serial_rx_n = phys.serial_rx_n;
      interface leds = leds.led_out;
      interface led_grn = phys.tx_leds;
      interface led_ylw = phys.rx_leds;
      interface deleteme_unused_clock = defaultClock;
      interface sfpctrl = sfpctrl;
//      interface deleteme_unused_clock2 = clocks.clock_50;
//      interface deleteme_unused_clock3 = defaultClock;
//      interface deleteme_unused_reset = defaultReset;
   endinterface
`endif
endmodule
