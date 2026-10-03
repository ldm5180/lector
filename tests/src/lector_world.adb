with Ada.Directories;
with Ada.Text_IO;

package body Lector_World is

   function Docs_Dir (Info : Fabula.Frames.Frame) return String is
      File : constant String := Fabula.Frames.Value (Info.File);
   begin
      return Ada.Directories.Containing_Directory (File) & "/docs";
   end Docs_Dir;

   --  Every line of an open file, joined by LF; Ok False once the text
   --  grows past Max_Document.
   procedure Read_Lines
     (File : Ada.Text_IO.File_Type;
      Text : out Unbounded_String;
      Ok   : out Boolean) is
   begin
      Text := Null_Unbounded_String;
      Ok := True;
      while Ok and then not Ada.Text_IO.End_Of_File (File) loop
         if Length (Text) > 0 then
            Append (Text, ASCII.LF);
         end if;
         Append (Text, Ada.Text_IO.Get_Line (File));
         Ok := Length (Text) <= Max_Document;
      end loop;
   end Read_Lines;

   procedure Named_Document
     (Dir  : String;
      Name : String;
      Text : out Unbounded_String;
      Ok   : out Boolean)
   is
      Path : constant String := Dir & "/" & Name & ".json";
      File : Ada.Text_IO.File_Type;
   begin
      Text := Null_Unbounded_String;
      Ok := Ada.Directories.Exists (Path);
      if Ok then
         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
         Read_Lines (File, Text, Ok);
         Ada.Text_IO.Close (File);
      end if;
   end Named_Document;

end Lector_World;
