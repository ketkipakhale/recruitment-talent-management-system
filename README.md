# Recruitment and Talent Management System

A portfolio project for managing recruitment from job posting through application review, interviews, decisions, and offers. It uses fictional company and candidate data and targets Microsoft SQL Server 2019+ (T-SQL).

## Portfolio highlights

- Designed a normalized SQL Server schema for jobs, candidates, applications, skills, interview panels, feedback, offers, and auditable status history.
- Implemented transactional T-SQL procedures with validation for job lifecycle, application transitions, interview scheduling conflicts, interviewer feedback, and offer decisions.
- Built reporting views and queries for the hiring funnel, time to hire, source effectiveness, and interviewer workload, using joins, aggregation, CTEs, and window functions.

## Run it

Run the scripts in numeric order against a SQL Server instance using SSMS, Azure Data Studio, or `sqlcmd`. `01_database.sql` creates and selects `RecruitmentTalentDB`; the remaining scripts use that database. Creating a database requires suitable server permissions. To reset the demo, drop the database manually and rerun the scripts.

1. `sql/01_database.sql`
2. `sql/02_tables.sql`
3. `sql/03_indexes.sql`
4. `sql/04_seed_data.sql`
5. `sql/05_procedures.sql`
6. `sql/06_views.sql`
7. `sql/07_reports.sql` (optional runnable report examples)
8. `tests/01_workflow_tests.sql` (transactional tests; rolls back its successful test writes)

The seed intentionally includes applications at varied stages and outcomes. Do not rerun the seed against an already populated database; use a fresh database.

## Schema overview

The normalized model separates departments, system users/hiring managers, job openings, skills and job requirements, candidates and skills, applications and status history, interview rounds/schedules/interviewers/feedback, and offers. See [`docs/ERD.md`](docs/ERD.md). Application and interview histories are explicit workflow records: core procedures write them transactionally, with no trigger-based business logic.

## Business rules

- An application is unique per candidate and job. Only a posted, open, not-yet-closed job accepts applications.
- Applications start at `Applied`; allowed transitions are `Applied → Screening`, `Screening → Interview|Rejected|Withdrawn`, `Interview → Offer|Rejected|Withdrawn`, `Offer → Hired|Rejected|Withdrawn`, and `Rejected → Screening`. Same-state updates are rejected. A closed job does not accept new applications.
- Interviews must be scheduled in the future with end after start. A person cannot be scheduled in overlapping interviews. Rescheduling writes an audit event. Feedback is unique per interviewer/interview and includes a 1–5 rating and recommendation.
- Offers have positive salary and valid date ranges. A declined offer is terminal; an accepted offer can update application stage to `Hired`. Creating/updating the offer and any corresponding application transition are atomic.
- UTC timestamps are stored with `datetime2`; report date math uses SQL Server date functions.

## Example workflow

```sql
DECLARE @DemoApplicationId int;
EXEC dbo.usp_PostJob @JobId = 5; -- seeded draft role
EXEC dbo.usp_SubmitApplication @JobId = 5, @CandidateId = 1, @Source = N'Referral', @SubmittedByUserId = 5;
SELECT @DemoApplicationId = ApplicationId FROM dbo.Application WHERE JobId = 5 AND CandidateId = 1;
EXEC dbo.usp_ChangeApplicationStatus @ApplicationId = @DemoApplicationId, @NewStatus = N'Screening', @ChangedByUserId = 5, @Notes = N'Initial review';
EXEC dbo.usp_ChangeApplicationStatus @ApplicationId = @DemoApplicationId, @NewStatus = N'Interview', @ChangedByUserId = 5, @Notes = N'Advance';
EXEC dbo.usp_ScheduleInterview @ApplicationId = @DemoApplicationId, @InterviewRoundId = 1, @StartsAt = DATEADD(day, 30, SYSUTCDATETIME()), @EndsAt = DATEADD(hour, 1, DATEADD(day, 30, SYSUTCDATETIME())), @Location = N'Video', @ScheduledByUserId = 5, @InterviewerUserIds = N'2,3';
EXEC dbo.usp_CreateOrUpdateOffer @ApplicationId = @DemoApplicationId, @SalaryAmount = 125000, @CurrencyCode = 'USD', @OfferDate = CONVERT(date, SYSUTCDATETIME()), @ExpiresOn = DATEADD(day, 10, CONVERT(date, SYSUTCDATETIME())), @OfferStatus = N'Pending', @CreatedByUserId = 5;
```

To test feedback, select a completed interview and one of its assigned interviewers; feedback is accepted only once per interviewer per completed interview. To close a job, use `dbo.usp_CloseJob`.

## Reports

Views provide open jobs, candidates by stage, and upcoming interviews. `07_reports.sql` contains hiring funnel conversion, time to hire, source effectiveness, and interviewer workload queries. The reports demonstrate joins, aggregation, CTEs, window functions, subqueries, and date calculations.

## Interview talking points

- **Normalization:** job and candidate skills use bridge tables; interview panels and feedback are distinct records so each interviewer can independently score each round.
- **Workflow integrity:** stored procedures validate the requested action, then commit related writes and audit records together using `XACT_ABORT`, `TRY/CATCH`, and explicit transactions.
- **History:** application status and interview schedule changes are append-only workflow events; current state remains on the parent row for efficient reads.
- **Indexes:** unique keys protect business identity; targeted indexes support job status/date searches, candidate application lookup, stage reporting, interview schedules, and feedback access.
- **Insights:** compare funnel stages and conversion, elapsed days from application to hire, source-level hires per applicant, and future interviewer load to spot bottlenecks.

## Files

- `sql/`: ordered database setup, tables, indexes, fictional seed, procedures, views, and reports.
- `tests/01_workflow_tests.sql`: positive and expected-failure workflow checks.
- `docs/ERD.md`: Mermaid entity relationship diagram.
