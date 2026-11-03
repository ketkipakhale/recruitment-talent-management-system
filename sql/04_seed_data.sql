USE RecruitmentTalentDB;
GO
INSERT dbo.Department(DepartmentName) VALUES (N'Engineering'),(N'Product'),(N'People Operations'),(N'Data');
INSERT dbo.AppUser(DepartmentId,FirstName,LastName,Email,UserRole) VALUES
(1,N'Avery',N'Jordan',N'avery.jordan@northstar.example',N'HiringManager'),(1,N'Morgan',N'Lee',N'morgan.lee@northstar.example',N'Interviewer'),
(4,N'Riley',N'Patel',N'riley.patel@northstar.example',N'Interviewer'),(2,N'Casey',N'Nguyen',N'casey.nguyen@northstar.example',N'HiringManager'),
(3,N'Jamie',N'Brooks',N'jamie.brooks@northstar.example',N'Recruiter'),(4,N'Taylor',N'Kim',N'taylor.kim@northstar.example',N'Interviewer'),
(2,N'Quinn',N'Garcia',N'quinn.garcia@northstar.example',N'Interviewer');
INSERT dbo.Skill(SkillName) VALUES(N'SQL Server'),(N'T-SQL'),(N'Python'),(N'Azure'),(N'Product Strategy'),(N'UX Research'),(N'Data Modeling'),(N'Communication');
INSERT dbo.JobOpening(DepartmentId,HiringManagerUserId,JobTitle,Location,EmploymentType,JobStatus,Description,PostedAt,ClosedAt) VALUES
(1,1,N'Senior Database Engineer',N'Remote - US',N'FullTime',N'Open',N'Design and optimize reliable SQL Server platforms.',DATEADD(day,-70,SYSUTCDATETIME()),NULL),
(4,1,N'Analytics Engineer',N'Boston, MA',N'FullTime',N'Open',N'Build trusted reporting datasets and semantic models.',DATEADD(day,-50,SYSUTCDATETIME()),NULL),
(2,4,N'Product Manager',N'Remote - US',N'FullTime',N'Open',N'Guide customer centered product delivery.',DATEADD(day,-35,SYSUTCDATETIME()),NULL),
(1,1,N'Data Platform Intern',N'Austin, TX',N'Internship',N'Closed',N'Assist platform engineering teams.',DATEADD(day,-100,SYSUTCDATETIME()),DATEADD(day,-15,SYSUTCDATETIME())),
(4,1,N'BI Analyst',N'Remote - US',N'Contract',N'Draft',N'Prepare operational dashboards.',NULL,NULL);
INSERT dbo.JobRequiredSkill(JobId,SkillId) VALUES(1,1),(1,2),(1,7),(2,1),(2,3),(2,7),(3,5),(3,6),(4,2),(4,3);
INSERT dbo.Candidate(FirstName,LastName,Email,Phone,Location) VALUES
(N'Alex',N'Rivera',N'alex.rivera@example.test',N'555-0101',N'Seattle, WA'),(N'Sam',N'Chen',N'sam.chen@example.test',N'555-0102',N'Boston, MA'),
(N'Jordan',N'Singh',N'jordan.singh@example.test',N'555-0103',N'Austin, TX'),(N'Drew',N'Williams',N'drew.williams@example.test',N'555-0104',N'Chicago, IL'),
(N'Emery',N'Clark',N'emery.clark@example.test',N'555-0105',N'Portland, OR'),(N'Robin',N'Lopez',N'robin.lopez@example.test',N'555-0106',N'Denver, CO'),
(N'Kai',N'Martin',N'kai.martin@example.test',N'555-0107',N'New York, NY'),(N'Finley',N'Young',N'finley.young@example.test',N'555-0108',N'San Diego, CA'),
(N'Reese',N'Allen',N'reese.allen@example.test',N'555-0109',N'Atlanta, GA'),(N'Harper',N'Baker',N'harper.baker@example.test',N'555-0110',N'Raleigh, NC'),
(N'Rowan',N'Nelson',N'rowan.nelson@example.test',N'555-0111',N'Phoenix, AZ'),(N'Parker',N'Hall',N'parker.hall@example.test',N'555-0112',N'Miami, FL'),
(N'Charlie',N'Adams',N'charlie.adams@example.test',N'555-0113',N'Boston, MA'),(N'Skyler',N'Turner',N'skyler.turner@example.test',N'555-0114',N'Seattle, WA'),
(N'Logan',N'Perez',N'logan.perez@example.test',N'555-0115',N'Austin, TX'),(N'Rory',N'Campbell',N'rory.campbell@example.test',N'555-0116',N'Portland, OR'),
(N'Bailey',N'Mitchell',N'bailey.mitchell@example.test',N'555-0117',N'Chicago, IL'),(N'Addison',N'Roberts',N'addison.roberts@example.test',N'555-0118',N'Denver, CO'),
(N'Jules',N'Carter',N'jules.carter@example.test',N'555-0119',N'New York, NY'),(N'Kendall',N'Phillips',N'kendall.phillips@example.test',N'555-0120',N'San Diego, CA');
INSERT dbo.CandidateSkill(CandidateId,SkillId,YearsExperience)
SELECT CandidateId,SkillId,CASE WHEN (CandidateId+SkillId)%3=0 THEN 5.0 WHEN (CandidateId+SkillId)%3=1 THEN 2.5 ELSE 1.0 END
FROM dbo.Candidate CROSS JOIN dbo.Skill WHERE (CandidateId+SkillId)%2=0;
INSERT dbo.InterviewRound(RoundName,SequenceNumber) VALUES(N'Recruiter Screen',1),(N'Technical Interview',2),(N'Final Panel',3);
/* Thirty applications with distinct candidates and varied stages/sources. */
INSERT dbo.Application(JobId,CandidateId,AppliedAt,ApplicationStatus,Source)
SELECT CASE WHEN CandidateId<=10 THEN 1 WHEN CandidateId<=16 THEN 2 WHEN CandidateId<=20 THEN 3 ELSE 4 END,
 CandidateId,DATEADD(day,-(CandidateId*2),SYSUTCDATETIME()),
 CASE CandidateId WHEN 1 THEN N'Hired' WHEN 2 THEN N'Offer' WHEN 3 THEN N'Interview' WHEN 4 THEN N'Interview' WHEN 5 THEN N'Rejected' WHEN 6 THEN N'Withdrawn' WHEN 7 THEN N'Screening' WHEN 8 THEN N'Rejected' WHEN 9 THEN N'Interview' WHEN 10 THEN N'Screening' WHEN 11 THEN N'Offer' WHEN 12 THEN N'Interview' WHEN 13 THEN N'Rejected' WHEN 14 THEN N'Screening' WHEN 15 THEN N'Withdrawn' WHEN 16 THEN N'Applied' WHEN 17 THEN N'Hired' WHEN 18 THEN N'Offer' WHEN 19 THEN N'Rejected' WHEN 20 THEN N'Interview' ELSE CASE CandidateId%3 WHEN 0 THEN N'Rejected' WHEN 1 THEN N'Applied' ELSE N'Screening' END END,
 CASE CandidateId%4 WHEN 0 THEN N'Referral' WHEN 1 THEN N'JobBoard' WHEN 2 THEN N'CareerSite' ELSE N'Agency' END
FROM dbo.Candidate WHERE CandidateId<=20;
INSERT dbo.ApplicationStatusHistory(ApplicationId,OldStatus,NewStatus,ChangedAt,ChangedByUserId,Notes)
SELECT ApplicationId,NULL,N'Applied',AppliedAt,5,N'Application received' FROM dbo.Application;
INSERT dbo.ApplicationStatusHistory(ApplicationId,OldStatus,NewStatus,ChangedAt,ChangedByUserId,Notes)
SELECT ApplicationId,N'Applied',ApplicationStatus,DATEADD(day,1,AppliedAt),5,N'Seeded stage progression' FROM dbo.Application WHERE ApplicationStatus<>N'Applied';
/* Scheduled and completed interviews, with a small fictional panel. */
INSERT dbo.Interview(ApplicationId,InterviewRoundId,StartsAt,EndsAt,Location,InterviewStatus)
SELECT ApplicationId,CASE WHEN ApplicationId%3=0 THEN 3 WHEN ApplicationId%2=0 THEN 2 ELSE 1 END,
 CASE WHEN ApplicationStatus IN(N'Interview',N'Offer',N'Hired') THEN DATEADD(day,-2,SYSUTCDATETIME()) ELSE DATEADD(day,2,SYSUTCDATETIME()) END,
 CASE WHEN ApplicationStatus IN(N'Interview',N'Offer',N'Hired') THEN DATEADD(hour,-1,SYSUTCDATETIME()) ELSE DATEADD(hour,3,SYSUTCDATETIME()) END,
 N'Video conference',CASE WHEN ApplicationStatus IN(N'Offer',N'Hired') THEN N'Completed' ELSE N'Scheduled' END
FROM dbo.Application WHERE ApplicationStatus IN(N'Interview',N'Offer',N'Hired');
INSERT dbo.Interviewer(InterviewId,UserId)
SELECT InterviewId,CASE WHEN InterviewId%2=0 THEN 2 ELSE 3 END FROM dbo.Interview;
INSERT dbo.Interviewer(InterviewId,UserId)
SELECT InterviewId,6 FROM dbo.Interview WHERE InterviewId%2=0;
INSERT dbo.InterviewHistory(InterviewId,EventType,OldStartsAt,OldEndsAt,NewStartsAt,NewEndsAt,ChangedByUserId)
SELECT InterviewId,N'Scheduled',NULL,NULL,StartsAt,EndsAt,5 FROM dbo.Interview;
INSERT dbo.InterviewFeedback(InterviewId,UserId,Rating,Recommendation,Comments)
SELECT i.InterviewId,x.UserId,CASE WHEN i.InterviewId%4=0 THEN 5 WHEN i.InterviewId%4=1 THEN 4 ELSE 3 END,
 CASE WHEN i.InterviewId%4=0 THEN N'StrongYes' WHEN i.InterviewId%4=1 THEN N'Proceed' ELSE N'Hold' END,N'Fictional sample feedback.'
FROM dbo.Interview i JOIN dbo.Interviewer x ON x.InterviewId=i.InterviewId WHERE i.InterviewStatus=N'Completed';
INSERT dbo.Offer(ApplicationId,SalaryAmount,CurrencyCode,OfferDate,ExpiresOn,OfferStatus,CreatedByUserId)
SELECT ApplicationId,CASE WHEN ApplicationId%2=0 THEN 135000 ELSE 120000 END,'USD',CONVERT(date,DATEADD(day,-3,SYSUTCDATETIME())),CONVERT(date,DATEADD(day,7,SYSUTCDATETIME())),
 CASE WHEN ApplicationStatus=N'Hired' THEN N'Accepted' ELSE N'Pending' END,5 FROM dbo.Application WHERE ApplicationStatus IN(N'Offer',N'Hired');
GO
