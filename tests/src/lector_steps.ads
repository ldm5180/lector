with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with Lector.Scan;
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
      E_Check_Parsed,
      E_Check_Refused,
      E_Check_Has,
      E_Check_Lacks,
      E_Check_Shape,
      E_Check_Shape_Ok,
      E_Check_Shape_Bad,
      E_Mask_One,
      E_Mask_Many,
      E_Escape,
      E_Check_Text,
      E_Check_Unchanged,
      E_Check_Idempotent,
      --  An event no pattern names: the named document's read posts it,
      --  and the next row's guard reads whether the file was there.
      E_Document_Settled);

   type Hook_Kind is (Fresh_World);

   --  Most keys one masking step names: past any list a log masks.
   Max_Mask_Keys : constant := 16;

   subtype Mask_Count is Natural range 0 .. Max_Mask_Keys;

   --  What one scenario holds: the document in hand, the value last read
   --  out of it, its parse with the parse's verdict, whether it is one
   --  complete object, and the text masked or escaped for a log with the
   --  keys it was masked by.  fabula copies it per step, so it holds values only.
   type World is record
      Doc     : Unbounded_String;
      Loaded  : Boolean := False;
      Value   : Unbounded_String;
      Parse   : Lector.Utilada.Document;
      Parsed  : Boolean := False;
      Verdict : Boolean := False;
      Text    : Unbounded_String;
      Keys    : Lector.Scan.Key_List (1 .. Max_Mask_Keys);
      Masked  : Mask_Count := 0;
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
      Step ("the value is absent")           >= E_Check_Empty,
      Step ("the parse succeeds")            >= E_Check_Parsed,
      Step ("the parse fails")               >= E_Check_Refused,
      Step ("the field {word} is present")   >= E_Check_Has,
      Step ("the field {word} is absent")    >= E_Check_Lacks,
      Step ("the document is checked for a single object")
                                             >= E_Check_Shape,
      Step ("the document is a single object")
                                             >= E_Check_Shape_Ok,
      Step ("the document is not a single object")
                                             >= E_Check_Shape_Bad,
      Step ("the values of these keys are masked:")
                                             >= E_Mask_Many,
      Step ("the values of {word} are masked")
                                             >= E_Mask_One,
      Step ("the document is escaped for a log")
                                             >= E_Escape,
      Step ("the text reads:")               >= E_Check_Text,
      Step ("the text is unchanged")         >= E_Check_Unchanged,
      Step ("masking it again changes nothing")
                                             >= E_Check_Idempotent];
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
