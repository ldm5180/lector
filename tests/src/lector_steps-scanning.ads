--  The targeted scans (scanning.feature, absence.feature): a field read
--  straight out of the document in hand, and the value it gave checked.
--  A region of the registry: Offer takes this feature's steps, Reset
--  starts a scenario, Phase names its state.

package Lector_Steps.Scanning is

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean);

   procedure Reset;

   function Phase return String;

end Lector_Steps.Scanning;
