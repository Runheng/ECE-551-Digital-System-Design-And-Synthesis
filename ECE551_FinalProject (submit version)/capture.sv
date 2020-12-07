module capture(clk,rst_n,wrt_smpl,run,capture_done,triggered,trig_pos,
               we,waddr,set_capture_done,armed);

  parameter ENTRIES = 384,		// defaults to 384 for simulation, use 12288 for DE-0
            LOG2 = 9;			// Log base 2 of number of entries
  
  input clk;					// system clock.
  input rst_n;					// active low asynch reset
  input wrt_smpl;				// from clk_rst_smpl.  Lets us know valid sample ready
  input run;					// signal from cmd_cfg that indicates we are in run mode
  input capture_done;			// signal from cmd_cfg register.
  input triggered;				// from trigger unit...we are triggered
  input [LOG2-1:0] trig_pos;	// How many samples after trigger do we capture
  
  output we;					// write enable to RAMs
  output reg [LOG2-1:0] waddr;	// write addr to RAMs
  output set_capture_done;		// asserted to set bit in cmd_cfg
  output reg armed;				// we have enough samples to accept a trigger

  typedef enum reg[1:0] {IDLE,CAPTURE,WAIT_RD} state_t;
  state_t state,nxt_state;
  
  reg [LOG2-1:0] trig_cnt;		         // how many samples post trigger?
 
  logic inc_cnt;                       // increment trig_cnt based on SM output
  logic clr;                           // clear waddr and trig_cnt/initialize to zero 
  logic clr_armed, set_armed;          // clear or set armed signal
  // trig_cnt flop //
  always_ff@(posedge clk, negedge rst_n) begin
    if(!rst_n)
      trig_cnt <=0;    
    else if (clr)
      trig_cnt <= 0;
    else if (inc_cnt)
      trig_cnt <= trig_cnt + 1;
  end

  // waddr flop //
  always_ff@(posedge clk, negedge rst_n) begin
    if(!rst_n)
      waddr <= 0;
    else if (clr || waddr >= ENTRIES)
      waddr <= 0;
    else if (we)
      waddr <= waddr + 1;
  end

  // armed flop //
  always_ff@(posedge clk, negedge rst_n) begin
    if(!rst_n)
      armed <= 1'b0;
    else if(clr_armed)
      armed <= 1'b0;
    else if(set_armed)
      armed <= 1'b1;
  end

  // state machine transition //
  always_ff@(posedge clk, negedge rst_n) begin
    if(!rst_n)
      state <= IDLE;
    else
      state <= nxt_state;
  end

  assign inc_cnt = (triggered & we)? 1'b1:1'b0;
  assign set_armed = ((waddr+trig_pos)==(ENTRIES-1))? 1'b1:1'b0;
  assign we = wrt_smpl&run&(~capture_done);
  assign set_capture_done = (triggered & (trig_pos == trig_cnt))? 1'b1:1'b0;
  // state machine logic //
  always_comb begin
    // default outputs //
    nxt_state = state;
    clr = 1'b0;
    clr_armed = 1'b0;
    // switch cases
    case(state)
      IDLE: if(run)begin
        nxt_state = CAPTURE;
        clr = 1'b1;
      end
      CAPTURE: if(triggered)begin
          if(trig_cnt == trig_pos)begin
            // set capture_done bit, clr armed
            clr_armed = 1'b1;
            nxt_state = WAIT_RD;
          end
      end
      WAIT_RD: if(!capture_done)begin
        nxt_state = IDLE;
      end
      default: 
         nxt_state = IDLE;
    endcase
  end
 
endmodule