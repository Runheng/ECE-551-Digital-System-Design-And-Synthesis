module SPI_RX(clk, rst_n, SS_n, SCLK, MOSI, edg, len8, mask, match, SPItrig);

input clk, rst_n, SS_n, SCLK, MOSI, edg, len8;
input[15:0] mask, match;
output SPItrig;

logic SCLK_ff1, SCLK_ff2, SCLK_ff3, MOSI_ff1, MOSI_ff2, MOSI_ff3, SS_ff1, SS_ff2; // used for meta-stability
logic done, shift, SCLK_rise, SCLK_fall, smp_edg; // used by state machine
logic result_8, result_16, result; // used for compare data with match
logic [15:0] data_msked, match_msked, xor_16;
logic [15:0] shft_reg;
logic [7:0] xor_8;

typedef enum reg {IDLE, RX}state_t;
state_t state, nxt_state;

// double flop for SS_n for meta-stability
always_ff@(posedge clk) begin
  SS_ff1 <= SS_n;
end
always_ff@(posedge clk) begin
  SS_ff2 <= SS_ff1;
end

// double flop SCLK for meta-stability, the third flop for later use in edge detector
always_ff@(posedge clk) begin
  SCLK_ff1 <= SCLK;
end
always_ff@(posedge clk) begin
  SCLK_ff2 <= SCLK_ff1;
end
always_ff@(posedge clk) begin
  SCLK_ff3 <= SCLK_ff2;
end

// triple flop MOSI for meta-stability and in phase with SCLK_rise or SCLK_fall
always_ff@(posedge clk)begin
  MOSI_ff1 <= MOSI;
end
always_ff@(posedge clk)begin
  MOSI_ff2 <= MOSI_ff1;
end
always_ff@(posedge clk)begin
  MOSI_ff3 <= MOSI_ff2;
end

// edge detector
assign SCLK_rise = ((~SCLK_ff3)&SCLK_ff2) ? 1'b1: 1'b0;
assign SCLK_fall = ((~SCLK_ff2)&SCLK_ff3) ? 1'b1: 1'b0;
assign smp_edg = (edg == 1) ? SCLK_rise: SCLK_fall;

// shift register logic
always_ff@(posedge clk) begin
  if(shift)
    shft_reg <= {shft_reg[14:0], MOSI_ff3};
  else 
    shft_reg <= shft_reg;
end

// compare and trig
assign match_msked = match | mask;
assign data_msked = shft_reg | mask;
assign xor_8 = match_msked[7:0]^data_msked[7:0];
assign xor_16 = match_msked ^ data_msked;
assign result_8 = (|xor_8)? 1'b0: 1'b1;
assign result_16 = (|xor_16) ? 1'b0: 1'b1;
assign result = (len8 == 1) ? result_8: result_16;
assign SPItrig = (done == 1) ? result: 1'b0;

// state machine transition
always_ff@(posedge clk, negedge rst_n) begin
  if(!rst_n)
    state <= IDLE;
  else
    state <= nxt_state;
end

//state machine logic
always_comb begin
  //default outputs
  nxt_state = state;
  done = 1'b0;
  shift = 1'b0;
  // switch cases
  case(state)
    IDLE: if(!SS_ff2) begin
      nxt_state = RX;
    end
    RX: if (SS_ff2) begin 
      done = 1'b1;
      nxt_state = IDLE;
    end else if(smp_edg) begin
      shift = 1'b1;
    end
  endcase
end

endmodule
