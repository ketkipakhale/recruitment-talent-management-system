/* Run with an account allowed to create databases. Fresh-install script. */
IF DB_ID(N'RecruitmentTalentDB') IS NULL
    EXEC(N'CREATE DATABASE RecruitmentTalentDB');
GO
USE RecruitmentTalentDB;
GO
