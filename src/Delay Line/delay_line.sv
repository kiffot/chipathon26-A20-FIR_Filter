module delay_line (
    input  logic clk,
    input  logic rst_n,
    
    //datapath part
    input  logic [15:0] data_in, //input sample
    output logic [17:0] pre_adder_out, //output from pre-adder

    //controlpath part
    input  logic        shift_en,
    input  logic [3:0]  sel, //for MUX selector
    
    //controlpath mode part
    input  logic        mode_odd, //1:odd, 0:even
    input  logic        mode_asym //1:Asy, 0:sym
);

    //SIPO processing 16x16, 16x1, 16x15
    logic [15:0] sipo_top [1:16]; //Taps 31-16
    logic [15:0] sipo_mid; //Center tap
    logic [15:0] sipo_bot [1:15]; // Taps 15-1

    //SIPO shifting (Shift Register)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i=1; i<=16; i++) sipo_top[i]<=16'd0;
            sipo_mid<=16'd0;
            for (int i=1; i<=15; i++) sipo_bot[i]<=16'd0;
        end
        else if (shift_en) begin
            //Shift top (16x16)
            sipo_top[1]<=data_in;
            for (int i=2; i<=16; i++) sipo_top[i]<=sipo_top[i-1];
            
            //Shift mid (16x1)
            sipo_mid <= sipo_top[16];

            //Shift bottom (16x15)
            if (mode_odd==1'b1) begin
                sipo_bot[1]<=sipo_mid; //if odd, take from mid
            end else begin
                sipo_bot[1]<=sipo_top[16]; //if even, straight from top
            end
            
            //shifting for bottom
            for (int i=2; i<=15; i++) sipo_bot[i]<=sipo_bot[i-1];
        end
    end

    //16:1 multiplexer logic part
    logic [15:0] mux_top;
    logic [15:0] mux_bot;
    logic [15:0] mux_bot_routed;

    always_comb begin
        //top mux (Taps 31-16)
        mux_top=sipo_top[16-sel]; 

        //bottom mux (Taps 15-1 dan data_in)
        if (sel==4'd15) begin
            mux_bot=data_in;
        end else begin
            mux_bot=sipo_bot[15-sel];
        end
        
        //'0' for odd mode
        if (mode_odd==1'b1 && sel==4'd15) begin
            mux_bot_routed=16'd0;
        end else begin
            mux_bot_routed=mux_bot;
        end
    end

    //assymetric logic using XOR and 2's Complement
    logic [15:0] bot_xor;
    
    always_comb begin
        if (mode_asym==1'b1) begin
            bot_xor=~mux_bot_routed; //asymmetric mode
        end else begin
            bot_xor=mux_bot_routed;  //symmetric mode
        end
    end

    //pre-adder process part 
    assign pre_adder_out = {mux_top[15], mux_top[15], mux_top}+{bot_xor[15], bot_xor[15], bot_xor}+mode_asym; 
endmodule