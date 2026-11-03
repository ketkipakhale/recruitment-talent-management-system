USE RecruitmentTalentDB;
GO
CREATE INDEX IX_JobOpening_Status_PostedAt ON dbo.JobOpening(JobStatus,PostedAt DESC) INCLUDE(JobTitle,DepartmentId,Location);
CREATE INDEX IX_JobOpening_Manager ON dbo.JobOpening(HiringManagerUserId,JobStatus);
CREATE INDEX IX_Application_Candidate_AppliedAt ON dbo.Application(CandidateId,AppliedAt DESC) INCLUDE(JobId,ApplicationStatus,Source);
CREATE INDEX IX_Application_Status_AppliedAt ON dbo.Application(ApplicationStatus,AppliedAt) INCLUDE(JobId,CandidateId,Source);
CREATE INDEX IX_StatusHistory_Application_ChangedAt ON dbo.ApplicationStatusHistory(ApplicationId,ChangedAt DESC);
CREATE INDEX IX_Interview_StartsAt_Status ON dbo.Interview(StartsAt,InterviewStatus) INCLUDE(EndsAt,ApplicationId,InterviewRoundId);
CREATE INDEX IX_Interview_Application ON dbo.Interview(ApplicationId,StartsAt DESC);
CREATE INDEX IX_Interviewer_User_Interview ON dbo.Interviewer(UserId,InterviewId);
CREATE INDEX IX_Feedback_User_CreatedAt ON dbo.InterviewFeedback(UserId,CreatedAt DESC);
GO
