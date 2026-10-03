--  Every read that gives a value, and the checks on it: the targeted
--  scans straight out of the document in hand (scanning.feature,
--  absence.feature) and a field out of the parsed document
--  (parsing.feature).  A region of the registry: Offer takes these
--  steps, Reset starts a scenario, Phase names its state.

package Lector_Steps.Reading is

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean);

   procedure Reset;

   function Phase return String;

end Lector_Steps.Reading;
