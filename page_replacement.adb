--  page_replacement.adb
--
--  Package body for Page Replacement Algorithms
--  Complete implementation of all algorithms from Wikipedia
--
--  Author: Robert Boettcher
--  Date: July 29, 2026
--

with Ada.Text_IO;
with Ada.Numerics.Discrete_Random;

package body Page_Replacement is

   package Random_Frame is new Ada.Numerics.Discrete_Random (Frame_Number);
   Gen : Random_Frame.Generator;

   -- ===================================================================
   -- INITIALIZATION
   -- ===================================================================

   procedure Initialize (
      The_Page_Table : out Page_Table_Type;
      Num_Frames : Frame_Number
   ) is
   begin
      for I in The_Page_Table'Range loop
         The_Page_Table(I) := (
            Page => 0,
            State => (Ref => Unreferenced, Modified => Clean),
            Last_Used => 0,
            Frequency => 0,
            In_Memory => False
         );
      end loop;
      Random_Frame.Reset(Gen);
   end Initialize;

   -- ===================================================================
   -- MAIN PROCESS REFERENCE
   -- ===================================================================

   procedure Process_Reference (
      The_Page_Table : in out Page_Table_Type;
      Reference : Page_Number;
      Algorithm : Algorithm_Type;
      Params : Algorithm_Parameters;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   ) is
      Hand : Frame_Number := The_Page_Table'First;
      History : Page_Table_Type(The_Page_Table'Range);
   begin
      if not Is_In_Memory(The_Page_Table, Reference) then
         Stats.Page_Faults := Stats.Page_Faults + 1;
      end if;

      case Algorithm is
         when FIFO => FIFO_Replace(The_Page_Table, Reference, Stats, Current_Time);
         when Optimal => raise Future_Knowledge_Required;
         when LRU => LRU_Replace(The_Page_Table, Reference, Stats, Current_Time);
         when Second_Chance => Second_Chance_Replace(The_Page_Table, Reference, Stats, Current_Time);
         when Clock => Clock_Replace(The_Page_Table, Reference, Stats, Current_Time, Hand);
         when NRU =>
            if Current_Time mod 100 = 0 then Clear_Reference_Bits(The_Page_Table); end if;
            NRU_Replace(The_Page_Table, Reference, Stats, Current_Time);
         when Random_Alg => Random_Replace(The_Page_Table, Reference, Stats, Current_Time);
         when NFU => NFU_Replace(The_Page_Table, Reference, Stats, Current_Time);
         when Aging => Aging_Replace(The_Page_Table, Reference, Stats, Current_Time, Params.Aging_Counter_Size);
         when MRU => MRU_Replace(The_Page_Table, Reference, Stats, Current_Time);
         when GCLOCK => GCLOCK_Replace(The_Page_Table, Reference, Stats, Current_Time, Hand);
         when Clock_Pro => Clock_Pro_Replace(The_Page_Table, Reference, Stats, Current_Time, Hand, History);
         when WSClock => WSClock_Replace(The_Page_Table, Reference, Stats, Current_Time, Hand, Params.Clock_Size);
         when CAR => CAR_Replace(The_Page_Table, Reference, Stats, Current_Time, Hand);
         when LRU_K => LRU_K_Replace(The_Page_Table, Reference, Stats, Current_Time, Params.K_Value);
         when ARC => ARC_Replace(The_Page_Table, Reference, Stats, Current_Time, Params.Clock_Size);
         when TwoQ => TwoQ_Replace(The_Page_Table, Reference, Stats, Current_Time);
      end case;

      if Params.Preclean /= None then Preclean(The_Page_Table, Params.Preclean, Stats); end if;
   end Process_Reference;

   -- ===================================================================
   -- SIMULATE
   -- ===================================================================

   procedure Simulate (
      The_References : Reference_String_Type;
      Num_Frames : Frame_Number;
      Algorithm : Algorithm_Type;
      Params : Algorithm_Parameters := Algorithm_Parameters'(Mode => Global, others => <>);
      Stats : out Algorithm_Statistics
   ) is
      The_Page_Table : Page_Table_Type(1 .. Num_Frames);
      Hand : Frame_Number := 1;
      History : Page_Table_Type(1 .. Num_Frames);
   begin
      Initialize(The_Page_Table, Num_Frames);
      Initialize(History, Num_Frames);
      Stats := (others => 0);

      for I in The_References'Range loop
         declare
            Current_Time : Page_Count := Page_Count(I);
         begin
            if Algorithm = Optimal then
               declare
                  Future_Refs : Reference_String_Type := The_References(I .. The_References'Last);
               begin
                  if not Is_In_Memory(The_Page_Table, The_References(I)) then
                     declare
                        Free_Frame : Frame_Number := Find_Free_Frame(The_Page_Table);
                     begin
                        if Free_Frame > 0 then
                           The_Page_Table(Free_Frame) := (
                              Page => The_References(I),
                              State => (Ref => Referenced, Modified => Clean),
                              Last_Used => Current_Time,
                              Frequency => 1,
                              In_Memory => True
                           );
                           Stats.Page_Replacements := Stats.Page_Replacements + 1;
                        else
                           declare
                              Victim : Frame_Number := Find_Optimal_Victim(The_Page_Table, Future_Refs, I);
                           begin
                              if The_Page_Table(Victim).State.Modified = Dirty then
                                 Stats.Dirty_Page_Writes := Stats.Dirty_Page_Writes + 1;
                              end if;
                              The_Page_Table(Victim) := (
                                 Page => The_References(I),
                                 State => (Ref => Referenced, Modified => Clean),
                                 Last_Used => Current_Time,
                                 Frequency => 1,
                                 In_Memory => True
                              );
                              Stats.Page_Replacements := Stats.Page_Replacements + 1;
                           end;
                        end if;
                     end;
                  else
                     declare
                        Frame : Frame_Number := Find_Frame(The_Page_Table, The_References(I));
                     begin
                        if Frame > 0 then
                           The_Page_Table(Frame).State.Ref := Referenced;
                           The_Page_Table(Frame).Last_Used := Current_Time;
                           The_Page_Table(Frame).Frequency := The_Page_Table(Frame).Frequency + 1;
                        end if;
                     end;
                  end if;
               end;
            else
               Process_Reference(The_Page_Table, The_References(I), Algorithm, Params, Stats, Current_Time);
            end if;
         end;
      end loop;
   end Simulate;

   -- ===================================================================
   -- FIFO
   -- ===================================================================

   procedure FIFO_Replace (
      The_Page_Table : in out Page_Table_Type;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   ) is
      Free_Frame : Frame_Number;
      Victim : Frame_Number;
   begin
      if Is_In_Memory(The_Page_Table, Reference) then
         declare
            Frame : Frame_Number := Find_Frame(The_Page_Table, Reference);
         begin
            if Frame > 0 then
               The_Page_Table(Frame).State.Ref := Referenced;
               The_Page_Table(Frame).Last_Used := Current_Time;
            end if;
         end;
         return;
      end if;

      Free_Frame := Find_Free_Frame(The_Page_Table);
      if Free_Frame > 0 then
         The_Page_Table(Free_Frame) := (
            Page => Reference,
            State => (Ref => Referenced, Modified => Clean),
            Last_Used => Current_Time,
            Frequency => 1,
            In_Memory => True
         );
         Stats.Page_Replacements := Stats.Page_Replacements + 1;
         return;
      end if;

      Victim := Find_FIFO_Victim(The_Page_Table);
      if The_Page_Table(Victim).State.Modified = Dirty then
         Stats.Dirty_Page_Writes := Stats.Dirty_Page_Writes + 1;
      end if;
      The_Page_Table(Victim) := (
         Page => Reference,
         State => (Ref => Referenced, Modified => Clean),
         Last_Used => Current_Time,
         Frequency => 1,
         In_Memory => True
      );
      Stats.Page_Replacements := Stats.Page_Replacements + 1;
   end FIFO_Replace;

   -- ===================================================================
   -- OPTIMAL
   -- ===================================================================

   procedure Optimal_Replace (
      The_Page_Table : in out Page_Table_Type;
      Reference : Page_Number;
      Future_References : Reference_String_Type;
      Current_Index : Positive;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   ) is
      Free_Frame : Frame_Number;
      Victim : Frame_Number;
   begin
      if Is_In_Memory(The_Page_Table, Reference) then
         declare
            Frame : Frame_Number := Find_Frame(The_Page_Table, Reference);
         begin
            if Frame > 0 then
               The_Page_Table(Frame).State.Ref := Referenced;
               The_Page_Table(Frame).Last_Used := Current_Time;
            end if;
         end;
         return;
      end if;

      Free_Frame := Find_Free_Frame(The_Page_Table);
      if Free_Frame > 0 then
         The_Page_Table(Free_Frame) := (
            Page => Reference,
            State => (Ref => Referenced, Modified => Clean),
            Last_Used => Current_Time,
            Frequency => 1,
            In_Memory => True
         );
         Stats.Page_Replacements := Stats.Page_Replacements + 1;
         return;
      end if;

      Victim := Find_Optimal_Victim(The_Page_Table, Future_References, Current_Index);
      if The_Page_Table(Victim).State.Modified = Dirty then
         Stats.Dirty_Page_Writes := Stats.Dirty_Page_Writes + 1;
      end if;
      The_Page_Table(Victim) := (
         Page => Reference,
         State => (Ref => Referenced, Modified => Clean),
         Last_Used => Current_Time,
         Frequency => 1,
         In_Memory => True
      );
      Stats.Page_Replacements := Stats.Page_Replacements + 1;
   end Optimal_Replace;

   -- ===================================================================
   -- LRU
   -- ===================================================================

   procedure LRU_Replace (
      The_Page_Table : in out Page_Table_Type;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   ) is
      Free_Frame : Frame_Number;
      Victim : Frame_Number;
   begin
      if Is_In_Memory(The_Page_Table, Reference) then
         declare
            Frame : Frame_Number := Find_Frame(The_Page_Table, Reference);
         begin
            if Frame > 0 then
               The_Page_Table(Frame).State.Ref := Referenced;
               The_Page_Table(Frame).Last_Used := Current_Time;
               The_Page_Table(Frame).Frequency := The_Page_Table(Frame).Frequency + 1;
            end if;
         end;
         return;
      end if;

      Free_Frame := Find_Free_Frame(The_Page_Table);
      if Free_Frame > 0 then
         The_Page_Table(Free_Frame) := (
            Page => Reference,
            State => (Ref => Referenced, Modified => Clean),
            Last_Used => Current_Time,
            Frequency => 1,
            In_Memory => True
         );
         Stats.Page_Replacements := Stats.Page_Replacements + 1;
         return;
      end if;

      Victim := Find_LRU_Victim(The_Page_Table);
      if The_Page_Table(Victim).State.Modified = Dirty then
         Stats.Dirty_Page_Writes := Stats.Dirty_Page_Writes + 1;
      end if;
      The_Page_Table(Victim) := (
         Page => Reference,
         State => (Ref => Referenced, Modified => Clean),
         Last_Used => Current_Time,
         Frequency => 1,
         In_Memory => True
      );
      Stats.Page_Replacements := Stats.Page_Replacements + 1;
   end LRU_Replace;

   -- ===================================================================
   -- SECOND CHANCE
   -- ===================================================================

   procedure Second_Chance_Replace (
      The_Page_Table : in out Page_Table_Type;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   ) is
      Free_Frame : Frame_Number;
      Victim : Frame_Number;
      Found : Boolean := False;
   begin
      if Is_In_Memory(The_Page_Table, Reference) then
         declare
            Frame : Frame_Number := Find_Frame(The_Page_Table, Reference);
         begin
            if Frame > 0 then
               The_Page_Table(Frame).State.Ref := Referenced;
               The_Page_Table(Frame).Last_Used := Current_Time;
               The_Page_Table(Frame).Frequency := The_Page_Table(Frame).Frequency + 1;
            end if;
         end;
         return;
      end if;

      Free_Frame := Find_Free_Frame(The_Page_Table);
      if Free_Frame > 0 then
         The_Page_Table(Free_Frame) := (
            Page => Reference,
            State => (Ref => Referenced, Modified => Clean),
            Last_Used => Current_Time,
            Frequency => 1,
            In_Memory => True
         );
         Stats.Page_Replacements := Stats.Page_Replacements + 1;
         return;
      end if;

      for I in The_Page_Table'Range loop
         if The_Page_Table(I).In_Memory then
            if The_Page_Table(I).State.Ref = Unreferenced then
               Victim := I;
               Found := True;
               exit;
            else
               The_Page_Table(I).State.Ref := Unreferenced;
            end if;
         end if;
      end loop;

      if not Found then
         for I in The_Page_Table'Range loop
            if The_Page_Table(I).In_Memory then
               Victim := I;
               Found := True;
               exit;
            end if;
         end loop;
      end if;

      if not Found then raise No_Free_Frames_Exception; end if;

      if The_Page_Table(Victim).State.Modified = Dirty then
         Stats.Dirty_Page_Writes := Stats.Dirty_Page_Writes + 1;
      end if;
      The_Page_Table(Victim) := (
         Page => Reference,
         State => (Ref => Referenced, Modified => Clean),
         Last_Used => Current_Time,
         Frequency => 1,
         In_Memory => True
      );
      Stats.Page_Replacements := Stats.Page_Replacements + 1;
   end Second_Chance_Replace;

   -- ===================================================================
   -- CLOCK
   -- ===================================================================

   procedure Clock_Replace (
      The_Page_Table : in out Page_Table_Type;
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
      if Is_In_Memory(The_Page_Table, Reference) then
         declare
            Frame : Frame_Number := Find_Frame(The_Page_Table, Reference);
         begin
            if Frame > 0 then
               The_Page_Table(Frame).State.Ref := Referenced;
               The_Page_Table(Frame).Last_Used := Current_Time;
               The_Page_Table(Frame).Frequency := The_Page_Table(Frame).Frequency + 1;
            end if;
         end;
         return;
      end if;

      Free_Frame := Find_Free_Frame(The_Page_Table);
      if Free_Frame > 0 then
         The_Page_Table(Free_Frame) := (
            Page => Reference,
            State => (Ref => Referenced, Modified => Clean),
            Last_Used => Current_Time,
            Frequency => 1,
            In_Memory => True
         );
         Stats.Page_Replacements := Stats.Page_Replacements + 1;
         return;
      end if;

      loop
         if The_Page_Table(Hand).In_Memory then
            if The_Page_Table(Hand).State.Ref = Unreferenced then
               Victim := Hand;
               Found := True;
               exit;
            else
               The_Page_Table(Hand).State.Ref := Unreferenced;
            end if;
         end if;

         if Hand = The_Page_Table'Last then Hand := The_Page_Table'First;
         else Hand := Hand + 1; end if;

         if Hand = Start_Hand then exit; end if;
      end loop;

      if not Found then
         for I in The_Page_Table'Range loop
            if The_Page_Table(I).In_Memory then
               Victim := I;
               Found := True;
               exit;
            end if;
         end loop;
      end if;

      if not Found then raise No_Free_Frames_Exception; end if;

      if Hand = The_Page_Table'Last then Hand := The_Page_Table'First;
      else Hand := Hand + 1; end if;

      if The_Page_Table(Victim).State.Modified = Dirty then
         Stats.Dirty_Page_Writes := Stats.Dirty_Page_Writes + 1;
      end if;
      The_Page_Table(Victim) := (
         Page => Reference,
         State => (Ref => Referenced, Modified => Clean),
         Last_Used => Current_Time,
         Frequency => 1,
         In_Memory => True
      );
      Stats.Page_Replacements := Stats.Page_Replacements + 1;
   end Clock_Replace;

   -- ===================================================================
   -- NRU
   -- ===================================================================

   procedure NRU_Replace (
      The_Page_Table : in out Page_Table_Type;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   ) is
      Free_Frame : Frame_Number;
      Victim : Frame_Number;
   begin
      if Is_In_Memory(The_Page_Table, Reference) then
         declare
            Frame : Frame_Number := Find_Frame(The_Page_Table, Reference);
         begin
            if Frame > 0 then
               The_Page_Table(Frame).State.Ref := Referenced;
               The_Page_Table(Frame).Last_Used := Current_Time;
               The_Page_Table(Frame).Frequency := The_Page_Table(Frame).Frequency + 1;
            end if;
         end;
         return;
      end if;

      Free_Frame := Find_Free_Frame(The_Page_Table);
      if Free_Frame > 0 then
         The_Page_Table(Free_Frame) := (
            Page => Reference,
            State => (Ref => Referenced, Modified => Clean),
            Last_Used => Current_Time,
            Frequency => 1,
            In_Memory => True
         );
         Stats.Page_Replacements := Stats.Page_Replacements + 1;
         return;
      end if;

      Victim := Find_NRU_Victim(The_Page_Table);
      if The_Page_Table(Victim).State.Modified = Dirty then
         Stats.Dirty_Page_Writes := Stats.Dirty_Page_Writes + 1;
      end if;
      The_Page_Table(Victim) := (
         Page => Reference,
         State => (Ref => Referenced, Modified => Clean),
         Last_Used => Current_Time,
         Frequency => 1,
         In_Memory => True
      );
      Stats.Page_Replacements := Stats.Page_Replacements + 1;
   end NRU_Replace;

   -- ===================================================================
   -- RANDOM
   -- ===================================================================

   procedure Random_Replace (
      The_Page_Table : in out Page_Table_Type;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   ) is
      Free_Frame : Frame_Number;
      Victim : Frame_Number;
   begin
      if Is_In_Memory(The_Page_Table, Reference) then
         declare
            Frame : Frame_Number := Find_Frame(The_Page_Table, Reference);
         begin
            if Frame > 0 then
               The_Page_Table(Frame).State.Ref := Referenced;
               The_Page_Table(Frame).Last_Used := Current_Time;
               The_Page_Table(Frame).Frequency := The_Page_Table(Frame).Frequency + 1;
            end if;
         end;
         return;
      end if;

      Free_Frame := Find_Free_Frame(The_Page_Table);
      if Free_Frame > 0 then
         The_Page_Table(Free_Frame) := (
            Page => Reference,
            State => (Ref => Referenced, Modified => Clean),
            Last_Used => Current_Time,
            Frequency => 1,
            In_Memory => True
         );
         Stats.Page_Replacements := Stats.Page_Replacements + 1;
         return;
      end if;

      Victim := Find_Random_Victim(The_Page_Table);
      if The_Page_Table(Victim).State.Modified = Dirty then
         Stats.Dirty_Page_Writes := Stats.Dirty_Page_Writes + 1;
      end if;
      The_Page_Table(Victim) := (
         Page => Reference,
         State => (Ref => Referenced, Modified => Clean),
         Last_Used => Current_Time,
         Frequency => 1,
         In_Memory => True
      );
      Stats.Page_Replacements := Stats.Page_Replacements + 1;
   end Random_Replace;

   -- ===================================================================
   -- NFU
   -- ===================================================================

   procedure NFU_Replace (
      The_Page_Table : in out Page_Table_Type;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   ) is
      Free_Frame : Frame_Number;
      Victim : Frame_Number;
   begin
      if Is_In_Memory(The_Page_Table, Reference) then
         declare
            Frame : Frame_Number := Find_Frame(The_Page_Table, Reference);
         begin
            if Frame > 0 then
               The_Page_Table(Frame).State.Ref := Referenced;
               The_Page_Table(Frame).Last_Used := Current_Time;
               The_Page_Table(Frame).Frequency := The_Page_Table(Frame).Frequency + 1;
            end if;
         end;
         return;
      end if;

      Free_Frame := Find_Free_Frame(The_Page_Table);
      if Free_Frame > 0 then
         The_Page_Table(Free_Frame) := (
            Page => Reference,
            State => (Ref => Referenced, Modified => Clean),
            Last_Used => Current_Time,
            Frequency => 1,
            In_Memory => True
         );
         Stats.Page_Replacements := Stats.Page_Replacements + 1;
         return;
      end if;

      Victim := Find_NFU_Victim(The_Page_Table);
      if The_Page_Table(Victim).State.Modified = Dirty then
         Stats.Dirty_Page_Writes := Stats.Dirty_Page_Writes + 1;
      end if;
      The_Page_Table(Victim) := (
         Page => Reference,
         State => (Ref => Referenced, Modified => Clean),
         Last_Used => Current_Time,
         Frequency => 1,
         In_Memory => True
      );
      Stats.Page_Replacements := Stats.Page_Replacements + 1;
   end NFU_Replace;

   -- ===================================================================
   -- AGING
   -- ===================================================================

   procedure Aging_Replace (
      The_Page_Table : in out Page_Table_Type;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count;
      Counter_Size : Positive
   ) is
      Free_Frame : Frame_Number;
      Victim : Frame_Number;
      Min_Counter : Page_Count := Page_Count'Last;
   begin
      if Is_In_Memory(The_Page_Table, Reference) then
         declare
            Frame : Frame_Number := Find_Frame(The_Page_Table, Reference);
         begin
            if Frame > 0 then
               The_Page_Table(Frame).Frequency := (The_Page_Table(Frame).Frequency / 2) or
                 (if The_Page_Table(Frame).State.Ref = Referenced then 2**(Counter_Size-1) else 0);
               The_Page_Table(Frame).State.Ref := Referenced;
               The_Page_Table(Frame).Last_Used := Current_Time;
            end if;
         end;
         return;
      end if;

      Free_Frame := Find_Free_Frame(The_Page_Table);
      if Free_Frame > 0 then
         The_Page_Table(Free_Frame) := (
            Page => Reference,
            State => (Ref => Referenced, Modified => Clean),
            Last_Used => Current_Time,
            Frequency => 2**(Counter_Size-1),
            In_Memory => True
         );
         Stats.Page_Replacements := Stats.Page_Replacements + 1;
         return;
      end if;

      for I in The_Page_Table'Range loop
         if The_Page_Table(I).In_Memory and The_Page_Table(I).Frequency < Min_Counter then
            Min_Counter := The_Page_Table(I).Frequency;
            Victim := I;
         end if;
      end loop;

      if The_Page_Table(Victim).State.Modified = Dirty then
         Stats.Dirty_Page_Writes := Stats.Dirty_Page_Writes + 1;
      end if;
      The_Page_Table(Victim) := (
         Page => Reference,
         State => (Ref => Referenced, Modified => Clean),
         Last_Used => Current_Time,
         Frequency => 2**(Counter_Size-1),
         In_Memory => True
      );
      Stats.Page_Replacements := Stats.Page_Replacements + 1;
   end Aging_Replace;

   -- ===================================================================
   -- MRU
   -- ===================================================================

   procedure MRU_Replace (
      The_Page_Table : in out Page_Table_Type;
      Reference : Page_Number;
      Stats : in out Algorithm_Statistics;
      Current_Time : Page_Count
   ) is
      Free_Frame : Frame_Number;
      Victim : Frame_Number;
   begin
      if Is_In_Memory(The_Page_Table, Reference) then
         declare
            Frame : Frame_Number := Find_Frame(The_Page_Table, Reference);
         begin
            if Frame > 0 then
               The_Page_Table(Frame).State.Ref := Referenced;
               The_Page_Table(Frame).Last_Used := Current_Time;
               The_Page_Table(Frame).Frequency := The_Page_Table(Frame).Frequency + 1;
            end if;
         end;
         return;
      end if;

      Free_Frame := Find_Free_Frame(The_Page_Table);
      if Free_Frame > 0 then
         The_Page_Table(Free_Frame) := (
            Page => Reference,
            State => (Ref => Referenced, Modified
