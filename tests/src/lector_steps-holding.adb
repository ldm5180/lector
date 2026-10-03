with Lector_World;

with Lector_Steps.Flows;

package body Lector_Steps.Holding is

   --  Blank until a step holds a document; a named one is Loading until
   --  its read settles.
   type State is (Blank, Loading, Holding);

   type Guard_Kind is (Always, Doc_Given, Loaded);

   type Action_Kind is
     (A_Nothing,
      A_Hold_Doc,
      A_Refuse_Doc,
      A_Load_Named,
      A_Refuse_Document,
      A_Hold_Empty);

   First_Capture : constant := 1;

   function Evaluate
     (G : Guard_Kind; Ctx : Step_Context; Evt : Step_Kind) return Boolean
   is
      pragma Unreferenced (Evt);
   begin
      return
        (case G is
           when Always    => True,
           when Doc_Given => Fabula.Args.Has_Doc (Ctx.A),
           when Loaded    => Ctx.W.Loaded);
   end Evaluate;

   function Name (Ctx : Step_Context) return String
   is (Fabula.Args.Word (Ctx.A, First_Capture));

   procedure Load_Named (Ctx : in out Step_Context) is
   begin
      Lector_World.Named_Document
        (Lector_World.Docs_Dir (Ctx.Info),
         Name (Ctx),
         Ctx.W.Doc,
         Ctx.W.Loaded);
      Then_Take (Ctx, E_Document_Settled);
   end Load_Named;

   procedure Execute
     (A : Action_Kind; Ctx : in out Step_Context; Evt : Step_Kind)
   is
      pragma Unreferenced (Evt);
   begin
      case A is
         when A_Nothing         =>
            null;

         when A_Hold_Doc        =>
            Ctx.W.Doc := To_Unbounded_String (Fabula.Args.Doc_String (Ctx.A));

         when A_Refuse_Doc      =>
            Fabula.Check.Fail_Step (Ctx.R, "the step carries no doc string");

         when A_Load_Named      =>
            Load_Named (Ctx);

         when A_Refuse_Document =>
            Fabula.Check.Fail_Step
              (Ctx.R,
               "no document named "
               & Name (Ctx)
               & " in "
               & Lector_World.Docs_Dir (Ctx.Info));

         when A_Hold_Empty      =>
            Ctx.W.Doc := Null_Unbounded_String;
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

   Hold_Doc         : constant Ev := (Kind => E_Hold_Doc);
   Hold_Named       : constant Ev := (Kind => E_Hold_Named);
   Hold_Empty       : constant Ev := (Kind => E_Hold_Empty);
   Document_Settled : constant Ev := (Kind => E_Document_Settled);

   --!format off
   Table : constant Transition_Table :=
     [Blank   + Hold_Doc (Doc_Given)        / A_Hold_Doc        >= Holding,
      Blank   + Hold_Doc                    / A_Refuse_Doc      >= Blank,
      Blank   + Hold_Named                  / A_Load_Named      >= Loading,
      Loading + Document_Settled (Loaded)   / A_Nothing         >= Holding,
      Loading + Document_Settled            / A_Refuse_Document >= Blank,
      Blank   + Hold_Empty                  / A_Hold_Empty      >= Holding];
   --!format on

   Current : State := Blank;

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean) is
   begin
      Flow.Take (Table, Current, Ctx, Evt, Handled);
   end Offer;

   procedure Reset is
   begin
      Current := Blank;
   end Reset;

   function Phase return String
   is (Current'Image);

   function Held return Boolean
   is (Current = Holding);

end Lector_Steps.Holding;
