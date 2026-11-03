USE RecruitmentTalentDB;
GO
CREATE TABLE dbo.Department (
 DepartmentId int IDENTITY(1,1) CONSTRAINT PK_Department PRIMARY KEY,
 DepartmentName nvarchar(100) NOT NULL CONSTRAINT UQ_Department_Name UNIQUE,
 CreatedAt datetime2(0) NOT NULL CONSTRAINT DF_Department_Created DEFAULT SYSUTCDATETIME()
);
CREATE TABLE dbo.AppUser (
 UserId int IDENTITY(1,1) CONSTRAINT PK_AppUser PRIMARY KEY,
 DepartmentId int NULL,
 FirstName nvarchar(80) NOT NULL, LastName nvarchar(80) NOT NULL,
 Email nvarchar(254) NOT NULL CONSTRAINT UQ_AppUser_Email UNIQUE,
 UserRole nvarchar(20) NOT NULL CONSTRAINT CK_AppUser_Role CHECK(UserRole IN (N'HiringManager',N'Recruiter',N'Interviewer',N'Admin')),
 IsActive bit NOT NULL CONSTRAINT DF_AppUser_Active DEFAULT(1),
 CreatedAt datetime2(0) NOT NULL CONSTRAINT DF_AppUser_Created DEFAULT SYSUTCDATETIME(),
 UpdatedAt datetime2(0) NOT NULL CONSTRAINT DF_AppUser_Updated DEFAULT SYSUTCDATETIME(),
 CONSTRAINT FK_AppUser_Department FOREIGN KEY(DepartmentId) REFERENCES dbo.Department(DepartmentId) ON DELETE SET NULL
);
CREATE TABLE dbo.JobOpening (
 JobId int IDENTITY(1,1) CONSTRAINT PK_JobOpening PRIMARY KEY,
 DepartmentId int NOT NULL, HiringManagerUserId int NOT NULL,
 JobTitle nvarchar(150) NOT NULL, Location nvarchar(120) NOT NULL,
 EmploymentType nvarchar(20) NOT NULL CONSTRAINT CK_Job_Employment CHECK(EmploymentType IN (N'FullTime',N'PartTime',N'Contract',N'Internship')),
 JobStatus nvarchar(20) NOT NULL CONSTRAINT DF_Job_Status DEFAULT(N'Draft') CONSTRAINT CK_Job_Status CHECK(JobStatus IN (N'Draft',N'Open',N'Closed')),
 Description nvarchar(max) NOT NULL,
 PostedAt datetime2(0) NULL, ClosedAt datetime2(0) NULL,
 CreatedAt datetime2(0) NOT NULL CONSTRAINT DF_Job_Created DEFAULT SYSUTCDATETIME(),
 UpdatedAt datetime2(0) NOT NULL CONSTRAINT DF_Job_Updated DEFAULT SYSUTCDATETIME(),
 CONSTRAINT FK_Job_Department FOREIGN KEY(DepartmentId) REFERENCES dbo.Department(DepartmentId),
 CONSTRAINT FK_Job_Manager FOREIGN KEY(HiringManagerUserId) REFERENCES dbo.AppUser(UserId)
);
CREATE TABLE dbo.Skill (
 SkillId int IDENTITY(1,1) CONSTRAINT PK_Skill PRIMARY KEY,
 SkillName nvarchar(100) NOT NULL CONSTRAINT UQ_Skill_Name UNIQUE
);
CREATE TABLE dbo.JobRequiredSkill (
 JobId int NOT NULL, SkillId int NOT NULL, IsRequired bit NOT NULL CONSTRAINT DF_JobSkill_Required DEFAULT(1),
 CONSTRAINT PK_JobRequiredSkill PRIMARY KEY(JobId,SkillId),
 CONSTRAINT FK_JobSkill_Job FOREIGN KEY(JobId) REFERENCES dbo.JobOpening(JobId) ON DELETE CASCADE,
 CONSTRAINT FK_JobSkill_Skill FOREIGN KEY(SkillId) REFERENCES dbo.Skill(SkillId)
);
CREATE TABLE dbo.Candidate (
 CandidateId int IDENTITY(1,1) CONSTRAINT PK_Candidate PRIMARY KEY,
 FirstName nvarchar(80) NOT NULL, LastName nvarchar(80) NOT NULL,
 Email nvarchar(254) NOT NULL CONSTRAINT UQ_Candidate_Email UNIQUE,
 Phone nvarchar(30) NULL, Location nvarchar(120) NULL,
 CreatedAt datetime2(0) NOT NULL CONSTRAINT DF_Candidate_Created DEFAULT SYSUTCDATETIME(),
 UpdatedAt datetime2(0) NOT NULL CONSTRAINT DF_Candidate_Updated DEFAULT SYSUTCDATETIME()
);
CREATE TABLE dbo.CandidateSkill (
 CandidateId int NOT NULL, SkillId int NOT NULL, YearsExperience decimal(4,1) NOT NULL CONSTRAINT CK_CandidateSkill_Years CHECK(YearsExperience BETWEEN 0 AND 80),
 CONSTRAINT PK_CandidateSkill PRIMARY KEY(CandidateId,SkillId),
 CONSTRAINT FK_CandidateSkill_Candidate FOREIGN KEY(CandidateId) REFERENCES dbo.Candidate(CandidateId) ON DELETE CASCADE,
 CONSTRAINT FK_CandidateSkill_Skill FOREIGN KEY(SkillId) REFERENCES dbo.Skill(SkillId)
);
CREATE TABLE dbo.Application (
 ApplicationId int IDENTITY(1,1) CONSTRAINT PK_Application PRIMARY KEY,
 JobId int NOT NULL, CandidateId int NOT NULL,
 AppliedAt datetime2(0) NOT NULL CONSTRAINT DF_Application_Applied DEFAULT SYSUTCDATETIME(),
 ApplicationStatus nvarchar(20) NOT NULL CONSTRAINT DF_Application_Status DEFAULT(N'Applied') CONSTRAINT CK_Application_Status CHECK(ApplicationStatus IN (N'Applied',N'Screening',N'Interview',N'Offer',N'Hired',N'Rejected',N'Withdrawn')),
 Source nvarchar(50) NOT NULL,
 CreatedAt datetime2(0) NOT NULL CONSTRAINT DF_Application_Created DEFAULT SYSUTCDATETIME(),
 UpdatedAt datetime2(0) NOT NULL CONSTRAINT DF_Application_Updated DEFAULT SYSUTCDATETIME(),
 CONSTRAINT UQ_Application_JobCandidate UNIQUE(JobId,CandidateId),
 CONSTRAINT FK_Application_Job FOREIGN KEY(JobId) REFERENCES dbo.JobOpening(JobId),
 CONSTRAINT FK_Application_Candidate FOREIGN KEY(CandidateId) REFERENCES dbo.Candidate(CandidateId)
);
CREATE TABLE dbo.ApplicationStatusHistory (
 ApplicationStatusHistoryId bigint IDENTITY(1,1) CONSTRAINT PK_ApplicationStatusHistory PRIMARY KEY,
 ApplicationId int NOT NULL, OldStatus nvarchar(20) NULL, NewStatus nvarchar(20) NOT NULL,
 ChangedAt datetime2(0) NOT NULL CONSTRAINT DF_StatusHistory_At DEFAULT SYSUTCDATETIME(),
 ChangedByUserId int NOT NULL, Notes nvarchar(500) NULL,
 CONSTRAINT FK_StatusHistory_Application FOREIGN KEY(ApplicationId) REFERENCES dbo.Application(ApplicationId) ON DELETE CASCADE,
 CONSTRAINT FK_StatusHistory_User FOREIGN KEY(ChangedByUserId) REFERENCES dbo.AppUser(UserId)
);
CREATE TABLE dbo.InterviewRound (
 InterviewRoundId int IDENTITY(1,1) CONSTRAINT PK_InterviewRound PRIMARY KEY,
 RoundName nvarchar(80) NOT NULL CONSTRAINT UQ_InterviewRound_Name UNIQUE,
 SequenceNumber int NOT NULL CONSTRAINT UQ_InterviewRound_Sequence UNIQUE CONSTRAINT CK_InterviewRound_Sequence CHECK(SequenceNumber > 0)
);
CREATE TABLE dbo.Interview (
 InterviewId int IDENTITY(1,1) CONSTRAINT PK_Interview PRIMARY KEY,
 ApplicationId int NOT NULL, InterviewRoundId int NOT NULL,
 StartsAt datetime2(0) NOT NULL, EndsAt datetime2(0) NOT NULL,
 Location nvarchar(160) NOT NULL,
 InterviewStatus nvarchar(20) NOT NULL CONSTRAINT DF_Interview_Status DEFAULT(N'Scheduled') CONSTRAINT CK_Interview_Status CHECK(InterviewStatus IN (N'Scheduled',N'Completed',N'Cancelled')),
 CreatedAt datetime2(0) NOT NULL CONSTRAINT DF_Interview_Created DEFAULT SYSUTCDATETIME(),
 UpdatedAt datetime2(0) NOT NULL CONSTRAINT DF_Interview_Updated DEFAULT SYSUTCDATETIME(),
 CONSTRAINT CK_Interview_Time CHECK(EndsAt > StartsAt),
 CONSTRAINT FK_Interview_Application FOREIGN KEY(ApplicationId) REFERENCES dbo.Application(ApplicationId) ON DELETE CASCADE,
 CONSTRAINT FK_Interview_Round FOREIGN KEY(InterviewRoundId) REFERENCES dbo.InterviewRound(InterviewRoundId)
);
CREATE TABLE dbo.InterviewHistory (
 InterviewHistoryId bigint IDENTITY(1,1) CONSTRAINT PK_InterviewHistory PRIMARY KEY,
 InterviewId int NOT NULL, EventType nvarchar(20) NOT NULL CONSTRAINT CK_InterviewHistory_Event CHECK(EventType IN (N'Scheduled',N'Rescheduled',N'Cancelled')),
 OldStartsAt datetime2(0) NULL, OldEndsAt datetime2(0) NULL, NewStartsAt datetime2(0) NOT NULL, NewEndsAt datetime2(0) NOT NULL,
 ChangedAt datetime2(0) NOT NULL CONSTRAINT DF_InterviewHistory_At DEFAULT SYSUTCDATETIME(), ChangedByUserId int NOT NULL,
 CONSTRAINT FK_InterviewHistory_Interview FOREIGN KEY(InterviewId) REFERENCES dbo.Interview(InterviewId) ON DELETE CASCADE,
 CONSTRAINT FK_InterviewHistory_User FOREIGN KEY(ChangedByUserId) REFERENCES dbo.AppUser(UserId)
);
CREATE TABLE dbo.Interviewer (
 InterviewId int NOT NULL, UserId int NOT NULL,
 CONSTRAINT PK_Interviewer PRIMARY KEY(InterviewId,UserId),
 CONSTRAINT FK_Interviewer_Interview FOREIGN KEY(InterviewId) REFERENCES dbo.Interview(InterviewId) ON DELETE CASCADE,
 CONSTRAINT FK_Interviewer_User FOREIGN KEY(UserId) REFERENCES dbo.AppUser(UserId)
);
CREATE TABLE dbo.InterviewFeedback (
 InterviewFeedbackId int IDENTITY(1,1) CONSTRAINT PK_InterviewFeedback PRIMARY KEY,
 InterviewId int NOT NULL, UserId int NOT NULL,
 Rating tinyint NOT NULL CONSTRAINT CK_Feedback_Rating CHECK(Rating BETWEEN 1 AND 5),
 Recommendation nvarchar(20) NOT NULL CONSTRAINT CK_Feedback_Recommendation CHECK(Recommendation IN (N'StrongYes',N'Proceed',N'Hold',N'Reject')),
 Comments nvarchar(1000) NOT NULL,
 CreatedAt datetime2(0) NOT NULL CONSTRAINT DF_Feedback_Created DEFAULT SYSUTCDATETIME(),
 UpdatedAt datetime2(0) NOT NULL CONSTRAINT DF_Feedback_Updated DEFAULT SYSUTCDATETIME(),
 CONSTRAINT UQ_Feedback_Interviewer UNIQUE(InterviewId,UserId),
 CONSTRAINT FK_Feedback_Interviewer FOREIGN KEY(InterviewId,UserId) REFERENCES dbo.Interviewer(InterviewId,UserId)
);
CREATE TABLE dbo.Offer (
 OfferId int IDENTITY(1,1) CONSTRAINT PK_Offer PRIMARY KEY,
 ApplicationId int NOT NULL CONSTRAINT UQ_Offer_Application UNIQUE,
 SalaryAmount decimal(12,2) NOT NULL CONSTRAINT CK_Offer_Salary CHECK(SalaryAmount > 0),
 CurrencyCode char(3) NOT NULL,
 OfferDate date NOT NULL, ExpiresOn date NOT NULL,
 OfferStatus nvarchar(20) NOT NULL CONSTRAINT DF_Offer_Status DEFAULT(N'Pending') CONSTRAINT CK_Offer_Status CHECK(OfferStatus IN (N'Pending',N'Accepted',N'Declined',N'Expired',N'Withdrawn')),
 CreatedByUserId int NOT NULL,
 CreatedAt datetime2(0) NOT NULL CONSTRAINT DF_Offer_Created DEFAULT SYSUTCDATETIME(),
 UpdatedAt datetime2(0) NOT NULL CONSTRAINT DF_Offer_Updated DEFAULT SYSUTCDATETIME(),
 CONSTRAINT CK_Offer_Dates CHECK(ExpiresOn >= OfferDate),
 CONSTRAINT FK_Offer_Application FOREIGN KEY(ApplicationId) REFERENCES dbo.Application(ApplicationId) ON DELETE CASCADE,
 CONSTRAINT FK_Offer_User FOREIGN KEY(CreatedByUserId) REFERENCES dbo.AppUser(UserId)
);
GO
