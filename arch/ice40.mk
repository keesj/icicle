PNR     ?= nextpnr
PCF      = boards/$(BOARD).pcf
FREQ_PLL ?= 24
FREQ_CPU ?= $(FREQ_PLL)

progmem_syn.hex:
	icebram -g 32 2048 > $@

$(PLL):
	icepll $(QUIET) -i $(FREQ_OSC) -o $(FREQ_PLL) -m -f $@

ifeq ($(PNR),arachne-pnr)
$(ASC_SYN): $(BLIF) $(PCF)
	arachne-pnr $(QUIET) -d $(DEVICE) -P $(PACKAGE) -o $@ -p $(PCF) $<
else
$(ASC_SYN): $(JSON) $(PCF)
	nextpnr-ice40 --$(SPEED)$(DEVICE) --package $(PACKAGE) --json $< --pcf $(PCF) --freq $(FREQ_CPU) --asc $@
endif

$(ASC): $(ASC_SYN) progmem_syn.hex progmem.hex
ifeq ($(PROGMEM),ram)
	icebram progmem_syn.hex progmem.hex < $< > $@
else
	cp $< $@
endif

$(BIN): $(ASC)
	icepack $< $@

$(TIME_RPT): $(ASC_SYN) $(PCF)
	icetime -t -m -d $(SPEED)$(DEVICE) -P $(PACKAGE) -p $(PCF) -c $(FREQ_CPU) -r $@ $<

$(STAT): $(ASC_SYN)
	icebox_stat $< > $@

flash: $(BIN) progmem.bin $(TIME_RPT)
	iceprog $<
ifeq ($(PROGMEM),flash)
	iceprog -o 1M progmem.bin
endif
