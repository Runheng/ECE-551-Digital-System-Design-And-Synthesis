module cmd_cfg(clk,rst_n,resp,send_resp,resp_sent,cmd,cmd_rdy,clr_cmd_rdy,
               set_capture_done,raddr,rdataCH1,rdataCH2,rdataCH3,rdataCH4,
			   rdataCH5,waddr,trig_pos,decimator,maskL,maskH,matchL,matchH,
			   baud_cntL,baud_cntH,TrigCfg,CH1TrigCfg,CH2TrigCfg,CH3TrigCfg,
			   CH4TrigCfg,CH5TrigCfg,VIH,VIL);
			   
  parameter ENTRIES = 384,	// defaults to 384 for simulation, use 12288 for DE-0
            LOG2 = 9;		// Log base 2 of number of entries
			
  input clk,rst_n;
  input [15:0] cmd;			// 16-bit command from UART (host) to be executed
  input cmd_rdy;			// indicates command is valid
  input resp_sent;			// indicates transmission of resp[7:0] to host is complete
  input set_capture_done;	// from the capture module (sets capture done bit in TrigCfg)
  input [LOG2-1:0] waddr;		// on a dump raddr is initialized to waddr
  input [7:0] rdataCH1;		// read data from RAMqueues
  input [7:0] rdataCH2,rdataCH3;
  input [7:0] rdataCH4,rdataCH5;
  output logic [7:0] resp;		// data to send to host as response (formed in SM)
  output reg send_resp;				// used to initiate transmission to host (via UART)
  output reg clr_cmd_rdy;			// when finished processing command use this to knock down cmd_rdy
  output reg [LOG2-1:0] raddr;		// read address to RAMqueues (same address to all queues)
  output [LOG2-1:0] trig_pos;	// how many sample after trigger to capture
  output reg [3:0] decimator;	// goes to clk_rst_smpl block
  output reg [7:0] maskL,maskH;				// to trigger logic for protocol triggering
  output reg [7:0] matchL,matchH;			// to trigger logic for protocol triggering
  output reg [7:0] baud_cntL,baud_cntH;		// to trigger logic for UART triggering
  output reg [5:0] TrigCfg;					// some bits to trigger logic, others to capture unit
  output reg [4:0] CH1TrigCfg,CH2TrigCfg;	// to channel trigger logic
  output reg [4:0] CH3TrigCfg,CH4TrigCfg;	// to channel trigger logic
  output reg [4:0] CH5TrigCfg;				// to channel trigger logic
  output reg [7:0] VIH,VIL;					// to dual_PWM to set thresholds
  logic ld, inc, wrt_reg;  // output of state machine used to control raddr register
  reg [7:0] trig_posH, trig_posL;  // spectify the upper/lower byte of trig_pos

  typedef enum reg[1:0] {IDLE, DMP_PREP, DMP, DMP_WT} state_t; 
  state_t state,nxt_state;

  // reg raddr
  always_ff@(posedge clk) begin    // this reg doesn't need reset
    if(ld)
      raddr <= waddr;
    else if (inc)
      raddr <= (raddr + 1)%ENTRIES;
  end

  // reg TrigCfg  
  always_ff@(posedge clk, negedge rst_n) begin
    if(!rst_n)
      TrigCfg <= 6'h03;
    else if(wrt_reg && (cmd[13:8]==6'h00))
      if(set_capture_done)
        TrigCfg <= {1'b1,cmd[4:0]};
      else 
        TrigCfg <= cmd[5:0];
    else if(set_capture_done)
        TrigCfg <= {1'b1, TrigCfg[4:0]};
  end

  // reg CH1TrigCfg
  always_ff@(posedge clk, negedge rst_n)begin
    if(!rst_n)
      CH1TrigCfg <= 5'h01;
    else if(wrt_reg && (cmd[13:8]==6'h01))
      CH1TrigCfg <= cmd[4:0];
  end

  // reg CH2TrigCfg
  always_ff@(posedge clk, negedge rst_n)begin
    if(!rst_n)
      CH2TrigCfg <= 5'h01;
    else if(wrt_reg && (cmd[13:8]==6'h02))
      CH2TrigCfg <= cmd[4:0];
  end

  // reg CH3TrigCfg
  always_ff@(posedge clk, negedge rst_n)begin
    if(!rst_n)
      CH3TrigCfg <= 5'h01;
    else if(wrt_reg && (cmd[13:8]==6'h03))
      CH3TrigCfg <= cmd[4:0];
  end
  
  // reg CH4TrigCfg
  always_ff@(posedge clk, negedge rst_n)begin
    if(!rst_n)
      CH4TrigCfg <= 5'h01;
    else if(wrt_reg && (cmd[13:8]==6'h04))
      CH4TrigCfg <= cmd[4:0];
  end

  // reg CH5TrigCfg
  always_ff@(posedge clk, negedge rst_n)begin
    if(!rst_n)
      CH5TrigCfg <= 5'h01;
    else if(wrt_reg && (cmd[13:8]==6'h05))
      CH5TrigCfg <= cmd[4:0];
  end

  // reg decimator
  always_ff@(posedge clk, negedge rst_n)begin
    if(!rst_n)
      decimator <= 4'h0;
    else if(wrt_reg && (cmd[13:8]==6'h06))
      decimator <= cmd[3:0];
  end
 
  // reg VIH
  always_ff@(posedge clk, negedge rst_n)begin
    if(!rst_n)
      VIH <= 8'hAA;
    else if(wrt_reg && (cmd[13:8]==6'h07))
      VIH <= cmd[7:0];
  end

  // reg VIL
  always_ff@(posedge clk, negedge rst_n)begin
    if(!rst_n)
      VIL <= 8'h55;
    else if(wrt_reg && (cmd[13:8]==6'h08))
      VIL <= cmd[7:0];
  end

  // reg matchH
  always_ff@(posedge clk, negedge rst_n)begin
    if(!rst_n)
      matchH <= 8'h00;
    else if(wrt_reg && (cmd[13:8]==6'h09))
      matchH <= cmd[7:0];
  end

  // reg matchL
  always_ff@(posedge clk, negedge rst_n)begin
    if(!rst_n)
      matchL <= 8'h00;
    else if(wrt_reg && (cmd[13:8]==6'h0A))
      matchL <= cmd[7:0];
  end

  // reg maskH
  always_ff@(posedge clk, negedge rst_n)begin
    if(!rst_n)
      maskH <= 8'h00;
    else if(wrt_reg && (cmd[13:8]==6'h0B))
      maskH <= cmd[7:0];
  end

  // reg maskL
  always_ff@(posedge clk, negedge rst_n)begin
    if(!rst_n)
      maskL <= 8'h00;
    else if(wrt_reg && (cmd[13:8]==6'h0C))
      maskL <= cmd[7:0];
  end

  // reg baud_cntH
  always_ff@(posedge clk, negedge rst_n)begin
    if(!rst_n)
      baud_cntH <= 8'h06;
    else if(wrt_reg && (cmd[13:8]==6'h0D))
      baud_cntH <= cmd[7:0];
  end

  // reg baud_cntL
  always_ff@(posedge clk, negedge rst_n)begin
    if(!rst_n)
      baud_cntL <= 8'hC8;
    else if(wrt_reg && (cmd[13:8]==6'h0E))
      baud_cntL <= cmd[7:0];
  end

  // reg trig_posH
  always_ff@(posedge clk, negedge rst_n)begin
    if(!rst_n)
      trig_posH <= 8'h00;
    else if(wrt_reg && (cmd[13:8]==6'h0F))
      trig_posH <= cmd[7:0];
  end

  // reg trig_posL
  always_ff@(posedge clk, negedge rst_n)begin
    if(!rst_n)
      trig_posL <= 8'h01;
    else if(wrt_reg && (cmd[13:8]==6'h10))
      trig_posL <= cmd[7:0];
  end
  
  assign trig_pos = {trig_posH[LOG2-9:0],trig_posL};

  // state machine transition
  always_ff@(posedge clk, negedge rst_n)begin
    if(!rst_n)
      state <= IDLE;
    else
      state <= nxt_state;
  end

  //state machine logic
  always_comb begin
    // default outputs
    nxt_state = state;
    ld = 1'b0;
    inc = 1'b0;
    send_resp = 1'b0;
    resp = 8'h00;
    clr_cmd_rdy = 1'b0;
    wrt_reg = 1'b0;
    // switch cases
    case(state)
      ///////////////////////////
      /////// process cmd ///////
      ///////////////////////////
      IDLE: begin
        ld = 1'b1;
        if(cmd_rdy) begin
        case(cmd[15:14])
          ////// dump channel //////
          2'b10: begin
            
            nxt_state = DMP_PREP;
          end
          ////// write reg //////
          2'b01: begin
            wrt_reg = 1'b1;
            resp = 8'hA5;
            send_resp = 1'b1;
            clr_cmd_rdy = 1'b1;
          end
          ////// read reg //////
          2'b00: begin 
            case(cmd[13:8])
              6'h00: resp = {2'b0, TrigCfg};
              6'h01: resp = {3'b0, CH1TrigCfg};
              6'h02: resp = {3'b0, CH2TrigCfg};
              6'h03: resp = {3'b0, CH3TrigCfg};
              6'h04: resp = {3'b0, CH4TrigCfg};
              6'h05: resp = {3'b0, CH5TrigCfg};
              6'h06: resp = {4'h0, decimator};
              6'h07: resp = VIH;
              6'h08: resp = VIL;
              6'h09: resp = matchH;
              6'h0A: resp = matchL;
              6'h0B: resp = maskH;
              6'h0C: resp = maskL;
              6'h0D: resp = baud_cntH;
              6'h0E: resp = baud_cntL;
              6'h0F: resp = trig_posH;
              6'h10: resp = trig_posL;
              default: begin end
            endcase
            send_resp = 1'b1;
            clr_cmd_rdy = 1'b1;
          end
          default: begin
            resp = 8'hEE;
            send_resp = 1'b1;
            clr_cmd_rdy = 1'b1;
          end
        endcase
       end
      end
      //////////////////////////////////////////
      // Wait 1 clk cycle for rdata to be rdy //
      //////////////////////////////////////////
      DMP_PREP: begin
        nxt_state = DMP;
      end
      /////////////////////////////////////////
      // read and send the data from channel //
      /////////////////////////////////////////
      DMP: begin
        case(cmd[10:8])
          3'h1: resp = rdataCH1;
          3'h2: resp = rdataCH2;
          3'h3: resp = rdataCH3;
          3'h4: resp = rdataCH4;
          3'h5: resp = rdataCH5;
        endcase
        send_resp = 1'b1;
        nxt_state = DMP_WT;
      end
      ///////////////////////////////////////////////////////////
      // wait for response and inc addr, end if dump completed //
      ///////////////////////////////////////////////////////////
      DMP_WT: if(resp_sent) begin
        inc = 1'b1;
        if ((raddr + 1'b1)!= waddr)
          nxt_state = DMP;
        else begin
          nxt_state = IDLE;
          clr_cmd_rdy = 1'b1;
        end
      end
      default: 
        nxt_state = IDLE;
    endcase
  end

endmodule
  