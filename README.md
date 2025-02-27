This is a fun project to produce the pulses as the MultiSIgnalGene do, but as a VHDL project.

It is design mostly for multiple channels.

The computation is done sequentially.
The number of CLK cycles per sample is eight times the number of channels plus four or the number of required CLK cycles of the serial DAC, whatever is the bigger one.

Especially for the large number of channels, if the ASIC or the FPGA contains a RAM, the number of LUT is reduced. It is designed to match many RAM interfaces.

The files are coming soon

