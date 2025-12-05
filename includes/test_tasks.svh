// Task to start the accelerator
// and wait for it to finish its task
task automatic start_and_wait_gemm();
begin
  automatic int cycle_count;
  cycle_count = 0;
  // Start the GEMM operation
  @(posedge clk_i);
  start = 1'b1;
  @(posedge clk_i);
  start = 1'b0;
  while (done == 1'b0) begin
  @(posedge clk_i);
  cycle_count = cycle_count + 1;
  if (cycle_count > 100000) begin
    $display("ERROR: GEMM operation timeout after %0d cycles", cycle_count);
    $fatal;
  end
  end
  @(posedge clk_i);
  $display("GEMM operation completed in %0d cycles", cycle_count);
end
endtask

// Task to verify the resulting matrix
// task automatic verify_result_c(
//   input logic signed [OutDataWidth-1:0] golden_data [DataDepth],
//   input logic signed [OutDataWidth-1:0] actual_data [DataDepth],
//   input logic        [   AddrWidth-1:0] num_data,
//   input logic                           fatal_on_mismatch
// );
// begin
//     // Compare with SRAM C contents
//   for (int unsigned addr = 0; addr < num_data; addr++) begin
//   if (golden_data[addr] !== actual_data[addr]) begin
//     $display("ERROR: Mismatch at address %0d: expected %h, got %h",
//             addr, golden_data[addr], actual_data[addr]);
//     if (fatal_on_mismatch)
//     $fatal;
//   end
//   end
//   $display("Result matrix C verification passed!");
// end
// endtask


  // task compute_golden(
  //   input int M_blk,
  //   input int K_blk,
  //   input int N_blk
  // );
  //   logic signed [InDataWidth-1:0] val_a;
  //   logic signed [InDataWidth-1:0] val_b;
  //   logic signed [OutDataWidth-1:0] sum;
  //   logic [SRAM_C_Width-1:0] pack_c;
    
  //   //output c
  //   for(int m = 0; m <M_blk; m = m + 1)begin
  //     for(int n = 0; n <N_blk; n = n + 1)begin
  //       //calculate one C block
  //       pack_c = '0;
  //       for(int r = 0; r < meshRow; r = r + 1)begin
  //         for(int c = 0; c < meshCol; c = c + 1)begin
  //           sum = 0;

  //           //dot product over K blocks
  //           for(int k = 0; k < K_blk; k = k + 1)begin
  //             //dot product inside the block
  //             for(int t = 0; t < tileSize; t = t + 1)begin
  //               //unpacked A
  //               val_a = i_sram_a.memory[m*K_blk + k][(r*tileSize + t)*InDataWidth +: InDataWidth];
  //               //unpacked B
  //               val_b = i_sram_b.memory[n*K_blk + k][(c*tileSize + t)*InDataWidth +: InDataWidth];
  //               sum = $signed(sum) + ($signed(val_a) * $signed(val_b));
  //             end
  //           end
  //           //pack result into 512-bit vector
  //           pack_c[(r*meshCol + c)*OutDataWidth +: OutDataWidth] = sum;
  //         end
  //       end
  //       G_memory[m*N_blk + n] = pack_c;
  //     end
  //   end

  // endtask

