with Ada.Command_Line;
with Ada.Text_IO; use Ada.Text_IO;

with Lector.Scan;
with Lector.Utilada;

--  The two ways to read a payload, side by side on one sample: the flat
--  parse for top-level fields, and the targeted scans for a field inside
--  an array a flattening parser would mangle.  Pure -- CI runs it; exits
--  non-zero if any reading comes back wrong, so it doubles as a smoke
--  test of the installed library.

procedure Json_Fields is

   Sample : constant String :=
     "{""status"": ""WORKING"","
     & " ""orderId"": 100047,"
     & " ""legs"": ["
     & "{""symbol"":""SPY"",""quantity"":""2""},"
     & "{""symbol"":""QQQ"",""quantity"":""7""}]}";

   Failed : Boolean := False;

   procedure Show (Label : String; Value : String; Expect : String) is
   begin
      Put_Line (Label & " = """ & Value & """");
      if Value /= Expect then
         Put_Line ("  EXPECTED """ & Expect & """");
         Failed := True;
      end if;
   end Show;

   Doc : Lector.Utilada.Document;
   Ok  : Boolean;

begin
   Put_Line ("payload: " & Sample);
   New_Line;

   --  Whole-document parse: top-level fields by name.
   Lector.Utilada.Parse (Sample, Doc, Ok);
   if not Ok then
      Put_Line ("parse failed");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;
   Show
     ("Utilada.Value status ",
      Lector.Utilada.Value (Doc, "status"),
      "WORKING");

   --  Targeted scans: fields the flattening parse cannot give you.
   Show
     ("Scan.Number_Value orderId ",
      Lector.Scan.Number_Value (Sample, "orderId", Sample'First),
      "100047");
   Show
     ("Scan.Object_Value QQQ quantity ",
      Lector.Scan.Object_Value (Sample, "symbol", "QQQ", "quantity"),
      "7");
   Show
     ("Scan document closes cleanly ",
      (if Lector.Scan.Ends_With_Object_Close (Sample) then "yes" else "no"),
      "yes");

   if Failed then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Json_Fields;
