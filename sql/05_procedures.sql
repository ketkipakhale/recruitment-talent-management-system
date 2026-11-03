USE RecruitmentTalentDB;
GO
CREATE OR ALTER PROCEDURE dbo.usp_PostJob @JobId int AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
  UPDATE dbo.JobOpening SET JobStatus=N'Open',PostedAt=SYSUTCDATETIME(),ClosedAt=NULL,UpdatedAt=SYSUTCDATETIME()
  WHERE JobId=@JobId AND JobStatus IN(N'Draft',N'Closed');
  IF @@ROWCOUNT=0 THROW 51001,'Job does not exist or cannot be posted from its current state.',1;
 END TRY BEGIN CATCH THROW; END CATCH
END;
GO
CREATE OR ALTER PROCEDURE dbo.usp_CloseJob @JobId int AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 UPDATE dbo.JobOpening SET JobStatus=N'Closed',ClosedAt=SYSUTCDATETIME(),UpdatedAt=SYSUTCDATETIME()
 WHERE JobId=@JobId AND JobStatus=N'Open';
 IF @@ROWCOUNT=0 THROW 51002,'Job does not exist or is not open.',1;
END;
GO
CREATE OR ALTER PROCEDURE dbo.usp_SubmitApplication
 @JobId int,@CandidateId int,@Source nvarchar(50),@SubmittedByUserId int
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF NULLIF(LTRIM(RTRIM(@Source)),N'') IS NULL THROW 51003,'Application source is required.',1;
 BEGIN TRY
  BEGIN TRAN;
  IF NOT EXISTS(SELECT 1 FROM dbo.JobOpening WHERE JobId=@JobId AND JobStatus=N'Open' AND (ClosedAt IS NULL OR ClosedAt>SYSUTCDATETIME())) THROW 51004,'Applications are accepted only for open jobs.',1;
  IF NOT EXISTS(SELECT 1 FROM dbo.Candidate WHERE CandidateId=@CandidateId) THROW 51005,'Candidate was not found.',1;
  IF NOT EXISTS(SELECT 1 FROM dbo.AppUser WHERE UserId=@SubmittedByUserId AND IsActive=1) THROW 51006,'Submitting user was not found or is inactive.',1;
  IF EXISTS(SELECT 1 FROM dbo.Application WITH(UPDLOCK,HOLDLOCK) WHERE JobId=@JobId AND CandidateId=@CandidateId) THROW 51032,'Candidate has already applied to this job.',1;
  INSERT dbo.Application(JobId,CandidateId,Source) VALUES(@JobId,@CandidateId,LTRIM(RTRIM(@Source)));
  DECLARE @ApplicationId int=CONVERT(int,SCOPE_IDENTITY());
  INSERT dbo.ApplicationStatusHistory(ApplicationId,OldStatus,NewStatus,ChangedByUserId,Notes) VALUES(@ApplicationId,NULL,N'Applied',@SubmittedByUserId,N'Application submitted');
  COMMIT;
  SELECT @ApplicationId AS ApplicationId;
 END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; THROW; END CATCH
END;
GO
CREATE OR ALTER PROCEDURE dbo.usp_ChangeApplicationStatus
 @ApplicationId int,@NewStatus nvarchar(20),@ChangedByUserId int,@Notes nvarchar(500)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @NewStatus NOT IN(N'Applied',N'Screening',N'Interview',N'Offer',N'Hired',N'Rejected',N'Withdrawn') THROW 51007,'Unknown application status.',1;
 BEGIN TRY
  BEGIN TRAN;
  DECLARE @OldStatus nvarchar(20);
  SELECT @OldStatus=ApplicationStatus FROM dbo.Application WITH(UPDLOCK,HOLDLOCK) WHERE ApplicationId=@ApplicationId;
  IF @OldStatus IS NULL THROW 51008,'Application was not found.',1;
  IF NOT EXISTS(SELECT 1 FROM dbo.AppUser WHERE UserId=@ChangedByUserId AND IsActive=1) THROW 51009,'Changing user was not found or is inactive.',1;
  IF NOT ((@OldStatus=N'Applied' AND @NewStatus=N'Screening') OR (@OldStatus=N'Screening' AND @NewStatus IN(N'Interview',N'Rejected',N'Withdrawn')) OR (@OldStatus=N'Interview' AND @NewStatus IN(N'Offer',N'Rejected',N'Withdrawn')) OR (@OldStatus=N'Offer' AND @NewStatus IN(N'Hired',N'Rejected',N'Withdrawn')) OR (@OldStatus=N'Rejected' AND @NewStatus=N'Screening'))
   THROW 51010,'Invalid application status transition.',1;
  UPDATE dbo.Application SET ApplicationStatus=@NewStatus,UpdatedAt=SYSUTCDATETIME() WHERE ApplicationId=@ApplicationId;
  INSERT dbo.ApplicationStatusHistory(ApplicationId,OldStatus,NewStatus,ChangedByUserId,Notes) VALUES(@ApplicationId,@OldStatus,@NewStatus,@ChangedByUserId,@Notes);
  COMMIT;
 END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; THROW; END CATCH
END;
GO
CREATE OR ALTER PROCEDURE dbo.usp_ScheduleInterview
 @ApplicationId int,@InterviewRoundId int,@StartsAt datetime2(0),@EndsAt datetime2(0),@Location nvarchar(160),
 @ScheduledByUserId int,@InterviewerUserIds nvarchar(4000),@InterviewId int=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @StartsAt<=SYSUTCDATETIME() OR @EndsAt<=@StartsAt THROW 51011,'Interview must have a future start and end after start.',1;
 IF NULLIF(LTRIM(RTRIM(@Location)),N'') IS NULL THROW 51012,'Interview location is required.',1;
 DECLARE @Panel TABLE(UserId int PRIMARY KEY);
 BEGIN TRY
  INSERT @Panel(UserId) SELECT DISTINCT TRY_CONVERT(int,LTRIM(RTRIM(value))) FROM STRING_SPLIT(@InterviewerUserIds,N',') WHERE TRY_CONVERT(int,LTRIM(RTRIM(value))) IS NOT NULL;
 END TRY BEGIN CATCH THROW 51013,'Interviewer list is invalid.',1; END CATCH
 IF NOT EXISTS(SELECT 1 FROM @Panel) THROW 51013,'At least one valid interviewer is required.',1;
 BEGIN TRY
  BEGIN TRAN;
  DECLARE @ScheduleLockResult int;
  EXEC @ScheduleLockResult=sys.sp_getapplock @Resource=N'RecruitmentTalent.InterviewSchedule',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=10000;
  IF @ScheduleLockResult<0 THROW 51033,'Could not obtain the interview schedule lock; retry the request.',1;
  IF NOT EXISTS(SELECT 1 FROM dbo.Application WHERE ApplicationId=@ApplicationId AND ApplicationStatus=N'Interview') THROW 51014,'Application must be at Interview stage.',1;
  IF NOT EXISTS(SELECT 1 FROM dbo.InterviewRound WHERE InterviewRoundId=@InterviewRoundId) THROW 51015,'Interview round was not found.',1;
  IF NOT EXISTS(SELECT 1 FROM dbo.AppUser WHERE UserId=@ScheduledByUserId AND IsActive=1) THROW 51016,'Scheduling user was not found or is inactive.',1;
  IF EXISTS(SELECT 1 FROM @Panel p LEFT JOIN dbo.AppUser u ON u.UserId=p.UserId AND u.IsActive=1 WHERE u.UserId IS NULL OR u.UserRole<>N'Interviewer') THROW 51017,'Every panel member must be an active interviewer.',1;
  IF EXISTS(SELECT 1 FROM @Panel p JOIN dbo.Interviewer x ON x.UserId=p.UserId JOIN dbo.Interview i ON i.InterviewId=x.InterviewId AND i.InterviewStatus=N'Scheduled'
    WHERE (@InterviewId IS NULL OR i.InterviewId<>@InterviewId) AND i.StartsAt<@EndsAt AND i.EndsAt>@StartsAt) THROW 51018,'An interviewer has an overlapping scheduled interview.',1;
  IF @InterviewId IS NULL
  BEGIN
   INSERT dbo.Interview(ApplicationId,InterviewRoundId,StartsAt,EndsAt,Location) VALUES(@ApplicationId,@InterviewRoundId,@StartsAt,@EndsAt,@Location);
   SET @InterviewId=CONVERT(int,SCOPE_IDENTITY());
   INSERT dbo.Interviewer(InterviewId,UserId) SELECT @InterviewId,UserId FROM @Panel;
   INSERT dbo.InterviewHistory(InterviewId,EventType,NewStartsAt,NewEndsAt,ChangedByUserId) VALUES(@InterviewId,N'Scheduled',@StartsAt,@EndsAt,@ScheduledByUserId);
  END
  ELSE
  BEGIN
   IF NOT EXISTS(SELECT 1 FROM dbo.Interview WITH(UPDLOCK,HOLDLOCK) WHERE InterviewId=@InterviewId AND ApplicationId=@ApplicationId AND InterviewStatus=N'Scheduled') THROW 51019,'Scheduled interview was not found for this application.',1;
   DECLARE @OldStart datetime2(0),@OldEnd datetime2(0);
   SELECT @OldStart=StartsAt,@OldEnd=EndsAt FROM dbo.Interview WHERE InterviewId=@InterviewId;
   UPDATE dbo.Interview SET StartsAt=@StartsAt,EndsAt=@EndsAt,Location=@Location,InterviewRoundId=@InterviewRoundId,UpdatedAt=SYSUTCDATETIME() WHERE InterviewId=@InterviewId;
   DELETE dbo.Interviewer WHERE InterviewId=@InterviewId;
   INSERT dbo.Interviewer(InterviewId,UserId) SELECT @InterviewId,UserId FROM @Panel;
   INSERT dbo.InterviewHistory(InterviewId,EventType,OldStartsAt,OldEndsAt,NewStartsAt,NewEndsAt,ChangedByUserId) VALUES(@InterviewId,N'Rescheduled',@OldStart,@OldEnd,@StartsAt,@EndsAt,@ScheduledByUserId);
  END;
  COMMIT;
  SELECT @InterviewId AS InterviewId;
 END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; THROW; END CATCH
END;
GO
CREATE OR ALTER PROCEDURE dbo.usp_RecordInterviewFeedback
 @InterviewId int,@InterviewerUserId int,@Rating tinyint,@Recommendation nvarchar(20),@Comments nvarchar(1000)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @Rating NOT BETWEEN 1 AND 5 THROW 51020,'Rating must be from 1 through 5.',1;
 IF @Recommendation NOT IN(N'StrongYes',N'Proceed',N'Hold',N'Reject') THROW 51021,'Unknown recommendation.',1;
 IF NULLIF(LTRIM(RTRIM(@Comments)),N'') IS NULL THROW 51022,'Feedback comments are required.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.Interview WHERE InterviewId=@InterviewId AND InterviewStatus=N'Completed') THROW 51023,'Feedback can be recorded only for a completed interview.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.Interviewer WHERE InterviewId=@InterviewId AND UserId=@InterviewerUserId) THROW 51024,'User is not assigned to this interview.',1;
 IF EXISTS(SELECT 1 FROM dbo.InterviewFeedback WHERE InterviewId=@InterviewId AND UserId=@InterviewerUserId) THROW 51025,'Feedback already exists; each interviewer may submit once.',1;
 INSERT dbo.InterviewFeedback(InterviewId,UserId,Rating,Recommendation,Comments) VALUES(@InterviewId,@InterviewerUserId,@Rating,@Recommendation,LTRIM(RTRIM(@Comments)));
END;
GO
CREATE OR ALTER PROCEDURE dbo.usp_CreateOrUpdateOffer
 @ApplicationId int,@SalaryAmount decimal(12,2),@CurrencyCode char(3),@OfferDate date,@ExpiresOn date,
 @OfferStatus nvarchar(20),@CreatedByUserId int
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @SalaryAmount<=0 OR @ExpiresOn<@OfferDate THROW 51026,'Salary must be positive and expiry cannot precede offer date.',1;
 IF @OfferStatus NOT IN(N'Pending',N'Accepted',N'Declined',N'Expired',N'Withdrawn') THROW 51027,'Unknown offer status.',1;
 IF @CurrencyCode NOT LIKE '[A-Z][A-Z][A-Z]' THROW 51028,'Currency code must contain three uppercase letters.',1;
 BEGIN TRY
  BEGIN TRAN;
  DECLARE @CurrentStatus nvarchar(20),@AppStatus nvarchar(20);
  SELECT @CurrentStatus=OfferStatus FROM dbo.Offer WITH(UPDLOCK,HOLDLOCK) WHERE ApplicationId=@ApplicationId;
  SELECT @AppStatus=ApplicationStatus FROM dbo.Application WITH(UPDLOCK,HOLDLOCK) WHERE ApplicationId=@ApplicationId;
  IF @AppStatus IS NULL THROW 51008,'Application was not found.',1;
  IF NOT EXISTS(SELECT 1 FROM dbo.AppUser WHERE UserId=@CreatedByUserId AND IsActive=1) THROW 51009,'Offer owner was not found or is inactive.',1;
  IF @AppStatus NOT IN(N'Interview',N'Offer',N'Hired') THROW 51029,'Offer requires an application at Interview, Offer, or Hired stage.',1;
  IF @CurrentStatus=N'Declined' AND @OfferStatus<>N'Declined' THROW 51030,'A declined offer is terminal.',1;
  IF @CurrentStatus=N'Accepted' AND @OfferStatus NOT IN(N'Accepted',N'Withdrawn') THROW 51031,'An accepted offer cannot be changed to this state.',1;
  IF @CurrentStatus IS NULL
   INSERT dbo.Offer(ApplicationId,SalaryAmount,CurrencyCode,OfferDate,ExpiresOn,OfferStatus,CreatedByUserId) VALUES(@ApplicationId,@SalaryAmount,@CurrencyCode,@OfferDate,@ExpiresOn,@OfferStatus,@CreatedByUserId);
  ELSE UPDATE dbo.Offer SET SalaryAmount=@SalaryAmount,CurrencyCode=@CurrencyCode,OfferDate=@OfferDate,ExpiresOn=@ExpiresOn,OfferStatus=@OfferStatus,UpdatedAt=SYSUTCDATETIME(),CreatedByUserId=@CreatedByUserId WHERE ApplicationId=@ApplicationId;
  IF @OfferStatus IN(N'Pending',N'Accepted') AND @AppStatus=N'Interview'
  BEGIN
   UPDATE dbo.Application SET ApplicationStatus=N'Offer',UpdatedAt=SYSUTCDATETIME() WHERE ApplicationId=@ApplicationId;
   INSERT dbo.ApplicationStatusHistory(ApplicationId,OldStatus,NewStatus,ChangedByUserId,Notes) VALUES(@ApplicationId,N'Interview',N'Offer',@CreatedByUserId,N'Offer created or updated');
   SET @AppStatus=N'Offer';
  END;
  IF @OfferStatus=N'Accepted' AND @AppStatus=N'Offer'
  BEGIN
   UPDATE dbo.Application SET ApplicationStatus=N'Hired',UpdatedAt=SYSUTCDATETIME() WHERE ApplicationId=@ApplicationId;
   INSERT dbo.ApplicationStatusHistory(ApplicationId,OldStatus,NewStatus,ChangedByUserId,Notes) VALUES(@ApplicationId,N'Offer',N'Hired',@CreatedByUserId,N'Offer accepted');
  END;
  IF @OfferStatus=N'Declined' AND @AppStatus=N'Offer'
  BEGIN
   UPDATE dbo.Application SET ApplicationStatus=N'Rejected',UpdatedAt=SYSUTCDATETIME() WHERE ApplicationId=@ApplicationId;
   INSERT dbo.ApplicationStatusHistory(ApplicationId,OldStatus,NewStatus,ChangedByUserId,Notes) VALUES(@ApplicationId,N'Offer',N'Rejected',@CreatedByUserId,N'Offer declined');
  END;
  COMMIT;
 END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; THROW; END CATCH
END;
GO
