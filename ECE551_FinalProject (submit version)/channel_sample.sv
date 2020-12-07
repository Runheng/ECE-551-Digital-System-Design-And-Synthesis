module channel_sample(smpl_clk,CH_L,CH_H,clk,smpl,CH_Lff5,CH_Hff5);

input smpl_clk, clk, CH_L, CH_H;
output reg [7:0] smpl;
output reg CH_Lff5, CH_Hff5;

logic CH_Lff1, CH_Lff2, CH_Lff3, CH_Lff4;
logic CH_Hff1, CH_Hff2, CH_Hff3, CH_Hff4;

// double flop for meta-stability for both high and low bit
always_ff@(negedge smpl_clk)begin
  CH_Lff1 <= CH_L;
end
always_ff@(negedge smpl_clk)begin
  CH_Lff2 <= CH_Lff1;
end
always_ff@(negedge smpl_clk)begin
  CH_Hff1 <= CH_H;
end
always_ff@(negedge smpl_clk)begin
  CH_Hff2 <= CH_Hff1;
end

// the rest six flops are used to keep the prior three sets of data
always_ff@(negedge smpl_clk)begin
  CH_Lff3 <=CH_Lff2;
end
always_ff@(negedge smpl_clk)begin
  CH_Lff4 <=CH_Lff3;
end
always_ff@(negedge smpl_clk)begin
  CH_Lff5 <=CH_Lff4;
end
always_ff@(negedge smpl_clk)begin
  CH_Hff3 <=CH_Hff2;
end
always_ff@(negedge smpl_clk)begin
  CH_Hff4 <=CH_Hff3;
end
always_ff@(negedge smpl_clk)begin
  CH_Hff5 <=CH_Hff4;
end

// use another flop to store sample data[7:0]
always_ff@(posedge clk)begin
  smpl <= {CH_Hff2, CH_Lff2, CH_Hff3,CH_Lff3,CH_Hff4,CH_Lff4,CH_Hff5,CH_Lff5};
end

endmodule