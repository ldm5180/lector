package body Lector.Scan
  with SPARK_Mode
is

   function Is_Blank (C : Character) return Boolean
   is (C in ' ' | ASCII.HT | ASCII.LF | ASCII.CR)
   with Static;

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

   function Mask_Values (Text : String; Key : Key_String) return String is
      Pattern : constant String := '"' & Key & '"';

      --  Growth argument for the buffer: each hit consumes at least
      --  Pattern'Length (>= 3) input characters and adds at most 3 bytes
      --  (the marker over an empty value), so the output never exceeds
      --  twice the input; +3 is headroom that keeps the edge proofs
      --  trivial.  Stack, not heap: the hot path allocates nothing.
      Buf  : String (1 .. 2 * Text'Length + 3) := [others => ' '];
      Last : Natural := 0;

      procedure Append (Part : String)
      with
        Pre  =>
          Last < Positive'Last
          and then Last <= Buf'Length
          and then Part'Length <= Buf'Length - Last,
        Post => Last = Last'Old + Part'Length;

      procedure Append (Part : String) is
      begin
         Buf (Last + 1 .. Last + Part'Length) := Part;
         Last := Last + Part'Length;
      end Append;

      I : Positive;
   begin
      if Text'Length = 0 then
         --  Also proves Text'First is a valid Positive below (a null
         --  slice's bounds can sit outside the index subtype).
         return "";
      end if;

      I := Text'First;
      loop
         pragma Loop_Variant (Increases => I);
         pragma
           Loop_Invariant
             (I in Text'First .. Text'Last + 1
                and then Last <= 2 * (I - Text'First));

         declare
            Hit : constant Natural := Find (Text, Pattern, I);
         begin
            if Hit = 0 or else I > Text'Last then
               Append (Text (I .. Text'Last));
               exit;
            end if;

            --  Step over the key, then any spaces and the colon, to the
            --  value.
            declare
               V : Positive := Hit + Pattern'Length;
            begin
               while V <= Text'Last and then Text (V) in ' ' | ':' loop
                  pragma
                    Loop_Invariant
                      (V in Text'First .. Text'Last
                         and then V >= Hit + Pattern'Length);
                  pragma Loop_Variant (Increases => V);
                  V := V + 1;
               end loop;

               if V > Text'Last then
                  Append (Text (I .. Text'Last));
                  exit;

               elsif Text (V) = '"' then
                  --  Quoted value: copy through the opening quote, emit
                  --  the marker, then resume at the closing quote.
                  declare
                     E : Positive := V + 1;
                  begin
                     while E <= Text'Last and then Text (E) /= '"' loop
                        pragma
                          Loop_Invariant
                            (E in Text'First .. Text'Last and then E >= V + 1);
                        pragma Loop_Variant (Increases => E);
                        E := E + 1;
                     end loop;
                     Append (Text (I .. V));
                     Append (Redacted);
                     if E <= Text'Last then
                        Append ("""");
                        I := E + 1;
                     else
                        I := E;  --  no closing quote; nothing more to copy
                     end if;
                  end;

               elsif Text (V) in '0' .. '9' then
                  --  Bare-number value: copy up to it, emit the marker,
                  --  resume after the digit run.
                  declare
                     E : Positive := V;
                  begin
                     while E <= Text'Last and then Text (E) in '0' .. '9' loop
                        pragma
                          Loop_Invariant
                            (E in Text'First .. Text'Last and then E >= V);
                        pragma Loop_Variant (Increases => E);
                        E := E + 1;
                     end loop;
                     Append (Text (I .. V - 1));
                     Append (Redacted);
                     I := E;
                  end;

               else
                  --  Not a string or number (null, object, array): leave
                  --  it, but advance past the key so the scan cannot
                  --  loop forever.
                  Append (Text (I .. V - 1));
                  I := V;
               end if;
            end;
         end;
         exit when I > Text'Last;
      end loop;

      return Buf (1 .. Last);
   end Mask_Values;

   --  A single lowercase hex digit 0 .. 15.  Arithmetic, not a table
   --  lookup: indexed components are not a potentially static expression,
   --  and this is called from the `with Static` Hex2 below.
   subtype Hex_Digit is Natural range 0 .. 15;

   function Hex_Digit_Char (D : Hex_Digit) return Character
   is (if D < 10
       then Character'Val (Character'Pos ('0') + D)
       else Character'Val (Character'Pos ('a') + D - 10))
   with Static;

   subtype Hex2_Result is String (1 .. 2);

   function Hex2 (V : Natural) return Hex2_Result
   is (Hex_Digit_Char ((V / 16) mod 16) & Hex_Digit_Char (V mod 16))
   with Static;

   --  One character's spelling inside a JSON string literal: itself, a
   --  short escape, or \u00xx -- never longer than 6 bytes (the bound
   --  Json_Escape's buffer and Post rely on).
   function Escape_Image (C : Character) return String
   with Post => Escape_Image'Result'Length in 1 .. 6
   is
   begin
      case C is
         when '"'      =>
            return "\""";

         when '\'      =>
            return "\\";

         when ASCII.LF =>
            return "\n";

         when ASCII.CR =>
            return "\r";

         when ASCII.HT =>
            return "\t";

         when ASCII.BS =>
            return "\b";

         when ASCII.FF =>
            return "\f";

         when others   =>
            if Character'Pos (C) < 16#20# then
               return "\u00" & Hex2 (Character'Pos (C));
            else
               return [1 => C];
            end if;
      end case;
   end Escape_Image;

   function Json_Escape (Text : String) return String is
      --  Sized by the worst case (every byte a \u00xx escape); stack,
      --  not heap.  Bodies worth escaping are far below the Pre bound.
      Buf  : String (1 .. 6 * Text'Length) := [others => ' '];
      Last : Natural := 0;
   begin
      for I in Text'Range loop
         pragma Loop_Invariant (Last <= 6 * (I - Text'First));

         declare
            E : constant String := Escape_Image (Text (I));
         begin
            Buf (Last + 1 .. Last + E'Length) := E;
            Last := Last + E'Length;
         end;
      end loop;
      return Buf (1 .. Last);
   end Json_Escape;

end Lector.Scan;
