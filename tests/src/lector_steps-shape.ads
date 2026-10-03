--  The single-object check (shape.feature): whether the document in
--  hand is one complete object with nothing after it.  A region of the
--  registry: Offer takes these steps, Reset starts a scenario, Phase
--  names its state.

package Lector_Steps.Shape is

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean);

   procedure Reset;

   function Phase return String;

end Lector_Steps.Shape;
