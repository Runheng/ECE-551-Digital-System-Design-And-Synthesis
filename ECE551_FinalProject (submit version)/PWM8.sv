module pwm8(clk, rst_n, duty, PWM_sig);

input clk, rst_n;
input[7:0] duty;
output reg PWM_sig;
logic[7:0] cnt;
logic d;

// ff for counter
always_ff@(posedge clk, negedge rst_n) begin
  if(!rst_n)
    cnt <= 8'h00;
  else
    cnt <= cnt+1;
end 

// ff for PWM_sig output
always_ff@(posedge clk, negedge rst_n)begin
  if(!rst_n)
    PWM_sig <= 1'b0;
  else
    PWM_sig <= d;
end

// combinational logic for comparator
always_comb begin
  if(cnt<= duty)
    d = 1'b1;
  else
    d = 1'b0;
end

endmodule
