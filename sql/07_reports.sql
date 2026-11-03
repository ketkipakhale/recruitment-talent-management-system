USE RecruitmentTalentDB;
GO
/* Hiring funnel: applications that reached each stage, including later outcomes. */
;WITH StageCounts AS (
 SELECT s.StageName,s.StageOrder,COUNT(DISTINCT CASE WHEN reached.StatusName IS NOT NULL THEN a.ApplicationId END) AS ApplicationCount
 FROM (VALUES(N'Applied',1),(N'Screening',2),(N'Interview',3),(N'Offer',4),(N'Hired',5)) s(StageName,StageOrder)
 LEFT JOIN dbo.Application a ON 1=1
 LEFT JOIN dbo.ApplicationStatusHistory h ON h.ApplicationId=a.ApplicationId
 LEFT JOIN (VALUES(N'Applied',1),(N'Screening',2),(N'Interview',3),(N'Offer',4),(N'Hired',5)) reached(StatusName,StageOrder) ON reached.StatusName=h.NewStatus AND reached.StageOrder>=s.StageOrder
 GROUP BY s.StageName,s.StageOrder
), Funnel AS (
 SELECT StageName,StageOrder,ApplicationCount,LAG(ApplicationCount) OVER(ORDER BY StageOrder) AS PreviousStageCount
 FROM StageCounts
)
SELECT StageName,ApplicationCount,PreviousStageCount,
 CAST(100.0*ApplicationCount/NULLIF(PreviousStageCount,0) AS decimal(6,2)) AS ConversionPct
FROM Funnel WHERE ApplicationCount>0 OR PreviousStageCount>0 ORDER BY StageOrder;
GO
/* Time to hire in days from application to first hired status event. */
SELECT j.JobTitle,COUNT(*) AS Hires,AVG(CONVERT(decimal(10,2),DATEDIFF(day,a.AppliedAt,h.HireAt))) AS AvgDaysToHire,
 MIN(DATEDIFF(day,a.AppliedAt,h.HireAt)) AS MinDays,MAX(DATEDIFF(day,a.AppliedAt,h.HireAt)) AS MaxDays
FROM dbo.Application a JOIN dbo.JobOpening j ON j.JobId=a.JobId
CROSS APPLY(SELECT MIN(ChangedAt) AS HireAt FROM dbo.ApplicationStatusHistory sh WHERE sh.ApplicationId=a.ApplicationId AND sh.NewStatus=N'Hired') h
WHERE h.HireAt IS NOT NULL GROUP BY j.JobTitle ORDER BY AvgDaysToHire;
GO
/* Source effectiveness: applicant volume, hires and hire percentage. */
SELECT Source,COUNT(*) AS Applicants,SUM(CASE WHEN ApplicationStatus=N'Hired' THEN 1 ELSE 0 END) AS Hires,
 CAST(100.0*SUM(CASE WHEN ApplicationStatus=N'Hired' THEN 1 ELSE 0 END)/NULLIF(COUNT(*),0) AS decimal(6,2)) AS HirePct
FROM dbo.Application GROUP BY Source ORDER BY HirePct DESC,Applicants DESC;
GO
/* Interviewer workload: next 30 days plus completed interviews in prior 30 days. */
SELECT u.UserId,u.FirstName+N' '+u.LastName AS Interviewer,
 SUM(CASE WHEN i.StartsAt>=SYSUTCDATETIME() AND i.StartsAt<DATEADD(day,30,SYSUTCDATETIME()) AND i.InterviewStatus=N'Scheduled' THEN 1 ELSE 0 END) AS Upcoming30Days,
 SUM(CASE WHEN i.StartsAt>=DATEADD(day,-30,SYSUTCDATETIME()) AND i.StartsAt<SYSUTCDATETIME() AND i.InterviewStatus=N'Completed' THEN 1 ELSE 0 END) AS CompletedLast30Days
FROM dbo.AppUser u LEFT JOIN dbo.Interviewer x ON x.UserId=u.UserId LEFT JOIN dbo.Interview i ON i.InterviewId=x.InterviewId
WHERE u.UserRole=N'Interviewer' GROUP BY u.UserId,u.FirstName,u.LastName ORDER BY Upcoming30Days DESC;
GO
