module trigger_logic(clk, rst_n, armed, CH1Trig, CH2Trig, CH3Trig, CH4Trig, CH5Trig, protTrig, set_capture_done, triggered);

input CH1Trig, CH2Trig, CH3Trig, CH4Trig, CH5Trig, protTrig, armed, set_capture_done, rst_n, clk;
output reg triggered;
logic ff_in;

always_comb begin
  if (triggered == 1'b1 && set_capture_done == 1'b1) begin
    ff_in = 1'b0;
  end
  else if (armed&CH1Trig&CH2Trig&CH3Trig&CH4Trig&CH5Trig&protTrig) begin
    ff_in = 1'b1;
  end else begin
    ff_in = ff_in;
  end
end

always_ff@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    triggered <= 1'b0;
  end else begin
   triggered <= ff_in;
  end
end
endmodule
