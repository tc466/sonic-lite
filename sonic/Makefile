QUARTUS_SH=$(shell which quartus_sh)
ROOTDIR=$(realpath .)
CONNECTALDIR?=$(ROOTDIR)/../../connectal/
IPDIR?=$(ROOTDIR)/../../fpgamake-cache/$(shell basename `/bin/pwd`)/
PROJTOP?=$(ROOTDIR)

CONNECTALFLAGS += --bscflags="+RTS -K46777216 -RTS -demote-errors G0066:G0045 -suppress-warnings G0046:G0020:S0015:S0080:S0039 -steps-max-intervals 20"
CONNECTALFLAGS += --bsvpath=$(PROJTOP)/../hw/bsv
CONNECTALFLAGS += --bsvpath=$(PROJTOP)/../hw/generated

S2H_INTERFACES=SonicTopRequest:SonicTop.request:host.derivedClock,host.derivedReset
H2S_INTERFACES=SonicTop:SonicTopIndication:host.derivedClock,host.derivedReset
MEM_READ_INTERFACES=lSonicTop.dmaReadClient
MEM_WRITE_INTERFACES=lSonicTop.dmaWriteClient
AUTOTOP= --interface pins:SonicTop.pins
PIN_TYPE = DE5Pins
PIN_TYPE_INCLUDE = DE5Pins
BSVFILES=$(CONNECTALDIR)/bsv/MemTypes.bsv $(PROJTOP)/../sonic/SonicTop.bsv
CPPFILES=$(PROJTOP)/cpp/dpdk.cpp
CPPFILES2=$(PROJTOP)/t/test-receive-single-packet.cpp
CONNECTALFLAGS += -l="tins"
NUMBER_OF_MASTERS=1
PIN_BINDINGS?=PCIE:PCIE LED:LED OSC:OSC SFPA:SFPA SFPB:SFPB SFPC:SFPC SFPD:SFPD SFP:SFP I2C:I2C BUTTON:BUTTON
PINOUT_FILE=../boards/de5.json
#CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/altera_mac/altera_mac.qip # To be removed.
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/pll_156/altera_pll_156.qip
#CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/sv_10g_pma/sv_10g_pma.qip
#CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/altera_clkctrl/altera_clkctrl.qip
CONNECTALFLAGS += --verilog=$(PROJTOP)/../hw/verilog/si570/
CONNECTALFLAGS += -D SonicVersion=$(shell printf "%d" 0x`git rev-parse --short=8 HEAD`)
CONNECTALFLAGS += -D PcieHostIF
CONNECTALFLAGS += -D DataBusWidth=128
CONNECTALFLAGS += --shared
CONNECTALFLAGS += -D NO_DEFAULT_POLLER
CONNECTALFLAGS += -D IMPORT_HOST_CLOCKS
CONNECTALFLAGS += --derivedclockperiod=6.4
#CONNECTALFLAGS += --chipscope=$(PROJTOP)/../../sonic-debug/stp/memread.stp
ifneq (, $(BLUESIM))
CONNECTALFLAGS += --pinfo=$(PROJTOP)/../boards/sonic_synth.json
endif

prebuild::
ifneq (, $(QUARTUS_SH))
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) $(QUARTUS_SH) -t $(CONNECTALDIR)/scripts/connectal-synth-pll.tcl)
	#(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) $(QUARTUS_SH) -t $(PROJTOP)/../hw/scripts/generate-mac.tcl) # To be removed.
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) $(QUARTUS_SH) -t $(CONNECTALDIR)/scripts/connectal-synth-eth.tcl)
endif

include $(CONNECTALDIR)/Makefile.connectal
