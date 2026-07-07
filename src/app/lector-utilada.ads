private with Util.Properties;

--  The whole-document parse: utilada's JSON reader behind a flat
--  property view.  All utilada specifics stay behind this one unit, and
--  its exceptions become Ok = False at this boundary -- malformed input
--  is a result, never an exception.  Nested payloads flatten into
--  composite keys, so top-level fields read directly by name; for fields
--  inside arrays, use the targeted Lector.Scan functions instead.
--
--  Note what Parse does NOT check: utilada's reader stops at the first
--  complete value, so "{...}trailing" parses.  Callers guarding a file on
--  disk check Lector.Scan.Ends_With_Object_Close first.

package Lector.Utilada is

   type Document is private;

   --  Ok False on malformed JSON; Doc is then empty (every Has False,
   --  every Value "").
   procedure Parse (Content : String; Doc : out Document; Ok : out Boolean);

   function Has (Doc : Document; Key : String) return Boolean;

   --  The field's value, or "" when absent.
   function Value (Doc : Document; Key : String) return String;

private

   type Document is record
      Props : Util.Properties.Manager;
   end record;

end Lector.Utilada;
