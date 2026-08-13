# FIM public operating runbooks

These documents are safe to share in the public FIM fork. They define portable
procedure but do not contain private handoff facts, credentials, confidential
inputs, or raw execution records.

Start each substantive session with scripts/Start-FIM-AgentSession.ps1. It
locates and fast-forwards the private hutchins-agent-ops clone, whose FIM
directory is the canonical shared context.

- DUAL_LAPTOP_WORKFLOW.md: transfer and return procedure.
- HANDOFF_TEMPLATE.md: public branch/tag and private receipt fields.
- FIM_MAINTAINER_GUIDE.md: concise code and release workflow map.
- FORECAST_WORKBOOK_BRIEFING.md: concise controlled-workbook safeguards.

The detailed private technical references and investigation evidence are routed
from hutchins-agent-ops/FIM/README.md after preflight.
