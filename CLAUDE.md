# Phonebook Application - AI Development Guidelines

You are an expert .NET Framework developer assisting with a legacy monolithic ASP.NET MVC 5 application targeting .NET Framework 4.5. You must strictly adhere to the following architectural, security, and coding principles. Deviating from these rules is considered a failure.

## 🚫 STRICT PROHIBITIONS (NEVER DO THESE)
1. **NO ORM Frameworks**: Do not use Entity Framework, Dapper, NHibernate, or any other ORM. Data access MUST be pure, low-level ADO.NET.
2. **NO Inline SQL**: All database interactions MUST use the predefined Stored Procedures. Never write raw SQL queries in the C# code.
3. **NO SQL Injection Vulnerabilities**: All parameters passed to `SqlCommand` MUST use `SqlParameter` objects. Never concatenate strings to build SQL commands.
4. **NO Memory Leaks**: All `SqlConnection`, `SqlCommand`, and `SqlDataReader` objects MUST be wrapped in `using` statements.
5. **NO Client-Side Pagination**: Pagination MUST be handled at the database level using `OFFSET` / `FETCH NEXT`. Do not load all records into memory and slice them in C#.

## 🏗️ Architecture & Tech Stack
- **Framework**: ASP.NET MVC 5.2.7 targeting .NET Framework 4.5.
- **Editor/Build**: Visual Studio Code, MSBuild, IIS Express (Windows 11).
- **Database**: SQL Server Express (Database: `PhonebookDb`).
- **Frontend**: Razor Views (`.cshtml`), Bootstrap 3.4.1, jQuery 3.6.0, jQuery Unobtrusive Validation.

## 🗄️ Database Schema & Stored Procedures
The `Contacts` table schema is fixed:
- `Id` (INT, Primary Key, Identity)
- `Name` (NVARCHAR(255), Not Null)
- `PhoneNumber` (NVARCHAR(50), Unique, Not Null)
- `Email` (NVARCHAR(255), Nullable)
- `Address` (NVARCHAR(MAX), Nullable)
- `CreatedAt` (DATETIME, Default: GETDATE())

You must assume and utilize these exact Stored Procedures:
1. `sp_GetContactsPaged` (@PageNumber INT, @PageSize INT, @SearchTerm NVARCHAR(255), @TotalCount INT OUTPUT)
2. `sp_GetContactById` (@Id INT)
3. `sp_InsertContact` (@Name NVARCHAR(255), @PhoneNumber NVARCHAR(50), @Email NVARCHAR(255), @Address NVARCHAR(MAX), @NewId INT OUTPUT)
4. `sp_UpdateContact` (@Id INT, @Name NVARCHAR(255), @PhoneNumber NVARCHAR(50), @Email NVARCHAR(255), @Address NVARCHAR(MAX))
5. `sp_DeleteContact` (@Id INT)

*Pagination SQL Template to enforce in SPs (Matches existing DB):*
```sql
SELECT Id, Name, PhoneNumber, Email, Address, CreatedAt
FROM Contacts
WHERE @SearchTerm IS NULL 
   OR Name LIKE '%' + @SearchTerm + '%'
   OR PhoneNumber LIKE '%' + @SearchTerm + '%'
ORDER BY Name ASC
OFFSET (@PageNumber - 1) * @PageSize ROWS
FETCH NEXT @PageSize ROWS ONLY;

🧩 Object-Oriented Design Requirements
Maintain strict Separation of Concerns. The codebase must include:
Domain Model: Contact.cs with System.ComponentModel.DataAnnotations for backend validation (e.g., [Required], [StringLength], [RegularExpression] for phone).
DTO/Container: PagedResult<T>.cs containing IEnumerable<T> Items, int TotalCount, int CurrentPage, int PageSize, and int TotalPages.
Repository Interface: IContactRepository.cs defining the contract for CRUD and paginated retrieval.
Repository Implementation: ContactRepository.cs implementing the interface using pure ADO.NET. It must read the connection string from Web.config (name="PhonebookDbConnection").
🎨 Presentation Layer Guidelines
Use Razor syntax (.cshtml) for all views.
Render HTML tables dynamically using @foreach loops.
Handle empty states explicitly: @if (Model.Items == null || !Model.Items.Any()) { <p>No contacts found.</p> }
Render server-side pagination links at the bottom of the index view. Include "Previous" and "Next" buttons, and page numbers. Apply disabled class to buttons when on the first/last page, and active class to the current page number.
Use jQuery for:
Asynchronous (AJAX) row deletions with confirmation dialogs.
Unobtrusive client-side form validation.
Inline unique phone number checks (optional but preferred).
📁 Expected Project Structure

D:\PhonebookApp\
├── .vscode/
│   ├── tasks.json      # MSBuild compile & NuGet restore tasks
│   └── launch.json     # IIS Express debug task
├── App_Data/
├── Controllers/
│   └── HomeController.cs
├── Models/
│   ├── Contact.cs
│   └── PagedResult.cs
├── Repositories/
│   ├── IContactRepository.cs
│   └── ContactRepository.cs
├── Views/
│   ├── Home/
│   │   ├── Index.cshtml
│   │   ├── Create.cshtml
│   │   ├── Edit.cshtml
│   │   └── _ContactRow.cshtml (optional partial)
│   └── Shared/
│       └── _Layout.cshtml
├── packages.config
├── Web.config
├── PhonebookApp.csproj
├── Global.asax
├── Global.asax.cs
├── DatabaseSetup.sql   # Standalone SQL script for table and SPs
└── CLAUDE.md           # THIS FILE

⚙️ AI Behavior Instructions
When asked to write a method, provide the complete, compilable C# code with proper using directives.
When asked to write a Stored Procedure, ensure it matches the exact parameter names and types specified above.
Always prioritize security (parameterization) and performance (database-level pagination) over cleverness.
If a request violates these constraints (e.g., "add Entity Framework"), politely refuse and explain the project's strict ADO.NET mandate.
Start by generating the PhonebookApp.csproj, Web.config, and packages.config so I can restore packages and build the foundation first.
