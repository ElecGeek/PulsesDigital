NETLIST_PROG?=gnetlist
EXPORT_PROG?=gaf
GHDL_PROG=ghdl
VFLAGS?=--std=08
SRCDIR?=
BUILDDIR?=build/
DESTDIR?=
WAVDESTDIR?=/mnt/ramfs/
SYNTHDESTDIR?=Synth/
CXXDESTDIR?=CXX/
YOSYS_PROG?=yosys
NEXTPNR-ICE40_PROG?=nextpnr-ice40
ICEPACK?=icepack

# The documentation of the test targets is in the xxx_test.vhdl file.

# The DAC configuration configurates all the project.
# Then any change supposed to pass again all the test form 1 to N
#   in this order. The xA, xB, xC etc can be passed in random order

# Test 1A, verify your DAC works correctly
DAC_simul : $(SCRDIR)DAC.vhdl $(SCRDIR)DAC_test.vhdl $(SCRDIR)DAC_package.vhdl $(SCRDIR)DAC_configure.vhdl $(SRCDIR)DAC_emulators.vhdl
	rm -f work-obj08.cf
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)utils_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)test_utils.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)DAC_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)amplitude_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)DAC.vhdl
#	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)DAC_configure.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)DAC_emulators.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)DAC_test.vhdl
	$(GHDL_PROG) -e $(VFLAGS) DAC_test_default_controler
#	$(GHDL_PROG) -e $(VFLAGS) DAC_test
	$(GHDL_PROG) -r $(VFLAGS) DAC_test_default_controler --vcd=$(WAVDESTDIR)DAC_test.wav 2>&1 | tee $(DESTDIR)DAC_test.out.txt
#	$(GHDL_PROG) -r $(VFLAGS) DAC_test --vcd=$(WAVDESTDIR)DAC_test.wav 2>&1 | tee $(DESTDIR)DAC_test.out.txt

# Test 1B, verify the pulses are correctly generated from the computed amplitude inside one frame
pulse_parts_simul : $(SCRDIR)pulse_gene.vhdl $(SCRDIR)pulse_gene_test.vhdl $(SCRDIR)utils_package.vhdl $(SCRDIR)pulse_gene_package.vhdl 
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)utils_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)DAC_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)amplitude_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)pulse_gene_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)pulse_gene.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)pulse_gene_test.vhdl
	$(GHDL_PROG) -e $(VFLAGS) Pulses_lowlevel_test
	$(GHDL_PROG) -r $(VFLAGS) Pulses_lowlevel_test --vcd=$(WAVDESTDIR)Pulses_lowlevel_test.wav 2>&1 | tee $(DESTDIR)Pulses_lowlevel_test.out.txt
	$(GHDL_PROG) -e $(VFLAGS) Pulses_sequencer_test
	$(GHDL_PROG) -r $(VFLAGS) Pulses_sequencer_test --vcd=$(WAVDESTDIR)Pulses_sequencer_test.wav 2>&1 | tee $(DESTDIR)Pulses_sequencer_test.out.txt

# Test 2
pulse_bundle_simul : $(SCRDIR)pulse_gene.vhdl $(SCRDIR)pulse_gene_test.vhdl  $(SCRDIR)utils_package.vhdl $(SCRDIR)pulse_gene_package.vhdl $(SRCDIR)DAC_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)utils_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)DAC_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)amplitude_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)pulse_gene_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)DAC.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)pulse_gene.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)pulse_bundle.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)DAC_emulators.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)pulse_bundle_test.vhdl
	$(GHDL_PROG) -e $(VFLAGS) Pulses_bundle_test_default_controler
	$(GHDL_PROG) -r $(VFLAGS) Pulses_bundle_test_default_controler --vcd=$(WAVDESTDIR)Pulses_bundle_test.wav 2>&1 | tee $(DESTDIR)Pulses_bundle_test.out.txt

amplitude_parts_simul : $(SCRDIR)amplitude.vhdl $(SCRDIR)amplitude_test.vhdl $(SCRDIR)utils_package.vhdl $(SCRDIR)amplitude_package.vhdl 
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)utils_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)DAC_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)amplitude_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)amplitude.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)amplitude_test.vhdl
	$(GHDL_PROG) -e $(VFLAGS) Amplitudes_multiplier_R2R_test
	$(GHDL_PROG) -r $(VFLAGS) Amplitudes_multiplier_R2R_test --vcd=$(WAVDESTDIR)amplitudes_multiplier_R2R_test.wav 2>&1 | tee $(DESTDIR)amplitudes_multiplier_R2R_test.out.txt
	$(GHDL_PROG) -e $(VFLAGS) Amplitudes_multiplier_test
	$(GHDL_PROG) -r $(VFLAGS) Amplitudes_multiplier_test --vcd=$(WAVDESTDIR)Amplitudes_multiplier_test.wav 2>&1 | tee $(DESTDIR)Amplitudes_multiplier_test.out.txt

amplitude_bundle_simul : $(SCRDIR)amplitude.vhdl $(SCRDIR)amplitude_test.vhdl $(SCRDIR)utils_package.vhdl $(SCRDIR)amplitude_package.vhdl 
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)utils_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)DAC_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)amplitude_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)volume_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)amplitude.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)volume.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)amplitude_test.vhdl
#	$(GHDL_PROG) -e $(VFLAGS) Amplitudes_multiplier_R2R_test
#	$(GHDL_PROG) -r $(VFLAGS) Amplitudes_multiplier_R2R_test --vcd=$(WAVDESTDIR)amplitudes_multiplier_R2R_test.wav 2>&1 | tee $(DESTDIR)amplitudes_multiplier_R2R_test.out.txt
#	$(GHDL_PROG) -e $(VFLAGS) Amplitudes_sequencer_test
#	$(GHDL_PROG) -r $(VFLAGS) Amplitudes_sequencer_test --vcd=$(WAVDESTDIR)Amplitudes_sequencer_test.wav 2>&1 | tee $(DESTDIR)Amplitudes_sequencer_test.out.txt

amplitude_parts_cxx : $(SCRDIR)amplitude.vhdl $(SCRDIR)amplitude_test.vhdl $(SCRDIR)utils_package.vhdl $(SCRDIR)amplitude_package.vhdl 
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)utils_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)DAC_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)amplitude_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)amplitude.vhdl
	mkdir -p $(CXXDESTDIR)
	$(YOSYS_PROG) -m ghdl -p '$(GHDL_PROG) $(VFLAGS) Amplitude_multiplier_CXX_wrap; write_cxxrtl $(CXXDESTDIR)amplitude_lowlevel.rtl.cxx' 2>&1 |tee $(CXXDESTDIR)amplitude_lowlevel.synth.out.txt


#	$(YOSYS_PROG) -m ghdl -p '$(GHDL_PROG) $(VFLAGS) Amplitude_multiplier_CXX_wrap; synth_ice40 -json $(SYNTHDESTDIR)amplitude_lowlevel.ice40.json' 2>&1 |tee $(SYNTHDESTDIR)amplitude_lowlevel.synth.out.txt
#	$(NEXTPNR-ICE40_PROG) --hx4k --package tq144 --freq 30.00 --top Amplitude_multiplier_CXX_wrap --asc $(SYNTHDESTDIR)amplitude_lowlevel.asc --json $(SYNTHDESTDIR)amplitude_lowlevel.ice40.json --placed-svg $(SYNTHDESTDIR)amplitude_lowlevel.placed.svg


project_synth : $(SCRDIR)pulse_gene.vhdl $(SCRDIR)pulse_gene_test.vhdl  $(SCRDIR)utils_package.vhdl $(SCRDIR)pulse_gene_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)utils_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)DAC_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)amplitude_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)pulse_gene_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)DAC.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)pulse_gene.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)pulse_bundle.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)project_bundle.vhdl
	$(GHDL_PROG) -e $(VFLAGS) PCB_bundle
	$(GHDL_PROG) --synth $(VFLAGS) --out=none PCB_bundle

	mkdir -p $(SYNTHDESTDIR)
	$(YOSYS_PROG) -m ghdl -p '$(GHDL_PROG) $(VFLAGS) PCB_bundle; synth_ice40 -json $(SYNTHDESTDIR)project_lowlevel.ice40.json' 2>&1 |tee $(SYNTHDESTDIR)project_lowlevel.synth.out.txt
	$(NEXTPNR-ICE40_PROG) --hx4k --package tq144 --freq 30.00 --top Project_bundle --asc $(SYNTHDESTDIR)project_lowlevel.asc --json $(SYNTHDESTDIR)project_lowlevel.ice40.json --placed-svg $(SYNTHDESTDIR)project_lowlevel.placed.svg --routed-svg $(SYNTHDESTDIR)project_lowlevel.routed.svg --report $(SYNTHDESTDIR)project_lowlevel.report.json 2>&1 |tee $(SYNTHDESTDIR)project_lowlevel.P_and_R.out.txt
	$(ICEPACK) $(SYNTHDESTDIR)project_lowlevel.asc $(SYNTHDESTDIR)project_lowlevel.bin 2>&1 |tee $(SYNTHDESTDIR)project_lowlevel.pack.out.txt


project_synth_gui : project_synth
	$(NEXTPNR-ICE40_PROG) --hx4k --package tq144 --freq 30.00 --top Project_bundle --asc $(SYNTHDESTDIR)project_lowlevel.asc --json $(SYNTHDESTDIR)project_lowlevel.ice40.json --gui

amplitude_low_level_synth : $(SCRDIR)amplitude.vhdl $(SCRDIR)amplitude_test.vhdl $(SCRDIR)utils_package.vhdl $(SCRDIR)amplitude_package.vhdl 
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)utils_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)amplitude_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)amplitude.vhdl
	mkdir -p $(SYNTHDESTDIR)
	$(YOSYS_PROG) -m ghdl -p '$(GHDL_PROG) $(VFLAGS) Amplitude_multiplier_CXX_wrap; synth_ice40 -json $(SYNTHDESTDIR)amplitude_lowlevel.ice40.json' 2>&1 |tee $(SYNTHDESTDIR)amplitude_lowlevel.synth.out.txt
	$(NEXTPNR-ICE40_PROG) --hx4k --package tq144 --freq 30.00 --top Amplitude_multiplier_CXX_wrap --asc $(SYNTHDESTDIR)amplitude_lowlevel.asc --json $(SYNTHDESTDIR)amplitude_lowlevel.ice40.json --placed-svg $(SYNTHDESTDIR)amplitude_lowlevel.placed.svg --routed-svg $(SYNTHDESTDIR)amplitude_lowlevel.routed.svg --report $(SYNTHDESTDIR)amplitude_lowlevelc.report.json 2>&1 |tee $(SYNTHDESTDIR)amplitude_lowlevel.P_and_R.out.txt
	$(ICEPACK) $(SYNTHDESTDIR)amplitude_lowlevel.asc $(SYNTHDESTDIR)amplitude_lowlevel.bin 2>&1 |tee $(SYNTHDESTDIR)amplitude_lowlevel.pack.out.txt


# --hx4k --lp384
# package cm225 qn32

pulse_gene_low_level_cxxrtl : $(SCRDIR)pulse_gene_test.vhdl $(SCRDIR)pulse_gene_test.vhdl  $(SCRDIR)utils_package.vhdl $(SCRDIR)pulse_gene_package.vhdl $(SCRDIR)DAC_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)utils_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)DAC_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)amplitude_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)pulse_gene_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)pulse_gene.vhdl
	mkdir -p $(SYNTHDESTDIR)
	$(YOSYS_PROG) -m ghdl -p '$(GHDL_PROG) $(VFLAGS) Pulses_bundle; write_cxxrtl $(SYNTHDESTDIR)pulse_gene_lowlevel.rtl.cxx' 2>&1 |tee $(SYNTHDESTDIR)pulse_gene_lowlevel.synth.out.txt

amplitude_cxxrtl : $(SCRDIR)amplitude.vhdl $(SCRDIR)amplitude_test.vhdl $(SCRDIR)utils_package.vhdl $(SCRDIR)amplitude_package.vhdl $(SCRDIR)DAC_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)utils_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)DAC_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)amplitude_package.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)amplitude.vhdl
	$(GHDL_PROG) -a $(VFLAGS) $(SCRDIR)amplitude_multiplier_CXX_wrap.vhdl
	mkdir -p $(SYNTHDESTDIR)
	$(YOSYS_PROG) -m ghdl -p '$(GHDL_PROG) $(VFLAGS) Amplitude_multiplier_CXX_wrap; write_cxxrtl $(SYNTHDESTDIR)amplitude_multiplier_CXX_wrap.rtl.cxx' 2>&1 |tee $(SYNTHDESTDIR)amplitude_multiplier_CXX_wrap.synth.out.txt


all_simul : DAC_simul pulse_parts_simul pulse_bundle_simul amplitude_parts_simul
	@echo "Done"

all_cxxrtl : pulse_gene_low_level_cxxrtl amplitude_cxxrtl

clean	:
	rm -f work-obj93.cf work-obj08.cf 
#	rm -f $(DESTDIR)AngleGene.net $(BUILDDIR)AngleGene.cir $(BUILDDIR)AngleGene_spice.cir
