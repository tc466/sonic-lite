import Clocks::*;
import ConnectalClocks::*;
import LedController::*;

import Ethernet::*;
import AlteraExtra::*;
import ALTERA_SI570_WRAPPER::*;

(* always_ready, always_enabled *)
interface DE5Pins;
`ifndef SIMULATION
   method Action osc_50(Bit#(1) b3d, Bit#(1) b4a, Bit#(1) b4d, Bit#(1) b7a, Bit#(1) b7d, Bit#(1) b8a, Bit#(1) b8d);
   method Action buttons(Bit#(4) v);
   method Action sfp(Bit#(1) refclk);
   interface SFPCtrl#(4) sfpctrl;
   method Bit#(4) serial_tx_data;
   method Action serial_rx(Bit#(4) data);
   method Bit#(1) led0;
   method Bit#(1) led1;
   method Bit#(1) led2;
   method Bit#(1) led3;
   method Bit#(4) led_bracket;
   interface Si570wrapI2c i2c;
   interface Clock deleteme_unused_clock;
   interface Clock deleteme_unused_clock2;
   interface Clock deleteme_unused_clock3;
   interface Reset deleteme_unused_reset;
`endif
endinterface

interface De5Clocks;
   interface Si570wrapI2c i2c;
   interface Clock clock_50;
   interface Reset reset_50_n;
   interface Clock clock_156_25;
   interface Reset reset_156_25_n;
   interface Clock clock_644_53;
endinterface

module mkDe5Clocks#(Bit#(1) clk_50, Bit#(1) clk_644)(De5Clocks);
   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();

   B2C1 iclock_50 <- mkB2C1();
   B2C1 iclock_644 <- mkB2C1();

   //Reset reset_50 <- mkResetInverter(reset_n, clocked_by clk_50_b4a_buf.outclk);
   Reset rst_50_n <- mkAsyncReset(2, defaultReset, iclock_50.c);
   Reset reset_644 <- mkResetInverter(defaultReset, clocked_by iclock_644.c);
   //Reset reset_644_53_n <- mkAsyncReset(2, reset_n, sfp_refclk);

   // ===================================
   // PLL:
   // Input:   SFP REFCLK from SI570
   // Output:  156.25MHz
   // Reset: Active High, must invert default Reset
   PLL156 pll156 <- mkPLL156(iclock_644.c, reset_644, clocked_by iclock_644.c, reset_by reset_644);
   Clock clk_156_25 = pll156.outclk_0;
   Reset rst_156   <- mkResetInverter(defaultReset, clocked_by clk_156_25);
   Reset rst_156_n <- mkAsyncReset(2, defaultReset, clk_156_25, clocked_by clk_156_25);

   // ===================================
   // PLL: SI570 configurable clock
   // Input:
   // Output:
   // Reset: Active Low, use default Reset
   Si570Wrap si570 <- mkSi570Wrap(iclock_50.c, rst_50_n, clocked_by iclock_50.c, reset_by rst_50_n);

   rule si570_connections;
      let ifreq_mode = 3'b110;  //644.53125 MHZ
      si570.ifreq.mode(ifreq_mode);
      si570.istart.go(1'b0);
   endrule

   rule input_clock_50;
      iclock_50.inputclock(clk_50);
   endrule

   rule input_clock_644;
      iclock_644.inputclock(clk_644);
   endrule

   interface i2c = si570.i2c;
   interface clock_50 = iclock_50.c;
   interface reset_50_n = rst_50_n;
   interface clock_156_25 = clk_156_25;
   interface reset_156_25_n = rst_156_n;
   interface clock_644_53 = iclock_644.c;
endmodule

interface De5Leds;
   method Bit#(1) led0_out;
   method Bit#(1) led1_out;
   method Bit#(1) led2_out;
   method Bit#(1) led3_out;
endinterface

module mkDe5Leds#(Clock clk0, Clock clk1, Clock clk2, Clock clk3)(De5Leds);
   Clock defaultClock <- exposeCurrentClock;
   Reset defaultReset <- exposeCurrentReset;

   Reset reset0 <- mkSyncReset(2, defaultReset, clk0);
   Reset reset1 <- mkSyncReset(2, defaultReset, clk1);
   Reset reset2 <- mkSyncReset(2, defaultReset, clk2);
   Reset reset3 <- mkSyncReset(2, defaultReset, clk3);

   LedController led0 <- mkLedController(False, clocked_by clk0, reset_by reset0);
   LedController led1 <- mkLedController(False, clocked_by clk1, reset_by reset1);
   LedController led2 <- mkLedController(False, clocked_by clk2, reset_by reset2);
   LedController led3 <- mkLedController(False, clocked_by clk3, reset_by reset3);

   rule led0_run;
      led0.setPeriod(led_off, 500, led_on_max, 500);
   endrule

   rule led1_run;
      led1.setPeriod(led_off, 500, led_on_max, 500);
   endrule

   rule led2_run;
      led2.setPeriod(led_off, 500, led_on_max, 500);
   endrule

   rule led3_run;
      led3.setPeriod(led_off, 500, led_on_max, 500);
   endrule

   method led0_out = led0.ifc.out;
   method led1_out = led1.ifc.out;
   method led2_out = led2.ifc.out;
   method led3_out = led3.ifc.out;
endmodule

interface De5SfpCtrl;
   method Action los (Bit#(1) v);
   method Action mod0_presnt_n (Bit#(1) v);
   method Bit#(1) ratesel0;
   method Bit#(1) ratesel1;
   method Bit#(1) txdisable;
   method Action txfault (Bit#(1) v);
endinterface

module mkDe5SfpCtrl(De5SfpCtrl);
   Wire#(Bit#(1)) los_wire <- mkDWire(0);
   Wire#(Bit#(1)) mod0_presnt_n_wire <- mkDWire(0);
   Wire#(Bit#(1)) txfault_wire <- mkDWire(0);
   Wire#(Bit#(1)) ratesel0_wire <- mkDWire(0);
   Wire#(Bit#(1)) ratesel1_wire <- mkDWire(0);
   Wire#(Bit#(1)) txdisable_wire <- mkDWire(0);

   rule set_output;
      ratesel0_wire <= 1'b1;
      ratesel1_wire <= 1'b1;
      txdisable_wire <= 1'b0;
   endrule

   method los = los_wire._write;
   method mod0_presnt_n = mod0_presnt_n_wire._write;
   method txfault = txfault_wire._write;
   method ratesel0 = ratesel0_wire;
   method ratesel1 = ratesel1_wire;
   method txdisable = txdisable_wire;
endmodule
