--  Lector: narrow JSON reading -- SPARK-proven targeted scans over raw
--  JSON text (Lector.Scan) and a utilada-backed whole-document parse into
--  a flat property view (Lector.Utilada).  Absence is empty, never an
--  error: missing keys read as "", and only malformed input flips a
--  parse's Ok to False.

package Lector
  with Pure, SPARK_Mode
is

end Lector;
