--  Targeted scans, redaction and escaping over raw JSON text: reading
--  scans for the payloads a flattening parser mangles (nested arrays,
--  repeated keys), shape checks a parser cannot make (trailing garbage
--  after the document), and the writing-side primitives a JSON log needs
--  (mask a secret key's values, escape a body into a JSON string).  Pure
--  string functions: no exceptions, no heap -- proved free of runtime
--  errors, so callers need no defensive wrapping.  Absence is empty (or
--  unchanged text), never an error.
--
--  The per-key scans require Text'Last < Positive'Last (an index just
--  past the end must exist); every ordinary string satisfies it.  The
--  string-building functions bound their input length (Pre) so the
--  output-size arithmetic is provable; both bounds are far beyond any
--  real payload.

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

   Redacted : constant String := "***";
   --  The marker Mask_Values writes over a secret value.

   --  Each JSON value of Key in Text replaced by the redaction marker: a
   --  quoted value becomes "***", a bare-number value becomes ***, and
   --  any other shape (null, object, array) is left alone.  Safe on
   --  absence and idempotent.  Masking is deliberately LOOSER than the
   --  reading scans: no colon is required after the key (any mix of
   --  spaces and colons is stepped over) and an unterminated quoted
   --  value still masks -- when in doubt, mask.  A value holding a quote
   --  or backslash is scanned to its next '"' like any other, so keys
   --  whose values may contain them (never account numbers or hashes)
   --  could under-mask; keep secrets in plain scalar values.
   function Mask_Values (Text : String; Key : Key_String) return String
   with
     Pre  =>
       Text'Last < Positive'Last and then Text'Length <= Natural'Last / 8,
     Post => Mask_Values'Result'Length <= 2 * Text'Length + 3;

   --  One key of a list: its length and its text, padded, so a list of
   --  keys is a plain array a caller writes as an aggregate of Key.
   subtype Key_Length is Natural range 0 .. Max_Key;

   type Key_Name is record
      Len  : Key_Length := 0;
      Text : String (1 .. Max_Key) := [others => ' '];
   end record;

   function Key (S : Key_String) return Key_Name
   with Post => Key'Result.Len = S'Length;

   type Key_List is array (Positive range <>) of Key_Name;

   --  Every listed key's values masked in ONE pass over Text: whichever
   --  key's value comes next is masked next, by the single-key rules
   --  above, under the same bound.  An empty list copies Text.  Seven
   --  keys over a wire body were seven passes and seven copies; this is
   --  one of each.
   function Mask_Values (Text : String; Keys : Key_List) return String
   with
     Pre  =>
       Text'Last < Positive'Last and then Text'Length <= Natural'Last / 8,
     Post => Mask_Values'Result'Length <= 2 * Text'Length + 3;

   --  A JSON string literal's contents: the RFC 8259 escapes for the
   --  quote, the backslash, and the C0 control characters (the short
   --  forms \n \r \t \b \f where they exist, \u00xx otherwise), so an
   --  arbitrary body embeds safely as a JSON string value.
   function Json_Escape (Text : String) return String
   with
     Pre  => Text'Length <= Natural'Last / 8,
     Post => Json_Escape'Result'Length <= 6 * Text'Length;

end Lector.Scan;
