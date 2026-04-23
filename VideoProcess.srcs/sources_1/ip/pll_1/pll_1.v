//#PLL
//#N_m=1
//#M_m=30
//#locked_window_size=2
//#locked_counter=2
//#IRRAD_mode=YES
//#clk0_ali=3
//#clk1_ali=3
//#c0_hpc=6
//#c0_lpc=6
//#c1_hpc=30
//#c1_lpc=30
//#clk0_pha_shf_byp=false
//#clk1_pha_shf_byp=false
//#clk2_pha_shf_byp=false
//#clk3_pha_shf_byp=false
//#clk4_pha_shf_byp=false
//#C0_pha=10
//#C0_pha_8=0
//#C1_pha=58
//#C1_pha_8=0
`timescale 1 ps / 1 ps
module pll_1(
	inclk0,
	c0,
	c1,
	c2);

	input	inclk0;
	output	c0;
	output	c1;
	output	c2;
`ifdef SIM_PLL_STUB
	localparam integer C0_HALF_PERIOD_PS = 4000;
	localparam integer C1_HALF_PERIOD_PS = 20000;
	localparam integer C2_HALF_PERIOD_PS = 4000;
	localparam integer C2_PHASE_SHIFT_PS = 2000;

	reg c0_reg;
	reg c1_reg;
	reg c2_reg;

	assign c0 = c0_reg;
	assign c1 = c1_reg;
	assign c2 = c2_reg;

	initial begin
		c0_reg = 1'b0;
		@(posedge inclk0);
		forever #(C0_HALF_PERIOD_PS) c0_reg = ~c0_reg;
	end

	initial begin
		c1_reg = 1'b0;
		@(posedge inclk0);
		forever #(C1_HALF_PERIOD_PS) c1_reg = ~c1_reg;
	end

	initial begin
		c2_reg = 1'b0;
		@(posedge inclk0);
		#(C2_PHASE_SHIFT_PS);
		forever #(C2_HALF_PERIOD_PS) c2_reg = ~c2_reg;
	end
`else
	wire[5:0] wireC;
	assign c0 = wireC[0];
	assign c1 = wireC[1];
	assign c2 = wireC[2];

	altpll	altpll_component (
				.inclk ({1'h0, inclk0}),
				.pllena (1'b1),
				.pfdena (1'b1),
				.areset (1'b0),
				.clk (wireC),
				.locked (),
				.extclk (),
				.activeclock (),
				.clkbad (),
				.clkena ({6{1'b1}}),
				.clkloss (),
				.clkswitch (1'b0),
				.configupdate (1'b1),
				.enable0 (),
				.enable1 (),
				.extclkena ({4{1'b1}}),
				.fbin (1'b1),
				.fbout (),
				.phasecounterselect ({4{1'b1}}),
				.phasedone (),
				.phasestep (1'b1),
				.phaseupdown (1'b1),
				.scanaclr (1'b0),
				.scanclk (1'b0),
				.scanclkena (1'b1),
				.scandata (1'b0),
				.scandataout (),
				.scandone (),
				.scanread (1'b0),
				.scanwrite (1'b0),
				.sclkout0 (),
				.sclkout1 (),
				.vcooverrange (),
				.vcounderrange ());
	defparam
		altpll_component.clk0_divide_by = 12,
		altpll_component.clk0_duty_cycle = 50,
		altpll_component.clk0_multiply_by = 30,
		altpll_component.clk0_phase_shift = "0",
		altpll_component.clk1_divide_by = 60,
		altpll_component.clk1_duty_cycle = 50,
		altpll_component.clk1_multiply_by = 30,
		altpll_component.clk1_phase_shift = "0",
		altpll_component.clk2_divide_by = 12,
		altpll_component.clk2_duty_cycle = 50,
		altpll_component.clk2_multiply_by = 30,
		altpll_component.clk2_phase_shift = "2000",
		altpll_component.clk5_divide_by = 30,
		altpll_component.clk5_duty_cycle = 50,
		altpll_component.clk5_multiply_by = 30,
		altpll_component.clk5_phase_shift = "0",
		altpll_component.inclk0_input_frequency = 20000,
		altpll_component.operation_mode = "NO_COMPENSATION",
		altpll_component.port_pllena = "PORT_UNUSED",
		altpll_component.port_pfdena = "PORT_UNUSED",
		altpll_component.port_areset = "PORT_UNUSED",
		altpll_component.port_locked = "PORT_UNUSED",
		altpll_component.port_clk0 = "PORT_USED",
		altpll_component.port_clk1 = "PORT_USED",
		altpll_component.port_clk2 = "PORT_USED",
		altpll_component.port_clk3 = "PORT_UNUSED",
		altpll_component.port_clk4 = "PORT_UNUSED",
		altpll_component.port_clk5 = "PORT_USED",
		altpll_component.port_extclk0 = "PORT_UNUSED",
		altpll_component.intended_device_family = "Stratix",
		altpll_component.lpm_type = "altpll",
		altpll_component.pll_type = "Enhanced",
		altpll_component.port_activeclock = "PORT_UNUSED",
		altpll_component.port_clkbad0 = "PORT_UNUSED",
		altpll_component.port_clkbad1 = "PORT_UNUSED",
		altpll_component.port_clkloss = "PORT_UNUSED",
		altpll_component.port_clkswitch = "PORT_UNUSED",
		altpll_component.port_fbin = "PORT_UNUSED",
		altpll_component.port_inclk0 = "PORT_USED",
		altpll_component.port_inclk1 = "PORT_UNUSED",
		altpll_component.port_phasecounterselect = "PORT_UNUSED",
		altpll_component.port_phasedone = "PORT_UNUSED",
		altpll_component.port_phasestep = "PORT_UNUSED",
		altpll_component.port_phaseupdown = "PORT_UNUSED",
		altpll_component.port_scanaclr = "PORT_UNUSED",
		altpll_component.port_scanclk = "PORT_UNUSED",
		altpll_component.port_scanclkena = "PORT_UNUSED",
		altpll_component.port_scandata = "PORT_UNUSED",
		altpll_component.port_scandataout = "PORT_UNUSED",
		altpll_component.port_scandone = "PORT_UNUSED",
		altpll_component.port_scanread = "PORT_UNUSED",
		altpll_component.port_scanwrite = "PORT_UNUSED",
		altpll_component.port_clkena0 = "PORT_UNUSED",
		altpll_component.port_clkena1 = "PORT_UNUSED",
		altpll_component.port_clkena2 = "PORT_UNUSED",
		altpll_component.port_clkena3 = "PORT_UNUSED",
		altpll_component.port_clkena4 = "PORT_UNUSED",
		altpll_component.port_clkena5 = "PORT_UNUSED",
		altpll_component.port_extclk1 = "PORT_UNUSED",
		altpll_component.port_extclk2 = "PORT_UNUSED",
		altpll_component.port_extclk3 = "PORT_UNUSED";
`endif
endmodule
