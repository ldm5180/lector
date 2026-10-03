with Lector.Scan;

with Lector_Steps.Flows;
with Lector_Steps.Holding;

package body Lector_Steps.Shape is

   --  Unchecked until the document in hand is checked; the verdict is
   --  then the world's.
   type State is (Unchecked, Checked);

   type Guard_Kind is (Always, Held);

   type Action_Kind is (A_Nothing, A_Check_Shape, A_Expect_Verdict);

   function Evaluate
     (G : Guard_Kind; Ctx : Step_Context; Evt : Step_Kind) return Boolean
   is
      pragma Unreferenced (Ctx, Evt);
   begin
      return
        (case G is
           when Always => True,
           when Held   => Holding.Held);
   end Evaluate;

   --  The verdict a check step expects: one complete object, or not.
   function Wanted (Evt : Step_Kind) return Boolean
   is (Evt = E_Check_Shape_Ok);

   function Said (Verdict : Boolean) return String
   is ("the document is "
       & (if Verdict then "" else "not ")
       & "a single object");

   procedure Execute
     (A : Action_Kind; Ctx : in out Step_Context; Evt : Step_Kind) is
   begin
      case A is
         when A_Nothing        =>
            null;

         when A_Check_Shape    =>
            Ctx.W.Verdict :=
              Lector.Scan.Is_Single_Object (To_String (Ctx.W.Doc));

         when A_Expect_Verdict =>
            Fabula.Check.Is_True
              (Ctx.R, Ctx.W.Verdict = Wanted (Evt), Said (Ctx.W.Verdict));
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

   Check_Shape     : constant Ev := (Kind => E_Check_Shape);
   Check_Shape_Ok  : constant Ev := (Kind => E_Check_Shape_Ok);
   Check_Shape_Bad : constant Ev := (Kind => E_Check_Shape_Bad);

   --!format off
   Table : constant Transition_Table :=
     [Unchecked + Check_Shape (Held) / A_Check_Shape    >= Checked,
      Checked   + Check_Shape_Ok     / A_Expect_Verdict >= Checked,
      Checked   + Check_Shape_Bad    / A_Expect_Verdict >= Checked];
   --!format on

   Current : State := Unchecked;

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean) is
   begin
      Flow.Take (Table, Current, Ctx, Evt, Handled);
   end Offer;

   procedure Reset is
   begin
      Current := Unchecked;
   end Reset;

   function Phase return String
   is (Current'Image);

end Lector_Steps.Shape;
