This is a fun project to produce the pulses as the MultiSIgnalGene do, but as a VHDL project.

It is designed mostly for multiple channels.

It is similar to the pulses_gene project. The macro blocs logic is the same, plus additional features. It is however only a pure VHDL project.

There are frames, super frames etc... Each frame level computes a macro bloc.
Inside each level, the computation is done sequentially, one channel after the other. 
At the lowest level, The number of CLK cycles per sound output sample is eight times the number of channels (plus four is extra RAM operation is requested) or the number of required CLK cycles of the serial DAC, whatever is the bigger one.

There is no documentation other than schematic diagrams. All the relevant data is in the code. A run of DOxygen can extract the documentation from all the project.
The assumptions, especially the vectors sizes rules, can be found by checking the "assert report severity" statements. In case of a very imprecise result, a severity error is sent. In case of a risk of crash, a failure is sent.

Especially for the large number of channels, if the ASIC or the FPGA contains a RAM, the number of LUT is reduced. It is designed to match many RAM interfaces.

The tests are organized as 3 levels.
Due to repetitive signals generated by sequencers, only a basic test entity has been written(*) to check the states one by one.
An end to end test for each level has been written(*).
A global end to end test has been written (*), however it should be run at night.

(*) That may not be done yet, coming soon.

