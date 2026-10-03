with Fabula.Check.Ints;

with Lector_Steps.Flows;

package body Lector_Steps.Smoke is

   --  Empty until a step reads fields; the check reads the count then.
   type State is (Empty, Read);

   type Guard_Kind is (Always, Fields_Read);

   type Action_Kind is
     (A_Nothing, A_Start, A_Add_Fields, A_Refuse_Fields, A_Check_Fields);

   function Evaluate
     (G : Guard_Kind; Ctx : Step_Context; Evt : Step_Kind) return Boolean
   is
      pragma Unreferenced (Evt);
   begin
      return
        (case G is
           when Always      => True,
           when Fields_Read => Count_Read (Ctx));
   end Evaluate;

   procedure Execute
     (A : Action_Kind; Ctx : in out Step_Context; Evt : Step_Kind)
   is
      pragma Unreferenced (Evt);
   begin
      case A is
         when A_Nothing       =>
            null;

         when A_Start         =>
            Ctx.W.Fields := 0;

         when A_Add_Fields    =>
            Ctx.W.Fields := Ctx.W.Fields + Count (Ctx);

         when A_Refuse_Fields =>
            Refuse_Count (Ctx);

         when A_Check_Fields  =>
            Fabula.Check.Ints.Equal
              (Ctx.R, Ctx.W.Fields, Count (Ctx), "the fields read");
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

   Start_Count : constant Ev := (Kind => E_Start_Count);
   Read_Fields : constant Ev := (Kind => E_Read_Fields);
   Check_Read  : constant Ev := (Kind => E_Check_Read);

   --!format off
   Table : constant Transition_Table :=
     [Empty + Start_Count                             / A_Start         >= Empty,
      Empty + Read_Fields (Fields_Read)               / A_Add_Fields    >= Read,
      Empty + Read_Fields                             / A_Refuse_Fields >= Empty,
      Read  + Read_Fields (Fields_Read)               / A_Add_Fields    >= Read,
      Read  + Read_Fields                             / A_Refuse_Fields >= Read,
      Read  + Check_Read  (Fields_Read)               / A_Check_Fields  >= Read,
      Read  + Check_Read                              / A_Refuse_Fields >= Read];
   --!format on

   Current : State := Empty;

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean) is
   begin
      Flow.Take (Table, Current, Ctx, Evt, Handled);
   end Offer;

   procedure Reset is
   begin
      Current := Empty;
   end Reset;

   function Phase return String
   is (Current'Image);

end Lector_Steps.Smoke;
