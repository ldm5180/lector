with AUnit.Assertions; use AUnit.Assertions;

with Lector.Utilada;

package body Lector_Utilada_Tests is

   use AUnit.Test_Cases.Registration;

   procedure Test_Parse_Object (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Doc : Lector.Utilada.Document;
      Ok  : Boolean;
   begin
      Lector.Utilada.Parse
        ("{""status"": ""FILLED"", ""quantity"": ""2""}", Doc, Ok);
      Assert (Ok, "a well-formed object parses");
      Assert (Lector.Utilada.Has (Doc, "status"), "field is present");
      Assert
        (Lector.Utilada.Value (Doc, "status") = "FILLED", "field reads back");
      Assert
        (not Lector.Utilada.Has (Doc, "missing"), "absent field is absent");
      Assert
        (Lector.Utilada.Value (Doc, "missing") = "",
         "absent field reads as empty, not an error");
   end Test_Parse_Object;

   procedure Test_Nested_Top_Level
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Doc : Lector.Utilada.Document;
      Ok  : Boolean;
   begin
      --  A nested payload (the order-status shape): the top-level field
      --  still reads directly by name.
      Lector.Utilada.Parse
        ("{""status"": ""WORKING"","
         & " ""children"": [{""status"": ""PENDING""}]}",
         Doc,
         Ok);
      Assert (Ok, "a nested object parses");
      Assert
        (Lector.Utilada.Value (Doc, "status") = "WORKING",
         "the top-level field is not shadowed by the nested one");
   end Test_Nested_Top_Level;

   procedure Test_Malformed (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Doc : Lector.Utilada.Document;
      Ok  : Boolean;
   begin
      Lector.Utilada.Parse ("{""broken"": ", Doc, Ok);
      Assert (not Ok, "malformed JSON is Ok = False, not an exception");
      Assert
        (Lector.Utilada.Value (Doc, "broken") = "",
         "a failed parse leaves an empty document");
   end Test_Malformed;

   procedure Test_Trailing_Garbage
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Doc : Lector.Utilada.Document;
      Ok  : Boolean;
   begin
      --  The reader stops at the first complete value, so trailing
      --  garbage parses -- pinned here because it is exactly why
      --  Lector.Scan.Ends_With_Object_Close exists for callers guarding
      --  files on disk.
      Lector.Utilada.Parse ("{""a"": ""1""}trailing", Doc, Ok);
      Assert (Ok, "the reader accepts trailing garbage (documented)");
   end Test_Trailing_Garbage;

   overriding
   procedure Register_Tests (T : in out Test) is
   begin
      Register_Routine
        (T, Test_Parse_Object'Access, "parse + flat field lookup");
      Register_Routine
        (T, Test_Nested_Top_Level'Access, "nested payload, top-level read");
      Register_Routine
        (T, Test_Malformed'Access, "malformed input is a result");
      Register_Routine
        (T,
         Test_Trailing_Garbage'Access,
         "trailing garbage parses (why the shape check exists)");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Lector.Utilada (flat-document parse)");
   end Name;

end Lector_Utilada_Tests;
