USE RecruitmentTalentDB;
GO
CREATE OR ALTER VIEW dbo.vw_OpenJobs AS
SELECT j.JobId,j.JobTitle,d.DepartmentName,j.Location,j.EmploymentType,j.PostedAt,u.FirstName+N' '+u.LastName AS HiringManager,
 (SELECT COUNT(*) FROM dbo.Application a WHERE a.JobId=j.JobId) AS ApplicationCount
FROM dbo.JobOpening j JOIN dbo.Department d ON d.DepartmentId=j.DepartmentId JOIN dbo.AppUser u ON u.UserId=j.HiringManagerUserId
WHERE j.JobStatus=N'Open';
GO
CREATE OR ALTER VIEW dbo.vw_CandidatesByStage AS
SELECT a.ApplicationId,a.ApplicationStatus,c.CandidateId,c.FirstName,c.LastName,c.Email,j.JobId,j.JobTitle,a.Source,a.AppliedAt,
 ROW_NUMBER() OVER(PARTITION BY a.ApplicationStatus ORDER BY a.AppliedAt DESC) AS StageRecency
FROM dbo.Application a JOIN dbo.Candidate c ON c.CandidateId=a.CandidateId JOIN dbo.JobOpening j ON j.JobId=a.JobId;
GO
CREATE OR ALTER VIEW dbo.vw_UpcomingInterviews AS
SELECT i.InterviewId,i.StartsAt,i.EndsAt,i.Location,r.RoundName,a.ApplicationId,c.FirstName+N' '+c.LastName AS Candidate,j.JobTitle,
 STRING_AGG(u.FirstName+N' '+u.LastName,N', ') AS Interviewers
FROM dbo.Interview i JOIN dbo.InterviewRound r ON r.InterviewRoundId=i.InterviewRoundId JOIN dbo.Application a ON a.ApplicationId=i.ApplicationId
JOIN dbo.Candidate c ON c.CandidateId=a.CandidateId JOIN dbo.JobOpening j ON j.JobId=a.JobId
JOIN dbo.Interviewer x ON x.InterviewId=i.InterviewId JOIN dbo.AppUser u ON u.UserId=x.UserId
WHERE i.InterviewStatus=N'Scheduled' AND i.StartsAt>SYSUTCDATETIME()
GROUP BY i.InterviewId,i.StartsAt,i.EndsAt,i.Location,r.RoundName,a.ApplicationId,c.FirstName,c.LastName,j.JobTitle;
GO
