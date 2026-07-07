package body Lector.Scan
  with SPARK_Mode
is

   Blank : constant String := " " & ASCII.HT & ASCII.LF & ASCII.CR;

   function Is_Blank (C : Character) return Boolean
   is (for some B of Blank => C = B);

   function Find
     (Text : String; Pattern : String; From : Positive) return Natural is
   begin
      if Pattern'Length = 0 or else Pattern'Length > Text'Length then
         return 0;
      end if;

      for I in
        Positive'Max (From, Text'First) .. Text'Last - Pattern'Length + 1
      loop
         if Text (I .. I + (Pattern'Length - 1)) = Pattern then
            return I;
         end if;
      end loop;
      return 0;
   end Find;

   --  Position where the value of `"Key"` + optional blanks + ':' +
   --  optional blanks starts, at or after From -- the shared prelude of
   --  every per-key scan -- or 0 when the key is absent, not followed by
   --  a colon, or the value would start past the end of Text.
   function Value_Start
     (Text : String; Key : Key_String; From : Positive) return Natural
   with
     Pre  => Text'Last < Positive'Last,
     Post =>
       Value_Start'Result = 0
       or else Value_Start'Result in Text'First .. Text'Last
   is
      Quoted : constant String := '"' & Key & '"';
      K      : constant Natural := Find (Text, Quoted, From);
      I      : Positive;
   begin
      if K = 0 or else Text'Last - K < Quoted'Length then
         --  Absent, or the key's closing quote ends the text: no room
         --  for a colon, let alone a value.
         return 0;
      end if;

      I := K + Quoted'Length;  --  just past the key's closing quote
      while I <= Text'Last and then Is_Blank (Text (I)) loop
         pragma Loop_Invariant (I in Text'First .. Text'Last);
         pragma Loop_Variant (Increases => I);
         I := I + 1;
      end loop;
      if I > Text'Last or else Text (I) /= ':' then
         return 0;
      end if;

      I := I + 1;
      while I <= Text'Last and then Is_Blank (Text (I)) loop
         pragma Loop_Invariant (I in Text'First .. Text'Last);
         pragma Loop_Variant (Increases => I);
         I := I + 1;
      end loop;
      if I > Text'Last then
         return 0;
      end if;
      return I;
   end Value_Start;

   function String_Value
     (Text : String; Key : Key_String; From : Positive) return String
   is
      I : constant Natural := Value_Start (Text, Key, From);
      J : Positive;
   begin
      if I = 0 or else Text (I) /= '"' then
         return "";
      end if;

      J := I + 1;  --  first byte of the value
      while J <= Text'Last and then Text (J) /= '"' loop
         pragma Loop_Invariant (J in Text'First .. Text'Last);
         pragma Loop_Variant (Increases => J);
         J := J + 1;
      end loop;
      if J > Text'Last then
         return "";  --  unterminated value

      end if;
      return Text (I + 1 .. J - 1);
   end String_Value;

   function Number_Value
     (Text : String; Key : Key_String; From : Positive) return String
   is
      I : constant Natural := Value_Start (Text, Key, From);
      J : Positive;
   begin
      if I = 0 or else Text (I) not in '0' .. '9' then
         return "";
      end if;

      J := I;
      while J <= Text'Last and then Text (J) in '0' .. '9' loop
         pragma Loop_Invariant (J in Text'First .. Text'Last);
         pragma Loop_Variant (Increases => J);
         J := J + 1;
      end loop;
      return Text (I .. J - 1);
   end Number_Value;

   procedure Next_Flat_Object
     (Text : String; From : Positive; First : out Natural; Last : out Natural)
   is
   begin
      Last := 0;
      First := Find (Text, "{", From);
      if First = 0 then
         return;
      end if;

      --  The first '}' after the '{'; Find cannot match at First itself.
      Last := Find (Text, "}", First);
      if Last = 0 then
         First := 0;
      end if;
   end Next_Flat_Object;

   function Object_Value
     (Text        : String;
      Match_Key   : Key_String;
      Match_Value : String;
      Want_Key    : Key_String) return String
   is
      First, Last : Natural;
   begin
      if Match_Value = "" or else Text'Length = 0 then
         --  The Text'Length guard also proves Text'First is a valid
         --  Positive below (a null slice's bounds can sit outside the
         --  index subtype).
         return "";
      end if;

      declare
         Pos : Positive := Text'First;
      begin
         loop
            pragma Loop_Variant (Increases => Pos);

            Next_Flat_Object (Text, Pos, First, Last);
            if First = 0 then
               return "";
            end if;

            if String_Value (Text (First .. Last), Match_Key, First)
              = Match_Value
            then
               return String_Value (Text (First .. Last), Want_Key, First);
            end if;

            --  Move past this object; when it closes the text, nothing
            --  is left to scan.
            if Last >= Text'Last then
               return "";
            end if;
            Pos := Last + 1;
         end loop;
      end;
   end Object_Value;

   function Ends_With_Object_Close (Text : String) return Boolean is
   begin
      for I in reverse Text'Range loop
         if not Is_Blank (Text (I)) then
            return Text (I) = '}';
         end if;
      end loop;
      return False;
   end Ends_With_Object_Close;

end Lector.Scan;
