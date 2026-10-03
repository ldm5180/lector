with Fabula.Main;

with Lector_Steps;

--  The feature runner: Fabula.Main over the crate's step registry,
--  run over tests/features/ by `make features` and `alr test`.

procedure Lector_Features is new
  Fabula.Main
    (Steps     => Lector_Steps.Steps,
     Step_Defs => Lector_Steps.Step_Defs,
     Hook_Defs => Lector_Steps.Hook_Defs,
     Execute   => Lector_Steps.Execute,
     Run_Hook  => Lector_Steps.Run_Hook);
