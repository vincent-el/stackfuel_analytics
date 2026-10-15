# Agent demo · transcript

Beat 1, the standard question, through the warehouse MCP server (`.mcp.json`), 15.10.2026. The
first run below speaks the protocol directly to the server, so the exchange is shown exactly as
the agent sees it; the Cursor run of the same question follows at the rehearsal.

**Ask.** Wie viele Teilnahmen sind im Verzug bei 20 Prozentpunkten?

**Tool call** `execute_query`

```sql
select
    count(*) filter (where is_behind_schedule) as im_verzug,
    count(*) as aktiv
from mart.report_progress_vs_schedule(date '2026-08-31', 20)
```

**Result**

```json
{"success": true, "columns": ["im_verzug", "aktiv"], "rows": [[48, 172]], "rowCount": 1}
```

**Answer.** 48 der 172 am Stichtag 31.08.2026 aktiven Teilnahmen liegen mindestens 20
Prozentpunkte hinter dem Zeitplan (28 %). Bei der Standardschwelle von 15 Prozentpunkten sind es
61 (35 %), wie in README § Results.

**Write attempt, refused by the database, not by a rule of ours:**

```
Invalid Input Error: Cannot execute statement of type "CREATE" on database "warehouse"
which is attached in read-only mode!
```

Beats 2 (a new question over the star) and 3 (the live edit of a definition, then `make build`:
dashboard, CSVs and the agent's answer change together) are run in the talk.
