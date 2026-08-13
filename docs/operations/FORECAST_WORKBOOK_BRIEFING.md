# Forecast workbook concise briefing

data/forecast.xlsx is the operational control workbook for FIM updates. It is
not a disposable data file: it may contain formulas, charts, links, hidden
sheets, review structure, and policy inputs required by the model.

## Before a workbook-changing run

1. Run the FIM session-start preflight and verify the public branch/tag and
   matching private task receipt.
2. Record the exact source workbook identity and make a dated backup when the
   run can change it.
3. Read the task-routed private workbook reference and the relevant workbook
   sections before changing inputs.
4. State expected output paths, acceptance checks, and rollback location.

## Safeguards

- Do not replace the workbook with an artifact-tool round-trip.
- Do not overwrite an existing dirty workbook or a workbook owned by another
  agent.
- Do not infer a complete update from an intermediate R stage or partial output.
- Record formulas, assumption changes, paths, outputs, validation, and failures
  in the private handoff and task receipt.

The private technical workbook reference contains the deeper sheet and process
material. Recheck its dated observations against the actual workbook used.
