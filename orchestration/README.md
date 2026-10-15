# orchestration

**The daily run.** `crontab` holds one line: at 06:00, `cd` into the clone and `make run`, stdout and
stderr appended to `storage/logs/run_<date>.log`. Each run lands its own record in
`storage/bucket/_load_history/` (`raw.load_history`): tables, pages, rows, 503 retries, watermarks.

**Failure** is a non-zero exit of `make run`: a fetch that keeps getting 503, a failing dbt test, a
locked warehouse. It is visible as the error at the end of that day's log; cron itself only mails it.

## Production ladder

- **L0, cron on a box.** This folder. Enough for one pipeline and one person who reads the log.
- **L1, cron instrumented.** Same line, plus: run records read as data (they already land in
  `raw.load_history`), a non-zero exit posted to Slack (`make run || notify`), the CloudWatch agent
  shipping the log, credentials from Secrets Manager instead of the Makefile defaults.
- **L2, AWS-native schedule, no box.** EventBridge Scheduler runs the pipeline image as an ECS
  Fargate task; logs in CloudWatch, retries by the scheduler. About 60 lines of Terraform.
- **L3, an orchestrator** (Airflow / MWAA, Prefect, Dagster), once there is a second dependent
  pipeline, a second person on call, or routine backfills. It adds: order across jobs, retry of the
  failed step only, backfills by logical date, run history with a UI, alerts.
  Measured on this loader with Prefect: roughly 28 code lines over the same fetch, load and build;
  108 packages / 128 MB to install; run 1 in 12.8 s, run 2 in 6.1 s; each run starts a temporary
  server. Retries and the run record it would add exist in the loader already.
- **L4, event-driven.** The landing event (a file in the bucket, a CRM webhook) triggers the run
  instead of the clock.
