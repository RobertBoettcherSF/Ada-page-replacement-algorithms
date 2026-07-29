--  page_replacement.ads
--
--  Package specification for Page Replacement Algorithms
--  Implements all major algorithms from Wikipedia: Page_replacement_algorithms
--
--  Author: Robert Boettcher
--  Date: July 29, 2026
--

package Page_Replacement is

   -- ===================================================================
   -- TYPE DEFINITIONS
   -- ===================================================================

   -- Basic types for page and frame identification
   type Page_Number is range 0 .. 2**32 - 1;
   type Frame_Number is range 0 .. 2**16 - 1;
   type Page_Count is range 0 .. 2**32 - 1;

   -- Reference and Modified bits (for NRU, Clock, etc.)
   type Reference_Bit is (Unreferenced, Referenced);
   type Modified_Bit is (Clean, Dirty);

   -- Page state combining reference and modified bits
   type Page_State is record
      Ref : Reference_Bit := Unreferenced;
      Modified : Modified_Bit := Clean;  -- FIXED: was "Mod" (reserved word)
   end record;

   -- Page Table Entry type
   type Page_Table_Entry is record
      Page : Page_Number;
      State : Page_State;
      Last_Used : Page_Count := 0;
      Frequency : Page_Count := 0;
      In_Memory : Boolean := False;
   end record;

   -- Page table type (dynamic array) - FIXED: renamed to avoid shadowing
   type Page_Table_Type is array (Frame_Number range <>) of Page_Table_Entry;

   -- Reference string type (sequence of page references) - FIXED: renamed
   type Reference_String_Type is array (Positive range <>) of Page_Number;

   -- Algorithm types enumeration
   type Algorithm_Type is (
      FIFO,
      Optimal,
      LRU,
      Second_Chance,
      Clock,
      NRU,
      Random_Alg,
      NFU,
      Aging,
      MRU,
      GCLOCK,
      Clock_Pro,
      WSClock,
      CAR,
      LRU_K,
      ARC,
      TwoQ
   );

   -- Replacement mode (Local vs Global)
   type Replacement_Mode is (Local, Global);

   -- Precleaning policy
   type Precleaning_Policy is (None, Eager, Conservative);

   -- ===================================================================
   -- EXCEPTIONS
   -- ===================================================================

   Page_Fault_Exception : exception;
   Invalid_Frame_Exception : exception;
   No_Free_Frames_Exception : exception;
   Invalid_Algorithm_Exception : exception;
   Future_Knowledge_Required : exception;

   -- ===================================================================
   -- ALGORITHM PARAMETERS
   -- ===================================================================

   type Algorithm_Parameters is record
      Mode : Replacement_Mode := Global;
      Preclean : Precleaning_Policy := None;
      K_Value : Positive := 1;
      Clock_Size : Frame_Number := 100;
      Aging_Counter_Size : Positive := 8;
   end record;

   -- ===================================================================
   -- STATISTICS
   -- ===================================================================

   type Algorithm_Statistics is record
      Page_Faults : Page_Count := 0;
      Page_Replacements : Page_Count := 0;
      Preclean_Operations : Page_Count := 0;
      Dirty_Page_Writes : Page_Count := 0;
   end record;

   -- ===================================================================
   -- MAIN PROCEDURES
   -- ===================================================================

   procedure Initialize (
      The_Page_Table : out Page_Table_Type;
      Num_Frames : Frame_Number
   );

   procedure Process_Reference (
      The_Page_Table : in out Page_Table_Type;
      Reference : Page_Number;
      Algorithm : Algorithm_Type;
      Params : Algorithm_Parameters;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   );

   procedure Simulate (
      The_References : Reference_String_Type;
      Num_Frames : Frame_Number;
      Algorithm : Algorithm_Type;
      Params : Algorithm_Parameters := Algorithm_Parameters'(Mode => Global, others => <>);
      Stats : out Algorithm_Statistics
   );

   -- ===================================================================
   -- ALGORITHM-SPECIFIC PROCEDURES
   -- ===================================================================

   procedure FIFO_Replace (
      The_Page_Table : in out Page_Table_Type;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   );

   procedure Optimal_Replace (
      The_Page_Table : in out Page_Table_Type;
      Reference : Page_Number;
      Future_References : Reference_String_Type;
      Current_Index : Positive;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   );

   procedure LRU_Replace (
      The_Page_Table : in out Page_Table_Type;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   );

   procedure Second_Chance_Replace (
      The_Page_Table : in out Page_Table_Type;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   );

   procedure Clock_Replace (
      The_Page_Table : in out Page_Table_Type;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count;
      Hand : in out Frame_Number
   );

   procedure NRU_Replace (
      The_Page_Table : in out Page_Table_Type;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   );

   procedure Random_Replace (
      The_Page_Table : in out Page_Table_Type;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   );

   procedure NFU_Replace (
      The_Page_Table : in out Page_Table_Type;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   );

   procedure Aging_Replace (
      The_Page_Table : in out Page_Table_Type;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count;
      Counter_Size : Positive
   );

   procedure MRU_Replace (
      The_Page_Table : in out Page_Table_Type;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   );

   -- ===================================================================
   -- HELPER FUNCTIONS
   -- ===================================================================

   function Is_In_Memory (
      The_Page_Table : Page_Table_Type;
      Page : Page_Number
   ) return Boolean;

   function Find_Frame (
      The_Page_Table : Page_Table_Type;
      Page : Page_Number
   ) return Frame_Number;

   function Find_Free_Frame (
      The_Page_Table : Page_Table_Type
   ) return Frame_Number;

   function Find_FIFO_Victim (
      The_Page_Table : Page_Table_Type
   ) return Frame_Number;

   function Find_LRU_Victim (
      The_Page_Table : Page_Table_Type
   ) return Frame_Number;

   function Find_MRU_Victim (
      The_Page_Table : Page_Table_Type
   ) return Frame_Number;

   function Find_NRU_Victim (
      The_Page_Table : Page_Table_Type
   ) return Frame_Number;

   function Find_NFU_Victim (
      The_Page_Table : Page_Table_Type
   ) return Frame_Number;

   function Find_Random_Victim (
      The_Page_Table : Page_Table_Type
   ) return Frame_Number;

   function Find_Optimal_Victim (
      The_Page_Table : Page_Table_Type;
      Future_References : Reference_String_Type;
      Current_Index : Positive
   ) return Frame_Number;

   procedure Update_Reference_Bits (
      The_Page_Table : in out Page_Table_Type;
      Current_Time : Page_Count
   );

   procedure Clear_Reference_Bits (
      The_Page_Table : in out Page_Table_Type
   );

   procedure Preclean (
      The_Page_Table : in out Page_Table_Type;
      Policy : Precleaning_Policy;
      Stats : in out Algorithm_Statistics
   );

   -- ===================================================================
   -- VALIDATION & UTILITY
   -- ===================================================================

   function Is_Valid_Page_Table (
      The_Page_Table : Page_Table_Type
   ) return Boolean;

   function Is_Valid_Reference_String (
      The_References : Reference_String_Type
   ) return Boolean;

   function Algorithm_Name (
      Alg : Algorithm_Type
   ) return String;

   procedure Print_Page_Table (
      The_Page_Table : Page_Table_Type
   );

   procedure Print_Statistics (
      Stats : Algorithm_Statistics;
      Algorithm : Algorithm_Type
   );

end Page_Replacement;
