--  The document a scenario holds, shared by every feature: spelled in a
--  doc string, named from the feature's docs/ directory, or empty.  A
--  region of the registry: Offer takes this feature's steps, Reset starts
--  a scenario, Phase names its state.

package Lector_Steps.Holding is

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean);

   procedure Reset;

   function Phase return String;

   --  Whether the scenario holds a document: the guard every reading
   --  feature's first step shares.
   function Held return Boolean;

end Lector_Steps.Holding;
