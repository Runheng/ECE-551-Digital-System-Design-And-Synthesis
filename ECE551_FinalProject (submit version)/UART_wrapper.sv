module UART_wrapper(clk, rst_n, RX, send_resp, resp, clr_cmd_rdy, TX, resp_sent, cmd_rdy, cmd);

input clk, rst_n, RX, send_resp, clr_cmd_rdy;
input [7:0] resp;
output TX, resp_sent;
output reg cmd_rdy;
output reg[15:0] cmd;

logic rx_rdy, clr_rdy, sel, set_rdy;
logic [7:0] rx_data, high_byte;

// declare states
typedef enum reg[1:0]{IDLE, TRANS_HIGH, TRANS_LOW} state_t;
state_t state, nxt_state;

// instantiate UART
UART iUART(.clk(clk),.rst_n(rst_n),.RX(RX),.TX(TX),.rx_rdy(rx_rdy),.clr_rx_rdy(clr_rdy),
                  .rx_data(rx_data),.trmt(send_resp),.tx_data(resp),.tx_done(resp_sent));

// rx_data to cmd logic
always_ff@(posedge clk) begin
  if(sel)
    high_byte <= rx_data;
  else
    high_byte <= high_byte;
end

assign cmd = {high_byte,rx_data};

// cmd_rdy flop
always_ff@(posedge clk) begin
  if(set_rdy && !rx_rdy && !clr_cmd_rdy)
    cmd_rdy <= 1'b1;
  else if (rx_rdy || clr_cmd_rdy)
    cmd_rdy <= 1'b0;
  else
    cmd_rdy <= cmd_rdy;
end

// state machine state transition
always_ff@(posedge clk, negedge rst_n) begin
  if(!rst_n) 
    state <= IDLE;
  else
    state <= nxt_state;
end

// state machine logic
always_comb begin
  // default outputs
  nxt_state = state; // stay in the same state
  clr_rdy = 1'b0;
  sel = 1'b0;
  set_rdy = 1'b0;
  // switch cases
  case(state)
    IDLE: if(rx_rdy)begin
      clr_rdy = 1'b1;
      sel = 1'b1;
      nxt_state = TRANS_HIGH;
    end
    TRANS_HIGH: if(rx_rdy)begin
      clr_rdy = 1'b1;
      set_rdy = 1'b1;
      nxt_state = TRANS_LOW;
    end
    TRANS_LOW: if(rx_rdy) begin
      clr_rdy = 1'b1;
      sel = 1'b1;
      nxt_state = TRANS_HIGH;
    end else if(clr_cmd_rdy) begin
      nxt_state = IDLE;
    end else begin
      set_rdy = 1'b1;
    end
    default: begin
      nxt_state = IDLE;
    end
  endcase
end
endmodule
