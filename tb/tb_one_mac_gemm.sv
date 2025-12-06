module tb_one_mac_gemm;
  //---------------------------
  // Design Time Parameters
  //---------------------------

  //---------------------------
  // DESIGN NOTE:
  // Parameters are a way to customize your design at
  // compile time. Here we define the data width,
  // memory depth, and number of ports for the
  // multi-port memory instances used in the DUT.
  //
  // In other test benches, you can also have test parameters,
  // such as the number of tests to run, or the sizes of
  // matrices to be used in the tests.
  //
  // You can customize these parameters as needed.
  // Or you can also add your own parameters.
  //---------------------------

  // General Parameters
  parameter int unsigned InDataWidth   = 8;
  parameter int unsigned OutDataWidth  = 32;

  parameter int unsigned meshRow      = 4;
  parameter int unsigned meshCol      = 4;
  parameter int unsigned tileSize     = 4;

  parameter int unsigned SRAM_AB_Width = meshRow * tileSize * InDataWidth; // 128 bits
  parameter int unsigned SRAM_C_Width  = meshRow * meshCol * OutDataWidth; // 512 bits


  parameter int unsigned DataDepth     = 4096;
  parameter int unsigned AddrWidth     = (DataDepth <= 1) ? 1 : $clog2(DataDepth);
  parameter int unsigned SizeAddrWidth = 8; // counts blocks now?
  
  // Test Parameters
  parameter int unsigned NumTests = 50;






  //---------------------------
  // Wires
  //---------------------------

  //use for block counting
  logic [SizeAddrWidth-1:0] M_i, K_i, N_i;

  int unsigned total_row;
  int unsigned total_col;
  int unsigned total_k;

  // Clock, reset, and other signals
  logic clk_i;
  logic rst_ni;
  logic start;
  logic done;
  
 logic [AddrWidth-1:0] test_depth;
  //---------------------------
  // Memory
  //---------------------------
  // Memory control
  logic [AddrWidth-1:0] sram_a_addr;
  logic [AddrWidth-1:0] sram_b_addr;
  logic [AddrWidth-1:0] sram_c_addr;

  // Memory access
  logic signed [ SRAM_AB_Width-1:0] sram_a_rdata;
  logic signed [ SRAM_AB_Width-1:0] sram_b_rdata;
  logic signed [SRAM_C_Width-1:0] sram_c_wdata;
  logic                           sram_c_we;

  // Golden data storage
  logic signed [SRAM_C_Width-1:0] G_memory [DataDepth];


  //---------------------------
  // Declaration of input and output memories
  //---------------------------
  logic signed [InDataWidth-1:0] flat_A [DataDepth];
  logic signed [InDataWidth-1:0] flat_B [DataDepth];
  logic signed [OutDataWidth-1:0] flat_C_golden [DataDepth];
  //---------------------------
  // DESIGN NOTE:
  // These are where the memories are instantiated for the DUT.
  // You can modify the data width and data depth parameters.
  //
  // This can be useful for increasing your memory bandwidth.
  // However, you need to think about and take care of how to,
  // initialize the memories accordingly.
  // That includes knowing how to pack the data accordingly.
  //
  // Make sure that the connection for the address, data, and wen
  // signals are consistent with the number of ports.
  //
  // Refer to the single_port_memory.sv and 
  // tb_single_port_memory.sv file for more details.
  //---------------------------

  // Input memory A
  // Note: this is read only
  single_port_memory #(
    .DataWidth     ( SRAM_AB_Width),
    .DataDepth     ( DataDepth    ),
    .AddrWidth     ( AddrWidth    )
  ) i_sram_a (
    .clk_i         ( clk_i        ),
    .rst_ni        ( rst_ni       ),
    .mem_addr_i    ( sram_a_addr  ),
    .mem_we_i      ( '0           ),
    .mem_wr_data_i ( '0           ),
    .mem_rd_data_o ( sram_a_rdata )
  );

  // Input memory B
  // Note: this is read only
  single_port_memory #(
    .DataWidth     ( SRAM_AB_Width),
    .DataDepth     ( DataDepth    ),
    .AddrWidth     ( AddrWidth    )
  ) i_sram_b (
    .clk_i         ( clk_i        ),
    .rst_ni        ( rst_ni       ),
    .mem_addr_i    ( sram_b_addr  ),
    .mem_we_i      ( '0           ),
    .mem_wr_data_i ( '0           ),
    .mem_rd_data_o ( sram_b_rdata )
  );

  // Output memory C
  // Note: this is write only
  single_port_memory #(
    .DataWidth     ( SRAM_C_Width ),
    .DataDepth     ( DataDepth    ),
    .AddrWidth     ( AddrWidth    )
  ) i_sram_c (
    .clk_i         ( clk_i        ),
    .rst_ni        ( rst_ni       ),
    .mem_addr_i    ( sram_c_addr  ),
    .mem_we_i      ( sram_c_we    ),
    .mem_wr_data_i ( sram_c_wdata ),
    .mem_rd_data_o ( /* unused */ )
  );

  //---------------------------
  // DUT instantiation
  //---------------------------
  gemm_accelerator_top #(
    .InDataWidth   ( InDataWidth   ),
    .OutDataWidth  ( OutDataWidth  ),
    .AddrWidth     ( AddrWidth     ),
    .SizeAddrWidth ( SizeAddrWidth ),
    .meshRow       ( meshRow       ),
    .meshCol       ( meshCol       ),
    .tileSize      ( tileSize      )
  ) i_dut (
    .clk_i          ( clk_i        ),
    .rst_ni         ( rst_ni       ),
    .start_i        ( start        ),
    .N_size_i       ( N_i          ),//block count
    .M_size_i       ( M_i          ),//block count
    .K_size_i       ( K_i          ),//block count
    .sram_a_addr_o  ( sram_a_addr  ),
    .sram_b_addr_o  ( sram_b_addr  ),
    .sram_c_addr_o  ( sram_c_addr  ),
    .sram_a_rdata_i ( sram_a_rdata ),
    .sram_b_rdata_i ( sram_b_rdata ),
    .sram_c_wdata_o ( sram_c_wdata ),
    .sram_c_we_o    ( sram_c_we    ),
    .done_o         ( done         )
  );

  //---------------------------
  // Tasks and functions
  //---------------------------
  `include "includes/common_tasks.svh"
  `include "includes/test_tasks.svh"
  `include "includes/test_func.svh"

  //---------------------------
  // Test control
  //---------------------------

  // Clock generation
  initial begin
    clk_i = 1'b0;
    forever #5 clk_i = ~clk_i;  // 100MHz clock
  end

  

  //initialize memories
  task init_memories(
    input int M_blk,
    input int K_blk,
    input int N_blk
    );
    logic signed [InDataWidth-1:0] temp_val;
    logic [SRAM_AB_Width-1:0] packed_a;
    logic [SRAM_AB_Width-1:0] packed_b;
    int global_r;
    int global_k;
    int global_c;
    //init SRAM A
    for (int m = 0; m < M_blk; m++) begin
      for(int k = 0; k < K_blk; k++) begin
        packed_a = '0;

        //pack 16 bytes 
        for(int r = 0; r < meshRow; r++)begin
          for(int t = 0; t < tileSize; t++)begin
          temp_val = $urandom();
          packed_a[(r*tileSize + t)*InDataWidth +: InDataWidth] = temp_val;  
          
          //fill flat A for golden
          global_r = m*meshRow + r;
          global_k = k*tileSize + t;
          flat_A[global_r * total_k + global_k] = temp_val;
          end
        end
        i_sram_a.memory[m*K_blk + k] = packed_a;
      end
    end

    //init SRAM B
    for (int n = 0; n < N_blk; n++) begin
      for(int k = 0; k < K_blk; k++) begin
        packed_b = '0;
        //pack 16 bytes 
        for(int c = 0; c < meshCol; c++)begin
          for(int t = 0; t < tileSize; t++)begin
          temp_val = $urandom();
          packed_b[(c*tileSize + t)*InDataWidth +: InDataWidth] = temp_val;  
          
          //fill flat B for golden

          global_c = n*meshCol + c;
          global_k = k*tileSize + t;
          flat_B[global_k * total_col + global_c] = temp_val;
          end
        end
        i_sram_b.memory[n*K_blk + k] = packed_b;
      end
    end
  endtask





  task verify_result_c(
    input int M_blk,
    input int N_blk
  );
    int errors;
    int global_r;
    int global_c;
    logic signed [OutDataWidth-1:0] dut_value;
    logic signed [OutDataWidth-1:0] golden_value;
    logic [SRAM_C_Width-1:0] c_block;
    errors = 0;

    for(int m = 0; m < M_blk; m++) begin
      for(int n = 0; n < N_blk; n++) begin
        c_block = i_sram_c.memory[m*N_blk + n];
        for(int r = 0; r < meshRow; r++) begin
          for(int c = 0; c < meshCol; c++) begin
            dut_value = c_block[(r*meshCol + c)*OutDataWidth +: OutDataWidth];
            global_r = m*meshRow + r;
            global_c = n*meshCol + c;
            golden_value = flat_C_golden[global_r * total_col + global_c];
            if (dut_value !== golden_value) begin
              $display("ERROR: Mismatch at C(%0d, %0d): expected %0d, got %0d",
                       global_r, global_c, golden_value, dut_value);
              errors++;
            end  
            // else begin
            //   $display("correct: match at C(%0d, %0d): expected %0d, got %0d",
            //            global_r, global_c, golden_value, dut_value);
            // end
          end
        end
      end
    end
  endtask
  //---------------------------
  // DESIGN NOTE:
  //
  // The sequence driver is usually the main stimulus
  // generator for the test bench. Here is where
  // you define the sequence of operations to be
  // performed during the simulation.
  //
  // It often starts with an initial reset sequence,
  // by loading default values and asserting the reset.
  //
  // We also do for-loops to run multiple tests
  // with different input parameters. In this case,
  // we randomize the matrix sizes for each test.
  //
  // You can also customize in here the way
  // the memories are initialized, how the golden
  // results are generated, and how the results
  // are verified.
  //
  // Refer to the tasks and functions included above
  // for more details.
  //---------------------------

  // Sequence driver
  initial begin

    // Initial reset
    start  = 1'b0;
    rst_ni = 1'b0;
    #50;
    rst_ni = 1'b1;

    for (integer num_test = 0; num_test < NumTests; num_test++) begin
      $display("Test number: %0d", num_test);

      if(num_test == 0) begin
        //case 1 :4x64 * 64x16
        M_i = 1; K_i = 1; N_i = 3;
        $display(">>CASE1: 4x64 * 64x16");
        end
        else if (num_test == 1) begin
            // Case 2: 16x64 * 64x4
            // M=4 Blocks (16 rows), K=16 Blocks (64 depth), N=1 Block (4 cols)
            M_i = 4; K_i = 16; N_i = 1;
            $display(">> Case 2: 16x64 * 64x4");
        end        
        else if (num_test == 2) begin
            // Case 3: 32x32 * 32x32
            // M=8 Blocks (32 rows), K=8 Blocks (32 depth), N=8 Blocks (32 cols)
            M_i = 8; K_i = 8; N_i = 8;
            $display(">> Case 3: 32x32 * 32x32");
        end 
        else begin
            // Random Tests (Upper limit: 8 blocks = 32 size)
            M_i = $urandom_range(1, 16);
            K_i = $urandom_range(1, 16);
            N_i = $urandom_range(1, 16);
            $display(">> Random Case");
        end
        total_col = N_i * meshCol;
        total_row = M_i * meshRow;
        total_k   = K_i * tileSize;
        $display("for test %0d   Block Dimensions: M=%0d, K=%0d, N=%0d", num_test, M_i, K_i, N_i);
      //---------------------------
      // DESIGN NOTE:
      // You will most likely modify this part
      // to initialize the input memories
      // according to your design requirements.
      //
      // In here, we simply fill the memories
      // with random data for testing.
      //
      // We assume a row-major storage for both matrices A and B.
      // Row major means that the elements of each row
      // are stored in contiguous memory locations.
      //
      // We also make the assumption that the matrix output C
      // will be stored in row-major format as well.
      //
      // Take note that you WILL change this part according to your design.
      // Just make sure that the way you initialize the memories
      // is consistent with the way you generate the golden results
      // and the way your DUT reads/writes the data.
      //
      // The tricky part here is that since the data accesses are
      // shared within a single long bit-width (suppose you use longer)
      // memory word. For example, if your memory word is 32 bits wide
      // and your data width is 8 bits, then you can pack
      // 4 data elements in a single memory word.
      // So when you initialize the memory, you need to
      // make sure that the data elements are packed
      // correctly within each memory word.
      //---------------------------
      
      // Initialize input memories and compute golden result
      init_memories(M_i, K_i, N_i);
      gemm_golden(total_row, total_k, total_col, flat_A, flat_B, flat_C_golden);


      // Just delay 1 cycle
      clk_delay(1);

      // Execute the GeMM
      start_and_wait_gemm();
      
      clk_delay(5);
      verify_result_c(M_i, N_i);

      // Just some trailing cycles
      // For easier monitoring in waveform
      clk_delay(10);
    end

    $display("All test tasks completed successfully!");
    $finish;
  end

endmodule
