--  The writing side (masking.feature): the document in hand with its
--  secret keys' values masked, or escaped into a JSON string, as a log
--  would write it.  A region of the registry: Offer takes these steps,
--  Reset starts a scenario, Phase names its state.

package Lector_Steps.Masking is

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean);

   procedure Reset;

   function Phase return String;

end Lector_Steps.Masking;
