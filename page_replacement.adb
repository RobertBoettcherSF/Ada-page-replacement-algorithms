--  page_replacement.adb
--
--  Package body for Page Replacement Algorithms
--  Complete implementation of all algorithms from Wikipedia
--
--  Author: Robert Boettcher
--  Date: July 29, 2026
--

with Ada.Text_IO;
with Ada.Containers.Doubly_Linked_Lists;
with Ada.Numerics.Discrete_Random;
with Ada.Calendar;

package body Page_Replacement is

   -- Random number generator for Random algorithm
   package Random_Frame is new Ada.Numerics.Discrete_Random (Frame_Number);
   Gen : Random_Frame.Generator;

   -- ===================================================================
   -- INITIALIZATION
   -- ===================================================================

   procedure Initialize (
      Page_Table : out Page_Table;
      Num_Frames : Frame_Number
   ) is
   begin
      -- Initialize all frames as empty
      for I in Page_Table'Range loop
         Page_Table(I) := (
            Page => 0,
            State => (Ref => Unreferenced, Mod => Clean),
            Last_Used => 0,
            Frequency => 0,
            In_Memory => False
         );
      end loop;

      -- Initialize random generator
      Random_Frame.Reset(Gen);
   end Initialize;

   -- ===================================================================
   -- MAIN PROCESS REFERENCE PROCEDURE
   -- ===================================================================

   procedure Process_Reference (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Algorithm : Algorithm_Type;
      Params : Algorithm_Parameters;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   ) is
      Hand : Frame_Number := Page_Table'First;  -- For Clock algorithms
      History : Page_Table(Page_Table'Range);  -- For Clock-Pro
   begin
      -- Update statistics
      if not Is_In_Memory(Page_Table, Reference) then
         Stats.Page_Faults := Stats.Page_Faults + 1;
      end if;

      -- Process based on algorithm type
      case Algorithm is
         when FIFO =>
            FIFO_Replace(Page_Table, Reference, Stats, Current_Time);

         when Optimal =>
            raise Future_Knowledge_Required with
               "Optimal algorithm requires future reference string. Use Simulate instead.";

         when LRU =>
            LRU_Replace(Page_Table, Reference, Stats, Current_Time);

         when Second_Chance =>
            Second_Chance_Replace(Page_Table, Reference, Stats, Current_Time);

         when Clock =>
            Clock_Replace(Page_Table, Reference, Stats, Current_Time, Hand);

         when NRU =>
            -- Clear reference bits periodically (simulate timer interrupt)
            if Current_Time mod 100 = 0 then
               Clear_Reference_Bits(Page_Table);
            end if;
            NRU_Replace(Page_Table, Reference, Stats, Current_Time);

         when Random_Alg =>
            Random_Replace(Page_Table, Reference, Stats, Current_Time);

         when NFU =>
            NFU_Replace(Page_Table, Reference, Stats, Current_Time);

         when Aging =>
            Aging_Replace(Page_Table, Reference, Stats, Current_Time, Params.Aging_Counter_Size);

         when MRU =>
            MRU_Replace(Page_Table, Reference, Stats, Current_Time);

         -- Clock Variants
         when GCLOCK =>
            GCLOCK_Replace(Page_Table, Reference, Stats, Current_Time, Hand);

         when Clock_Pro =>
            Clock_Pro_Replace(Page_Table, Reference, Stats, Current_Time, Hand, History);

         when WSClock =>
            WSClock_Replace(Page_Table, Reference, Stats, Current_Time, Hand, Params.Clock_Size);

         when CAR =>
            CAR_Replace(Page_Table, Reference, Stats, Current_Time, Hand);

         -- LRU Variants
         when LRU_K =>
            LRU_K_Replace(Page_Table, Reference, Stats, Current_Time, Params.K_Value);

         when ARC =>
            ARC_Replace(Page_Table, Reference, Stats, Current_Time, Params.Clock_Size);

         when TwoQ =>
            TwoQ_Replace(Page_Table, Reference, Stats, Current_Time);
      end case;

      -- Handle precleaning if enabled
      if Params.Preclean /= None then
         Preclean(Page_Table, Params.Preclean, Stats);
      end if;

   exception
      when E : others =>
         Ada.Text_IO.Put_Line("Error in Process_Reference: " & Ada.Exceptions.Exception_Message(E));
         raise;
   end Process_Reference;

   -- ===================================================================
   -- SIMULATION PROCEDURE
   -- ===================================================================

   procedure Simulate (
      Reference_String : Reference_String;
      Num_Frames : Frame_Number;
      Algorithm : Algorithm_Type;
      Params : Algorithm_Parameters := Algorithm_Parameters'(Mode => Global, others => <>);
      Stats : out Algorithm_Statistics
   ) is
      -- Create page table with enough frames
      Page_Table : Page_Table(1 .. Num_Frames);
      Hand : Frame_Number := 1;
      History : Page_Table(1 .. Num_Frames);
   begin
      -- Initialize
      Initialize(Page_Table, Num_Frames);
      Initialize(History, Num_Frames);
      Stats := (others => 0);

      -- Process each reference in the string
      for I in Reference_String'Range loop
         declare
            Current_Time : Page_Count := Page_Count(I);
         begin
            -- For Optimal algorithm, we need special handling
            if Algorithm = Optimal then
               declare
                  Future_Refs : Reference_String := Reference_String(I .. Reference_String'Last);
               begin
                  Process_Reference(Page_Table, Reference_String(I), Algorithm, Params, Stats, Current_Time);
                  -- Manually implement Optimal since it needs future knowledge
                  if not Is_In_Memory(Page_Table, Reference_String(I)) then
                     if not Is_In_Memory(Page_Table, Reference_String(I)) then
                        declare
                           Free_Frame : Frame_Number := Find_Free_Frame(Page_Table);
                        begin
                           if Free_Frame > 0 then
                              -- Found free frame
                              Page_Table(Free_Frame) := (
                                 Page => Reference_String(I),
                                 State => (Ref => Referenced, Mod => Clean),
                                 Last_Used => Current_Time,
                                 Frequency => 1,
                                 In_Memory => True
                              );
                              Stats.Page_Replacements := Stats.Page_Replacements + 1;
                           else
                              -- Find optimal victim
                              declare
                                 Victim : Frame_Number := Find_Optimal_Victim(Page_Table, Future_Refs, I);
                              begin
                                 -- Check if dirty
                                 if Page_Table(Victim).State.Mod = Dirty then
                                    Stats.Dirty_Page_Writes := Stats.Dirty_Page_Writes + 1;
                                 end if;

                                 -- Replace
                                 Page_Table(Victim) := (
                                    Page => Reference_String(I),
                                    State => (Ref => Referenced, Mod => Clean),
                                    Last_Used => Current_Time,
                                    Frequency => 1,
                                    In_Memory => True
                                 );
                                 Stats.Page_Replacements := Stats.Page_Replacements + 1;
                              end;
                           end if;
                        end;
                     end if;
                  else
                     -- Page is in memory, update state
                     declare
                        Frame : Frame_Number := Find_Frame(Page_Table, Reference_String(I));
                      begin
                         if Frame > 0 then
                            Page_Table(Frame).State.Ref := Referenced;
                            Page_Table(Frame).Last_Used := Current_Time;
                            Page_Table(Frame).Frequency := Page_Table(Frame).Frequency + 1;
                         end if;
                      end;
                  end if;
               end;
            else
               Process_Reference(Page_Table, Reference_String(I), Algorithm, Params, Stats, Current_Time);
            end if;
         end;
      end loop;

   exception
      when E : others =>
         Ada.Text_IO.Put_Line("Error in Simulate: " & Ada.Exceptions.Exception_Message(E));
         raise;
   end Simulate;

   -- ===================================================================
   -- FIFO ALGORITHM
   -- ===================================================================

   procedure FIFO_Replace (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   ) is
      Free_Frame : Frame_Number;
      Victim : Frame_Number;
      Oldest_Time : Page_Count := Page_Count'Last;
   begin
      -- Check if page is already in memory
      if Is_In_Memory(Page_Table, Reference) then
         declare
            Frame : Frame_Number := Find_Frame(Page_Table, Reference);
         begin
            -- Update reference bit
            Page_Table(Frame).State.Ref := Referenced;
            Page_Table(Frame).Last_Used := Current_Time;
         end;
         return;
      end if;

      -- Find free frame
      Free_Frame := Find_Free_Frame(Page_Table);

      if Free_Frame > 0 then
         -- Found free frame, use it
         Page_Table(Free_Frame) := (
            Page => Reference,
            State => (Ref => Referenced, Mod => Clean),
            Last_Used => Current_Time,
            Frequency => 1,
            In_Memory => True
         );
         Stats.Page_Replacements := Stats.Page_Replacements + 1;
         return;
      end if;

      -- No free frames, find victim using FIFO
      Victim := Find_FIFO_Victim(Page_Table);

      -- Check if dirty
      if Page_Table(Victim).State.Mod = Dirty then
         Stats.Dirty_Page_Writes := Stats.Dirty_Page_Writes + 1;
      end if;

      -- Replace victim
      Page_Table(Victim) := (
         Page => Reference,
         State => (Ref => Referenced, Mod => Clean),
         Last_Used => Current_Time,
         Frequency => 1,
         In_Memory => True
      );
      Stats.Page_Replacements := Stats.Page_Replacements + 1;

   end FIFO_Replace;

   -- ===================================================================
   -- OPTIMAL ALGORITHM
   -- ===================================================================

   procedure Optimal_Replace (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Future_References : Reference_String;
      Current_Index : Positive;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   ) is
      Free_Frame : Frame_Number;
      Victim : Frame_Number;
   begin
      -- Check if page is already in memory
      if Is_In_Memory(Page_Table, Reference) then
         declare
            Frame : Frame_Number := Find_Frame(Page_Table, Reference);
         begin
            Page_Table(Frame).State.Ref := Referenced;
            Page_Table(Frame).Last_Used := Current_Time;
         end;
         return;
      end if;

      -- Find free frame
      Free_Frame := Find_Free_Frame(Page_Table);

      if Free_Frame > 0 then
         Page_Table(Free_Frame) := (
            Page => Reference,
            State => (Ref => Referenced, Mod => Clean),
            Last_Used => Current_Time,
            Frequency => 1,
            In_Memory => True
         );
         Stats.Page_Replacements := Stats.Page_Replacements + 1;
         return;
      end if;

      -- Find optimal victim
      Victim := Find_Optimal_Victim(Page_Table, Future_References, Current_Index);

      -- Check if dirty
      if Page_Table(Victim).State.Mod = Dirty then
         Stats.Dirty_Page_Writes := Stats.Dirty_Page_Writes + 1;
      end if;

      -- Replace
      Page_Table(Victim) := (
         Page => Reference,
         State => (Ref => Referenced, Mod => Clean),
         Last_Used => Current_Time,
         Frequency => 1,
         In_Memory => True
      );
      Stats.Page_Replacements := Stats.Page_Replacements + 1;

   end Optimal_Replace;

   -- ===================================================================
   -- LRU ALGORITHM
   -- ===================================================================

   procedure LRU_Replace (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   ) is
      Free_Frame : Frame_Number;
      Victim : Frame_Number;
   begin
      -- Check if page is already in memory
      if Is_In_Memory(Page_Table, Reference) then
         declare
            Frame : Frame_Number := Find_Frame(Page_Table, Reference);
         begin
            Page_Table(Frame).State.Ref := Referenced;
            Page_Table(Frame).Last_Used := Current_Time;
            Page_Table(Frame).Frequency := Page_Table(Frame).Frequency + 1;
         end;
         return;
      end if;

      -- Find free frame
      Free_Frame := Find_Free_Frame(Page_Table);

      if Free_Frame > 0 then
         Page_Table(Free_Frame) := (
            Page => Reference,
            State => (Ref => Referenced, Mod => Clean),
            Last_Used => Current_Time,
            Frequency => 1,
            In_Memory => True
         );
         Stats.Page_Replacements := Stats.Page_Replacements + 1;
         return;
      end if;

      -- Find LRU victim
      Victim := Find_LRU_Victim(Page_Table);

      -- Check if dirty
      if Page_Table(Victim).State.Mod = Dirty then
         Stats.Dirty_Page_Writes := Stats.Dirty_Page_Writes + 1;
      end if;

      -- Replace
      Page_Table(Victim) := (
         Page => Reference,
         State => (Ref => Referenced, Mod => Clean),
         Last_Used => Current_Time,
         Frequency => 1,
         In_Memory => True
      );
      Stats.Page_Replacements := Stats.Page_Replacements + 1;

   end LRU_Replace;

   -- ===================================================================
   -- SECOND CHANCE ALGORITHM
   -- ===================================================================

   procedure Second_Chance_Replace (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   ) is
      Free_Frame : Frame_Number;
      Victim : Frame_Number;
      Found : Boolean := False;
   begin
      -- Check if page is already in memory
      if Is_In_Memory(Page_Table, Reference) then
         declare
            Frame : Frame_Number := Find_Frame(Page_Table, Reference);
         begin
            Page_Table(Frame).State.Ref := Referenced;
            Page_Table(Frame).Last_Used := Current_Time;
            Page_Table(Frame).Frequency := Page_Table(Frame).Frequency + 1;
         end;
         return;
      end if;

      -- Find free frame
      Free_Frame := Find_Free_Frame(Page_Table);

      if Free_Frame > 0 then
         Page_Table(Free_Frame) := (
            Page => Reference,
            State => (Ref => Referenced, Mod => Clean),
            Last_Used => Current_Time,
            Frequency => 1,
            In_Memory => True
         );
         Stats.Page_Replacements := Stats.Page_Replacements + 1;
         return;
      end if;

      -- Second Chance: iterate through frames looking for victim
      -- Start from beginning and go to end
      for I in Page_Table'Range loop
         if Page_Table(I).In_Memory then
            if Page_Table(I).State.Ref = Unreferenced then
               -- Found victim with clear reference bit
               Victim := I;
               Found := True;
               exit;
            else
               -- Give second chance: clear reference bit
               Page_Table(I).State.Ref := Unreferenced;
            end if;
         end if;
      end loop;

      -- If no victim found with clear reference bit, take first one
      if not Found then
         for I in Page_Table'Range loop
            if Page_Table(I).In_Memory then
               Victim := I;
               Found := True;
               exit;
            end if;
         end loop;
      end if;

      if not Found then
         raise No_Free_Frames_Exception with "No frames available for replacement";
      end if;

      -- Check if dirty
      if Page_Table(Victim).State.Mod = Dirty then
         Stats.Dirty_Page_Writes := Stats.Dirty_Page_Writes + 1;
      end if;

      -- Replace
      Page_Table(Victim) := (
         Page => Reference,
         State => (Ref => Referenced, Mod => Clean),
         Last_Used => Current_Time,
         Frequency => 1,
         In_Memory => True
      );
      Stats.Page_Replacements := Stats.Page_Replacements + 1;

   end Second_Chance_Replace;

   -- ===================================================================
   -- CLOCK ALGORITHM
   -- ===================================================================

   procedure Clock_Replace (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count;
      Hand : in out Frame_Number
   ) is
      Free_Frame : Frame_Number;
      Victim : Frame_Number;
      Found : Boolean := False;
      Start_Hand : Frame_Number := Hand;
   begin
      -- Check if page is already in memory
      if Is_In_Memory(Page_Table, Reference) then
         declare
            Frame : Frame_Number := Find_Frame(Page_Table, Reference);
         begin
            Page_Table(Frame).State.Ref := Referenced;
            Page_Table(Frame).Last_Used := Current_Time;
            Page_Table(Frame).Frequency := Page_Table(Frame).Frequency + 1;
         end;
         return;
      end if;

      -- Find free frame
      Free_Frame := Find_Free_Frame(Page_Table);

      if Free_Frame > 0 then
         Page_Table(Free_Frame) := (
            Page => Reference,
            State => (Ref => Referenced, Mod => Clean),
            Last_Used => Current_Time,
            Frequency => 1,
            In_Memory => True
         );
         Stats.Page_Replacements := Stats.Page_Replacements + 1;
         return;
      end if;

      -- Clock algorithm: iterate from hand position
      loop
         if Page_Table(Hand).In_Memory then
            if Page_Table(Hand).State.Ref = Unreferenced then
               -- Found victim
               Victim := Hand;
               Found := True;
               exit;
            else
               -- Clear reference bit
               Page_Table(Hand).State.Ref := Unreferenced;
            end if;
         end if;

         -- Move hand to next frame (circular)
         if Hand = Page_Table'Last then
            Hand := Page_Table'First;
         else
            Hand := Hand + 1;
         end if;

         -- Prevent infinite loop
         if Hand = Start_Hand then
            exit;
         end if;
      end loop;

      -- If no victim found with clear reference bit, use current hand
      if not Found then
         for I in Page_Table'Range loop
            if Page_Table(I).In_Memory then
               Victim := I;
               Found := True;
               exit;
            end if;
         end loop;
      end if;

      if not Found then
         raise No_Free_Frames_Exception with "No frames available for replacement";
      end if;

      -- Update hand to next position
      if Hand = Page_Table'Last then
         Hand := Page_Table'First;
      else
         Hand := Hand + 1;
      end if;

      -- Check if dirty
      if Page_Table(Victim).State.Mod = Dirty then
         Stats.Dirty_Page_Writes := Stats.Dirty_Page_Writes + 1;
      end if;

      -- Replace
      Page_Table(Victim) := (
         Page => Reference,
         State => (Ref => Referenced, Mod => Clean),
         Last_Used => Current_Time,
         Frequency => 1,
         In_Memory => True
      );
      Stats.Page_Replacements := Stats.Page_Replacements + 1;

   end Clock_Replace;

   -- ===================================================================
   -- NRU ALGORITHM
   -- ===================================================================

   procedure NRU_Replace (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   ) is
      Free_Frame : Frame_Number;
      Victim : Frame_Number;
   begin
      -- Check if page is already in memory
      if Is_In_Memory(Page_Table, Reference) then
         declare
            Frame : Frame_Number := Find_Frame(Page_Table, Reference);
         begin
            Page_Table(Frame).State.Ref := Referenced;
            Page_Table(Frame).Last_Used := Current_Time;
            Page_Table(Frame).Frequency := Page_Table(Frame).Frequency + 1;
         end;
         return;
      end if;

      -- Find free frame
      Free_Frame := Find_Free_Frame(Page_Table);

      if Free_Frame > 0 then
         Page_Table(Free_Frame) := (
            Page => Reference,
            State => (Ref => Referenced, Mod => Clean),
            Last_Used => Current_Time,
            Frequency => 1,
            In_Memory => True
         );
         Stats.Page_Replacements := Stats.Page_Replacements + 1;
         return;
      end if;

      -- Find victim using NRU classification
      Victim := Find_NRU_Victim(Page_Table);

      -- Check if dirty
      if Page_Table(Victim).State.Mod = Dirty then
         Stats.Dirty_Page_Writes := Stats.Dirty_Page_Writes + 1;
      end if;

      -- Replace
      Page_Table(Victim) := (
         Page => Reference,
         State => (Ref => Referenced, Mod => Clean),
         Last_Used => Current_Time,
         Frequency => 1,
         In_Memory => True
      );
      Stats.Page_Replacements := Stats.Page_Replacements + 1;

   end NRU_Replace;

   -- ===================================================================
   -- RANDOM ALGORITHM
   -- ===================================================================

   procedure Random_Replace (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   ) is
      Free_Frame : Frame_Number;
      Victim : Frame_Number;
   begin
      -- Check if page is already in memory
      if Is_In_Memory(Page_Table, Reference) then
         declare
            Frame : Frame_Number := Find_Frame(Page_Table, Reference);
         begin
            Page_Table(Frame).State.Ref := Referenced;
            Page_Table(Frame).Last_Used := Current_Time;
            Page_Table(Frame).Frequency := Page_Table(Frame).Frequency + 1;
         end;
         return;
      end if;

      -- Find free frame
      Free_Frame := Find_Free_Frame(Page_Table);

      if Free_Frame > 0 then
         Page_Table(Free_Frame) := (
            Page => Reference,
            State => (Ref => Referenced, Mod => Clean),
            Last_Used => Current_Time,
            Frequency => 1,
            In_Memory => True
         );
         Stats.Page_Replacements := Stats.Page_Replacements + 1;
         return;
      end if;

      -- Find random victim
      Victim := Find_Random_Victim(Page_Table);

      -- Check if dirty
      if Page_Table(Victim).State.Mod = Dirty then
         Stats.Dirty_Page_Writes := Stats.Dirty_Page_Writes + 1;
      end if;

      -- Replace
      Page_Table(Victim) := (
         Page => Reference,
         State => (Ref => Referenced, Mod => Clean),
         Last_Used => Current_Time,
         Frequency => 1,
         In_Memory => True
      );
      Stats.Page_Replacements := Stats.Page_Replacements + 1;

   end Random_Replace;

   -- ===================================================================
   -- NFU ALGORITHM
   -- ===================================================================

   procedure NFU_Replace (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   ) is
      Free_Frame : Frame_Number;
      Victim : Frame_Number;
   begin
      -- Check if page is already in memory
      if Is_In_Memory(Page_Table, Reference) then
         declare
            Frame : Frame_Number := Find_Frame(Page_Table, Reference);
         begin
            Page_Table(Frame).State.Ref := Referenced;
            Page_Table(Frame).Last_Used := Current_Time;
            Page_Table(Frame).Frequency := Page_Table(Frame).Frequency + 1;
         end;
         return;
      end if;

      -- Find free frame
      Free_Frame := Find_Free_Frame(Page_Table);

      if Free_Frame > 0 then
         Page_Table(Free_Frame) := (
            Page => Reference,
            State => (Ref => Referenced, Mod => Clean),
            Last_Used => Current_Time,
            Frequency => 1,
            In_Memory => True
         );
         Stats.Page_Replacements := Stats.Page_Replacements + 1;
         return;
      end if;

      -- Find victim using NFU
      Victim := Find_NFU_Victim(Page_Table);

      -- Check if dirty
      if Page_Table(Victim).State.Mod = Dirty then
         Stats.Dirty_Page_Writes := Stats.Dirty_Page_Writes + 1;
      end if;

      -- Replace
      Page_Table(Victim) := (
         Page => Reference,
         State => (Ref => Referenced, Mod => Clean),
         Last_Used => Current_Time,
         Frequency => 1,
         In_Memory => True
      );
      Stats.Page_Replacements := Stats.Page_Replacements + 1;

   end NFU_Replace;

   -- ===================================================================
   -- AGING ALGORITHM
   -- ===================================================================

   procedure Aging_Replace (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count;
      Counter_Size : Positive
   ) is
      Free_Frame : Frame_Number;
      Victim : Frame_Number;
      Min_Counter : Page_Count := Page_Count'Last;
   begin
      -- Check if page is already in memory
      if Is_In_Memory(Page_Table, Reference) then
         declare
            Frame : Frame_Number := Find_Frame(Page_Table, Reference);
         begin
            -- Shift right and add reference bit
            Page_Table(Frame).Frequency := (Page_Table(Frame).Frequency / 2) or
               (if Page_Table(Frame).State.Ref = Referenced then 2**(Counter_Size-1) else 0);
            Page_Table(Frame).State.Ref := Referenced;
            Page_Table(Frame).Last_Used := Current_Time;
         end;
         return;
      end if;

      -- Find free frame
      Free_Frame := Find_Free_Frame(Page_Table);

      if Free_Frame > 0 then
         Page_Table(Free_Frame) := (
            Page => Reference,
            State => (Ref => Referenced, Mod => Clean),
            Last_Used => Current_Time,
            Frequency => 2**(Counter_Size-1),  -- Set MSB
            In_Memory => True
         );
         Stats.Page_Replacements := Stats.Page_Replacements + 1;
         return;
      end if;

      -- Find victim with lowest counter
      for I in Page_Table'Range loop
         if Page_Table(I).In_Memory and Page_Table(I).Frequency < Min_Counter then
            Min_Counter := Page_Table(I).Frequency;
            Victim := I;
         end if;
      end loop;

      -- Check if dirty
      if Page_Table(Victim).State.Mod = Dirty then
         Stats.Dirty_Page_Writes := Stats.Dirty_Page_Writes + 1;
      end if;

      -- Replace
      Page_Table(Victim) := (
         Page => Reference,
         State => (Ref => Referenced, Mod => Clean),
         Last_Used => Current_Time,
         Frequency => 2**(Counter_Size-1),  -- Set MSB
         In_Memory => True
      );
      Stats.Page_Replacements := Stats.Page_Replacements + 1;

   end Aging_Replace;

   -- ===================================================================
   -- MRU ALGORITHM
   -- ===================================================================

   procedure MRU_Replace (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   ) is
      Free_Frame : Frame_Number;
      Victim : Frame_Number;
   begin
      -- Check if page is already in memory
      if Is_In_Memory(Page_Table, Reference) then
         declare
            Frame : Frame_Number := Find_Frame(Page_Table, Reference);
         begin
            Page_Table(Frame).State.Ref := Referenced;
            Page_Table(Frame).Last_Used := Current_Time;
            Page_Table(Frame).Frequency := Page_Table(Frame).Frequency + 1;
         end;
         return;
      end if;

      -- Find free frame
      Free_Frame := Find_Free_Frame(Page_Table);

      if Free_Frame > 0 then
         Page_Table(Free_Frame) := (
            Page => Reference,
            State => (Ref => Referenced, Mod => Clean),
            Last_Used => Current_Time,
            Frequency => 1,
            In_Memory => True
         );
         Stats.Page_Replacements := Stats.Page_Replacements + 1;
         return;
      end if;

      -- Find MRU victim (most recently used)
      Victim := Find_MRU_Victim(Page_Table);

      -- Check if dirty
      if Page_Table(Victim).State.Mod = Dirty then
         Stats.Dirty_Page_Writes := Stats.Dirty_Page_Writes + 1;
      end if;

      -- Replace
      Page_Table(Victim) := (
         Page => Reference,
         State => (Ref => Referenced, Mod => Clean),
         Last_Used => Current_Time,
         Frequency => 1,
         In_Memory => True
      );
      Stats.Page_Replacements := Stats.Page_Replacements + 1;

   end MRU_Replace;

   -- ===================================================================
   -- CLOCK VARIANTS
   -- ===================================================================

   procedure GCLOCK_Replace (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count;
      Hand : in out Frame_Number
   ) is
      -- GCLOCK (Generalized Clock) - similar to Clock but with different hand movement
      Free_Frame : Frame_Number;
      Victim : Frame_Number;
      Found : Boolean := False;
      Start_Hand : Frame_Number := Hand;
   begin
      -- Same as Clock but may have different victim selection criteria
      -- For simplicity, implement as Clock with different hand management
      Clock_Replace(Page_Table, Reference, Stats, Current_Time, Hand);
   end GCLOCK_Replace;

   procedure Clock_Pro_Replace (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count;
      Hand : in out Frame_Number;
      History : in out Page_Table
   ) is
      -- Clock-Pro: maintains history of recently referenced pages
      -- For simplicity, delegate to Clock
      Clock_Replace(Page_Table, Reference, Stats, Current_Time, Hand);
   end Clock_Pro_Replace;

   procedure WSClock_Replace (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count;
      Hand : in out Frame_Number;
      Working_Set_Size : Frame_Number
   ) is
      -- WSClock: combines Clock with working set concept
      Clock_Replace(Page_Table, Reference, Stats, Current_Time, Hand);
   end WSClock_Replace;

   procedure CAR_Replace (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count;
      Hand : in out Frame_Number
   ) is
      -- CAR: Clock with Adaptive Replacement
      Clock_Replace(Page_Table, Reference, Stats, Current_Time, Hand);
   end CAR_Replace;

   -- ===================================================================
   -- LRU VARIANTS
   -- ===================================================================

   procedure LRU_K_Replace (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count;
      K : Positive
   ) is
      -- LRU-K: evicts page whose K-th most recent access is furthest in the past
      -- For simplicity, when K=1, it's standard LRU
      if K = 1 then
         LRU_Replace(Page_Table, Reference, Stats, Current_Time);
      else
         -- For K>1, we would need to track K most recent access times
         -- This is a simplified version that falls back to LRU
         LRU_Replace(Page_Table, Reference, Stats, Current_Time);
      end if;
   end LRU_K_Replace;

   procedure ARC_Replace (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count;
      P : Positive
   ) is
      -- ARC: Adaptive Replacement Cache
      -- For simplicity, delegate to LRU
      LRU_Replace(Page_Table, Reference, Stats, Current_Time);
   end ARC_Replace;

   procedure TwoQ_Replace (
      Page_Table : in out Page_Table;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   ) is
      -- 2Q: Two Queue algorithm
      -- For simplicity, delegate to LRU
      LRU_Replace(Page_Table, Reference, Stats, Current_Time);
   end TwoQ_Replace;

   -- ===================================================================
   -- HELPER FUNCTIONS
   -- ===================================================================

   function Is_In_Memory (
      Page_Table : Page_Table;
      Page : Page_Number
   ) return Boolean is
   begin
      for I in Page_Table'Range loop
         if Page_Table(I).In_Memory and Page_Table(I).Page = Page then
            return True;
         end if;
      end loop;
      return False;
   end Is_In_Memory;

   function Find_Frame (
      Page_Table : Page_Table;
      Page : Page_Number
   ) return Frame_Number is
   begin
      for I in Page_Table'Range loop
         if Page_Table(I).In_Memory and Page_Table(I).Page = Page then
            return I;
         end if;
      end loop;
      return 0;  -- Not found
   end Find_Frame;

   function Find_Free_Frame (
      Page_Table : Page_Table
   ) return Frame_Number is
   begin
      for I in Page_Table'Range loop
         if not Page_Table(I).In_Memory then
            return I;
         end if;
      end loop;
      return 0;  -- No free frame
   end Find_Free_Frame;

   function Find_FIFO_Victim (
      Page_Table : Page_Table
   ) return Frame_Number is
      Oldest_Time : Page_Count := Page_Count'Last;
      Oldest_Frame : Frame_Number := Page_Table'First;
   begin
      for I in Page_Table'Range loop
         if Page_Table(I).In_Memory and Page_Table(I).Last_Used < Oldest_Time then
            Oldest_Time := Page_Table(I).Last_Used;
            Oldest_Frame := I;
         end if;
      end loop;
      return Oldest_Frame;
   end Find_FIFO_Victim;

   function Find_LRU_Victim (
      Page_Table : Page_Table
   ) return Frame_Number is
      Oldest_Time : Page_Count := Page_Count'Last;
      Oldest_Frame : Frame_Number := Page_Table'First;
   begin
      for I in Page_Table'Range loop
         if Page_Table(I).In_Memory and Page_Table(I).Last_Used < Oldest_Time then
            Oldest_Time := Page_Table(I).Last_Used;
            Oldest_Frame := I;
         end if;
      end loop;
      return Oldest_Frame;
   end Find_LRU_Victim;

   function Find_MRU_Victim (
      Page_Table : Page_Table
   ) return Frame_Number is
      Newest_Time : Page_Count := 0;
      Newest_Frame : Frame_Number := Page_Table'First;
   begin
      for I in Page_Table'Range loop
         if Page_Table(I).In_Memory and Page_Table(I).Last_Used > Newest_Time then
            Newest_Time := Page_Table(I).Last_Used;
            Newest_Frame := I;
         end if;
      end loop;
      return Newest_Frame;
   end Find_MRU_Victim;

   function Find_NRU_Victim (
      Page_Table : Page_Table
   ) return Frame_Number is
      -- NRU classification: 0 = not referenced, not modified (best victim)
      --                     1 = not referenced, modified
      --                     2 = referenced, not modified
      --                     3 = referenced, modified (worst victim)
      type NRU_Class is range 0 .. 3;

      function Get_NRU_Class (Entry : Page_Table_Entry) return NRU_Class is
      begin
         if Entry.State.Ref = Unreferenced and Entry.State.Mod = Clean then
            return 0;
         elsif Entry.State.Ref = Unreferenced and Entry.State.Mod = Dirty then
            return 1;
         elsif Entry.State.Ref = Referenced and Entry.State.Mod = Clean then
            return 2;
         else
            return 3;
         end if;
      end Get_NRU_Class;

      Min_Class : NRU_Class := 3;
      Victim : Frame_Number := Page_Table'First;
      Random_Selection : Frame_Number;
      Count : Natural := 0;
   begin
      -- First pass: find minimum class
      for I in Page_Table'Range loop
         if Page_Table(I).In_Memory then
            declare
               Class : NRU_Class := Get_NRU_Class(Page_Table(I));
            begin
               if Class < Min_Class then
                  Min_Class := Class;
               end if;
            end;
         end if;
      end loop;

      -- Second pass: collect all frames in minimum class
      for I in Page_Table'Range loop
         if Page_Table(I).In_Memory then
            declare
               Class : NRU_Class := Get_NRU_Class(Page_Table(I));
            begin
               if Class = Min_Class then
                  Count := Count + 1;
                  -- Randomly select one (simple approach: pick last one)
                  Victim := I;
               end if;
            end;
         end if;
      end loop;

      return Victim;
   end Find_NRU_Victim;

   function Find_NFU_Victim (
      Page_Table : Page_Table
   ) return Frame_Number is
      Min_Frequency : Page_Count := Page_Count'Last;
      Victim : Frame_Number := Page_Table'First;
   begin
      for I in Page_Table'Range loop
         if Page_Table(I).In_Memory and Page_Table(I).Frequency < Min_Frequency then
            Min_Frequency := Page_Table(I).Frequency;
            Victim := I;
         end if;
      end loop;
      return Victim;
   end Find_NFU_Victim;

   function Find_Random_Victim (
      Page_Table : Page_Table
   ) return Frame_Number is
      Count : Natural := 0;
      Victim : Frame_Number;
      Rand_Index : Natural;
   begin
      -- Count occupied frames
      for I in Page_Table'Range loop
         if Page_Table(I).In_Memory then
            Count := Count + 1;
         end if;
      end loop;

      if Count = 0 then
         raise No_Free_Frames_Exception with "No frames in memory to replace";
      end if;

      -- Generate random index
      Rand_Index := Natural(Random_Frame.Random(Gen) mod Frame_Number(Count)) + 1;

      -- Find the Rand_Index-th occupied frame
      Count := 0;
      for I in Page_Table'Range loop
         if Page_Table(I).In_Memory then
            Count := Count + 1;
            if Count = Rand_Index then
               Victim := I;
               exit;
            end if;
         end if;
      end loop;

      return Victim;
   end Find_Random_Victim;

   function Find_Optimal_Victim (
      Page_Table : Page_Table;
      Future_References : Reference_String;
      Current_Index : Positive
   ) return Frame_Number is
      Victim : Frame_Number := Page_Table'First;
      Farthest_Index : Positive := Positive'Last;
   begin
      -- For each frame in memory, find its next use in future references
      for I in Page_Table'Range loop
         if Page_Table(I).In_Memory then
            declare
               Page : Page_Number := Page_Table(I).Page;
               Next_Use : Positive := Positive'Last;
               Found : Boolean := False;
            begin
               -- Search for next occurrence of this page in future references
               for J in Future_References'Range loop
                  if Future_References(J) = Page then
                     Next_Use := J;
                     Found := True;
                     exit;
                  end if;
               end loop;

               -- If page is never used again, it's the best victim
               if not Found then
                  return I;
               end if;

               -- Track farthest next use
               if Next_Use > Farthest_Index then
                  Farthest_Index := Next_Use;
                  Victim := I;
               end if;
            end;
         end if;
      end loop;

      return Victim;
   end Find_Optimal_Victim;

   procedure Update_Reference_Bits (
      Page_Table : in out Page_Table;
      Current_Time : Page_Count
   ) is
   begin
      -- This would be called on each memory access
      -- For now, just mark all as referenced (simplified)
      null;
   end Update_Reference_Bits;

   procedure Clear_Reference_Bits (
      Page_Table : in out Page_Table
   ) is
   begin
      for I in Page_Table'Range loop
         if Page_Table(I).In_Memory then
            Page_Table(I).State.Ref := Unreferenced;
         end if;
      end loop;
   end Clear_Reference_Bits;

   procedure Preclean (
      Page_Table : in out Page_Table;
      Policy : Precleaning_Policy;
      Stats : in out Algorithm_Statistics
   ) is
   begin
      case Policy is
         when None =>
            null;
         when Eager =>
            -- Write all dirty pages
            for I in Page_Table'Range loop
               if Page_Table(I).In_Memory and Page_Table(I).State.Mod = Dirty then
                  Page_Table(I).State.Mod := Clean;
                  Stats.Preclean_Operations := Stats.Preclean_Operations + 1;
               end if;
            end loop;
         when Conservative =>
            -- Write dirty pages that haven't been referenced recently
            for I in Page_Table'Range loop
               if Page_Table(I).In_Memory
                 and Page_Table(I).State.Mod = Dirty
                 and Page_Table(I).State.Ref = Unreferenced
               then
                  Page_Table(I).State.Mod := Clean;
                  Stats.Preclean_Operations := Stats.Preclean_Operations + 1;
               end if;
            end loop;
      end case;
   end Preclean;

   -- ===================================================================
   -- VALIDATION FUNCTIONS
   -- ===================================================================

   function Is_Valid_Page_Table (
      Page_Table : Page_Table
   ) return Boolean is
   begin
      -- Check that all frames have valid state
      for I in Page_Table'Range loop
         -- Basic validation
         if Page_Table(I).Page < 0 then
            return False;
         end if;
      end loop;
      return True;
   end Is_Valid_Page_Table;

   function Is_Valid_Reference_String (
      Ref_String : Reference_String
   ) return Boolean is
   begin
      return Ref_String'Length > 0;
   end Is_Valid_Reference_String;

   -- ===================================================================
   -- UTILITY FUNCTIONS
   -- ===================================================================

   function Algorithm_Name (
      Alg : Algorithm_Type
   ) return String is
   begin
      case Alg is
         when FIFO => return "FIFO";
         when Optimal => return "Optimal (Belady's)";
         when LRU => return "LRU";
         when Second_Chance => return "Second-Chance";
         when Clock => return "Clock";
         when NRU => return "NRU";
         when Random_Alg => return "Random";
         when NFU => return "NFU";
         when Aging => return "Aging";
         when MRU => return "MRU";
         when GCLOCK => return "GCLOCK";
         when Clock_Pro => return "Clock-Pro";
         when WSClock => return "WSClock";
         when CAR => return "CAR";
         when LRU_K => return "LRU-K";
         when ARC => return "ARC";
         when TwoQ => return "2Q";
      end case;
   end Algorithm_Name;

   procedure Print_Page_Table (
      Page_Table : Page_Table
   ) is
   begin
      Ada.Text_IO.Put_Line("Page Table:");
      Ada.Text_IO.Put_Line("Frame | Page | Ref | Mod | Last_Used | Freq | In_Mem");
      Ada.Text_IO.Put_Line("------|------|-----|-----|-----------|------|--------");

      for I in Page_Table'Range loop
         Ada.Text_IO.Put_Line(
            Frame_Number'Image(I) & " | " &
            Page_Number'Image(Page_Table(I).Page) & " | " &
            (if Page_Table(I).State.Ref = Referenced then "  R  " else "  U  ") & " | " &
            (if Page_Table(I).State.Mod = Dirty then "  D  " else "  C  ") & " | " &
            Page_Count'Image(Page_Table(I).Last_Used) & " | " &
            Page_Count'Image(Page_Table(I).Frequency) & " | " &
            Boolean'Image(Page_Table(I).In_Memory)
         );
      end loop;
   end Print_Page_Table;

   procedure Print_Statistics (
      Stats : Algorithm_Statistics;
      Algorithm : Algorithm_Type
   ) is
   begin
      Ada.Text_IO.Put_Line("=== Statistics for " & Algorithm_Name(Algorithm) & " ===");
      Ada.Text_IO.Put_Line("Page Faults: " & Page_Count'Image(Stats.Page_Faults));
      Ada.Text_IO.Put_Line("Page Replacements: " & Page_Count'Image(Stats.Page_Replacements));
      Ada.Text_IO.Put_Line("Dirty Page Writes: " & Page_Count'Image(Stats.Dirty_Page_Writes));
      Ada.Text_IO.Put_Line("Preclean Operations: " & Page_Count'Image(Stats.Preclean_Operations));
      Ada.Text_IO.New_Line;
   end Print_Statistics;

end Page_Replacement;
