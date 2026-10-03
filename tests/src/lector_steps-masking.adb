with Lector.Scan;

with Lector_Steps.Flows;
with Lector_Steps.Holding;

package body Lector_Steps.Masking is

   --  Idle until the document in hand is masked or escaped; the checks
   --  read the text then.
   type State is (Idle, Written);

   type Guard_Kind is (Always, Held, Key_Fits, Keys_Fit, Keys_Kept, Doc_Given);

   type Action_Kind is
     (A_Nothing,
      A_Mask_One,
      A_Mask_Many,
      A_Escape,
      A_Refuse_Keys,
      A_Check_Text,
      A_Refuse_Text,
      A_Check_Unchanged,
      A_Check_Idempotent,
      A_Refuse_Again);

   Key_Capture : constant := 1;
   Key_Column  : constant := 1;

   function Fits (Key : String) return Boolean
   is (Key'Length in 1 .. Lector.Scan.Max_Key);

   --  The table's keys, one per row of its one column.
   function Rows (Ctx : Step_Context) return Natural
   is (if Fabula.Args.Has_Table (Ctx.A)
       then Fabula.Args.Row_Count (Ctx.A)
       else 0);

   function Cell (Ctx : Step_Context; Row : Positive) return String
   is (Fabula.Args.Cell (Ctx.A, Row, Key_Column));

   function Table_Fits (Ctx : Step_Context) return Boolean
   is (Rows (Ctx) in 1 .. Max_Mask_Keys
       and then (for all Row in 1 .. Rows (Ctx) => Fits (Cell (Ctx, Row))));

   function Evaluate
     (G : Guard_Kind; Ctx : Step_Context; Evt : Step_Kind) return Boolean
   is
      pragma Unreferenced (Evt);
   begin
      return
        (case G is
           when Always    => True,
           when Held      => Holding.Held,
           when Key_Fits  =>
             Holding.Held
             and then Fits (Fabula.Args.Word (Ctx.A, Key_Capture)),
           when Keys_Fit  => Holding.Held and then Table_Fits (Ctx),
           when Keys_Kept => Ctx.W.Masked > 0,
           when Doc_Given => Fabula.Args.Has_Doc (Ctx.A));
   end Evaluate;

   function Kept (Ctx : Step_Context) return Lector.Scan.Key_List
   is (Ctx.W.Keys (1 .. Ctx.W.Masked));

   procedure Keep_Keys (Ctx : in out Step_Context; Keys : Lector.Scan.Key_List)
   is
   begin
      Ctx.W.Masked := Keys'Length;
      Ctx.W.Keys (1 .. Keys'Length) := Keys;
   end Keep_Keys;

   function Table_Keys (Ctx : Step_Context) return Lector.Scan.Key_List
   is ([for Row in 1 .. Rows (Ctx) => Lector.Scan.Key (Cell (Ctx, Row))]);

   procedure Write (Ctx : in out Step_Context; Text : String) is
   begin
      Ctx.W.Text := To_Unbounded_String (Text);
   end Write;

   procedure Mask (Ctx : in out Step_Context; Keys : Lector.Scan.Key_List) is
   begin
      Keep_Keys (Ctx, Keys);
      Write (Ctx, Lector.Scan.Mask_Values (To_String (Ctx.W.Doc), Kept (Ctx)));
   end Mask;

   procedure Compare_Text (Ctx : in out Step_Context; Want : String) is
   begin
      Fabula.Check.Text_Equal
        (Ctx.R, To_String (Ctx.W.Text), Want, "the text written");
   end Compare_Text;

   function Again (Ctx : Step_Context) return String
   is (Lector.Scan.Mask_Values (To_String (Ctx.W.Text), Kept (Ctx)));

   --  Why a masking step's keys are refused.
   Too_Many : constant String :=
     "name one to"
     & Max_Mask_Keys'Image
     & " keys of one to"
     & Lector.Scan.Max_Key'Image
     & " characters each";

   procedure Execute
     (A : Action_Kind; Ctx : in out Step_Context; Evt : Step_Kind)
   is
      pragma Unreferenced (Evt);
   begin
      case A is
         when A_Nothing          =>
            null;

         when A_Mask_One         =>
            Mask
              (Ctx, [Lector.Scan.Key (Fabula.Args.Word (Ctx.A, Key_Capture))]);

         when A_Mask_Many        =>
            Mask (Ctx, Table_Keys (Ctx));

         when A_Escape           =>
            Ctx.W.Masked := 0;
            Write (Ctx, Lector.Scan.Json_Escape (To_String (Ctx.W.Doc)));

         when A_Refuse_Keys      =>
            Fabula.Check.Fail_Step (Ctx.R, Too_Many);

         when A_Check_Text       =>
            Compare_Text (Ctx, Fabula.Args.Doc_String (Ctx.A));

         when A_Refuse_Text      =>
            Fabula.Check.Fail_Step (Ctx.R, "the step carries no doc string");

         when A_Check_Unchanged  =>
            Compare_Text (Ctx, To_String (Ctx.W.Doc));

         when A_Check_Idempotent =>
            Fabula.Check.Text_Equal
              (Ctx.R, Again (Ctx), To_String (Ctx.W.Text), "masked again");

         when A_Refuse_Again     =>
            Fabula.Check.Fail_Step (Ctx.R, "the text was escaped, not masked");
      end case;
   end Execute;

   package Flow is new
     Lector_Steps.Flows
       (State       => State,
        Guard_Kind  => Guard_Kind,
        Action_Kind => Action_Kind,
        Evaluate    => Evaluate,
        Execute     => Execute,
        Always      => Always,
        Nothing     => A_Nothing);

   use Flow.Machines;
   use Flow.Op;

   Mask_One         : constant Ev := (Kind => E_Mask_One);
   Mask_Many        : constant Ev := (Kind => E_Mask_Many);
   Escape           : constant Ev := (Kind => E_Escape);
   Check_Text       : constant Ev := (Kind => E_Check_Text);
   Check_Unchanged  : constant Ev := (Kind => E_Check_Unchanged);
   Check_Idempotent : constant Ev := (Kind => E_Check_Idempotent);

   --!format off
   Table : constant Transition_Table :=
     [Idle    + Mask_One  (Key_Fits)          / A_Mask_One         >= Written,
      Idle    + Mask_One  (Held)              / A_Refuse_Keys      >= Idle,
      Idle    + Mask_Many (Keys_Fit)          / A_Mask_Many        >= Written,
      Idle    + Mask_Many (Held)              / A_Refuse_Keys      >= Idle,
      Idle    + Escape    (Held)              / A_Escape           >= Written,
      Written + Check_Text (Doc_Given)        / A_Check_Text       >= Written,
      Written + Check_Text                    / A_Refuse_Text      >= Written,
      Written + Check_Unchanged               / A_Check_Unchanged  >= Written,
      Written + Check_Idempotent (Keys_Kept)  / A_Check_Idempotent >= Written,
      Written + Check_Idempotent              / A_Refuse_Again     >= Written];
   --!format on

   Current : State := Idle;

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean) is
   begin
      Flow.Take (Table, Current, Ctx, Evt, Handled);
   end Offer;

   procedure Reset is
   begin
      Current := Idle;
   end Reset;

   function Phase return String
   is (Current'Image);

end Lector_Steps.Masking;
