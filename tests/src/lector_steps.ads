with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with Lector.Utilada;

with Fabula.Args;
with Fabula.Check;
with Fabula.Frames;
with Fabula.Registry;

--  The step registry the feature runner dispatches on: one Step_Kind
--  per pattern, one table that reads like the features, and one Execute
--  that offers each step to every feature's state machine.

package Lector_Steps is

   --  The steps.  Each is an event of one feature's state machine, in
   --  its own child package.
   type Step_Kind is
     (E_Hold_Doc,
      E_Hold_Named,
      E_Hold_Empty,
      E_Scan_String,
      E_Scan_String_After,
      E_Scan_Number,
      E_Scan_Object,
      E_Read_Field,
      E_Parse,
      E_Check_Value,
      E_Check_Empty,
      --  An event no pattern names: the named document's read posts it,
      --  and the next row's guard reads whether the file was there.
      E_Document_Settled);

   type Hook_Kind is (Fresh_World);

   --  What one scenario holds: the document in hand, the value last read
   --  out of it, and its parse with the parse's verdict.  fabula copies it per step, so it holds values only.
   type World is record
      Doc    : Unbounded_String;
      Loaded : Boolean := False;
      Value  : Unbounded_String;
      Parse  : Lector.Utilada.Document;
      Parsed : Boolean := False;
   end record;

   --  One step as a machine sees it: the scenario, the step's arguments,
   --  frame and outcome, and the event an action asks to be taken next
   --  (Then_Take), which the runner posts before the step returns.
   type Step_Context is record
      W        : World;
      A        : Fabula.Args.List;
      Info     : Fabula.Frames.Frame;
      R        : Fabula.Check.Outcome;
      Has_Next : Boolean := False;
      Next     : Step_Kind := Step_Kind'First;
   end record;

   procedure Then_Take (Ctx : in out Step_Context; Evt : Step_Kind);

   package Steps is new
     Fabula.Registry
       (Step_Kind => Step_Kind,
        Hook_Kind => Hook_Kind,
        Context   => World);
   use Steps;

   --!format off
   Step_Defs : constant Steps.Step_Table :=
     [Step ("a document:")                   >= E_Hold_Doc,
      Step ("the document named {word}")     >= E_Hold_Named,
      Step ("an empty document")             >= E_Hold_Empty,
      Step ("the string value of {word} is read")
                                             >= E_Scan_String,
      Step ("the string value of {word} after the first {word} is read")
                                             >= E_Scan_String_After,
      Step ("the number value of {word} is read")
                                             >= E_Scan_Number,
      Step ("the {word} of the object whose {word} is {string} is read")
                                             >= E_Scan_Object,
      Step ("the {word} of the object whose {word} is {word} is read")
                                             >= E_Scan_Object,
      Step ("the document is parsed")        >= E_Parse,
      Step ("the field {word} is read")      >= E_Read_Field,
      Step ("the value is {string}")         >= E_Check_Value,
      Step ("the value is empty")            >= E_Check_Empty,
      Step ("the value is absent")           >= E_Check_Empty];
   --!format on

   Hook_Defs : constant Steps.Hook_Table := [Before >= Fresh_World];

   procedure Execute
     (S    : Step_Kind;
      Ctx  : in out World;
      A    : Fabula.Args.List;
      Info : Fabula.Frames.Frame;
      R    : in out Fabula.Check.Outcome);

   procedure Run_Hook
     (H    : Hook_Kind;
      Ctx  : in out World;
      Info : Fabula.Frames.Frame;
      R    : in out Fabula.Check.Outcome);

end Lector_Steps;
