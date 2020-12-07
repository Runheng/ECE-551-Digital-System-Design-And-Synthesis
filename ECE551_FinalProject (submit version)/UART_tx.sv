module UART_tx(clk, rst_n, trmt, tx_data, tx_done, TX);

input clk, rst_n, trmt;
input [7:0] tx_data;
output reg tx_done;
output reg TX;

typedef enum reg{IDLE,TRANS} state_t;
state_t state, nxt_state;

logic[5:0] baud_cnt;
logic[3:0] bit_cnt;
logic[8:0] tx_shift_reg;
logic load, shift, transmitting, set_done;

///// counting num bits already transmitted /////
always_ff@(posedge clk) begin
  if(load)
    bit_cnt <= 4'h0;
  else if (shift)
    bit_cnt <= bit_cnt + 1;
  else 
    bit_cnt <= bit_cnt;
end

///// counting baud to determine when to shift /////
always_ff@(posedge clk) begin
  if (load|shift) 
    baud_cnt <= 6'h00;
  else if (transmitting)
    baud_cnt <= baud_cnt + 1;
  else 
    baud_cnt <= baud_cnt;
end

///// check if shift should be asserted /////
assign shift = (baud_cnt == 34)? 1:0;

///// transmit current bit /////
always_ff@(posedge clk, negedge rst_n) begin
  if (!rst_n) begin
    tx_shift_reg <= 9'h1FF;
    TX <= tx_shift_reg[0];
  end else if(load) begin
    tx_shift_reg <= {tx_data, 1'b0};
    TX <= tx_shift_reg[0]; 
  end else if(shift) begin
    tx_shift_reg <= {1'b1, tx_shift_reg[8:1]};
    TX <= tx_shift_reg[0];
  end else begin
    tx_shift_reg <= tx_shift_reg;
    TX <= tx_shift_reg[0];
  end
end

///// assert tx_done /////
always_ff@(posedge clk, negedge rst_n) begin
  if(!rst_n)
    tx_done <= 1'b0;
  else if (set_done&(!load))
    tx_done <= 1'b1;
  else if(load)
    tx_done <= 1'b0;
  else
    tx_done <= tx_done;
end

///// state machine /////
always_ff@(posedge clk, negedge rst_n) begin
  if(!rst_n)
    state <= IDLE;
  else
    state <= nxt_state;
end
always_comb begin
  // default outpus //  
  transmitting = 1'b0;
  set_done = 1'b0;
  nxt_state = IDLE;
  case(state)
    IDLE: if(trmt) begin
      load = 1'b1;
      nxt_state = TRANS;
    end
    TRANS: if(bit_cnt < 4'hA) begin
      transmitting = 1'b1;
      load = 1'b0;
      nxt_state = TRANS;
      end else begin
      set_done = 1'b1;
      load = 1'b0;
      nxt_state = IDLE;
      end
    default: begin 
    end
  endcase
end

endmodule
