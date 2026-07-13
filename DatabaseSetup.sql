/*
    DatabaseSetup.sql
    Phonebook Application - Standalone database setup script.

    Run this script against a SQL Server Express instance that already has
    the "PhonebookDb" database created (or uncomment the CREATE DATABASE
    block below to create it).

    Safe to re-run: existing objects are dropped/recreated where applicable.
*/

-- ============================================================
-- 0. (Optional) Create the database
-- ============================================================
-- IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'PhonebookDb')
-- BEGIN
--     CREATE DATABASE PhonebookDb;
-- END
-- GO

USE PhonebookDb;
GO

-- ============================================================
-- 1. Table: Contacts
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Contacts')
BEGIN
    CREATE TABLE Contacts
    (
        Id           INT IDENTITY(1,1) NOT NULL,
        Name         NVARCHAR(255)     NOT NULL,
        PhoneNumber  NVARCHAR(50)      NOT NULL,
        Email        NVARCHAR(255)     NULL,
        Address      NVARCHAR(MAX)     NULL,
        CreatedAt    DATETIME          NOT NULL CONSTRAINT DF_Contacts_CreatedAt DEFAULT (GETDATE()),
        CONSTRAINT PK_Contacts PRIMARY KEY CLUSTERED (Id ASC),
        CONSTRAINT UQ_Contacts_PhoneNumber UNIQUE (PhoneNumber)
    );
END
GO

-- ============================================================
-- 2. Stored Procedure: sp_GetContactsPaged
-- ============================================================
IF OBJECT_ID('dbo.sp_GetContactsPaged', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_GetContactsPaged;
GO

CREATE PROCEDURE dbo.sp_GetContactsPaged
    @PageNumber   INT,
    @PageSize     INT,
    @SearchTerm   NVARCHAR(255) = NULL,
    @TotalCount   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @SearchTerm = NULLIF(LTRIM(RTRIM(@SearchTerm)), '');

    SELECT @TotalCount = COUNT(*)
    FROM Contacts
    WHERE @SearchTerm IS NULL
       OR Name LIKE '%' + @SearchTerm + '%'
       OR PhoneNumber LIKE '%' + @SearchTerm + '%';

    SELECT Id, Name, PhoneNumber, Email, Address, CreatedAt
    FROM Contacts
    WHERE @SearchTerm IS NULL
       OR Name LIKE '%' + @SearchTerm + '%'
       OR PhoneNumber LIKE '%' + @SearchTerm + '%'
    ORDER BY Name ASC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ============================================================
-- 3. Stored Procedure: sp_GetContactById
-- ============================================================
IF OBJECT_ID('dbo.sp_GetContactById', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_GetContactById;
GO

CREATE PROCEDURE dbo.sp_GetContactById
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT Id, Name, PhoneNumber, Email, Address, CreatedAt
    FROM Contacts
    WHERE Id = @Id;
END
GO

-- ============================================================
-- 4. Stored Procedure: sp_InsertContact
-- ============================================================
IF OBJECT_ID('dbo.sp_InsertContact', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_InsertContact;
GO

CREATE PROCEDURE dbo.sp_InsertContact
    @Name          NVARCHAR(255),
    @PhoneNumber   NVARCHAR(50),
    @Email         NVARCHAR(255) = NULL,
    @Address       NVARCHAR(MAX) = NULL,
    @NewId         INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Contacts (Name, PhoneNumber, Email, Address, CreatedAt)
    VALUES (@Name, @PhoneNumber, @Email, @Address, GETDATE());

    SET @NewId = SCOPE_IDENTITY();
END
GO

-- ============================================================
-- 5. Stored Procedure: sp_UpdateContact
-- ============================================================
IF OBJECT_ID('dbo.sp_UpdateContact', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_UpdateContact;
GO

CREATE PROCEDURE dbo.sp_UpdateContact
    @Id            INT,
    @Name          NVARCHAR(255),
    @PhoneNumber   NVARCHAR(50),
    @Email         NVARCHAR(255) = NULL,
    @Address       NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE Contacts
    SET Name        = @Name,
        PhoneNumber = @PhoneNumber,
        Email       = @Email,
        Address     = @Address
    WHERE Id = @Id;

    SELECT @@ROWCOUNT AS AffectedRows;
END
GO

-- ============================================================
-- 6. Stored Procedure: sp_DeleteContact
-- ============================================================
IF OBJECT_ID('dbo.sp_DeleteContact', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_DeleteContact;
GO

CREATE PROCEDURE dbo.sp_DeleteContact
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM Contacts
    WHERE Id = @Id;

    SELECT @@ROWCOUNT AS AffectedRows;
END
GO
