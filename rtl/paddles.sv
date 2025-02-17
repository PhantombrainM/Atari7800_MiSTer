// k7800 (c) by Jamie Blanks

// k7800 is licensed under a
// Creative Commons Attribution-NonCommercial 4.0 International License.

// You should have received a copy of the license along with this
// work. If not, see http://creativecommons.org/licenses/by-nc/4.0/.

module paddle_select
(
	input       clk,
	input [7:0] value,
	output      select
);
	logic [7:0] last_value;
	always_ff @(posedge clk) begin
		last_value <= value;
		if (last_value != value && (&value[7:6] || ~|value[7:6]))
			select <= 1;
		else
			select <= 0;
	end
endmodule

module paddle_chooser
(
	input   logic                   clk,            // System clock
	input   logic                   reset,          // Cold Reset
	input   logic   [3:0]           mask,           // Mask of enabled paddles
	input   logic                   enable0,        // Port 0 Enable
	input   logic                   enable1,        // Port 1 Enable
	
	input   logic   [24:0]          mouse,          // PS2 Mouse Input
	input   logic   [3:0][15:0]     analog,         // Analog stick for controller X
	input   logic   [3:0][7:0]      paddle,         // Spinner input X
	input   logic   [3:0]           buttons_in,
	
	output  logic   [3:0]           assigned,       // Momentary input assigned signal
	output  logic   [3:0][7:0]      pd_out,         // Paddle output data
	output  logic   [3:0][3:0]      paddle_type,    // Paddle output data type
	output  logic   [3:0]           paddle_but  // Paddle buttons
);

	// Determinations:
	// Mouse -- Button pressed
	// Spinner/Analog -- Movement to extremes
	
	logic [3:0] xs_assigned, ys_assigned, pdi_assigned, paddle_assigned, output_assigned;
	logic mouse_assigned;
	logic [1:0] types[4];
	logic [1:0] index[4];
	logic [3:0] analog_axis;
	logic mouse_button;
	logic [3:0][7:0] xs_unsigned;
	logic [3:0][7:0] ys_unsigned;
	logic [3:0] xs_select, ys_select, p_select;
	
	assign xs_unsigned[0] = {~analog[0][7], analog[0][6:0]};
	assign xs_unsigned[1] = {~analog[1][7], analog[1][6:0]};
	assign xs_unsigned[2] = {~analog[2][7], analog[2][6:0]};
	assign xs_unsigned[3] = {~analog[3][7], analog[3][6:0]};
	
	assign ys_unsigned[0] = {~analog[0][15], analog[0][14:8]};
	assign ys_unsigned[1] = {~analog[1][15], analog[1][14:8]};
	assign ys_unsigned[2] = {~analog[2][15], analog[2][14:8]};
	assign ys_unsigned[3] = {~analog[3][15], analog[3][14:8]};

	paddle_select pdjx0(clk, xs_unsigned[0], xs_select[0]);
	paddle_select pdjx1(clk, xs_unsigned[1], xs_select[1]);
	paddle_select pdjx2(clk, xs_unsigned[2], xs_select[2]);
	paddle_select pdjx3(clk, xs_unsigned[3], xs_select[3]);
	
	paddle_select pdjy0(clk, ys_unsigned[0], ys_select[0]);
	paddle_select pdjy1(clk, ys_unsigned[1], ys_select[1]);
	paddle_select pdjy2(clk, ys_unsigned[2], ys_select[2]);
	paddle_select pdjy3(clk, ys_unsigned[3], ys_select[3]);
	
	paddle_select pdp0(clk, paddle[0], p_select[0]);
	paddle_select pdp1(clk, paddle[1], p_select[1]);
	paddle_select pdp2(clk, paddle[2], p_select[2]);
	paddle_select pdp3(clk, paddle[3], p_select[3]);
	
	logic [3:0][15:0] old_analog;
	logic [3:0][7:0] old_paddle;
	logic old_stb;
	reg  signed [8:0] mx = 0;
	wire signed [8:0] mdx = {mouse[4],mouse[4],mouse[15:9]};
	wire signed [8:0] mdx2 = (mdx > 15) ? 9'd15 : (mdx < -15) ? -8'd15 : mdx;
	wire signed [8:0] nmx = mx + mdx2;
	
	assign mouse_button = mouse[0];

	always_comb begin
		paddle_but = 4'b0000;
		for (logic [2:0] x = 0; x < 3'd4; x = x + 2'd1) begin
			pd_out[x] = 8'd0;
			if (output_assigned[x]) begin
				case (paddle_type[x])
					0: begin pd_out[x] = ~paddle[index[x]]; paddle_but[x] = buttons_in[index[x]]; end
					1: begin pd_out[x] = ~(analog_axis[x] ? xs_unsigned[index[x]][7:0] : ys_unsigned[index[x]][7:0]); paddle_but[x] = buttons_in[index[x]]; end
					2: begin pd_out[x] = ~{~mx[7], mx[6:0]}; paddle_but[x] = mouse_button | ((~xs_assigned[0] & ~ys_assigned[0]) ? buttons_in[0] : 1'b0); end
					default: ;
				endcase
			end
		end
	end
	
	always @(posedge clk) begin
		reg current_assign;
		assigned <= '0;
		current_assign = 0; // NOTE: This is blocking!
		for (logic [2:0] y = 0; y < 3'd4; y = y + 2'd1) begin
			if (~output_assigned[y] && ((y==0 || ~mask[y[1:0]-1'd1]) ? 1'b1 : output_assigned[y[1:0]-1'd1]) && mask[y] && ~current_assign) begin
				for (logic [2:0] x = 0; x < 3'd4; x = x + 2'd1) begin
					if (xs_select[x] && ~xs_assigned[x]) begin
						assigned[y] <= 1;
						xs_assigned[x] <= 1;
						current_assign = 1;
						ys_assigned[x] <= 1;
						output_assigned[y] <= 1;
						paddle_type[y] <= 1;
						index[y] <= x[1:0];
						analog_axis[y] <= 1;
					end
				end
				for (logic [2:0] x = 0; x < 3'd4; x = x + 2'd1) begin
					if (ys_select[x] && ~ys_assigned[x]) begin
						assigned[y] <= 1;
						ys_assigned[x] <= 1;
						xs_assigned[x] <= 1;
						current_assign = 1;
						output_assigned[y] <= 1;
						paddle_type[y] <= 1;
						analog_axis[y] <= 0;
						index[y] <= x[1:0];
					end
				end
				for (logic [2:0] x = 0; x < 3'd4; x = x + 2'd1) begin
					if (p_select[x] && ~pdi_assigned[x]) begin
						assigned[y] <= 1;
						pdi_assigned[x] <= 1;
						current_assign = 1;
						output_assigned[y] <= 1;
						paddle_type[y] <= 0;
						index[y] <= x[1:0];
					end
				end
				if (~mouse_assigned && mouse_button) begin
					assigned[y] <= 1;
					mouse_assigned <= 1;
					current_assign = 1;
					output_assigned[y] <= 1;
					paddle_type[y] <= 2;
					index[y] <= 0;
				end
			end
		end
		old_stb <= mouse[24];
		if(old_stb != mouse[24]) begin
			mx <= (nmx < -128) ? -9'd128 : (nmx > 127) ? 9'd127 : nmx;
		end
	
		if (reset) begin
			mouse_assigned <= 0;
			assigned <= '0;
			index <= '{2'd0, 2'd0, 2'd0, 2'd0};
			pdi_assigned <= '0;
			xs_assigned <= '0;
			ys_assigned <= '0;
			output_assigned <= '0;
			paddle_type <= '0;
		end
	end
endmodule

module paddle_timer (
	input clk,
	input ce,
	input reset,
	input [9:0] kohms,
	input clear,
	input read,
	output charged,
	output logic [33:0] difference
);

// Note that this is in nanoseconds times 100.
parameter NS_PER_TICK = 33'd6984;

localparam CLEAR_NS = 33'd3352320;

logic [32:0] clear_count, high_count, lowest, highest;
// wire [32:0] paddle_timing[1024];
logic [1:0] read_count;
logic old_read;
wire read_measured = &read_count;
logic [32:0] width = 0;
logic cleared = 0;

always @(posedge clk) if (ce) begin
	old_read <= clear;
	if (~read_measured && (clear && ~old_read))
		read_count <= read_count + 1'd1;

	if (clear) begin
		if (clear_count < CLEAR_NS)
			clear_count <= clear_count + NS_PER_TICK;
		else begin
			cleared <= 1;
			high_count <= 0;
			charged <= 0;
		end
	end else begin
		clear_count <= 0;
		if (high_count < difference /*paddle_timing[kohms_big]*/) begin
			high_count <= high_count + NS_PER_TICK;
		end else begin
			charged <= 1;
		end

		if (cleared) begin
			if (read && highest < high_count)
				highest <= high_count;
			if (read && high_count < lowest) begin
				lowest <= high_count;
				highest <= '0; // Reset highest until lowest stabilizes.
				read_count <= 2'b00;
			end
			if (lowest < highest)
				width <= (highest - lowest);
		end
		difference <= ((lowest > highest) | ~read_measured ? 33'h114B6C376 : (lowest + (((width + {NS_PER_TICK, 1'b0}) >> 4'd8) * kohms[7:0])));

	end
	if (reset) begin
		cleared <= 0;
		width <= 0;
		read_count <= 0;
		lowest <= {33{1'b1}};
		highest <= '0;
		difference <= '0;
	end
end

// assign paddle_timing = '{
// 	33'h0005C136C, 33'h000A13B62, 33'h000E66358, 33'h0012B8B4E, 33'h00170B344, 33'h001B5DB3A, 33'h001FB0330, 33'h002402B26,
// 	33'h00285531C, 33'h002CA7B12, 33'h0030FA308, 33'h00354CAFE, 33'h00399F2F4, 33'h003DF1AEA, 33'h0042442E0, 33'h004696AD6,
// 	33'h004AE92CC, 33'h004F3BAC2, 33'h00538E2B8, 33'h0057E0AAE, 33'h005C332A4, 33'h006085A9A, 33'h0064D8290, 33'h00692AA86,
// 	33'h006D7D27C, 33'h0071CFA72, 33'h007622268, 33'h007A74A5E, 33'h007EC7254, 33'h008319A4A, 33'h00876C240, 33'h008BBEA36,
// 	33'h00901122C, 33'h009463A22, 33'h0098B6218, 33'h009D08A0E, 33'h00A15B204, 33'h00A5AD9FA, 33'h00AA001F0, 33'h00AE529E6,
// 	33'h00B2A51DC, 33'h00B6F79D2, 33'h00BB4A1C8, 33'h00BF9C9BE, 33'h00C3EF1B4, 33'h00C8419AA, 33'h00CC941A0, 33'h00D0E6996,
// 	33'h00D53918C, 33'h00D98B982, 33'h00DDDE178, 33'h00E23096E, 33'h00E683164, 33'h00EAD595A, 33'h00EF28150, 33'h00F37A946,
// 	33'h00F7CD13C, 33'h00FC1F932, 33'h010072128, 33'h0104C491E, 33'h010917114, 33'h010D6990A, 33'h0111BC100, 33'h01160E8F6,
// 	33'h011A610EC, 33'h011EB38E2, 33'h0123060D8, 33'h0127588CE, 33'h012BAB0C4, 33'h012FFD8BA, 33'h0134500B0, 33'h0138A28A6,
// 	33'h013CF509C, 33'h014147892, 33'h01459A088, 33'h0149EC87E, 33'h014E3F074, 33'h01529186A, 33'h0156E4060, 33'h015B36856,
// 	33'h015F8904C, 33'h0163DB842, 33'h01682E038, 33'h016C8082E, 33'h0170D3024, 33'h01752581A, 33'h017978010, 33'h017DCA806,
// 	33'h01821CFFC, 33'h01866F7F2, 33'h018AC1FE8, 33'h018F147DE, 33'h019366FD4, 33'h0197B97CA, 33'h019C0BFC0, 33'h01A05E7B6,
// 	33'h01A4B0FAC, 33'h01A9037A2, 33'h01AD55F98, 33'h01B1A878E, 33'h01B5FAF84, 33'h01BA4D77A, 33'h01BE9FF70, 33'h01C2F2766,
// 	33'h01C744F5C, 33'h01CB97752, 33'h01CFE9F48, 33'h01D43C73E, 33'h01D88EF34, 33'h01DCE172A, 33'h01E133F20, 33'h01E586716,
// 	33'h01E9D8F0C, 33'h01EE2B702, 33'h01F27DEF8, 33'h01F6D06EE, 33'h01FB22EE4, 33'h01FF756DA, 33'h0203C7ED0, 33'h02081A6C6,
// 	33'h020C6CEBC, 33'h0210BF6B2, 33'h021511EA8, 33'h02196469E, 33'h021DB6E94, 33'h02220968A, 33'h02265BE80, 33'h022AAE676,
// 	33'h022F00E6C, 33'h023353662, 33'h0237A5E58, 33'h023BF864E, 33'h02404AE44, 33'h02449D63A, 33'h0248EFE30, 33'h024D42626,
// 	33'h025194E1C, 33'h0255E7612, 33'h025A39E08, 33'h025E8C5FE, 33'h0262DEDF4, 33'h0267315EA, 33'h026B83DE0, 33'h026FD65D6,
// 	33'h027428DCC, 33'h02787B5C2, 33'h027CCDDB8, 33'h0281205AE, 33'h028572DA4, 33'h0289C559A, 33'h028E17D90, 33'h02926A586,
// 	33'h0296BCD7C, 33'h029B0F572, 33'h029F61D68, 33'h02A3B455E, 33'h02A806D54, 33'h02AC5954A, 33'h02B0ABD40, 33'h02B4FE536,
// 	33'h02B950D2C, 33'h02BDA3522, 33'h02C1F5D18, 33'h02C64850E, 33'h02CA9AD04, 33'h02CEED4FA, 33'h02D33FCF0, 33'h02D7924E6,
// 	33'h02DBE4CDC, 33'h02E0374D2, 33'h02E489CC8, 33'h02E8DC4BE, 33'h02ED2ECB4, 33'h02F1814AA, 33'h02F5D3CA0, 33'h02FA26496,
// 	33'h02FE78C8C, 33'h0302CB482, 33'h03071DC78, 33'h030B7046E, 33'h030FC2C64, 33'h03141545A, 33'h031867C50, 33'h031CBA446,
// 	33'h03210CC3C, 33'h03255F432, 33'h0329B1C28, 33'h032E0441E, 33'h033256C14, 33'h0336A940A, 33'h033AFBC00, 33'h033F4E3F6,
// 	33'h0343A0BEC, 33'h0347F33E2, 33'h034C45BD8, 33'h0350983CE, 33'h0354EABC4, 33'h03593D3BA, 33'h035D8FBB0, 33'h0361E23A6,
// 	33'h036634B9C, 33'h036A87392, 33'h036ED9B88, 33'h03732C37E, 33'h03777EB74, 33'h037BD136A, 33'h038023B60, 33'h038476356,
// 	33'h0388C8B4C, 33'h038D1B342, 33'h03916DB38, 33'h0395C032E, 33'h039A12B24, 33'h039E6531A, 33'h03A2B7B10, 33'h03A70A306,
// 	33'h03AB5CAFC, 33'h03AFAF2F2, 33'h03B401AE8, 33'h03B8542DE, 33'h03BCA6AD4, 33'h03C0F92CA, 33'h03C54BAC0, 33'h03C99E2B6,
// 	33'h03CDF0AAC, 33'h03D2432A2, 33'h03D695A98, 33'h03DAE828E, 33'h03DF3AA84, 33'h03E38D27A, 33'h03E7DFA70, 33'h03EC32266,
// 	33'h03F084A5C, 33'h03F4D7252, 33'h03F929A48, 33'h03FD7C23E, 33'h0401CEA34, 33'h04062122A, 33'h040A73A20, 33'h040EC6216,
// 	33'h041318A0C, 33'h04176B202, 33'h041BBD9F8, 33'h0420101EE, 33'h0424629E4, 33'h0428B51DA, 33'h042D079D0, 33'h04315A1C6,
// 	33'h0435AC9BC, 33'h0439FF1B2, 33'h043E519A8, 33'h0442A419E, 33'h0446F6994, 33'h044B4918A, 33'h044F9B980, 33'h0453EE176,
// 	33'h04584096C, 33'h045C93162, 33'h0460E5958, 33'h04653814E, 33'h04698A944, 33'h046DDD13A, 33'h04722F930, 33'h047682126,
// 	33'h047AD491C, 33'h047F27112, 33'h048379908, 33'h0487CC0FE, 33'h048C1E8F4, 33'h0490710EA, 33'h0494C38E0, 33'h0499160D6,
// 	33'h049D688CC, 33'h04A1BB0C2, 33'h04A60D8B8, 33'h04AA600AE, 33'h04AEB28A4, 33'h04B30509A, 33'h04B757890, 33'h04BBAA086,
// 	33'h04BFFC87C, 33'h04C44F072, 33'h04C8A1868, 33'h04CCF405E, 33'h04D146854, 33'h04D59904A, 33'h04D9EB840, 33'h04DE3E036,
// 	33'h04E29082C, 33'h04E6E3022, 33'h04EB35818, 33'h04EF8800E, 33'h04F3DA804, 33'h04F82CFFA, 33'h04FC7F7F0, 33'h0500D1FE6,
// 	33'h0505247DC, 33'h050976FD2, 33'h050DC97C8, 33'h05121BFBE, 33'h05166E7B4, 33'h051AC0FAA, 33'h051F137A0, 33'h052365F96,
// 	33'h0527B878C, 33'h052C0AF82, 33'h05305D778, 33'h0534AFF6E, 33'h053902764, 33'h053D54F5A, 33'h0541A7750, 33'h0545F9F46,
// 	33'h054A4C73C, 33'h054E9EF32, 33'h0552F1728, 33'h055743F1E, 33'h055B96714, 33'h055FE8F0A, 33'h05643B700, 33'h05688DEF6,
// 	33'h056CE06EC, 33'h057132EE2, 33'h0575856D8, 33'h0579D7ECE, 33'h057E2A6C4, 33'h05827CEBA, 33'h0586CF6B0, 33'h058B21EA6,
// 	33'h058F7469C, 33'h0593C6E92, 33'h059819688, 33'h059C6BE7E, 33'h05A0BE674, 33'h05A510E6A, 33'h05A963660, 33'h05ADB5E56,
// 	33'h05B20864C, 33'h05B65AE42, 33'h05BAAD638, 33'h05BEFFE2E, 33'h05C352624, 33'h05C7A4E1A, 33'h05CBF7610, 33'h05D049E06,
// 	33'h05D49C5FC, 33'h05D8EEDF2, 33'h05DD415E8, 33'h05E193DDE, 33'h05E5E65D4, 33'h05EA38DCA, 33'h05EE8B5C0, 33'h05F2DDDB6,
// 	33'h05F7305AC, 33'h05FB82DA2, 33'h05FFD5598, 33'h060427D8E, 33'h06087A584, 33'h060CCCD7A, 33'h06111F570, 33'h061571D66,
// 	33'h0619C455C, 33'h061E16D52, 33'h062269548, 33'h0626BBD3E, 33'h062B0E534, 33'h062F60D2A, 33'h0633B3520, 33'h063805D16,
// 	33'h063C5850C, 33'h0640AAD02, 33'h0644FD4F8, 33'h06494FCEE, 33'h064DA24E4, 33'h0651F4CDA, 33'h0656474D0, 33'h065A99CC6,
// 	33'h065EEC4BC, 33'h06633ECB2, 33'h0667914A8, 33'h066BE3C9E, 33'h067036494, 33'h067488C8A, 33'h0678DB480, 33'h067D2DC76,
// 	33'h06818046C, 33'h0685D2C62, 33'h068A25458, 33'h068E77C4E, 33'h0692CA444, 33'h06971CC3A, 33'h069B6F430, 33'h069FC1C26,
// 	33'h06A41441C, 33'h06A866C12, 33'h06ACB9408, 33'h06B10BBFE, 33'h06B55E3F4, 33'h06B9B0BEA, 33'h06BE033E0, 33'h06C255BD6,
// 	33'h06C6A83CC, 33'h06CAFABC2, 33'h06CF4D3B8, 33'h06D39FBAE, 33'h06D7F23A4, 33'h06DC44B9A, 33'h06E097390, 33'h06E4E9B86,
// 	33'h06E93C37C, 33'h06ED8EB72, 33'h06F1E1368, 33'h06F633B5E, 33'h06FA86354, 33'h06FED8B4A, 33'h07032B340, 33'h07077DB36,
// 	33'h070BD032C, 33'h071022B22, 33'h071475318, 33'h0718C7B0E, 33'h071D1A304, 33'h07216CAFA, 33'h0725BF2F0, 33'h072A11AE6,
// 	33'h072E642DC, 33'h0732B6AD2, 33'h0737092C8, 33'h073B5BABE, 33'h073FAE2B4, 33'h074400AAA, 33'h0748532A0, 33'h074CA5A96,
// 	33'h0750F828C, 33'h07554AA82, 33'h07599D278, 33'h075DEFA6E, 33'h076242264, 33'h076694A5A, 33'h076AE7250, 33'h076F39A46,
// 	33'h07738C23C, 33'h0777DEA32, 33'h077C31228, 33'h078083A1E, 33'h0784D6214, 33'h078928A0A, 33'h078D7B200, 33'h0791CD9F6,
// 	33'h0796201EC, 33'h079A729E2, 33'h079EC51D8, 33'h07A3179CE, 33'h07A76A1C4, 33'h07ABBC9BA, 33'h07B00F1B0, 33'h07B4619A6,
// 	33'h07B8B419C, 33'h07BD06992, 33'h07C159188, 33'h07C5AB97E, 33'h07C9FE174, 33'h07CE5096A, 33'h07D2A3160, 33'h07D6F5956,
// 	33'h07DB4814C, 33'h07DF9A942, 33'h07E3ED138, 33'h07E83F92E, 33'h07EC92124, 33'h07F0E491A, 33'h07F537110, 33'h07F989906,
// 	33'h07FDDC0FC, 33'h08022E8F2, 33'h0806810E8, 33'h080AD38DE, 33'h080F260D4, 33'h0813788CA, 33'h0817CB0C0, 33'h081C1D8B6,
// 	33'h0820700AC, 33'h0824C28A2, 33'h082915098, 33'h082D6788E, 33'h0831BA084, 33'h08360C87A, 33'h083A5F070, 33'h083EB1866,
// 	33'h08430405C, 33'h084756852, 33'h084BA9048, 33'h084FFB83E, 33'h08544E034, 33'h0858A082A, 33'h085CF3020, 33'h086145816,
// 	33'h08659800C, 33'h0869EA802, 33'h086E3CFF8, 33'h08728F7EE, 33'h0876E1FE4, 33'h087B347DA, 33'h087F86FD0, 33'h0883D97C6,
// 	33'h08882BFBC, 33'h088C7E7B2, 33'h0890D0FA8, 33'h08952379E, 33'h089975F94, 33'h089DC878A, 33'h08A21AF80, 33'h08A66D776,
// 	33'h08AABFF6C, 33'h08AF12762, 33'h08B364F58, 33'h08B7B774E, 33'h08BC09F44, 33'h08C05C73A, 33'h08C4AEF30, 33'h08C901726,
// 	33'h08CD53F1C, 33'h08D1A6712, 33'h08D5F8F08, 33'h08DA4B6FE, 33'h08DE9DEF4, 33'h08E2F06EA, 33'h08E742EE0, 33'h08EB956D6,
// 	33'h08EFE7ECC, 33'h08F43A6C2, 33'h08F88CEB8, 33'h08FCDF6AE, 33'h090131EA4, 33'h09058469A, 33'h0909D6E90, 33'h090E29686,
// 	33'h09127BE7C, 33'h0916CE672, 33'h091B20E68, 33'h091F7365E, 33'h0923C5E54, 33'h09281864A, 33'h092C6AE40, 33'h0930BD636,
// 	33'h09350FE2C, 33'h093962622, 33'h093DB4E18, 33'h09420760E, 33'h094659E04, 33'h094AAC5FA, 33'h094EFEDF0, 33'h0953515E6,
// 	33'h0957A3DDC, 33'h095BF65D2, 33'h096048DC8, 33'h09649B5BE, 33'h0968EDDB4, 33'h096D405AA, 33'h097192DA0, 33'h0975E5596,
// 	33'h097A37D8C, 33'h097E8A582, 33'h0982DCD78, 33'h09872F56E, 33'h098B81D64, 33'h098FD455A, 33'h099426D50, 33'h099879546,
// 	33'h099CCBD3C, 33'h09A11E532, 33'h09A570D28, 33'h09A9C351E, 33'h09AE15D14, 33'h09B26850A, 33'h09B6BAD00, 33'h09BB0D4F6,
// 	33'h09BF5FCEC, 33'h09C3B24E2, 33'h09C804CD8, 33'h09CC574CE, 33'h09D0A9CC4, 33'h09D4FC4BA, 33'h09D94ECB0, 33'h09DDA14A6,
// 	33'h09E1F3C9C, 33'h09E646492, 33'h09EA98C88, 33'h09EEEB47E, 33'h09F33DC74, 33'h09F79046A, 33'h09FBE2C60, 33'h0A0035456, 
// 	33'h0A0487C4C, 33'h0A08DA442, 33'h0A0D2CC38, 33'h0A117F42E, 33'h0A15D1C24, 33'h0A1A2441A, 33'h0A1E76C10, 33'h0A22C9406,
// 	33'h0A271BBFC, 33'h0A2B6E3F2, 33'h0A2FC0BE8, 33'h0A34133DE, 33'h0A3865BD4, 33'h0A3CB83CA, 33'h0A410ABC0, 33'h0A455D3B6,
// 	33'h0A49AFBAC, 33'h0A4E023A2, 33'h0A5254B98, 33'h0A56A738E, 33'h0A5AF9B84, 33'h0A5F4C37A, 33'h0A639EB70, 33'h0A67F1366,
// 	33'h0A6C43B5C, 33'h0A7096352, 33'h0A74E8B48, 33'h0A793B33E, 33'h0A7D8DB34, 33'h0A81E032A, 33'h0A8632B20, 33'h0A8A85316,
// 	33'h0A8ED7B0C, 33'h0A932A302, 33'h0A977CAF8, 33'h0A9BCF2EE, 33'h0AA021AE4, 33'h0AA4742DA, 33'h0AA8C6AD0, 33'h0AAD192C6,
// 	33'h0AB16BABC, 33'h0AB5BE2B2, 33'h0ABA10AA8, 33'h0ABE6329E, 33'h0AC2B5A94, 33'h0AC70828A, 33'h0ACB5AA80, 33'h0ACFAD276,
// 	33'h0AD3FFA6C, 33'h0AD852262, 33'h0ADCA4A58, 33'h0AE0F724E, 33'h0AE549A44, 33'h0AE99C23A, 33'h0AEDEEA30, 33'h0AF241226,
// 	33'h0AF693A1C, 33'h0AFAE6212, 33'h0AFF38A08, 33'h0B038B1FE, 33'h0B07DD9F4, 33'h0B0C301EA, 33'h0B10829E0, 33'h0B14D51D6,
// 	33'h0B19279CC, 33'h0B1D7A1C2, 33'h0B21CC9B8, 33'h0B261F1AE, 33'h0B2A719A4, 33'h0B2EC419A, 33'h0B3316990, 33'h0B3769186,
// 	33'h0B3BBB97C, 33'h0B400E172, 33'h0B4460968, 33'h0B48B315E, 33'h0B4D05954, 33'h0B515814A, 33'h0B55AA940, 33'h0B59FD136,
// 	33'h0B5E4F92C, 33'h0B62A2122, 33'h0B66F4918, 33'h0B6B4710E, 33'h0B6F99904, 33'h0B73EC0FA, 33'h0B783E8F0, 33'h0B7C910E6,
// 	33'h0B80E38DC, 33'h0B85360D2, 33'h0B89888C8, 33'h0B8DDB0BE, 33'h0B922D8B4, 33'h0B96800AA, 33'h0B9AD28A0, 33'h0B9F25096,
// 	33'h0BA37788C, 33'h0BA7CA082, 33'h0BAC1C878, 33'h0BB06F06E, 33'h0BB4C1864, 33'h0BB91405A, 33'h0BBD66850, 33'h0BC1B9046,
// 	33'h0BC60B83C, 33'h0BCA5E032, 33'h0BCEB0828, 33'h0BD30301E, 33'h0BD755814, 33'h0BDBA800A, 33'h0BDFFA800, 33'h0BE44CFF6,
// 	33'h0BE89F7EC, 33'h0BECF1FE2, 33'h0BF1447D8, 33'h0BF596FCE, 33'h0BF9E97C4, 33'h0BFE3BFBA, 33'h0C028E7B0, 33'h0C06E0FA6,
// 	33'h0C0B3379C, 33'h0C0F85F92, 33'h0C13D8788, 33'h0C182AF7E, 33'h0C1C7D774, 33'h0C20CFF6A, 33'h0C2522760, 33'h0C2974F56,
// 	33'h0C2DC774C, 33'h0C3219F42, 33'h0C366C738, 33'h0C3ABEF2E, 33'h0C3F11724, 33'h0C4363F1A, 33'h0C47B6710, 33'h0C4C08F06,
// 	33'h0C505B6FC, 33'h0C54ADEF2, 33'h0C59006E8, 33'h0C5D52EDE, 33'h0C61A56D4, 33'h0C65F7ECA, 33'h0C6A4A6C0, 33'h0C6E9CEB6,
// 	33'h0C72EF6AC, 33'h0C7741EA2, 33'h0C7B94698, 33'h0C7FE6E8E, 33'h0C8439684, 33'h0C888BE7A, 33'h0C8CDE670, 33'h0C9130E66,
// 	33'h0C958365C, 33'h0C99D5E52, 33'h0C9E28648, 33'h0CA27AE3E, 33'h0CA6CD634, 33'h0CAB1FE2A, 33'h0CAF72620, 33'h0CB3C4E16,
// 	33'h0CB81760C, 33'h0CBC69E02, 33'h0CC0BC5F8, 33'h0CC50EDEE, 33'h0CC9615E4, 33'h0CCDB3DDA, 33'h0CD2065D0, 33'h0CD658DC6,
// 	33'h0CDAAB5BC, 33'h0CDEFDDB2, 33'h0CE3505A8, 33'h0CE7A2D9E, 33'h0CEBF5594, 33'h0CF047D8A, 33'h0CF49A580, 33'h0CF8ECD76,
// 	33'h0CFD3F56C, 33'h0D0191D62, 33'h0D05E4558, 33'h0D0A36D4E, 33'h0D0E89544, 33'h0D12DBD3A, 33'h0D172E530, 33'h0D1B80D26,
// 	33'h0D1FD351C, 33'h0D2425D12, 33'h0D2878508, 33'h0D2CCACFE, 33'h0D311D4F4, 33'h0D356FCEA, 33'h0D39C24E0, 33'h0D3E14CD6,
// 	33'h0D42674CC, 33'h0D46B9CC2, 33'h0D4B0C4B8, 33'h0D4F5ECAE, 33'h0D53B14A4, 33'h0D5803C9A, 33'h0D5C56490, 33'h0D60A8C86,
// 	33'h0D64FB47C, 33'h0D694DC72, 33'h0D6DA0468, 33'h0D71F2C5E, 33'h0D7645454, 33'h0D7A97C4A, 33'h0D7EEA440, 33'h0D833CC36,
// 	33'h0D878F42C, 33'h0D8BE1C22, 33'h0D9034418, 33'h0D9486C0E, 33'h0D98D9404, 33'h0D9D2BBFA, 33'h0DA17E3F0, 33'h0DA5D0BE6,
// 	33'h0DAA233DC, 33'h0DAE75BD2, 33'h0DB2C83C8, 33'h0DB71ABBE, 33'h0DBB6D3B4, 33'h0DBFBFBAA, 33'h0DC4123A0, 33'h0DC864B96,
// 	33'h0DCCB738C, 33'h0DD109B82, 33'h0DD55C378, 33'h0DD9AEB6E, 33'h0DDE01364, 33'h0DE253B5A, 33'h0DE6A6350, 33'h0DEAF8B46,
// 	33'h0DEF4B33C, 33'h0DF39DB32, 33'h0DF7F0328, 33'h0DFC42B1E, 33'h0E0095314, 33'h0E04E7B0A, 33'h0E093A300, 33'h0E0D8CAF6,
// 	33'h0E11DF2EC, 33'h0E1631AE2, 33'h0E1A842D8, 33'h0E1ED6ACE, 33'h0E23292C4, 33'h0E277BABA, 33'h0E2BCE2B0, 33'h0E3020AA6,
// 	33'h0E347329C, 33'h0E38C5A92, 33'h0E3D18288, 33'h0E416AA7E, 33'h0E45BD274, 33'h0E4A0FA6A, 33'h0E4E62260, 33'h0E52B4A56,
// 	33'h0E570724C, 33'h0E5B59A42, 33'h0E5FAC238, 33'h0E63FEA2E, 33'h0E6851224, 33'h0E6CA3A1A, 33'h0E70F6210, 33'h0E7548A06,
// 	33'h0E799B1FC, 33'h0E7DED9F2, 33'h0E82401E8, 33'h0E86929DE, 33'h0E8AE51D4, 33'h0E8F379CA, 33'h0E938A1C0, 33'h0E97DC9B6,
// 	33'h0E9C2F1AC, 33'h0EA0819A2, 33'h0EA4D4198, 33'h0EA92698E, 33'h0EAD79184, 33'h0EB1CB97A, 33'h0EB61E170, 33'h0EBA70966,
// 	33'h0EBEC315C, 33'h0EC315952, 33'h0EC768148, 33'h0ECBBA93E, 33'h0ED00D134, 33'h0ED45F92A, 33'h0ED8B2120, 33'h0EDD04916,
// 	33'h0EE15710C, 33'h0EE5A9902, 33'h0EE9FC0F8, 33'h0EEE4E8EE, 33'h0EF2A10E4, 33'h0EF6F38DA, 33'h0EFB460D0, 33'h0EFF988C6,
// 	33'h0F03EB0BC, 33'h0F083D8B2, 33'h0F0C900A8, 33'h0F10E289E, 33'h0F1535094, 33'h0F198788A, 33'h0F1DDA080, 33'h0F222C876,
// 	33'h0F267F06C, 33'h0F2AD1862, 33'h0F2F24058, 33'h0F337684E, 33'h0F37C9044, 33'h0F3C1B83A, 33'h0F406E030, 33'h0F44C0826,
// 	33'h0F491301C, 33'h0F4D65812, 33'h0F51B8008, 33'h0F560A7FE, 33'h0F5A5CFF4, 33'h0F5EAF7EA, 33'h0F6301FE0, 33'h0F67547D6,
// 	33'h0F6BA6FCC, 33'h0F6FF97C2, 33'h0F744BFB8, 33'h0F789E7AE, 33'h0F7CF0FA4, 33'h0F814379A, 33'h0F8595F90, 33'h0F89E8786,
// 	33'h0F8E3AF7C, 33'h0F928D772, 33'h0F96DFF68, 33'h0F9B3275E, 33'h0F9F84F54, 33'h0FA3D774A, 33'h0FA829F40, 33'h0FAC7C736,
// 	33'h0FB0CEF2C, 33'h0FB521722, 33'h0FB973F18, 33'h0FBDC670E, 33'h0FC218F04, 33'h0FC66B6FA, 33'h0FCABDEF0, 33'h0FCF106E6,
// 	33'h0FD362EDC, 33'h0FD7B56D2, 33'h0FDC07EC8, 33'h0FE05A6BE, 33'h0FE4ACEB4, 33'h0FE8FF6AA, 33'h0FED51EA0, 33'h0FF1A4696,
// 	33'h0FF5F6E8C, 33'h0FFA49682, 33'h0FFE9BE78, 33'h1002EE66E, 33'h100740E64, 33'h100B9365A, 33'h100FE5E50, 33'h101438646,
// 	33'h10188AE3C, 33'h101CDD632, 33'h10212FE28, 33'h10258261E, 33'h1029D4E14, 33'h102E2760A, 33'h103279E00, 33'h1036CC5F6,
// 	33'h103B1EDEC, 33'h103F715E2, 33'h1043C3DD8, 33'h1048165CE, 33'h104C68DC4, 33'h1050BB5BA, 33'h10550DDB0, 33'h1059605A6,
// 	33'h105DB2D9C, 33'h106205592, 33'h106657D88, 33'h106AAA57E, 33'h106EFCD74, 33'h10734F56A, 33'h1077A1D60, 33'h107BF4556,
// 	33'h108046D4C, 33'h108499542, 33'h1088EBD38, 33'h108D3E52E, 33'h109190D24, 33'h1095E351A, 33'h109A35D10, 33'h109E88506,
// 	33'h10A2DACFC, 33'h10A72D4F2, 33'h10AB7FCE8, 33'h10AFD24DE, 33'h10B424CD4, 33'h10B8774CA, 33'h10BCC9CC0, 33'h10C11C4B6,
// 	33'h10C56ECAC, 33'h10C9C14A2, 33'h10CE13C98, 33'h10D26648E, 33'h10D6B8C84, 33'h10DB0B47A, 33'h10DF5DC70, 33'h10E3B0466,
// 	33'h10E802C5C, 33'h10EC55452, 33'h10F0A7C48, 33'h10F4FA43E, 33'h10F94CC34, 33'h10FD9F42A, 33'h1101F1C20, 33'h110644416,
// 	33'h110A96C0C, 33'h110EE9402, 33'h11133BBF8, 33'h11178E3EE, 33'h111BE0BE4, 33'h1120333DA, 33'h112485BD0, 33'h1128D83C6,
// 	33'h112D2ABBC, 33'h11317D3B2, 33'h1135CFBA8, 33'h113A2239E, 33'h113E74B94, 33'h1142C738A, 33'h114719B80, 33'h114B6C376
// };

endmodule