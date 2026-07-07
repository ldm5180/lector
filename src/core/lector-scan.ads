--  Targeted scans over raw JSON text, for the payloads a flattening
--  parser mangles (nested arrays, repeated keys) and for shape checks a
--  parser cannot make (trailing garbage after the document).  Pure string
--  functions: no exceptions, no allocation, results are slices of the
--  input -- proved free of runtime errors, so callers need no defensive
--  wrapping.  Absence is empty, never an error: a missing key, a key not
--  followed by the expected shape, or an unterminated value all read as
--  "".
--
--  The per-key scans require Text'Last < Positive'Last (an index just
--  past the end must exist); every ordinary string satisfies it.

package Lector.Scan
  with SPARK_Mode
is

   Max_Key : constant := 128;
   --  Longest key the scans accept; JSON keys in the wild are tiny, and
   --  a bound keeps the quoted-key concatenation provably in range.

   subtype Key_String is String
   with Dynamic_Predicate => Key_String'Length in 1 .. Max_Key;

   --  Position of the first occurrence of Pattern in Text at or after
   --  From; 0 when absent (including when Pattern is empty).
   function Find
     (Text : String; Pattern : String; From : Positive) return Natural
   with
     Post =>
       Find'Result = 0
       or else (Find'Result >= From
                and then Find'Result >= Text'First
                and then Pattern'Length >= 1
                and then Text'Last - Find'Result >= Pattern'Length - 1
                and then Text
                           (Find'Result .. Find'Result + (Pattern'Length - 1))
                         = Pattern);

   --  The quoted string value following `"Key" :` at or after From --
   --  String_Value ("{""name"": ""ada""}", "name", 1) = "ada" --
   --  tolerating blanks around the colon; "" when the key is absent, not
   --  followed by a colon and a quoted value, or unterminated.
   function String_Value
     (Text : String; Key : Key_String; From : Positive) return String
   with
     Pre  => Text'Last < Positive'Last,
     Post => String_Value'Result'Length <= Text'Length;

   --  The digit run following `"Key" :` at or after From -- JSON numbers
   --  arrive as text and may exceed what a Natural holds, so the digits
   --  come back verbatim; "" when the key is absent, not followed by a
   --  colon, or not followed by a digit.
   function Number_Value
     (Text : String; Key : Key_String; From : Positive) return String
   with
     Pre  => Text'Last < Positive'Last,
     Post => Number_Value'Result'Length <= Text'Length;

   --  Bounds of the next flat `{ ... }` window at or after From: First
   --  is the '{' and Last the first '}' after it (flat objects only --
   --  the values must not contain braces, so there is no nesting to
   --  track).  First = Last = 0 when no complete object remains.
   procedure Next_Flat_Object
     (Text : String; From : Positive; First : out Natural; Last : out Natural)
   with
     Post =>
       (if First = 0
        then Last = 0
        else
          First >= From
          and then First >= Text'First
          and then Last > First
          and then Last <= Text'Last);

   --  Walk the flat objects of an array and read Want_Key out of the one
   --  whose Match_Key equals Match_Value -- e.g. the "hashValue" of the
   --  object whose "accountNumber" is a given number.  "" when Match_Value
   --  is empty or no object matches.
   function Object_Value
     (Text        : String;
      Match_Key   : Key_String;
      Match_Value : String;
      Want_Key    : Key_String) return String
   with
     Pre  => Text'Last < Positive'Last,
     Post => Object_Value'Result'Length <= Text'Length;

   --  True when the last non-blank byte is the object close '}'.  Parsers
   --  that stop at the first complete value accept "{...}trailing"
   --  silently, so callers guarding a file on disk check this BEFORE
   --  parsing: it catches truncated-or-doubled-write corruption.
   function Ends_With_Object_Close (Text : String) return Boolean;

end Lector.Scan;
