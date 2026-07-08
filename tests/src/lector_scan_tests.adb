with AUnit.Assertions; use AUnit.Assertions;

with Lector.Scan; use Lector.Scan;

--  The scans' absence-of-runtime-error story is carried by the proof;
--  what lives here is the reading behavior itself: which value comes
--  back for which text shape.

package body Lector_Scan_Tests is

   use AUnit.Test_Cases.Registration;

   procedure Test_String_Value (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Doc : constant String := "{""name"": ""ada"", ""kind"":""crate""}";
   begin
      Assert (String_Value (Doc, "name", Doc'First) = "ada", "spaced colon");
      Assert (String_Value (Doc, "kind", Doc'First) = "crate", "tight colon");
      Assert (String_Value (Doc, "missing", Doc'First) = "", "absent key");
      Assert
        (String_Value ("{""k"": ""unterminated", "k", 1) = "",
         "unterminated value reads as absent");
      Assert
        (String_Value ("{""k"" ""no-colon""}", "k", 1) = "",
         "key without a colon reads as absent");
      Assert
        (String_Value ("{""k"": 42}", "k", 1) = "",
         "non-string value reads as absent for the string scan");
   end Test_String_Value;

   procedure Test_From_Offset (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Two      : constant String := "{""id"": ""first""} {""id"": ""second""}";
      At_First : constant Natural := Find (Two, """id""", Two'First);
   begin
      Assert (At_First > 0, "the first key is found");
      Assert
        (String_Value (Two, "id", At_First + 1) = "second",
         "From skips past the first occurrence");
   end Test_From_Offset;

   procedure Test_Number_Value (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Doc : constant String :=
        "{""orderId"": 100047, ""big"": 99999999999999999999}";
   begin
      Assert (Number_Value (Doc, "orderId", Doc'First) = "100047", "digits");
      Assert
        (Number_Value (Doc, "big", Doc'First) = "99999999999999999999",
         "digits beyond Natural come back verbatim");
      Assert (Number_Value (Doc, "missing", Doc'First) = "", "absent key");
      Assert
        (Number_Value ("{""k"": ""text""}", "k", 1) = "",
         "non-number value reads as absent for the number scan");
   end Test_Number_Value;

   procedure Test_Object_Value (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  The accountNumbers shape: an array of flat two-field objects.
      Doc : constant String :=
        "[{""accountNumber"":""111"",""hashValue"":""AAA""},"
        & "{""accountNumber"":""222"",""hashValue"":""BBB""}]";
   begin
      Assert
        (Object_Value (Doc, "accountNumber", "222", "hashValue") = "BBB",
         "the matching object's field comes back");
      Assert
        (Object_Value (Doc, "accountNumber", "111", "hashValue") = "AAA",
         "the first object matches too");
      Assert
        (Object_Value (Doc, "accountNumber", "333", "hashValue") = "",
         "no matching object reads as absent");
      Assert
        (Object_Value (Doc, "accountNumber", "", "hashValue") = "",
         "an empty match value never matches");
   end Test_Object_Value;

   procedure Test_Json_Escape (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert
        (Json_Escape ("a""b\c" & ASCII.LF & ASCII.HT & ASCII.NUL)
         = "a\""b\\c\n\t\u0000",
         "quote, backslash, short escapes and \u00xx, in place");
      Assert
        (Json_Escape (ASCII.CR & ASCII.BS & ASCII.FF & ASCII.ESC)
         = "\r\b\f\u001b",
         "the remaining short escapes and a bare C0");
      Assert (Json_Escape ("plain text") = "plain text", "plain passes");
      Assert (Json_Escape ("") = "", "empty passes");
   end Test_Json_Escape;

   procedure Test_Mask_Values (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert
        (Mask_Values ("{""hashValue"":""AB12"",""id"":7}", "hashValue")
         = "{""hashValue"":""***"",""id"":7}",
         "a quoted value masks in place, neighbours untouched");
      Assert
        (Mask_Values ("{""orderId"": 100247}", "orderId")
         = "{""orderId"": ***}",
         "a bare-number value masks (spaces after the colon tolerated)");
      Assert
        (Mask_Values ("{""a"":""x"",""a"":""y""}", "a")
         = "{""a"":""***"",""a"":""***""}",
         "every occurrence masks");
      Assert
        (Mask_Values ("{""other"":""x""}", "absent") = "{""other"":""x""}",
         "an absent key changes nothing");
      Assert
        (Mask_Values ("{""k"":""unterminated", "k") = "{""k"":""***",
         "an unterminated value still masks, nothing trails");
      Assert
        (Mask_Values ("{""k"":null}", "k") = "{""k"":null}",
         "a non-scalar value is left alone (and the scan advances)");
      Assert
        (Mask_Values ("tail is ""k""", "k") = "tail is ""k""",
         "a key ending the text copies the remainder unchanged");
      Assert
        (Mask_Values (Mask_Values ("{""k"":""s3cr3t""}", "k"), "k")
         = "{""k"":""***""}",
         "masking is idempotent");
      Assert (Mask_Values ("", "k") = "", "empty text passes");
   end Test_Mask_Values;

   procedure Test_Object_Close (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Ends_With_Object_Close ("{""a"":1}"), "plain object");
      Assert
        (Ends_With_Object_Close ("{""a"":1}" & ASCII.LF & "  "),
         "trailing blanks are fine");
      Assert
        (not Ends_With_Object_Close ("{""a"":1}garbage"),
         "trailing garbage is corruption");
      Assert (not Ends_With_Object_Close (""), "empty is not a document");
   end Test_Object_Close;

   overriding
   procedure Register_Tests (T : in out Test) is
   begin
      Register_Routine (T, Test_String_Value'Access, "string values by key");
      Register_Routine
        (T, Test_From_Offset'Access, "From scans past earlier occurrences");
      Register_Routine
        (T, Test_Number_Value'Access, "digit runs by key, verbatim");
      Register_Routine (T, Test_Object_Value'Access, "flat-object array walk");
      Register_Routine
        (T, Test_Object_Close'Access, "strict document-close check");
      Register_Routine
        (T, Test_Json_Escape'Access, "RFC 8259 string escaping");
      Register_Routine
        (T, Test_Mask_Values'Access, "secret values mask by key");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Lector.Scan (targeted JSON scans)");
   end Name;

end Lector_Scan_Tests;
