--  test_page_replacement.adb
--
--  Test program for Page Replacement Algorithms
--

with Page_Replacement;
with Ada.Text_IO;

procedure Test_Page_Replacement is
   use Page_Replacement;

   -- Define a reference string (page numbers)
   type Ref_String is array (1 .. 20) of Page_Number;
   References : constant Ref_String := 
     (1, 2, 3, 4, 1, 2, 5, 1, 2, 3, 4, 5, 6, 7, 8, 9, 1, 2, 3, 4);

   -- Statistics
   Stats : Algorithm_Statistics;

   -- Parameters
   Params : Algorithm_Parameters := 
     Algorithm_Parameters'(Mode => Global, others => <>);
begin
   Ada.Text_IO.Put_Line("Testing Page Replacement Algorithms");
   Ada.Text_IO.Put_Line("=====================================");
   Ada.Text_IO.New_Line;

   -- Test FIFO with 3 frames
   Ada.Text_IO.Put_Line("Running FIFO with 3 frames...");
   Simulate(References, 3, FIFO, Params, Stats);
   Print_Statistics(Stats, FIFO);

   -- Reset stats
   Stats := (others => 0);

   -- Test LRU with 3 frames
   Ada.Text_IO.Put_Line("Running LRU with 3 frames...");
   Simulate(References, 3, LRU, Params, Stats);
   Print_Statistics(Stats, LRU);

   -- Reset stats
   Stats := (others => 0);

   -- Test Clock with 3 frames
   Ada.Text_IO.Put_Line("Running Clock with 3 frames...");
   Simulate(References, 3, Clock, Params, Stats);
   Print_Statistics(Stats, Clock);

   -- Reset stats
   Stats := (others => 0);

   -- Test Optimal with 3 frames
   Ada.Text_IO.Put_Line("Running Optimal with 3 frames...");
   Simulate(References, 3, Optimal, Params, Stats);
   Print_Statistics(Stats, Optimal);

   Ada.Text_IO.Put_Line("All tests completed!");
end Test_Page_Replacement;
