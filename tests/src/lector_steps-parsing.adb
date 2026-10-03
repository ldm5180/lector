with Lector.Utilada;

with Lector_Steps.Flows;
with Lector_Steps.Holding;

package body Lector_Steps.Parsing is

   --  Unparsed until the document in hand is parsed; the verdict and the
   --  document are then the world's.
   type State is (Unparsed, Parsed);

   type Guard_Kind is (Always, Held);

   type Action_Kind is
     (A_Nothing, A_Parse, A_Check_Parsed, A_Check_Has, A_Check_Lacks);

   Field : constant := 1;

   function Has_Field (Ctx : Step_Context) return Boolean
   is (Lector.Utilada.Has (Ctx.W.Parse, Fabula.Args.Word (Ctx.A, Field)));

   --  The verdict a check step expects of the parse.
   function Wanted (Evt : Step_Kind) return Boolean
   is (Evt = E_Check_Parsed);

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

   procedure Execute
     (A : Action_Kind; Ctx : in out Step_Context; Evt : Step_Kind) is
   begin
      case A is
         when A_Nothing      =>
            null;

         when A_Parse        =>
            Lector.Utilada.Parse
              (To_String (Ctx.W.Doc), Ctx.W.Parse, Ctx.W.Parsed);

         when A_Check_Parsed =>
            Fabula.Check.Is_True
              (Ctx.R,
               Ctx.W.Parsed = Wanted (Evt),
               "the parse "
               & (if Ctx.W.Parsed then "succeeded" else "failed"));

         when A_Check_Has    =>
            Fabula.Check.Is_True
              (Ctx.R, Has_Field (Ctx), "the parsed document lacks it");

         when A_Check_Lacks  =>
            Fabula.Check.Is_False
              (Ctx.R, Has_Field (Ctx), "the parsed document holds it");
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

   Parse         : constant Ev := (Kind => E_Parse);
   Check_Parsed  : constant Ev := (Kind => E_Check_Parsed);
   Check_Refused : constant Ev := (Kind => E_Check_Refused);
   Check_Has     : constant Ev := (Kind => E_Check_Has);
   Check_Lacks   : constant Ev := (Kind => E_Check_Lacks);

   --!format off
   Table : constant Transition_Table :=
     [Unparsed + Parse (Held)   / A_Parse        >= Parsed,
      Parsed   + Check_Parsed  / A_Check_Parsed >= Parsed,
      Parsed   + Check_Refused / A_Check_Parsed >= Parsed,
      Parsed   + Check_Has     / A_Check_Has    >= Parsed,
      Parsed   + Check_Lacks   / A_Check_Lacks  >= Parsed];
   --!format on

   Current : State := Unparsed;

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean) is
   begin
      Flow.Take (Table, Current, Ctx, Evt, Handled);
   end Offer;

   procedure Reset is
   begin
      Current := Unparsed;
   end Reset;

   function Phase return String
   is (Current'Image);

   function Done return Boolean
   is (Current = Parsed);

end Lector_Steps.Parsing;
