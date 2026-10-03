--  The runner's own smoke test (smoke.feature): fields are counted as
--  they are read.  A region of the registry: Offer takes this feature's
--  steps, Reset starts a scenario, Phase names its state.

package Lector_Steps.Smoke is

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean);

   procedure Reset;

   function Phase return String;

end Lector_Steps.Smoke;
