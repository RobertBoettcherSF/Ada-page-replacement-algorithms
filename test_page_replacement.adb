--  test_page_replacement.adb
--
--  Test program for Page Replacement Algorithms
--

with Page_Replacement;
with Ada.Text_IO;

procedure Test_Page_Replacement is
   use Page_Replacement;

   -- Define a reference string using the CORRECT type from the package
   type Test_Ref_String is array (1 .. 20) of Page_Number;
   References : constant Test_Ref_String := 
     (1, 2, 3, 4, 1, 2, 5, 1, 2, 3, 4, 5, 6, 7, 8, 9, 1, 2, 3, 4);

   -- Convert to Reference_String_Type for the Simulate procedure
   function To_Reference_String_Type (R : Test_Ref_String) return Reference_String_Type is
      Result : Reference_String_Type(1 .. R'Length);
   begin
      for I in R'Range loop
         Result(I) := R(I);
      end loop;
      return Result;
   end To_Reference_String_Type;

   -- Statistics
   Stats : Algorithm_Statistics;

   -- Parameters
   Params : Algorithm_Parameters := 
     Algorithm_Parameters'(Mode => Global, others => <>);

   The_References : Reference_String_Type := To_Reference_String_Type(References);
begin
   Ada.Text_IO.Put_Line("Testing Page Replacement Algorithms");
   Ada.Text_IO.Put_Line("=====================================");
   Ada.Text_IO.New_Line;

   -- Test FIFO with 3 frames
   Ada.Text_IO.Put_Line("Running FIFO with 3 frames...");
   Simulate(The_References, 3, FIFO, Params, Stats);
   Print_Statistics(Stats, FIFO);

   -- Reset stats
   Stats := (others => 0);

   -- Test LRU with 3 frames
   Ada.Text_IO.Put_Line("Running LRU with 3 frames...");
   Simulate(The_References, 3, LRU, Params, Stats);
   Print_Statistics(Stats, LRU);

   -- Reset stats
   Stats := (others => 0);

   -- Test Clock with 3 frames
   Ada.Text_IO.Put_Line("Running Clock with 3 frames...");
   Simulate(The_References, 3, Clock, Params, Stats);
   Print_Statistics(Stats, Clock);

   -- Reset stats
   Stats := (others => 0);

   -- Test Optimal with 3 frames
   Ada.Text_IO.Put_Line("Running Optimal with 3 frames...");
   Simulate(The_References, 3, Optimal, Params, Stats);
   Print_Statistics(Stats, Optimal);

   Ada.Text_IO.Put_Line("All tests completed!");
end Test_Page_Replacement;
