with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with Fabula.Frames;

--  What the features read that is not per scenario: the named documents
--  under a feature's docs/ directory, and the small text helpers the
--  steps share.  A scenario's own values live in Lector_Steps.World.

package Lector_World is

   --  Longest named document read, in bytes: far past any wire payload
   --  a feature states, and a bound so a stray file cannot swamp a run.
   Max_Document : constant := 65_536;

   --  The docs/ directory beside the feature file Info is running.
   function Docs_Dir (Info : Fabula.Frames.Frame) return String;

   --  The document Dir/Name.json, its lines joined by LF; Ok False when
   --  the file is missing or longer than Max_Document.
   procedure Named_Document
     (Dir  : String;
      Name : String;
      Text : out Unbounded_String;
      Ok   : out Boolean);

   --  Key in double quotes, as it appears in a document.
   function Quoted (Key : String) return String
   is ('"' & Key & '"');

end Lector_World;
