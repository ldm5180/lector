with Lector.Scan;

with Lector_World;

with Lector_Steps.Flows;
with Lector_Steps.Holding;

package body Lector_Steps.Scanning is

   --  Idle until a scan reads a value; the checks read it then, and
   --  another scan may read the same document again.
   type State is (Idle, Read);

   type Guard_Kind is (Always, Held, Fits, Found);

   type Action_Kind is
     (A_Nothing,
      A_Scan_String,
      A_Scan_String_After,
      A_Scan_Number,
      A_Scan_Object,
      A_Refuse_Key,
      A_Refuse_First,
      A_Check_Value);

   --  The captures: the key a scan reads, then the key it starts after
   --  or the key an object is matched on, then the value matched.
   Read_Key   : constant := 1;
   Second_Key : constant := 2;
   Match      : constant := 3;

   function Capture (Ctx : Step_Context; N : Positive) return String
   is (Fabula.Args.Word (Ctx.A, N));

   --  How many of a step's leading captures are keys.
   function Key_Count (Evt : Step_Kind) return Positive
   is (if Evt in E_Scan_String_After | E_Scan_Object
       then Second_Key
       else Read_Key);

   function Fits (Ctx : Step_Context; N : Positive) return Boolean
   is (Capture (Ctx, N)'Length <= Lector.Scan.Max_Key);

   --  The first of a step's keys longer than a scan accepts, if any.
   function Long_Key (Ctx : Step_Context; Evt : Step_Kind) return Natural is
   begin
      for N in Read_Key .. Key_Count (Evt) loop
         if not Fits (Ctx, N) then
            return N;
         end if;
      end loop;
      return 0;
   end Long_Key;

   function Doc (Ctx : Step_Context) return String
   is (To_String (Ctx.W.Doc));

   --  Where the first occurrence of the second key is; 0 when absent.
   function First_At (Ctx : Step_Context) return Natural
   is (Lector.Scan.Find
         (Doc (Ctx), Lector_World.Quoted (Capture (Ctx, Second_Key)), 1));

   function Evaluate
     (G : Guard_Kind; Ctx : Step_Context; Evt : Step_Kind) return Boolean is
   begin
      return
        (case G is
           when Always => True,
           when Held   => Holding.Held,
           when Fits   => Holding.Held and then Long_Key (Ctx, Evt) = 0,
           when Found  =>
             Holding.Held
             and then Long_Key (Ctx, Evt) = 0
             and then First_At (Ctx) > 0);
   end Evaluate;

   procedure Keep (Ctx : in out Step_Context; Value : String) is
   begin
      Ctx.W.Value := To_Unbounded_String (Value);
   end Keep;

   function String_After (Ctx : Step_Context) return String
   is (Lector.Scan.String_Value
         (Doc (Ctx), Capture (Ctx, Read_Key), First_At (Ctx) + 1));

   function Object_Field (Ctx : Step_Context) return String
   is (Lector.Scan.Object_Value
         (Doc (Ctx),
          Match_Key   => Capture (Ctx, Second_Key),
          Match_Value => Capture (Ctx, Match),
          Want_Key    => Capture (Ctx, Read_Key)));

   procedure Execute
     (A : Action_Kind; Ctx : in out Step_Context; Evt : Step_Kind) is
   begin
      case A is
         when A_Nothing           =>
            null;

         when A_Scan_String       =>
            Keep
              (Ctx,
               Lector.Scan.String_Value
                 (Doc (Ctx), Capture (Ctx, Read_Key), 1));

         when A_Scan_String_After =>
            Keep (Ctx, String_After (Ctx));

         when A_Scan_Number       =>
            Keep
              (Ctx,
               Lector.Scan.Number_Value
                 (Doc (Ctx), Capture (Ctx, Read_Key), 1));

         when A_Scan_Object       =>
            Keep (Ctx, Object_Field (Ctx));

         when A_Refuse_Key        =>
            Fabula.Check.Fail_Step
              (Ctx.R,
               "a key is at most"
               & Lector.Scan.Max_Key'Image
               & " characters: "
               & Capture (Ctx, Long_Key (Ctx, Evt)));

         when A_Refuse_First      =>
            Fabula.Check.Fail_Step
              (Ctx.R,
               "the document holds no "
               & Lector_World.Quoted (Capture (Ctx, Second_Key))
               & " to start after");

         when A_Check_Value       =>
            Fabula.Check.Text_Equal
              (Ctx.R,
               To_String (Ctx.W.Value),
               Fabula.Args.Text (Ctx.A, Read_Key),
               "the value read");
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

   Scan_String       : constant Ev := (Kind => E_Scan_String);
   Scan_String_After : constant Ev := (Kind => E_Scan_String_After);
   Scan_Number       : constant Ev := (Kind => E_Scan_Number);
   Scan_Object       : constant Ev := (Kind => E_Scan_Object);
   Check_Value       : constant Ev := (Kind => E_Check_Value);

   --!format off
   Table : constant Transition_Table :=
     [Idle + Scan_String       (Fits)  / A_Scan_String       >= Read,
      Idle + Scan_String       (Held)  / A_Refuse_Key        >= Idle,
      Idle + Scan_String_After (Found) / A_Scan_String_After >= Read,
      Idle + Scan_String_After (Fits)  / A_Refuse_First      >= Idle,
      Idle + Scan_String_After (Held)  / A_Refuse_Key        >= Idle,
      Idle + Scan_Number       (Fits)  / A_Scan_Number       >= Read,
      Idle + Scan_Number       (Held)  / A_Refuse_Key        >= Idle,
      Idle + Scan_Object       (Fits)  / A_Scan_Object       >= Read,
      Idle + Scan_Object       (Held)  / A_Refuse_Key        >= Idle,
      Read + Scan_String       (Fits)  / A_Scan_String       >= Read,
      Read + Scan_String       (Held)  / A_Refuse_Key        >= Read,
      Read + Scan_String_After (Found) / A_Scan_String_After >= Read,
      Read + Scan_String_After (Fits)  / A_Refuse_First      >= Read,
      Read + Scan_String_After (Held)  / A_Refuse_Key        >= Read,
      Read + Scan_Number       (Fits)  / A_Scan_Number       >= Read,
      Read + Scan_Number       (Held)  / A_Refuse_Key        >= Read,
      Read + Scan_Object       (Fits)  / A_Scan_Object       >= Read,
      Read + Scan_Object       (Held)  / A_Refuse_Key        >= Read,
      Read + Check_Value               / A_Check_Value       >= Read];
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

end Lector_Steps.Scanning;
