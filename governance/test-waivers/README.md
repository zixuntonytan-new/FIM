# Test waivers

Create a waiver here only when a meaningful automated test is genuinely
unavailable for a changed executable source file. A waiver is temporary and
must use these exact fields:

```markdown
# Test waiver: <short task name>

- Affected files: `path/to/file` (comma-separate multiple paths)
- Reason: why a meaningful automated test is unavailable
- Compensating evidence: the actual review, assertion, simulation, or run used
- Owner: responsible person or team
- Approval: explicit user approval reference (for example, the approved PR or chat)
- Expires: YYYY-MM-DD
```

The policy checker accepts a waiver only when every field is present, it names
the changed executable file it covers, and it expires within 30 days. A waiver
cannot override a failed test or source-size check. Agents must obtain explicit
user approval before creating one; the approval reference is review evidence,
not a substitute for the actual compensating evidence.
