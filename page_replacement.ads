--  page_replacement.ads
--
--  Package specification for Page Replacement Algorithms
--  Implements all major algorithms from Wikipedia: Page_replacement_algorithms
--
--  Author: Robert Boettcher
--  Date: July 29, 2026
--

with Ada.Containers.Doubly_Linked_Lists;
with Ada.Containers.Vectors;
with Ada.Numerics.Discrete_Random;

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
      Modified : Modified_Bit := Clean;  -- Changed from "Mod" to "Modified"
   end record;

   -- Page Table Entry type
   type Page_Table_Entry is record
      Page : Page_Number;
      State : Page_State;
      Last_Used : Page_Count := 0;  -- For LRU, Aging, etc.
      Frequency : Page_Count := 0; -- For NFU
      In_Memory : Boolean := False;
   end record;

   -- Page table type (dynamic array)
   type Page_Table is array (Frame_Number range <>) of Page_Table_Entry;

   -- Reference string type (sequence of page references)
   type Reference_String is array (Positive range <>) of Page_Number;

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
      -- Clock variants
      GCLOCK,
      Clock_Pro,
      WSClock,
      CAR,
      -- LRU variants
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

   -- Parameters for algorithm variants
   type Algorithm_Parameters is record
      Mode : Replacement_Mode := Global;
      Preclean : Precleaning_Policy := None;
      K_Value : Positive := 1;  -- For LRU-K
      Clock_Size : Frame_Number := 100; -- For Clock variants
      Aging_Counter_Size : Positive := 8; -- For Aging algorithm
   end record;

   -- ===================================================================
   -- STATISTICS
   -- ===================================================================

   -- Statistics for algorithm performance
   type Algorithm_Statistics is record
      Page_Faults : Page_Count := 0;
      Page_Replacements : Page_Count := 0;
      Preclean_Operations : Page_Count := 0;
      Dirty_Page_Writes : Page_Count := 0;
   end record;

   -- ===================================================================
   -- MAIN PROCEDURES
   -- ===================================================================

   -- Initialize page table with given number of frames
   procedure Initialize (
      Page_Table : out Page_Table;
      Num_Frames : Frame_Number
   );

   -- Process a single page reference for a specific algorithm
   procedure Process_Reference (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Algorithm : Algorithm_Type;
      Params : Algorithm_Parameters;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   );

   -- Simulate a complete reference string with a specific algorithm
   procedure Simulate (
      Reference_String : Reference_String;
      Num_Frames : Frame_Number;
      Algorithm : Algorithm_Type;
      Params : Algorithm_Parameters := Algorithm_Parameters'(Mode => Global, others => <>);
      Stats : out Algorithm_Statistics
   );

   -- ===================================================================
   -- ALGORITHM-SPECIFIC PROCEDURES
   -- ===================================================================

   -- FIFO Algorithm
   procedure FIFO_Replace (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   );

   -- Optimal Algorithm (requires future reference string)
   procedure Optimal_Replace (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Future_References : Reference_String;
      Current_Index : Positive;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   );

   -- LRU Algorithm
   procedure LRU_Replace (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   );

   -- Second Chance Algorithm
   procedure Second_Chance_Replace (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   );

   -- Clock Algorithm
   procedure Clock_Replace (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count;
      Hand : in out Frame_Number
   );

   -- NRU Algorithm
   procedure NRU_Replace (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   );

   -- Random Algorithm
   procedure Random_Replace (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   );

   -- NFU Algorithm
   procedure NFU_Replace (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   );

   -- Aging Algorithm
   procedure Aging_Replace (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count;
      Counter_Size : Positive
   );

   -- MRU Algorithm
   procedure MRU_Replace (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   );

   -- ===================================================================
   -- CLOCK VARIANTS
   -- ===================================================================

   -- GCLOCK Algorithm
   procedure GCLOCK_Replace (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count;
      Hand : in out Frame_Number
   );

   -- Clock-Pro Algorithm
   procedure Clock_Pro_Replace (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count;
      Hand : in out Frame_Number;
      History : in out Page_Table
   );

   -- WSClock Algorithm
   procedure WSClock_Replace (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count;
      Hand : in out Frame_Number;
      Working_Set_Size : Frame_Number
   );

   -- CAR Algorithm
   procedure CAR_Replace (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count;
      Hand : in out Frame_Number
   );

   -- ===================================================================
   -- LRU VARIANTS
   -- ===================================================================

   -- LRU-K Algorithm
   procedure LRU_K_Replace (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count;
      K : Positive
   );

   -- ARC Algorithm (Adaptive Replacement Cache)
   procedure ARC_Replace (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count;
      P : Positive  -- Cache size parameter
   );

   -- 2Q Algorithm
   procedure TwoQ_Replace (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   );

   -- ===================================================================
   -- HELPER FUNCTIONS
   -- ===================================================================

   -- Check if page is in memory
   function Is_In_Memory (
      Page_Table : Page_Table;
      Page : Page_Number
   ) return Boolean;

   -- Find frame containing a specific page
   function Find_Frame (
      Page_Table : Page_Table;
      Page : Page_Number
   ) return Frame_Number;

   -- Find a free frame (not in memory)
   function Find_Free_Frame (
      Page_Table : Page_Table
   ) return Frame_Number;

   -- Find victim frame using FIFO
   function Find_FIFO_Victim (
      Page_Table : Page_Table
   ) return Frame_Number;

   -- Find victim frame using LRU
   function Find_LRU_Victim (
      Page_Table : Page_Table
   ) return Frame_Number;

   -- Find victim frame using MRU
   function Find_MRU_Victim (
      Page_Table : Page_Table
   ) return Frame_Number;

   -- Find victim frame using NRU classification
   function Find_NRU_Victim (
      Page_Table : Page_Table
   ) return Frame_Number;

   -- Find victim frame using NFU
   function Find_NFU_Victim (
      Page_Table : Page_Table
   ) return Frame_Number;

   -- Find victim frame using Random
   function Find_Random_Victim (
      Page_Table : Page_Table
   ) return Frame_Number;

   -- Find victim for Optimal algorithm (requires future references)
   function Find_Optimal_Victim (
      Page_Table : Page_Table;
      Future_References : Reference_String;
      Current_Index : Positive
   ) return Frame_Number;

   -- Update reference bits (for Clock, Second-Chance, etc.)
   procedure Update_Reference_Bits (
      Page_Table : in out Page_Table;
      Current_Time : Page_Count
   );

   -- Clear reference bits periodically (for NRU)
   procedure Clear_Reference_Bits (
      Page_Table : in out Page_Table
   );

   -- Preclean dirty pages
   procedure Preclean (
      Page_Table : in out Page_Table;
      Policy : Precleaning_Policy;
      Stats : in out Algorithm_Statistics
   );

   -- ===================================================================
   -- VALIDATION FUNCTIONS
   -- ===================================================================

   -- Validate page table
   function Is_Valid_Page_Table (
      Page_Table : Page_Table
   ) return Boolean;

   -- Validate reference string
   function Is_Valid_Reference_String (
      Ref_String : Reference_String
   ) return Boolean;

   -- ===================================================================
   -- UTILITY FUNCTIONS
   -- ===================================================================

   -- Get algorithm name as string
   function Algorithm_Name (
      Alg : Algorithm_Type
   ) return String;

   -- Print page table state (for debugging)
   procedure Print_Page_Table (
      Page_Table : Page_Table
   );

   -- Print statistics
   procedure Print_Statistics (
      Stats : Algorithm_Statistics;
      Algorithm : Algorithm_Type
   );

end Page_Replacement;
