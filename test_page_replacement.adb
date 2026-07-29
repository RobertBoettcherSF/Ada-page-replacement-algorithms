with Page_Replacement;
with Ada.Text_IO;

procedure Test_Page_Replacement is
   use Page_Replacement;

   The_References : constant Reference_String_Type := (1, 2, 3, 4, 1, 2, 5, 1, 2, 3);
   Stats : Algorithm_Statistics;
begin
   Simulate(The_References, 3, FIFO, Stats);
   Ada.Text_IO.Put_Line("FIFO: " & Stats.Page_Faults'Image & " faults");
   Stats := (others => 0);

   Simulate(The_References, 3, LRU, Stats);
   Ada.Text_IO.Put_Line("LRU: " & Stats.Page_Faults'Image & " faults");
   Stats := (others => 0);

   Simulate(The_References, 3, Random_Alg, Stats);
   Ada.Text_IO.Put_Line("Random: " & Stats.Page_Faults'Image & " faults");
end Test_Page_Replacement;
