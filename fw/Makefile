TARGETS=adp_ps2.hex adp_ps2dk.hex
#AVRA=/home/las/programming/avra/src/avra
#AVR_INCLUDES=/home/las/programming/avra/includes

AVRA=avra
AVR_INCLUDES=/usr/include/avr

AFLAGS=

all: $(TARGETS)

clean:
	rm -f $(TARGETS) *.lst *.eep.hex *.obj *.cof

adp_ps2dk.hex: adp_ps2.asm
	$(AVRA) $(AFLAGS) -D DEVKIT -I $(AVR_INCLUDES) -l adp_ps2dk.lst $<

%.hex: %.asm iface_ps2.inc
	$(AVRA) $(AFLAGS) -I $(AVR_INCLUDES) -l $*.lst $<
	
