# Glossary

The words the data and the weekly report use, German first because the sources are German. Source: where the word comes from in this repository's inputs.

| DE | EN | In this data | Source |
|:--|:--|:--|:--|
| Teilnehmende, Teilnehmer:in | participant | one row in `participants`; may appear twice under two ids | CRM |
| Teilnahme | participation | one row in `enrollments`: a participant in one training; the unit of every KPI | CRM |
| Training | training | one of 8 trainings, each with a list of modules | CRM |
| Variante | variant | vollzeit · teilzeit · berufsbegleitend; sets the planned duration | CRM |
| Modul | module | a unit of a training, ordered; completed when the LXP logs `module_completed` | LXP |
| Kohorte, Kursstart | cohort | the participations that start a training on the same date | CRM, Excel |
| Stichtag | reference date | the day every answer is computed for: 31.08.2026 | task |
| Datenstand | data as of | the day the sources were taken: 01.09.2026 | task |
| angemeldet | registered | booked, not started | CRM status |
| aktiv | active | learning right now; the Q1 population | CRM status |
| pausiert | paused | participation running, learning stopped; shown beside active, counted for coach load | CRM status |
| abgeschlossen | completed | finished; the coach confirmed the exam | CRM status |
| abgebrochen | dropped out | ended before the plan, by anyone | CRM status |
| storniert | cancelled | ended before it started; not a dropout | CRM status |
| geplantes Ende | planned end | the date the training should end for this participation | CRM |
| Förderart | funding type | who pays: voucher, employer, self | CRM |
| Bildungsgutschein | education voucher | the Agentur für Arbeit or Jobcenter pays the training | domain |
| Agentur für Arbeit | employment agency | the funder behind most vouchers; receives attendance reports | domain |
| Coach | coach | the person who supports a participation; named in the Excel, not in the CRM | Excel |
| Betreuungsliste | assignment list | the hand-kept Excel: who coaches whom, Ampel, last contact | Excel |
| Ampel | traffic light | the coach's judgement of a participation; the list holds grün, gelb and rot, also as "g", "r" and empty; the legend defines gelb as "leichter Verzug / Kontakt nötig" | Excel |
| Letzter Kontakt | last contact | the date the coach last reached the participant | Excel |
| Coach-Auslastung | coach load | active or paused participations per coach | Q5 |
| Lernfortschritt | learning progress | completed modules over the training's modules | Q3 |
| Zeitfortschritt | time progress | days elapsed over planned days, capped at 100 % | Q3 |
| im Verzug | behind schedule | time progress minus learning progress ≥ 15 points | Q3 |
| Abschlussfeedback | end-of-course survey | the survey completers answer; holds the NPS | LXP |
| Wochenfeedback | weekly survey | satisfaction and tempo per week | LXP |
| NPS | Net Promoter Score | promoters (9–10) minus detractors (0–6), in percent | Q4 |
| Leitung Training Operations | head of training operations | the reader of the weekly report | task |

## Disambiguation

| Word | Means here | Not |
|:--|:--|:--|
| Teilnahme | one participant in one training; the unit every KPI counts | the person (Teilnehmende) |
| Coach | the person on the Betreuungsliste who supports a participation | Tutor, Lehrkraft, Mentor: other titles for overlapping roles; one role here |
| Training | one of the 8 products with modules | a cohort (one run of it) or a module (one part of it) |
| abgeschlossen | completed, as the CRM status says | passed an exam: the data holds no exam result |
| aktiv | the CRM status; learning right now | the running, funded participation, which includes pausiert |
