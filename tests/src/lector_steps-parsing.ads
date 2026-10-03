--  The whole-document parse (parsing.feature): the document in hand
--  parsed, and the parse's verdict and fields checked.  A region of the
--  registry: Offer takes these steps, Reset starts a scenario, Phase
--  names its state.

package Lector_Steps.Parsing is

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean);

   procedure Reset;

   function Phase return String;

   --  Whether the scenario has parsed its document, well-formed or not:
   --  the guard a field read shares.
   function Done return Boolean;

end Lector_Steps.Parsing;
