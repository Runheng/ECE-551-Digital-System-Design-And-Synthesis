module dual_PWM(clk, rst_n, VIL, VIH, VIL_PWM, VIH_PWM);

input clk, rst_n;
input[7:0] VIL, VIH;
output VIL_PWM, VIH_PWM;

pwm8 high(.clk(clk), .rst_n(rst_n), .duty(VIH), .PWM_sig(VIH_PWM));
pwm8 low (.clk(clk), .rst_n(rst_n), .duty(VIL), .PWM_sig(VIL_PWM));

endmodule
