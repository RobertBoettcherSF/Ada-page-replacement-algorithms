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
   -- HELPER FUNCTIONS
   -- ===================================================================

   function Is_In_Memory (
      The_Page_Table : Page_Table_Type;
      Page : Page_Number
   ) return Boolean is
   begin
      for I in The_Page_Table'Range loop
         if The_Page_Table(I).In_Memory and The_Page_Table(I).Page = Page then
            return True;
         end if;
      end loop;
      return False;
   end Is_In_Memory;

   function Find_Frame (
      The_Page_Table : Page_Table_Type;
      Page : Page_Number
   ) return Frame_Number is
   begin
      for I in The_Page_Table'Range loop
         if The_Page_Table(I).In_Memory and The_Page_Table(I).Page = Page then
            return I;
         end if;
      end loop;
      return 0;
   end Find_Frame;

   function Find_Free_Frame (
      The_Page_Table : Page_Table_Type
   ) return Frame_Number is
   begin
      for I in The_Page_Table'Range loop
         if not The_Page_Table(I).In_Memory then
            return I;
         end if;
      end loop;
      return 0;
   end Find_Free_Frame;

   function Find_FIFO_Victim (
      The_Page_Table : Page_Table_Type
   ) return Frame_Number is
      Oldest_Time : Page_Count := Page_Count'Last;
      Oldest_Frame : Frame_Number := The_Page_Table'First;
   begin
      for I in The_Page_Table'Range loop
         if The_Page_Table(I).In_Memory and The_Page_Table(I).Last_Used < Oldest_Time then
            Oldest_Time := The_Page_Table(I).Last_Used;
            Oldest_Frame := I;
         end if;
      end loop;
      return Oldest_Frame;
   end Find_FIFO_Victim;

   function Find_LRU_Victim (
      The_Page_Table : Page_Table_Type
   ) return Frame_Number is
      Oldest_Time : Page_Count := Page_Count'Last;
      Oldest_Frame : Frame_Number := The_Page_Table'First;
   begin
      for I in The_Page_Table'Range loop
         if The_Page_Table(I).In_Memory and The_Page_Table(I).Last_Used < Oldest_Time then
            Oldest_Time := The_Page_Table(I).Last_Used;
            Oldest_Frame := I;
         end if;
      end loop;
      return Oldest_Frame;
   end Find_LRU_Victim;

   function Find_MRU_Victim (
      The_Page_Table : Page_Table_Type
   ) return Frame_Number is
      Newest_Time : Page_Count := 0;
      Newest_Frame : Frame_Number := The_Page_Table'First;
   begin
      for I in The_Page_Table'Range loop
         if The_Page_Table(I).In_Memory and The_Page_Table(I).Last_Used > Newest_Time then
            Newest_Time := The_Page_Table(I).Last_Used;
            Newest_Frame := I;
         end if;
      end loop;
      return Newest_Frame;
   end Find_MRU_Victim;

   function Find_NRU_Victim (
      The_Page_Table : Page_Table_Type
   ) return Frame_Number is
      type NRU_Class is range 0 .. 3;

      function Get_NRU_Class (Entry : Page_Table_Entry) return NRU_Class is
      begin
         if Entry.State.Ref = Unreferenced and Entry.State.Modified = Clean then
            return 0;
         elsif Entry.State.Ref = Unreferenced and Entry.State.Modified = Dirty then
            return 1;
         elsif Entry.State.Ref = Referenced and Entry.State.Modified = Clean then
            return 2;
         else
            return 3;
         end if;
      end Get_NRU_Class;

      Min_Class : NRU_Class := 3;
      Victim : Frame_Number := The_Page_Table'First;
   begin
      for I in The_Page_Table'Range loop
         if The_Page_Table(I).In_Memory then
            declare
               Class : NRU_Class := Get_NRU_Class(The_Page_Table(I));
            begin
               if Class < Min_Class then
                  Min_Class := Class;
               end if;
            end;
         end if;
      end loop;

      for I in The_Page_Table'Range loop
         if The_Page_Table(I).In_Memory then
            declare
               Class : NRU_Class := Get_NRU_Class(The_Page_Table(I));
            begin
               if Class = Min_Class then
                  Victim := I;
               end if;
            end;
         end if;
      end loop;

      return Victim;
   end Find_NRU_Victim;

   function Find_NFU_Victim (
      The_Page_Table : Page_Table_Type
   ) return Frame_Number is
      Min_Frequency : Page_Count := Page_Count'Last;
      Victim : Frame_Number := The_Page_Table'First;
   begin
      for I in The_Page_Table'Range loop
         if The_Page_Table(I).In_Memory and The_Page_Table(I).Frequency < Min_Frequency then
            Min_Frequency := The_Page_Table(I).Frequency;
            Victim := I;
         end if;
      end loop;
      return Victim;
   end Find_NFU_Victim;

   function Find_Random_Victim (
      The_Page_Table : Page_Table_Type
   ) return Frame_Number is
      Count : Natural := 0;
      Victim : Frame_Number;
      Rand_Index : Natural;
   begin
      for I in The_Page_Table'Range loop
         if The_Page_Table(I).In_Memory then
            Count := Count + 1;
         end if;
      end loop;

      if Count = 0 then
         raise No_Free_Frames_Exception;
      end if;

      Rand_Index := Natural(Random_Frame.Random(Gen) mod Frame_Number(Count)) + 1;

      Count := 0;
      for I in The_Page_Table'Range loop
         if The_Page_Table(I).In_Memory then
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
      The_Page_Table : Page_Table_Type;
      Future_References : Reference_String_Type;
      Current_Index : Positive
   ) return Frame_Number is
      Victim : Frame_Number := The_Page_Table'First;
      Farthest_Index : Positive := Positive'Last;
   begin
      for I in The_Page_Table'Range loop
         if The_Page_Table(I).In_Memory then
            declare
               Page : Page_Number := The_Page_Table(I).Page;
               Next_Use : Positive := Positive'Last;
               Found : Boolean := False;
            begin
               for J in Future_References'Range loop
                  if Future_References(J) = Page then
                     Next_Use := J;
                     Found := True;
                     exit;
                  end if;
               end loop;

               if not Found then
                  return I;
               end if;

               if Next_Use > Farthest_Index then
                  Farthest_Index := Next_Use;
                  Victim := I;
               end if;
            end;
         end if;
      end loop;

      return Victim;
   end Find_Optimal_Victim;

   procedure Clear_Reference_Bits (
      The_Page_Table : in out Page_Table_Type
   ) is
   begin
      for I in The_Page_Table'Range loop
         if The_Page_Table(I).In_Memory then
            The_Page_Table(I).State.Ref := Unreferenced;
         end if;
      end loop;
   end Clear_Reference_Bits;

   procedure Preclean (
      The_Page_Table : in out Page_Table_Type;
      Policy : Precleaning_Policy;
      Stats : in out Algorithm_Statistics
   ) is
   begin
      case Policy is
         when None => null;
         when Eager =>
            for I in The_Page_Table'Range loop
               if The_Page_Table(I).In_Memory and The_Page_Table(I).State.Modified = Dirty then
                  The_Page_Table(I).State.Modified := Clean;
                  Stats.Preclean_Operations := Stats.Preclean_Operations + 1;
               end if;
            end loop;
         when Conservative =>
            for I in The_Page_Table'Range loop
               if The_Page_Table(I).In_Memory
                 and The_Page_Table(I).State.Modified = Dirty
                 and The_Page_Table(I).State.Ref = Unreferenced
               then
                  The_Page_Table(I).State.Modified := Clean;
                  Stats.Preclean_Operations := Stats.Preclean_Operations + 1;
               end if;
            end loop;
      end case;
   end Preclean;

   -- ===================================================================
   -- ALGORITHM IMPLEMENTATIONS
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

      if not Found then
         raise No_Free_Frames_Exception;
      end if;

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
      if Is_In_Memory(The_Page_Table
