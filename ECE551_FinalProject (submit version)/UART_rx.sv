module UART_rx(clk, rst_n, RX, clr_rdy, rdy, rx_data);

input clk, rst_n, RX, clr_rdy;
output reg rdy;
output reg [7:0] rx_data;

typedef enum reg{IDLE, RECEIVE} state_t;
state_t state, nxt_state;

logic start, receiving, shift, set_rdy, rx, rx_good; // rx is the stable version of RX
logic[3:0] bit_cnt;
logic[5:0] baud_cnt;
logic[8:0] rx_shft_reg;

///// bit count flop setup /////
always_ff@(posedge clk) begin
  if(start)
    bit_cnt <= 4'h0;
  else if(shift)
    bit_cnt <= bit_cnt + 1;
  else
    bit_cnt <= bit_cnt;
end

///// baud count flop setup /////
always_ff@(posedge clk) begin
    if(start|shift)
      baud_cnt <= 6'h22;
    else if (receiving)
      baud_cnt <= baud_cnt - 1;
    else 
      baud_cnt <= baud_cnt;
end

///// assign shift signal by comparing baud_cnt with 0 /////
assign shift = (baud_cnt == 0) ? 1:0;

///// double ff to improve metastability /////
always_ff@(posedge clk)begin
    rx <= RX;
end
always_ff@(posedge clk)begin
    rx_good <= rx;
end

///// rx_data flop setup /////
always_ff@(posedge clk) begin
    if(shift) begin
      rx_shft_reg <= {rx_good, rx_shft_reg[8:1]};
      rx_data <= rx_shft_reg[7:0];
    end else begin
      rx_shft_reg <= rx_shft_reg;
      rx_data <= rx_shft_reg[7:0];
    end
end

///// rx ready flop setup /////
always_ff@(posedge clk, negedge rst_n) begin
    if(!rst_n)
      rdy <= 1'b0;
    else if(set_rdy)
      rdy <= 1'b1;
    else if(start | clr_rdy)
      rdy <= 1'b0;
    else
      rdy <= rdy;
end

///// state machine /////
always_ff@(posedge clk, negedge rst_n) begin
    if(!rst_n)
      state <= IDLE;
    else
      state <= nxt_state;
end
always_comb begin
    // set default values
    nxt_state = IDLE;
    start = 1'b0;
    receiving = 1'b0;
    set_rdy = 1'b0;
    case(state)
      IDLE: if(RX==0)begin
        nxt_state = RECEIVE;
        start = 1'b1;
      end
      RECEIVE: if(bit_cnt<4'hA)begin 
        nxt_state = RECEIVE;
        receiving = 1'b1;
      end else begin
        set_rdy = 1'b1;
      end
      default: begin end
    endcase
end

endmodule
