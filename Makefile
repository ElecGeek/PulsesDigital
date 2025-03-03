NETLIST_PROG?=gnetlist
EXPORT_PROG?=gaf
GHDL_PROG=ghdl
VFLAGS?=--std=08
SRCDIR?=
BUILDDIR?=build/
DESTDIR?=
WAVDESTDIR?=/mnt/ramfs/
SYNTHDESTDIR?=Synth/
YOSYS_PROG?=yosys
NEXTPNR-ICE40_PROG?=nextpnr-ice40
ICEPACK?=icepack


# There are many small and fast entities to simulate
# Then they are together 
pulse_parts_simul : $(SCRDIR)pulse_gene.vhdl $(SCRDIR)pulse_gene_test.vhdl $(SCRDIR)utils_package.vhdl $(SCRDIR)pulse_gene_package.vhdl 
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)utils_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)pulse_gene_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)pulse_gene.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)pulse_gene_test.vhdl
	$(GHDL_PROG) -e $(VFLAGS) Pulses_lowlevel_test
	$(GHDL_PROG) -r $(VFLAGS) Pulses_lowlevel_test --vcd=$(WAVDESTDIR)Pulses_lowlevel_test.wav 2>&1 | tee $(DESTDIR)Pulses_lowlevel_test.out.txt
	$(GHDL_PROG) -e $(VFLAGS) Pulses_sequencer_test
	$(GHDL_PROG) -r $(VFLAGS) Pulses_sequencer_test --vcd=$(WAVDESTDIR)Pulses_sequencer_test.wav 2>&1 | tee $(DESTDIR)Pulses_sequencer_test.out.txt

pulse_bundle_simul : $(SCRDIR)pulse_gene.vhdl $(SCRDIR)pulse_gene_test.vhdl  $(SCRDIR)utils_package.vhdl $(SCRDIR)pulse_gene_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)utils_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)pulse_gene_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)pulse_gene.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)pulse_gene_test.vhdl
	$(GHDL_PROG) -e $(VFLAGS) Pulses_bundle_test
	$(GHDL_PROG) -r $(VFLAGS) Pulses_bundle_test --vcd=$(WAVDESTDIR)Pulses_bundle_test.wav 2>&1 | tee $(DESTDIR)Pulses_bundle_test.out.txt

amplitude_parts_simul : $(SCRDIR)amplitude.vhdl $(SCRDIR)amplitude_test.vhdl $(SCRDIR)utils_package.vhdl $(SCRDIR)amplitude_package.vhdl 
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)utils_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)amplitude_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)amplitude.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)amplitude_test.vhdl
	$(GHDL_PROG) -e $(VFLAGS) Amplitudes_multiplier_test
	$(GHDL_PROG) -r $(VFLAGS) Amplitudes_multiplier_test --vcd=$(WAVDESTDIR)Amplitudes_multiplier_test.wav 2>&1 | tee $(DESTDIR)Amplitudes_multiplier_test.out.txt
	$(GHDL_PROG) -e $(VFLAGS) Amplitudes_sequencer_test
	$(GHDL_PROG) -r $(VFLAGS) Amplitudes_sequencer_test --vcd=$(WAVDESTDIR)Amplitudes_sequencer_test.wav 2>&1 | tee $(DESTDIR)Amplitudes_sequencer_test.out.txt


pulse_gene_low_level_synth : $(SCRDIR)pulse_gene.vhdl $(SCRDIR)pulse_gene_test.vhdl  $(SCRDIR)utils_package.vhdl $(SCRDIR)pulse_gene_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)utils_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)pulse_gene_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)pulse_gene.vhdl
	mkdir -p $(SYNTHDESTDIR)
	$(YOSYS_PROG) -m ghdl -p '$(GHDL_PROG) $(VFLAGS) Pulses_bundle; synth_ice40 -json $(SYNTHDESTDIR)pulse_gene_lowlevel.ice40.json' 2>&1 |tee $(SYNTHDESTDIR)pulse_gene_lowlevel.synth.out.txt
	$(NEXTPNR-ICE40_PROG) --hx4k --package tq144 --freq 30.00 --top Pulses_bundle --asc $(SYNTHDESTDIR)pulse_gene_lowlevel.asc --json $(SYNTHDESTDIR)pulse_gene_lowlevel.ice40.json --placed-svg $(SYNTHDESTDIR)pulse_gene_lowlevel.placed.svg --routed-svg $(SYNTHDESTDIR)pulse_gene_lowlevel.routed.svg --report $(SYNTHDESTDIR)pulse_gene_lowlevelc.report.json 2>&1 |tee $(SYNTHDESTDIR)pulse_gene_lowlevel.P_and_R.out.txt
	$(ICEPACK) $(SYNTHDESTDIR)pulse_gene_lowlevel.asc $(SYNTHDESTDIR)pulse_gene_lowlevel.bin 2>&1 |tee $(SYNTHDESTDIR)pulse_gene_lowlevel.pack.out.txt

# --hx4k --lp384
# package cm225 qn32

pulse_gene_low_level_cxxrtl : $(SCRDIR)pulse_gene_test.vhdl $(SCRDIR)pulse_gene_test.vhdl  $(SCRDIR)utils_package.vhdl $(SCRDIR)pulse_gene_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)utils_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)pulse_gene_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)pulse_gene.vhdl
	mkdir -p $(SYNTHDESTDIR)
	$(YOSYS_PROG) -m ghdl -p '$(GHDL_PROG) $(VFLAGS) Pulses_bundle; write_cxxrtl $(SYNTHDESTDIR)pulse_gene_lowlevel.rtl.cxx' 2>&1 |tee $(SYNTHDESTDIR)pulse_gene_lowlevel.synth.out.txt


clean	:
	rm -f work-obj93.cf work-obj08.cf 
#	rm -f $(DESTDIR)AngleGene.net $(BUILDDIR)AngleGene.cir $(BUILDDIR)AngleGene_spice.cir
