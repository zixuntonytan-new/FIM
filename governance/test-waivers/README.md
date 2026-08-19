# Test waivers

Create a waiver here only when a meaningful automated test is genuinely
unavailable for a changed executable source file. A waiver is temporary and
must use these exact fields:

```markdown
# Test waiver: <short task name>

- Affected files: `path/to/file`
- Reason: why a meaningful automated test is unavailable
- Compensating evidence: the actual review, assertion, simulation, or run used
- Owner: responsible person or team
- Expires: YYYY-MM-DD
```

The policy checker accepts a waiver only when every field is present and its
expiry date is today or later. Agents cannot use a waiver to override a failed
test or source-size check.
