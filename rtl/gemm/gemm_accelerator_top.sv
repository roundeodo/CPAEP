//---------------------------
// The 64-MAC GeMM accelerator top module
//
// Description:
// This module implements a simple General Matrix-Matrix Multiplication (GeMM)
// accelerator using a 64 Multiply-Accumulate (MAC) Processing Elements (PEs).
// It interfaces with three SRAMs for input matrices A and B, and output matrix C.
//
// It includes a controller to manage the GeMM operation and address generation logic
// for accessing the SRAMs based on the current matrix sizes and counters.
//
// Parameters:
// - InDataWidth  : Width of the input data (matrix elements).
// - OutDataWidth : Width of the output data (result matrix elements).
// - AddrWidth    : Width of the address bus for SRAMs.
// - SizeAddrWidth: Width of the size parameters for matrices.
//
// Ports:
// - clk_i        : Clock input.
// - rst_ni       : Active-low reset input.
// - start_i      : Start signal to initiate the GeMM operation.
// - M_size_i     : block nums of matrix M (number of M_blocks in A and C).
// - K_size_i     : block nums of matrix K (number of K_blocks in A and B).
// - N_size_i     : block nums of matrix N (number of N_blocks in B and C).
// - sram_a_addr_o: Address output for SRAM A.
// - sram_b_addr_o: Address output for SRAM B.
// - sram_c_addr_o: Address output for SRAM C.
// - sram_a_rdata_i: Data input from SRAM A.
// - sram_b_rdata_i: Data input from SRAM B.
// - sram_c_wdata_o: Data output to SRAM C.
// - sram_c_we_o  : Write enable output for SRAM C.
// - done_o       : Done signal indicating completion of the GeMM operation.
//---------------------------

module gemm_accelerator_top #(
  parameter int unsigned InDataWidth = 8,
  parameter int unsigned OutDataWidth = 32,
  parameter int unsigned AddrWidth = 16,
  parameter int unsigned SizeAddrWidth = 8,
  parameter int unsigned meshRow = 2,
  parameter int unsigned meshCol = 2,
  parameter int unsigned tileSize = 16
) (
  input  logic                            clk_i,
  input  logic                            rst_ni,
  input  logic                            start_i,

  input  logic        [SizeAddrWidth-1:0] M_size_i,
  input  logic        [SizeAddrWidth-1:0] K_size_i,
  input  logic        [SizeAddrWidth-1:0] N_size_i,

  output logic        [    AddrWidth-1:0] sram_a_addr_o,
  output logic        [    AddrWidth-1:0] sram_b_addr_o,
  output logic        [    AddrWidth-1:0] sram_c_addr_o,

  input  logic signed [  meshRow * tileSize * InDataWidth-1:0] sram_a_rdata_i,
  input  logic signed [  meshCol * tileSize * InDataWidth-1:0] sram_b_rdata_i,

  output logic signed [ meshRow * meshCol * OutDataWidth-1:0] sram_c_wdata_o,

  output logic                            sram_c_we_o,
  output logic                            done_o
);

  //---------------------------
  // Wires
  //---------------------------
  logic [SizeAddrWidth-1:0] M_count;
  logic [SizeAddrWidth-1:0] K_count;
  logic [SizeAddrWidth-1:0] N_count;
  logic [SizeAddrWidth-1:0] M_count_write;
  logic [SizeAddrWidth-1:0] N_count_write;

  logic busy;
  logic valid_data;
  assign valid_data = start_i || busy;  // Always valid in this simple design

  logic init_save_ctrl; //from controller to mac array
  logic result_valid_ctrl; //from controller to WE logic
  assign sram_c_we_o = result_valid_ctrl;
  //---------------------------
  // DESIGN NOTE:
  // This is a simple GeMM accelerator design using a 64 MAC PE.
  // The controller manages just the counting capabilities.
  // Check the gemm_controller.sv file for more details.
  //
  // Essentially, it tightly couples the counters and an FSM together.
  // The address generation logic is just after this controller.
  //
  // You have the option to combine the address generation and controller
  // all in one module if you prefer. We did this intentionally to separate tasks.
  //---------------------------

  // Main GeMM controller
  gemm_controller #(
    .AddrWidth      ( SizeAddrWidth )
  ) i_gemm_controller (
    .clk_i          ( clk_i       ),
    .rst_ni         ( rst_ni      ),
    .start_i        ( start_i     ),
    .input_valid_i  ( 1'b1        ),  // Always valid in this simple design
    .init_save_o    ( init_save_ctrl ),
    .result_valid_o ( result_valid_ctrl ),
    .busy_o         ( busy        ),
    .done_o         ( done_o      ),
    //the block size of M, K, N
    .M_size_i       ( M_size_i    ),
    .K_size_i       ( K_size_i    ),
    .N_size_i       ( N_size_i    ),
    //the block indices of M, K, N
    .M_count_o      ( M_count     ),
    .K_count_o      ( K_count     ),
    .N_count_o      ( N_count     ),
    .M_count_write_o( M_count_write),
    .N_count_write_o( N_count_write)
  );

  //---------------------------
  // DESIGN NOTE:
  // This part is the address generation logic for the input and output SRAMs.
  // A B C are in block-base layout
  //formula:
  // global_block_index = outer_count * total_inner_blocks + inner_count

  //---------------------------

  // Input addresses for matrices A and B
  // matrix A: row major of blocks [M_block][K_block]
  //  address_A = M_count * K_size_i + K_count
  assign sram_a_addr_o = (M_count * K_size_i + K_count);
  
  // matrix B: column major of blocks [N_block][K_block]
  //  address_B = N_count * K_size_i + K_count
  assign sram_b_addr_o = (N_count * K_size_i + K_count);

  // matrix C :row-major of blocks [M_block][N_block]
  //  address_C = M_count * N_size_i + N_count
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      sram_c_addr_o <= '0;
    end else if (1'b1) begin  // Always valid in this simple design
      sram_c_addr_o <= (M_count * N_size_i + N_count);
    end
  end
  //assign sram_c_addr_o = (M_count_write * N_size_i + N_count_write);


  //---------------------------
  // DESIGN NOTE:
  // This part is the MAC PE instantiation and data path logic.
  // However, you can expand this part to support multiple PEs
  // by adjusting the data widths and input/output connections accordingly.
  //
  // Systemverilog has a useful mechanism to generate multiple instances
  // using generate-for loops.
  // Below is an example of a 2D generate-for loop to create a grid of PEs.
  //
  // ----------- BEGIN CODE EXAMPLE -----------
  // genvar m, k, n;
  //
  //   for (m = 0; m < M; m++) begin : gem_mac_pe_m
  //     for (n = 0; n < N; n++) begin : gem_mac_pe_n
  //         mac_module #(
  //           < insert parameters >
  //         ) i_mac_pe (
  //           < insert port connections >
  //         );
  //     end
  //   end
  // ----------- END CODE EXAMPLE -----------
  // 
  // There are many guides on the internet (or even ChatGPT) about generate-for loops.
  // We will give it as an exercise to you to modify this part to support multiple MAC PEs.
  // 
  // When dealing with multiple PEs, be careful with the connection alignment
  // across different PEs as it can be tricky to debug later on.
  // Plan this very carefully, especially when delaing with the correcet data ports
  // data widths, slicing, valid signals, and so much more.
  //
  // Additionally, this MAC PE is already output stationary.
  // You have the freedom to change the dataflow as you see fit.
  //---------------------------

  // The MAC PE instantiation and data path logics

  //DATA reshaping for MAC array
  //SRAM provide 1D vectors but the MAC array needs 3D arrays

  //A_reshaped
  logic signed [meshRow-1:0][tileSize-1:0][InDataWidth-1:0] a_data_reshaped;
  always_comb begin
    for(int r = 0; r < meshRow; r = r + 1) begin
      for(int t = 0; t < tileSize; t = t + 1) begin
        a_data_reshaped[r][t] = sram_a_rdata_i[(r*tileSize + t)*InDataWidth +: InDataWidth];
      end
    end
  end

  //B_reshaped
  logic signed [meshCol-1:0][tileSize-1:0][InDataWidth-1:0] b_data_reshaped;
  always_comb begin
    for(int c = 0; c < meshCol; c = c + 1) begin
      for(int t = 0; t < tileSize; t = t + 1) begin
        b_data_reshaped[c][t] = sram_b_rdata_i[(c*tileSize + t)*InDataWidth +: InDataWidth];
      end
    end
  end

  //C_reshaped
  logic signed [meshRow-1:0][meshCol-1:0][OutDataWidth-1:0] c_data_reshaped;
  always_comb begin
    for(int r = 0; r < meshRow; r = r + 1) begin
      for(int c = 0; c < meshCol; c = c + 1) begin
        sram_c_wdata_o[(r*meshCol + c)*OutDataWidth +: OutDataWidth] = c_data_reshaped[r][c];
      end
    end
  end

  mac_array_3D_444 #(
    .InDataWidth  ( InDataWidth  ),
    .OutDataWidth ( OutDataWidth ),
    .meshRow      ( meshRow      ),
    .meshCol      ( meshCol      ),
    .tileSize     ( tileSize     )
  ) i_mac_array (
    .clk_i        ( clk_i               ),
    .rst_ni       ( rst_ni              ),
    .a_i          ( a_data_reshaped     ),
    .b_i          ( b_data_reshaped     ),
    .a_valid_i    ( valid_data          ),
    .b_valid_i    ( valid_data          ),
    .init_save_i  ( init_save_ctrl      ),
    .acc_clr_i    (!busy                ), //clear when not busy
    .c_o          ( c_data_reshaped     )
  );



endmodule
