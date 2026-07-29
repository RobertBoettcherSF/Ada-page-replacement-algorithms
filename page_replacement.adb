--  page_replacement.adb
with Ada.Text_IO;
with Ada.Numerics.Discrete_Random;

package body Page_Replacement is

   package Random_Frame is new Ada.Numerics.Discrete_Random (Frame_Number);
   Gen : Random_Frame.Generator;

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
            In_Memory => False
         );
      end loop;
      Random_Frame.Reset(Gen);
   end Initialize;

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
      return 1;
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
      return 1;
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
   begin
      return Find_FIFO_Victim(The_Page_Table);
   end Find_LRU_Victim;

   function Find_Random_Victim (
      The_Page_Table : Page_Table_Type
   ) return Frame_Number is
      Count : Natural := 0;
      Rand_Index : Natural;
      Victim : Frame_Number := The_Page_Table'First;
   begin
      for I in The_Page_Table'Range loop
         if The_Page_Table(I).In_Memory then
            Count := Count + 1;
         end if;
      end loop;

      if Count > 0 then
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
      end if;
      return Victim;
   end Find_Random_Victim;

   function Algorithm_Name (Alg : Algorithm_Type) return String is
   begin
      case Alg is
         when FIFO => return "FIFO";
         when LRU => return "LRU";
         when Clock => return "Clock";
         when Optimal => return "Optimal";
         when NRU => return "NRU";
         when Random_Alg => return "Random";
      end case;
   end Algorithm_Name;

   procedure Simulate (
      The_References : Reference_String_Type;
      Num_Frames : Frame_Number;
      Algorithm : Algorithm_Type;
      Stats : out Algorithm_Statistics
   ) is
      The_Page_Table : Page_Table_Type(1 .. Num_Frames);
      Hand : Frame_Number := 1;
   begin
      Initialize(The_Page_Table, Num_Frames);
      Stats := (others => 0);

      for I in The_References'Range loop
         declare
            Reference : Page_Number := The_References(I);
            Current_Time : Page_Count := Page_Count(I);
            Free_Frame : Frame_Number;
            Victim : Frame_Number;
         begin
            Stats.Page_Faults := Stats.Page_Faults + 1;

            if Is_In_Memory(The_Page_Table, Reference) then
               declare
                  Frame : Frame_Number := Find_Frame(The_Page_Table, Reference);
               begin
                  The_Page_Table(Frame).State.Ref := Referenced;
                  The_Page_Table(Frame).Last_Used := Current_Time;
               end;
            else
               Free_Frame := Find_Free_Frame(The_Page_Table);
               if Free_Frame > 0 then
                  The_Page_Table(Free_Frame) := (
                     Page => Reference,
                     State => (Ref => Referenced, Modified => Clean),
                     Last_Used => Current_Time,
                     In_Memory => True
                  );
               else
                  case Algorithm is
                     when FIFO => Victim := Find_FIFO_Victim(The_Page_Table);
                     when LRU => Victim := Find_LRU_Victim(The_Page_Table);
                     when Random_Alg => Victim := Find_Random_Victim(The_Page_Table);
                     when others => Victim := Find_FIFO_Victim(The_Page_Table);
                  end case;

                  The_Page_Table(Victim) := (
                     Page => Reference,
                     State => (Ref => Referenced, Modified => Clean),
                     Last_Used => Current_Time,
                     In_Memory => True
                  );
               end if;
               Stats.Page_Replacements := Stats.Page_Replacements + 1;
            end if;
         end;
      end loop;
   end Simulate;

end Page_Replacement;
