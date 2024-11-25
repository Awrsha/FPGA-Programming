// Attention Mechanism Hardware Accelerator
// Top level module

module attention_accelerator #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 12,
    parameter SEQ_LENGTH = 512,
    parameter HEAD_DIM = 64,
    parameter NUM_HEADS = 8
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] q_in,
    input wire [DATA_WIDTH-1:0] k_in, 
    input wire [DATA_WIDTH-1:0] v_in,
    input wire [ADDR_WIDTH-1:0] addr_in,
    output reg done,
    output reg [DATA_WIDTH-1:0] out_data,
    output reg [ADDR_WIDTH-1:0] out_addr
);

// Internal signals
reg [DATA_WIDTH-1:0] q_mem [0:SEQ_LENGTH-1][0:HEAD_DIM-1];
reg [DATA_WIDTH-1:0] k_mem [0:SEQ_LENGTH-1][0:HEAD_DIM-1];
reg [DATA_WIDTH-1:0] v_mem [0:SEQ_LENGTH-1][0:HEAD_DIM-1];
reg [DATA_WIDTH-1:0] scores [0:SEQ_LENGTH-1][0:SEQ_LENGTH-1];
reg [DATA_WIDTH-1:0] attention [0:SEQ_LENGTH-1][0:HEAD_DIM-1];

// FSM states
localparam IDLE = 3'd0;
localparam LOAD = 3'd1;
localparam COMPUTE_SCORES = 3'd2; 
localparam SOFTMAX = 3'd3;
localparam COMPUTE_ATTENTION = 3'd4;
localparam OUTPUT = 3'd5;

reg [2:0] state;
reg [2:0] next_state;

// Counters
reg [$clog2(SEQ_LENGTH)-1:0] seq_cnt;
reg [$clog2(HEAD_DIM)-1:0] dim_cnt;
reg [$clog2(NUM_HEADS)-1:0] head_cnt;

// Control signals
reg load_en;
reg compute_en;
reg output_en;

// Arithmetic units
reg [DATA_WIDTH-1:0] dot_product;
reg [DATA_WIDTH-1:0] scale_factor;
reg [DATA_WIDTH-1:0] softmax_sum;
reg [DATA_WIDTH-1:0] attention_sum;

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= IDLE;
    else 
        state <= next_state;
end

always @(*) begin
    case (state)
        IDLE: next_state = start ? LOAD : IDLE;
        LOAD: next_state = (seq_cnt == SEQ_LENGTH-1 && dim_cnt == HEAD_DIM-1) ? COMPUTE_SCORES : LOAD;
        COMPUTE_SCORES: next_state = (seq_cnt == SEQ_LENGTH-1) ? SOFTMAX : COMPUTE_SCORES;
        SOFTMAX: next_state = (seq_cnt == SEQ_LENGTH-1) ? COMPUTE_ATTENTION : SOFTMAX;
        COMPUTE_ATTENTION: next_state = (seq_cnt == SEQ_LENGTH-1 && dim_cnt == HEAD_DIM-1) ? OUTPUT : COMPUTE_ATTENTION;
        OUTPUT: next_state = (seq_cnt == SEQ_LENGTH-1) ? IDLE : OUTPUT;
        default: next_state = IDLE;
    endcase
end

// Memory load logic
always @(posedge clk) begin
    if (state == LOAD && load_en) begin
        q_mem[seq_cnt][dim_cnt] <= q_in;
        k_mem[seq_cnt][dim_cnt] <= k_in;
        v_mem[seq_cnt][dim_cnt] <= v_in;
    end
end

// Score computation
always @(posedge clk) begin
    if (state == COMPUTE_SCORES && compute_en) begin
        dot_product = 0;
        for (int i = 0; i < HEAD_DIM; i = i + 1) begin
            dot_product = dot_product + q_mem[seq_cnt][i] * k_mem[dim_cnt][i];
        end
        scores[seq_cnt][dim_cnt] <= dot_product / scale_factor;
    end
end

// Softmax implementation
always @(posedge clk) begin
    if (state == SOFTMAX) begin
        softmax_sum = 0;
        for (int i = 0; i < SEQ_LENGTH; i = i + 1) begin
            softmax_sum = softmax_sum + $exp(scores[seq_cnt][i]);
        end
        
        for (int i = 0; i < SEQ_LENGTH; i = i + 1) begin
            scores[seq_cnt][i] <= $exp(scores[seq_cnt][i]) / softmax_sum;
        end
    end
end

// Attention computation
always @(posedge clk) begin
    if (state == COMPUTE_ATTENTION && compute_en) begin
        attention_sum = 0;
        for (int i = 0; i < SEQ_LENGTH; i = i + 1) begin
            attention_sum = attention_sum + scores[seq_cnt][i] * v_mem[i][dim_cnt];
        end
        attention[seq_cnt][dim_cnt] <= attention_sum;
    end
end

// Output logic
always @(posedge clk) begin
    if (state == OUTPUT && output_en) begin
        out_data <= attention[seq_cnt][dim_cnt];
        out_addr <= {seq_cnt, dim_cnt};
        done <= (seq_cnt == SEQ_LENGTH-1 && dim_cnt == HEAD_DIM-1);
    end else begin
        done <= 0;
    end
end

// Counter logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        seq_cnt <= 0;
        dim_cnt <= 0;
        head_cnt <= 0;
    end else begin
        case (state)
            LOAD: begin
                if (dim_cnt == HEAD_DIM-1) begin
                    dim_cnt <= 0;
                    seq_cnt <= seq_cnt + 1;
                end else begin
                    dim_cnt <= dim_cnt + 1;
                end
            end
            
            COMPUTE_SCORES: begin
                if (dim_cnt == HEAD_DIM-1) begin
                    dim_cnt <= 0;
                    seq_cnt <= seq_cnt + 1;
                end else begin
                    dim_cnt <= dim_cnt + 1;
                end
            end
            
            SOFTMAX: begin
                seq_cnt <= seq_cnt + 1;
            end
            
            COMPUTE_ATTENTION: begin
                if (dim_cnt == HEAD_DIM-1) begin
                    dim_cnt <= 0;
                    seq_cnt <= seq_cnt + 1;
                end else begin
                    dim_cnt <= dim_cnt + 1;
                end
            end
            
            OUTPUT: begin
                if (dim_cnt == HEAD_DIM-1) begin
                    dim_cnt <= 0;
                    seq_cnt <= seq_cnt + 1;
                end else begin
                    dim_cnt <= dim_cnt + 1;
                end
            end
            
            default: begin
                seq_cnt <= 0;
                dim_cnt <= 0;
                head_cnt <= 0;
            end
        endcase
    end
end

// Control signal generation
always @(*) begin
    load_en = 0;
    compute_en = 0;
    output_en = 0;
    
    case (state)
        LOAD: load_en = 1;
        COMPUTE_SCORES: compute_en = 1;
        COMPUTE_ATTENTION: compute_en = 1;
        OUTPUT: output_en = 1;
        default: begin
            load_en = 0;
            compute_en = 0;
            output_en = 0;
        end
    endcase
end

// Scale factor initialization
initial begin
    scale_factor = $sqrt(HEAD_DIM);
end

endmodule

// Testbench
module attention_accelerator_tb;

parameter DATA_WIDTH = 32;
parameter ADDR_WIDTH = 12;
parameter SEQ_LENGTH = 512;
parameter HEAD_DIM = 64;
parameter NUM_HEADS = 8;

reg clk;
reg rst_n;
reg start;
reg [DATA_WIDTH-1:0] q_in;
reg [DATA_WIDTH-1:0] k_in;
reg [DATA_WIDTH-1:0] v_in;
reg [ADDR_WIDTH-1:0] addr_in;

wire done;
wire [DATA_WIDTH-1:0] out_data;
wire [ADDR_WIDTH-1:0] out_addr;

attention_accelerator #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .SEQ_LENGTH(SEQ_LENGTH),
    .HEAD_DIM(HEAD_DIM),
    .NUM_HEADS(NUM_HEADS)
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .q_in(q_in),
    .k_in(k_in),
    .v_in(v_in),
    .addr_in(addr_in),
    .done(done),
    .out_data(out_data),
    .out_addr(out_addr)
);

// Clock generation
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

// Test stimulus
initial begin
    // Reset
    rst_n = 0;
    start = 0;
    q_in = 0;
    k_in = 0;
    v_in = 0;
    addr_in = 0;
    
    #100;
    rst_n = 1;
    
    // Start processing
    start = 1;
    
    // Test input data
    for (int i = 0; i < SEQ_LENGTH; i = i + 1) begin
        for (int j = 0; j < HEAD_DIM; j = j + 1) begin
            q_in = $random;
            k_in = $random;
            v_in = $random;
            addr_in = {i[ADDR_WIDTH-1:0], j[ADDR_WIDTH-1:0]};
            #10;
        end
    end
    
    // Wait for completion
    wait(done);
    
    // Add verification checks here
    
    #1000;
    $finish;
end

// Monitor results
always @(posedge clk) begin
    if (done) begin
        $display("Output data: %h at address: %h", out_data, out_addr);
    end
end

// Optional waveform dumping
initial begin
    $dumpfile("attention_accelerator.vcd");
    $dumpvars(0, attention_accelerator_tb);
end

endmodule

// Memory module for matrix storage
module matrix_memory #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 12,
    parameter DEPTH = 512
)(
    input wire clk,
    input wire we,
    input wire [ADDR_WIDTH-1:0] addr,
    input wire [DATA_WIDTH-1:0] din,
    output reg [DATA_WIDTH-1:0] dout
);

reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

always @(posedge clk) begin
    if (we)
        mem[addr] <= din;
    dout <= mem[addr];
end

endmodule

// Floating point multiplier
module fp_multiplier #(
    parameter WIDTH = 32
)(
    input wire [WIDTH-1:0] a,
    input wire [WIDTH-1:0] b,
    output reg [WIDTH-1:0] result
);

// IEEE-754 fields
wire sign_a = a[WIDTH-1];
wire sign_b = b[WIDTH-1];
wire [7:0] exp_a = a[WIDTH-2:WIDTH-9];
wire [7:0] exp_b = b[WIDTH-2:WIDTH-9];
wire [22:0] mant_a = a[WIDTH-10:0];
wire [22:0] mant_b = b[WIDTH-10:0];

// Internal signals
wire sign_res = sign_a ^ sign_b;
wire [8:0] exp_res = exp_a + exp_b - 8'd127;
wire [47:0] mant_res = {1'b1,mant_a} * {1'b1,mant_b};

always @(*) begin
    // Normalize result
    if (mant_res[47])
        result = {sign_res, exp_res[7:0], mant_res[46:24]};
    else
        result = {sign_res, exp_res[7:0]-8'd1, mant_res[45:23]};
end

endmodule

// Floating point adder
module fp_adder #(
    parameter WIDTH = 32
)(
    input wire [WIDTH-1:0] a,
    input wire [WIDTH-1:0] b,
    output reg [WIDTH-1:0] result
);

// IEEE-754 fields
wire sign_a = a[WIDTH-1];
wire sign_b = b[WIDTH-1];
wire [7:0] exp_a = a[WIDTH-2:WIDTH-9];
wire [7:0] exp_b = b[WIDTH-2:WIDTH-9];
wire [22:0] mant_a = a[WIDTH-10:0];
wire [22:0] mant_b = b[WIDTH-10:0];

// Internal signals
wire [24:0] aligned_mant_a = {2'b01,mant_a};
wire [24:0] aligned_mant_b = {2'b01,mant_b};
wire [7:0] exp_diff = exp_a - exp_b;
wire [24:0] shifted_mant;
wire [24:0] sum_mant;
wire [7:0] final_exp;

always @(*) begin
    // Align mantissas
    if (exp_a > exp_b) begin
        shifted_mant = aligned_mant_b >> exp_diff;
        sum_mant = aligned_mant_a + shifted_mant;
        final_exp = exp_a;
    end else begin
        shifted_mant = aligned_mant_a >> (exp_b - exp_a);
        sum_mant = aligned_mant_b + shifted_mant;
        final_exp = exp_b;
    end
    
    // Normalize result
    if (sum_mant[24])
        result = {1'b0, final_exp + 8'd1, sum_mant[23:1]};
    else
        result = {1'b0, final_exp, sum_mant[22:0]};
end

endmodule