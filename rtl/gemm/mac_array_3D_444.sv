module mac_array_3D_444#(
    parameter int unsigned InDataWidth = 8,
    parameter int unsigned OutDataWidth = 32,
    parameter int unsigned meshRow = 4,
    parameter int unsigned meshCol = 4,
    parameter int unsigned tileSize = 4
)(
    //clock and reset
    input logic clk_i,
    input  logic rst_ni,
    //input operands
    input  logic signed [meshRow-1:0][tileSize-1:0][InDataWidth-1:0] a_i,//[rows][length of vector]
    input  logic signed [meshCol-1:0][tileSize-1:0][InDataWidth-1:0] b_i,//[columns][length of vector]
    //valid signals for inputs
    input  logic a_valid_i,
    input  logic b_valid_i,
    input  logic init_save_i,
    //clear signal for output
    input  logic acc_clr_i,
    //output accumulation
    output logic signed [meshRow-1:0][meshCol-1:0][OutDataWidth-1:0] c_o
);


    //general mac initialization
    genvar i, j;
    generate 
        for(i = 0; i < meshRow; i++ )begin : gen_rows
            for(j = 0; j < meshCol; j++)begin : gen_cols
                general_mac_pe #(
                    .InDataWidth  ( InDataWidth  ),
                    .NumInputs    ( tileSize     ),
                    .OutDataWidth ( OutDataWidth )
                ) mac_pe_inst (
                    .clk_i        ( clk_i                        ),
                    .rst_ni       ( rst_ni                       ),
                    .a_i          ( a_i[i]                       ),
                    .b_i          ( b_i[j]                       ),
                    .a_valid_i    ( a_valid_i                    ),
                    .b_valid_i    ( b_valid_i                    ),
                    .init_save_i  ( init_save_i                  ),
                    .acc_clr_i    ( acc_clr_i                    ),
                    .c_o          ( c_o[i][j]                    )
                );
            end
        end
    endgenerate

endmodule