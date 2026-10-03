with Lector.Utilada;

with Lector_Steps.Flows;
with Lector_Steps.Holding;

package body Lector_Steps.Parsing is

   --  Unparsed until the document in hand is parsed; the verdict and the
   --  document are then the world's.
   type State is (Unparsed, Parsed);

   type Guard_Kind is (Always, Held);

   type Action_Kind is (A_Nothing, A_Parse);

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
     (A : Action_Kind; Ctx : in out Step_Context; Evt : Step_Kind)
   is
      pragma Unreferenced (Evt);
   begin
      case A is
         when A_Nothing =>
            null;

         when A_Parse   =>
            Lector.Utilada.Parse
              (To_String (Ctx.W.Doc), Ctx.W.Parse, Ctx.W.Parsed);
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

   Parse : constant Ev := (Kind => E_Parse);

   --!format off
   Table : constant Transition_Table :=
     [Unparsed + Parse (Held) / A_Parse >= Parsed];
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
