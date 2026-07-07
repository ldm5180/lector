with Util.Serialize.IO.JSON;

package body Lector.Utilada is

   procedure Parse (Content : String; Doc : out Document; Ok : out Boolean) is
      Empty : Util.Properties.Manager;
   begin
      Doc.Props := Util.Serialize.IO.JSON.Read (Content);
      Ok := True;
   exception
      when others =>
         --  Malformed JSON (Util.Serialize.IO.Parse_Error) and anything
         --  else unexpected mean the same thing to callers: no document.
         Doc.Props := Empty;
         Ok := False;
   end Parse;

   function Has (Doc : Document; Key : String) return Boolean
   is (Doc.Props.Exists (Key));

   function Value (Doc : Document; Key : String) return String
   is (if Doc.Props.Exists (Key) then Doc.Props.Get (Key) else "");

end Lector.Utilada;
