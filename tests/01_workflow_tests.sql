/* Run after setup. Creates four clearly named test candidates and removes them at the end. */
USE RecruitmentTalentDB;
GO
SET NOCOUNT ON;
SET XACT_ABORT OFF;
DECLARE @CandidateId int,@AppId int,@InterviewId int,@OtherAppId int,@ConflictAppId int,@ConflictInterviewId int,@Now datetime2(0)=SYSUTCDATETIME();
INSERT dbo.Candidate(FirstName,LastName,Email) VALUES(N'Test',N'Normal',N'test.normal@example.test'); SET @CandidateId=SCOPE_IDENTITY();
EXEC dbo.usp_SubmitApplication @JobId=1,@CandidateId=@CandidateId,@Source=N'Test',@SubmittedByUserId=5;
SELECT @AppId=ApplicationId FROM dbo.Application WHERE JobId=1 AND CandidateId=@CandidateId;
IF NOT EXISTS(SELECT 1 FROM dbo.ApplicationStatusHistory WHERE ApplicationId=@AppId AND NewStatus=N'Applied') THROW 52001,'Submit did not write initial status history.',1;
EXEC dbo.usp_ChangeApplicationStatus @ApplicationId=@AppId,@NewStatus=N'Screening',@ChangedByUserId=5,@Notes=N'Test progress';
EXEC dbo.usp_ChangeApplicationStatus @ApplicationId=@AppId,@NewStatus=N'Interview',@ChangedByUserId=5,@Notes=N'Advance';
EXEC dbo.usp_ScheduleInterview @ApplicationId=@AppId,@InterviewRoundId=1,@StartsAt=DATEADD(day,4,@Now),@EndsAt=DATEADD(hour,1,DATEADD(day,4,@Now)),@Location=N'Test video',@ScheduledByUserId=5,@InterviewerUserIds=N'2',@InterviewId=NULL;
SELECT @InterviewId=MAX(InterviewId) FROM dbo.Interview WHERE ApplicationId=@AppId;
EXEC dbo.usp_ScheduleInterview @ApplicationId=@AppId,@InterviewRoundId=1,@StartsAt=DATEADD(day,5,@Now),@EndsAt=DATEADD(hour,1,DATEADD(day,5,@Now)),@Location=N'Test video',@ScheduledByUserId=5,@InterviewerUserIds=N'2',@InterviewId=@InterviewId;
IF NOT EXISTS(SELECT 1 FROM dbo.InterviewHistory WHERE InterviewId=@InterviewId AND EventType=N'Rescheduled') THROW 52002,'Reschedule did not write audit history.',1;
/* Duplicate application. */
BEGIN TRY EXEC dbo.usp_SubmitApplication @JobId=1,@CandidateId=@CandidateId,@Source=N'Test',@SubmittedByUserId=5; THROW 52003,'Duplicate application unexpectedly succeeded.',1; END TRY BEGIN CATCH IF ERROR_NUMBER()=52003 THROW; END CATCH;
/* Invalid status transition. */
BEGIN TRY EXEC dbo.usp_ChangeApplicationStatus @ApplicationId=@AppId,@NewStatus=N'Hired',@ChangedByUserId=5; THROW 52004,'Invalid transition unexpectedly succeeded.',1; END TRY BEGIN CATCH IF ERROR_NUMBER()=52004 THROW; END CATCH;
/* Closed job. */
INSERT dbo.Candidate(FirstName,LastName,Email) VALUES(N'Test',N'Closed',N'test.closed@example.test'); SET @OtherAppId=SCOPE_IDENTITY();
BEGIN TRY EXEC dbo.usp_SubmitApplication @JobId=4,@CandidateId=@OtherAppId,@Source=N'Test',@SubmittedByUserId=5; THROW 52005,'Closed job application unexpectedly succeeded.',1; END TRY BEGIN CATCH IF ERROR_NUMBER()=52005 THROW; END CATCH;
/* Interview overlap against a different application assigned to the same panel member. */
INSERT dbo.Candidate(FirstName,LastName,Email) VALUES(N'Test',N'Conflict',N'test.conflict@example.test'); SET @CandidateId=SCOPE_IDENTITY();
EXEC dbo.usp_SubmitApplication @JobId=1,@CandidateId=@CandidateId,@Source=N'Test',@SubmittedByUserId=5;
SELECT @ConflictAppId=ApplicationId FROM dbo.Application WHERE JobId=1 AND CandidateId=@CandidateId;
EXEC dbo.usp_ChangeApplicationStatus @ApplicationId=@ConflictAppId,@NewStatus=N'Screening',@ChangedByUserId=5;
EXEC dbo.usp_ChangeApplicationStatus @ApplicationId=@ConflictAppId,@NewStatus=N'Interview',@ChangedByUserId=5;
EXEC dbo.usp_ScheduleInterview @ApplicationId=@ConflictAppId,@InterviewRoundId=1,@StartsAt=DATEADD(day,6,@Now),@EndsAt=DATEADD(hour,1,DATEADD(day,6,@Now)),@Location=N'Conflict fixture',@ScheduledByUserId=5,@InterviewerUserIds=N'2',@InterviewId=NULL;
SELECT @ConflictInterviewId=MAX(InterviewId) FROM dbo.Interview WHERE ApplicationId=@ConflictAppId;
BEGIN TRY EXEC dbo.usp_ScheduleInterview @ApplicationId=@AppId,@InterviewRoundId=1,@StartsAt=DATEADD(day,6,@Now),@EndsAt=DATEADD(hour,1,DATEADD(day,6,@Now)),@Location=N'Conflict',@ScheduledByUserId=5,@InterviewerUserIds=N'2',@InterviewId=@InterviewId; THROW 52006,'Schedule conflict unexpectedly succeeded.',1; END TRY BEGIN CATCH IF ERROR_NUMBER()=52006 THROW; END CATCH;
/* Missing feedback: scheduled interview is not eligible for feedback. */
BEGIN TRY EXEC dbo.usp_RecordInterviewFeedback @InterviewId=@InterviewId,@InterviewerUserId=2,@Rating=5,@Recommendation=N'Proceed',@Comments=N'Test'; THROW 52007,'Feedback before completion unexpectedly succeeded.',1; END TRY BEGIN CATCH IF ERROR_NUMBER()=52007 THROW; END CATCH;
/* A declined offer closes an Offer-stage application and cannot be reopened. */
INSERT dbo.Candidate(FirstName,LastName,Email) VALUES(N'Test',N'Offer',N'test.offer@example.test'); SET @CandidateId=SCOPE_IDENTITY();
EXEC dbo.usp_SubmitApplication @JobId=1,@CandidateId=@CandidateId,@Source=N'Test',@SubmittedByUserId=5;
SELECT @OtherAppId=ApplicationId FROM dbo.Application WHERE JobId=1 AND CandidateId=@CandidateId;
EXEC dbo.usp_ChangeApplicationStatus @ApplicationId=@OtherAppId,@NewStatus=N'Screening',@ChangedByUserId=5;
EXEC dbo.usp_ChangeApplicationStatus @ApplicationId=@OtherAppId,@NewStatus=N'Interview',@ChangedByUserId=5;
EXEC dbo.usp_CreateOrUpdateOffer @ApplicationId=@OtherAppId,@SalaryAmount=100000,@CurrencyCode='USD',@OfferDate=CONVERT(date,@Now),@ExpiresOn=DATEADD(day,7,CONVERT(date,@Now)),@OfferStatus=N'Declined',@CreatedByUserId=5;
IF NOT EXISTS(SELECT 1 FROM dbo.Application WHERE ApplicationId=@OtherAppId AND ApplicationStatus=N'Rejected') THROW 52008,'Declined offer did not reject application.',1;
BEGIN TRY EXEC dbo.usp_CreateOrUpdateOffer @ApplicationId=@OtherAppId,@SalaryAmount=100000,@CurrencyCode='USD',@OfferDate=CONVERT(date,@Now),@ExpiresOn=DATEADD(day,7,CONVERT(date,@Now)),@OfferStatus=N'Pending',@CreatedByUserId=5; THROW 52009,'Declined offer unexpectedly reopened.',1; END TRY BEGIN CATCH IF ERROR_NUMBER()=52009 THROW; END CATCH;
DELETE a FROM dbo.Application a JOIN dbo.Candidate c ON c.CandidateId=a.CandidateId WHERE c.Email IN(N'test.normal@example.test',N'test.closed@example.test',N'test.conflict@example.test',N'test.offer@example.test');
DELETE dbo.Candidate WHERE Email IN(N'test.normal@example.test',N'test.closed@example.test',N'test.conflict@example.test',N'test.offer@example.test');
PRINT 'Workflow tests passed; test records removed.';
GO
