--  page_replacement.ads
package Page_Replacement is

   type Page_Number is range 0 .. 1000;
   type Frame_Number is range 1 .. 100;
   type Page_Count is range 0 .. 10000;

   type Reference_Bit is (Unreferenced, Referenced);
   type Modified_Bit is (Clean, Dirty);

   type Page_State is record
      Ref : Reference_Bit := Unreferenced;
      Modified : Modified_Bit := Clean;
   end record;

   type Page_Table_Entry is record
      Page : Page_Number;
      State : Page_State;
      Last_Used : Page_Count := 0;
      In_Memory : Boolean := False;
   end record;

   type Page_Table_Type is array (Frame_Number range <>) of Page_Table_Entry;
   type Reference_String_Type is array (Positive range <>) of Page_Number;

   type Algorithm_Type is (FIFO, LRU, Clock, Optimal, NRU, Random_Alg);

   type Algorithm_Statistics is record
      Page_Faults : Page_Count := 0;
      Page_Replacements : Page_Count := 0;
   end record;

   procedure Initialize (
      The_Page_Table : out Page_Table_Type;
      Num_Frames : Frame_Number
   );

   procedure Simulate (
      The_References : Reference_String_Type;
      Num_Frames : Frame_Number;
      Algorithm : Algorithm_Type;
      Stats : out Algorithm_Statistics
   );

   function Algorithm_Name (Alg : Algorithm_Type) return String;

end Page_Replacement;
