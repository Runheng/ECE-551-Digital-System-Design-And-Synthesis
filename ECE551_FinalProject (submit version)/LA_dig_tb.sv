`timescale 1ns / 100ps
module LA_dig_tb();
			
//// Interconnects to DUT/support defined as type wire /////
wire clk400MHz,locked;			// PLL output signals to DUT
wire clk;						// 100MHz clock generated at this level from clk400MHz
wire VIH_PWM,VIL_PWM;			// connect to PWM outputs to monitor
wire CH1L,CH1H,CH2L,CH2H,CH3L;	// channel data inputs from AFE model
wire CH3H,CH4L,CH4H,CH5L,CH5H;	// channel data inputs from AFE model
wire RX,TX;						// interface to host
wire cmd_sent,resp_rdy;			// from master UART, monitored in test bench
wire [7:0] resp;				// from master UART, reponse received from DUT
wire tx_prot;					// UART signal for protocol triggering
wire SS_n,SCLK,MOSI;			// SPI signals for SPI protocol triggering
wire CH1L_mux,CH1H_mux;         // output of muxing logic for CH1 to enable testing of protocol triggering
wire CH2L_mux,CH2H_mux;			// output of muxing logic for CH2 to enable testing of protocol triggering
wire CH3L_mux,CH3H_mux;			// output of muxing logic for CH3 to enable testing of protocol triggering

////// Stimulus is declared as type reg ///////
reg REF_CLK, RST_n;
reg [15:0] host_cmd;			// command host is sending to DUT
reg send_cmd;					// asserted to initiate sending of command
reg clr_resp_rdy;				// asserted to knock down resp_rdy
reg [1:0] clk_div;				// counter used to derive 100MHz clk from clk400MHz
reg strt_tx;					// kick off unit used for protocol triggering
reg en_AFE;
reg capture_done_bit;			// flag used in polling for capture_done
reg [7:0] res,exp;				// used to store result and expected read from files

wire AFE_clk;

///////////////////////////////////////////
// Channel Dumps can be written to file //
/////////////////////////////////////////
integer fptr1;		// file pointer for CH1 dumps
integer fptr2;		// file pointer for CH2 dumps
integer fptr3;		// file pointer for CH3 dumps
integer fptr4;		// file pointer for CH4 dumps
integer fptr5;		// file pointer for CH5 dumps
integer fptr6;          // file pointer for CH1 dumps with different VIH and VIL
integer fptr7;          // file pointer for CH1 dumps with SPI triggering protocal
integer fexp;		// file pointer to file with expected results
integer found_res,found_expected,loop_cnt;
integer mismatches;	// number of mismatches when comparing results to expected
integer sample;		// sample counter in dump & compare

///////////////////////////
// Define command bytes //
/////////////////////////
localparam DUMP_CH1  = 8'h81;		// Dump channel 1
localparam DUMP_CH2  = 8'h82;		// Dump channel 2
localparam DUMP_CH3  = 8'h83;		// Dump channel 3
localparam DUMP_CH4  = 8'h84;		// Dump channel 4
localparam DUMP_CH5  = 8'h85;		// Dump channel 5
localparam TRIG_CFG_RD = 8'h00;		// Used to read TRIG_CFG register
localparam SET_DEC     = 8'h46;		// Write to decimator register
localparam SET_VIH_PWM = 8'h47;		// Set VIH trigger level [255:0] are valid values
localparam SET_VIL_PWM = 8'h48;		// Set VIL trigger level [255:0] are valid values
localparam SET_CH1_TRG = 8'h41;		// Write to CH1 trigger config register
localparam SET_CH2_TRG = 8'h42;		// Write to CH2 trigger config register
localparam SET_CH3_TRG = 8'h43;		// Write to CH3 trigger config register
localparam SET_CH4_TRG = 8'h44;		// Write to CH4 trigger config register
localparam SET_CH5_TRG = 8'h45;		// Write to CH5 trigger config register
localparam SET_TRG_CFG = 8'h40;		// Write to TrigCfg register
localparam WRT_TRGPOSH = 8'h4F;		// Write to trig_posH register
localparam WRT_TRGPOSL = 8'h50;		// Write to trig_posL register
localparam SET_MATCHH  = 8'h49;		// Write to matchH register
localparam SET_MATCHL  = 8'h4A;		// Write to matchL register
localparam SET_MASKH   = 8'h4B;		// Write to maskH register
localparam SET_MASKL   = 8'h4C;		// Write to maskL register
localparam SET_BAUDH   = 8'h4D;		// Write to baudD register
localparam SET_BAUDL   = 8'h4E;		// Write to baudL register
/////////////////////////////////
localparam UART_triggering = 1'b0;	// set to true if testing UART based triggering
reg SPI_triggering = 1'b0;	// set to true if testing SPI based triggering
localparam POS_ACK = 8'hA5;
localparam NEG_ACK = 8'hEE;

assign AFE_clk = en_AFE & clk400MHz;
///// Instantiate Analog Front End model (provides stimulus to channels) ///////
AFE iAFE(.smpl_clk(AFE_clk),.VIH_PWM(VIH_PWM),.VIL_PWM(VIL_PWM),
         .CH1L(CH1L),.CH1H(CH1H),.CH2L(CH2L),.CH2H(CH2H),.CH3L(CH3L),
         .CH3H(CH3H),.CH4L(CH4L),.CH4H(CH4H),.CH5L(CH5L),.CH5H(CH5H));
		 
//// Mux for muxing in protocol triggering for CH1 /////
assign {CH1H_mux,CH1L_mux} = (UART_triggering) ? {2{tx_prot}} :		// assign to output of UART_tx used to test UART triggering
                             (SPI_triggering) ? {2{SS_n}}: 			// assign to output of SPI SS_n if SPI triggering
				             {CH1H,CH1L};

//// Mux for muxing in protocol triggering for CH2 /////
assign {CH2H_mux,CH2L_mux} = (SPI_triggering) ? {2{SCLK}}: 			// assign to output of SPI SCLK if SPI triggering
				             {CH2H,CH2L};	

//// Mux for muxing in protocol triggering for CH3 /////
assign {CH3H_mux,CH3L_mux} = (SPI_triggering) ? {2{MOSI}}: 			// assign to output of SPI MOSI if SPI triggering
				             {CH3H,CH3L};					  
	 
////// Instantiate DUT ////////		  
LA_dig iDUT(.clk400MHz(clk400MHz),.RST_n(RST_n),.locked(locked),
            .VIH_PWM(VIH_PWM),.VIL_PWM(VIL_PWM),.CH1L(CH1L_mux),.CH1H(CH1H_mux),
			.CH2L(CH2L_mux),.CH2H(CH2H_mux),.CH3L(CH3L_mux),.CH3H(CH3H_mux),.CH4L(CH4L),
			.CH4H(CH4H),.CH5L(CH5L),.CH5H(CH5H),.RX(RX),.TX(TX));

///// Instantiate PLL to provide 400MHz clk from 50MHz ///////
pll8x iPLL(.ref_clk(REF_CLK),.RST_n(RST_n),.out_clk(clk400MHz),.locked(locked));

///// It is useful to have a 100MHz clock at this level similar //////
///// to main system clock (clk).  So we will create one        //////
always @(posedge clk400MHz, negedge locked)
  if (~locked)
    clk_div <= 2'b00;
  else
    clk_div <= clk_div+1;
assign clk = clk_div[1];

//// Instantiate Master UART (mimics host commands) //////
CommMaster iMSTR(.clk(clk), .rst_n(RST_n), .RX(TX), .TX(RX),
                     .cmd(host_cmd), .snd_cmd(send_cmd),
					 .cmd_cmplt(cmd_sent), .resp_rdy(resp_rdy),
					 .resp(resp), .clr_resp_rdy(clr_resp_rdy));
					 
////////////////////////////////////////////////////////////////
// Instantiate transmitter as source for protocol triggering //
//////////////////////////////////////////////////////////////
UART_tx iTX(.clk(clk), .rst_n(RST_n), .TX(tx_prot), .trmt(strt_tx),
            .tx_data(8'h96), .tx_done());
					 
////////////////////////////////////////////////////////////////////
// Instantiate SPI transmitter as source for protocol triggering //
//////////////////////////////////////////////////////////////////
SPI_TX iSPI(.clk(clk),.rst_n(RST_n),.SS_n(SS_n),.SCLK(SCLK),.wrt(strt_tx),.done(done),
            .tx_data(16'hABCD),.MOSI(MOSI),.pos_edge(1'b0),.width8(1'b0));

initial begin
  fptr1 = $fopen("CH1dmp.txt","w");			// open file to write CH1 dumps to
  fptr2 = $fopen("CH2dmp.txt","w");			// open file to write CH2 dumps to
  fptr3 = $fopen("CH3dmp.txt","w");			// open file to write CH3 dumps to
  fptr4 = $fopen("CH4dmp.txt","w");			// open file to write CH4 dumps to
  fptr5 = $fopen("CH5dmp.txt","w");			// open file to write CH5 dumps to

  en_AFE = 0;
  strt_tx = 0;								// do not initiate protocol trigger for now

  ////////////////////////////////////////////////////////////////////////////////
  //                          test channel dump                                 //
  ////////////////////////////////////////////////////////////////////////////////
  $display("Start testing dump channels");
  init;  // initialization and basic setup
  ////// Set for CH1 triggering on positive edge //////
  send_Cmd({SET_CH1_TRG,8'h10});
  wait_Resp(100000);
  check_Resp(POS_ACK);
    
  ////// Leave all other registers at their default /////
  ////// and set RUN bit, but enable AFE first //////
  en_AFE = 1;
  send_Cmd({SET_TRG_CFG,8'h13});	// set the run bit, keep protocol triggering off
  wait_Resp(100000);   
  check_Resp(POS_ACK);

  wait_cap_done;  // polling until capture_done is set

  send_Cmd({DUMP_CH1,8'h00});	// dump CH1 results 
  collect_dump(fptr1,1); // Now collect CH1 dump into a file 

  // test if CH2-CH5 also works well with dump, use plot to analyze 
  send_Cmd({DUMP_CH2,8'h00});
  collect_dump(fptr2,2);
  send_Cmd({DUMP_CH3,8'h00});
  collect_dump(fptr3,3);
  send_Cmd({DUMP_CH4,8'h00});
  collect_dump(fptr4,4);
  send_Cmd({DUMP_CH5,8'h00});
  collect_dump(fptr5,5);
  
  repeat(10) @(posedge clk);
  $fclose(fptr1);
  $fclose(fptr2);
  $fclose(fptr3);
  $fclose(fptr4);
  $fclose(fptr5);  
  
  //// Now compare dmp.txt to expected results ////
  compare_dump($fopen("test1_expected.txt","r"),$fopen("CH1dmp.txt","r"),1);
  $display("END of testing dump Channel");
  $display("*********************************************");

  ////////////////////////////////////////////////////////////////////////////////
  //                          test spi trigger                                  //
  ////////////////////////////////////////////////////////////////////////////////
  $display("Start testing SPI Protocol Trigger Logic");
  init;
  SPI_triggering = 1'b1;
  send_Cmd({SET_MATCHH,8'hAB}); // set match
  wait_Resp(100000);
  check_Resp(POS_ACK);
  send_Cmd({SET_MATCHL,8'hCD});
  wait_Resp(100000);
  check_Resp(POS_ACK);

  send_Cmd({SET_MASKH, 8'h00}); // set mask
  wait_Resp(100000);
  check_Resp(POS_ACK);
  send_Cmd({SET_MASKL, 8'h10});
  wait_Resp(100000);
  check_Resp(POS_ACK);
  
  send_Cmd({SET_DEC,8'h03});  // set decimator to 2 to zoom in
  wait_Resp(100000);
  check_Resp(POS_ACK);

  send_Cmd({SET_TRG_CFG,8'h19});  // enable spi, posedge
  wait_Resp(100000);
  check_Resp(POS_ACK);
   
  while(!iDUT.iDIG.iTRG.iTRG.armed) begin // wait until armed is set
    @(posedge clk);
  end

  @(negedge clk);
  strt_tx = 1'b1; 	// toggle strt_tx for one clk cycle to start transmission
  @(negedge clk);
  strt_tx = 1'b0;

  wait_cap_done;  // poll for capture done
  fptr7 = $fopen("CH7dmp.txt","w"); // open a new file and dump CH3 into it(MOSI line)
  send_Cmd({DUMP_CH3,8'h00});
  collect_dump(fptr7,7);
  repeat(10)@(posedge clk);
  $fclose(fptr7);
  SPI_triggering = 1'b0;

  $display("END of testing SPI Protocal Trigger Logic");
  $display("*********************************************");
  
  ///////////////////////////////////////////////////////////////////////////////
  //                       test different VIL, VIH                             //
  ///////////////////////////////////////////////////////////////////////////////
  $display("Start testing different value for VIL and VIH");
  init;
  send_Cmd({SET_VIH_PWM, 8'hCC});  // modify VIH
  wait_Resp(100000);
  check_Resp(POS_ACK);
  send_Cmd({SET_VIL_PWM, 8'h33});  // modify VIL
  wait_Resp(100000);
  check_Resp(POS_ACK);

  send_Cmd({SET_CH1_TRG,8'h08});  // set CH1 trigger on negedge
  wait_Resp(100000);
  check_Resp(POS_ACK);

  send_Cmd({SET_TRG_CFG,8'h13});  // set the run bit, keep protocol triggering off
  wait_Resp(100000);   
  check_Resp(POS_ACK);

  fptr6 = $fopen("CH6dmp.txt","w");	// open file to write CH1 dumps to
  wait_cap_done;  // polling until capture_done is set
  send_Cmd({DUMP_CH1,8'h00});	// dump CH1 results 
  collect_dump(fptr6,6); // Now collect CH1 dump into a file 
  repeat(10) @(posedge clk);
  $fclose(fptr6);
  $display("END of testing different VIL and VIH");
  $display("*********************************************");

   // end of all tests // 
  $display("YEAH!! ALL TESTS PASSED!!! END OF TESTBENCH.");
  $stop();
end

always
  #10.4 REF_CLK = ~REF_CLK;

`include "tb_tasks.txt"

endmodule	
