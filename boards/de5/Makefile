
#
# Programm DE5 User Flash
#

all: program

comma := ,
null  :=
space := $(null) #

ifneq (, $(QUARTUS_ROOTDIR))
NIOS2EDS_ROOTDIR=$(QUARTUS_ROOTDIR)/../nios2eds
QUARTUS_PGM_PATH=$(QUARTUS_ROOTDIR)/bin/quartus_pgm
endif

ifeq (, $(SERIALNO))
BOARD_USB=1
else
BOARD_USB=$(subst $(comma),$(space),$(strip $(SERIALNO)))
endif

ifneq (, $(DTP))
BUILDBOT_TREE="dtp"
FIRMWARE="mkPcieTop.sof"
endif

ifneq (, $(SONIC))
BUILDBOT_TREE="sonic"
FIRMWARE="mkPcieTop.sof"
endif

ifneq (, $(DMAC))
BUILDBOT_TREE="dmac"
FIRMWARE="mkPcieTop.sof"
endif

ifneq (, $(DEBUG))
BUILDBOT_TREE="$(BUILDBOT_TREE)-debug"
endif

ifneq (, $(SV))
PROJDIR=$(PWD)
firmware:
	rm -f $(FIRMWARE) flash_hw.flash flash_hw.map.flash
	wget http://xcloud1.cs.cornell.edu/archive/$(BUILDBOT_TREE)/de5/$(SV)/bin/$(FIRMWARE)
else
PROJDIR?=../../$(BUILDBOT_TREE)/de5/
firmware:

endif

program: firmware
	@echo QUARTUS_ROOTDIR=$(QUARTUS_ROOTDIR)
	@echo QUARTUS_PGM_PATH=$(QUARTUS_PGM_PATH)
	@echo SV=$(SV)
	@echo BOARD_USB=$(BOARD_USB)
	@echo BUILDBOT_TREE=$(BUILDBOT_TREE)
	@echo PROJDIR=$(PROJDIR)
	# convert to .flash
	$(NIOS2EDS_ROOTDIR)/nios2_command_shell.sh sof2flash --input=$(PROJDIR)/$(FIRMWARE) --output=flash_hw.flash --offset=0x20C0000 --pfl --optionbit=0x00030000 --programmingmode=PS
	@rm -f prog.log.*
	# program pfl
	@for i in $(BOARD_USB); do $(QUARTUS_PGM_PATH) -m jtag -c $$i -o "p;S5_PFL.sof" >> prog.log.$$i; done
	#programming with .flash
	@for i in $(BOARD_USB); do \
		nohup sh -c "$(NIOS2EDS_ROOTDIR)/nios2_command_shell.sh nios2-flash-programmer -c $$i --base=0x0 flash_hw.flash >> prog.log.$$i && \
		$(NIOS2EDS_ROOTDIR)/nios2_command_shell.sh nios2-flash-programmer -c $$i --base=0x0 S5_OptionBits.flash >> prog.log.$$i " & \
	done

clean:
	rm prog.log.* flash_hw.flash flash_hw.map.flash
