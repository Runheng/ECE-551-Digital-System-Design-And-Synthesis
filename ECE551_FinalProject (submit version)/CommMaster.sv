module CommMaster(clk, rst_n, cmd, snd_cmd, RX, clr_resp_rdy, TX, resp_rdy, resp, cmd_cmplt);

// setup inputs and outputs
input[15:0] cmd;
input clk, rst_n, snd_cmd, RX, clr_resp_rdy;
output reg TX, cmd_cmplt, resp_rdy;
output reg [7:0]resp;

logic[7:0] tx_data, low_byte;
logic trmt, tx_done, sel;

// declare possible states in state machine
typedef enum reg[1:0] {IDLE, SEND_HIGH, SEND_LOW, CMPLT} state_t;
state_t state, nxt_state;

// instantiate UART_TX
UART_tx iTX(.clk(clk), .rst_n(rst_n), .TX(TX), .trmt(trmt),
        .tx_data(tx_data), .tx_done(tx_done));
// instantiate UART_RX
UART_rx iRX(.clk(clk), .rst_n(rst_n), .RX(RX), .clr_rdy(clr_resp_rdy), .rdy(resp_rdy), .rx_data(resp));

// flop that store low byte 
always_ff@(posedge clk) begin
  if(snd_cmd)
    low_byte <= cmd[7:0];
end

// assign tx_data to low byte or high byte
assign tx_data = (sel == 1) ? cmd[15:8] : low_byte; 

// control state machine transition
always_ff@(posedge clk, negedge rst_n) begin
  if(!rst_n)
    state <= IDLE;
  else 
    state <= nxt_state;
end

// control state machine logic
always_comb begin
  // default outputs
  nxt_state = state;
  sel = 1'b0;
  trmt = 1'b0;
  cmd_cmplt = 1'b0;
  // switch cases
  case(state)
    IDLE: if(snd_cmd) begin
      sel = 1'b1;
      trmt = 1'b1;
      nxt_state = SEND_HIGH;
    end
    SEND_HIGH: if(tx_done) begin
      trmt = 1'b1;
      nxt_state = SEND_LOW;
    end
    SEND_LOW: if(tx_done) begin
      cmd_cmplt = 1'b1;
      nxt_state = CMPLT;
    end
    CMPLT:if(snd_cmd)begin
      sel = 1'b1;
      trmt = 1'b1;
      nxt_state = SEND_HIGH;
    end else begin
      cmd_cmplt = 1'b1;
    end
  endcase
end

endmodule

