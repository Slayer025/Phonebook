# Phonebook Application

A legacy-style monolithic ASP.NET MVC 5 (.NET Framework 4.5) phonebook application using pure ADO.NET
data access, stored procedures, and server-side pagination. See `CLAUDE.md` for the full architectural
and coding rules this project adheres to.

## Prerequisites

Make sure the following are installed before working on or running this project:

- **.NET Framework 4.5** — the project strictly targets `v4.5` (`TargetFrameworkVersion` in the `.csproj`, `targetFramework="4.5"` in both `Web.config` and `Views/Web.config`). If this machine has no v4.5 Developer/Targeting Pack installed under `C:\Program Files (x86)\Reference Assemblies\...`, the build instead pulls the reference assemblies from the `Microsoft.NETFramework.ReferenceAssemblies.net45` NuGet package (see the `Install NET45 Reference Assemblies` task below) — no system-wide install required.
- **SQL Server Express** — hosts the `PhonebookDb` database.
- **Visual Studio Code** — primary editor for this project.
- **NuGet CLI** (`nuget.exe`) — used to restore `packages.config` dependencies (MVC, Razor, WebPages, jQuery, Bootstrap, Microsoft.Web.Infrastructure) and the .NET 4.5 reference assemblies package.
- **MSBuild** — from Visual Studio Build Tools. This environment's install lives at `D:\BuildTools\MSBuild\Current\Bin\MSBuild.exe` (adjust if yours differs).
- **IIS Express** — used to host and debug the site locally. This environment has it installed to a non-default location, `D:\IIS Express\iisexpress.exe` (installed there because the C: drive was full — see `launch.json`).

## Installation

1. **Clone / copy the project** to your local machine (e.g., `D:\PhonebookApp`).

2. **Restore NuGet packages.**
   From the project root, either run the VS Code task (`Terminal > Run Task... > Restore NuGet Packages`) or run manually:
   ```
   nuget restore PhonebookApp.csproj
   ```

3. **Create the database and schema.**
   Open `DatabaseSetup.sql` in SQL Server Management Studio (or run it via `sqlcmd`) against your SQL Server Express instance:
   ```
   sqlcmd -S .\SQLEXPRESS -i DatabaseSetup.sql
   ```
   This script creates the `Contacts` table (if it doesn't already exist) and all five stored procedures:
   `sp_GetContactsPaged`, `sp_GetContactById`, `sp_InsertContact`, `sp_UpdateContact`, `sp_DeleteContact`.
   If the `PhonebookDb` database itself does not exist yet, uncomment the `CREATE DATABASE` block at the
   top of the script first.

4. **Verify the connection string** (see below) matches your SQL Server Express instance.

## Configuring the Connection String

The app reads its database connection from `Web.config` under the key `PhonebookDbConnection`:

```xml
<connectionStrings>
  <add name="PhonebookDbConnection"
       connectionString="Data Source=.\SQLEXPRESS;Initial Catalog=PhonebookDb;Integrated Security=True;"
       providerName="System.Data.SqlClient" />
</connectionStrings>
```

If your SQL Server Express instance uses a different instance name, a different database name, or requires
SQL authentication instead of Windows Integrated Security, update the `connectionString` value accordingly, e.g.:

```xml
<add name="PhonebookDbConnection"
     connectionString="Data Source=YOUR_SERVER\YOUR_INSTANCE;Initial Catalog=PhonebookDb;User Id=youruser;Password=yourpassword;"
     providerName="System.Data.SqlClient" />
```

`ContactRepository.cs` reads this value via `ConfigurationManager.ConnectionStrings["PhonebookDbConnection"].ConnectionString` —
the `name` attribute must stay in sync with that key.

## Building and Running

This project ships with VS Code tasks and a launch configuration under `.vscode/`.

### Build

- **Via Command Palette:** `Terminal > Run Build Task...` (or `Ctrl+Shift+B`) runs the default build task,
  `Build with MSBuild`. It runs three tasks in sequence: `Restore NuGet Packages` → `Install NET45 Reference
  Assemblies` → `Build with MSBuild`.
- **Via terminal (exact commands that work in this environment):**
  ```
  nuget restore PhonebookApp.csproj -PackagesDirectory "D:\PhonebookApp\packages"
  nuget install Microsoft.NETFramework.ReferenceAssemblies.net45 -OutputDirectory "D:\PhonebookApp\packages"

  & "D:\BuildTools\MSBuild\Current\Bin\MSBuild.exe" PhonebookApp.csproj `
      /p:Configuration=Debug `
      /p:VSToolsPath="D:\BuildTools\MSBuild\Microsoft\VisualStudio\v18.0" `
      /p:FrameworkPathOverride="D:\PhonebookApp\packages\Microsoft.NETFramework.ReferenceAssemblies.net45.1.0.3\build\.NETFramework\v4.5" `
      /t:Build /v:minimal
  ```

  > **Why the extra properties:** `VSToolsPath` points MSBuild at the folder containing
  > `WebApplications\Microsoft.WebApplication.targets` (this machine's Build Tools install doesn't register
  > it automatically). `FrameworkPathOverride` points at the NuGet-restored v4.5 reference assemblies, since
  > this machine has no v4.5 Developer/Targeting Pack installed system-wide (v4.8 is present, but the project
  > must stay on v4.5). If either `MSBuild.exe`'s location or the reference-assemblies package version
  > (currently `1.0.3`) differs on your machine, update the paths in `tasks.json` and above accordingly.
  > Also note `Reference Include="Microsoft.Web.Infrastructure"` in the `.csproj` has an explicit `<HintPath>`
  > and `<Private>True</Private>` — without `<Private>True</Private>` (Copy Local), that DLL won't be copied
  > into `bin\` and the app throws `Could not load file or assembly 'Microsoft.Web.Infrastructure'` at runtime.

### Run / Debug

- Open the **Run and Debug** panel in VS Code and select **"IIS Express: Launch PhonebookApp"**, or press `F5`.
- This launches `iisexpress.exe` pointed at the project folder on port `8080`, after running the default build task.
- Once running, browse to `http://localhost:8080/` to view the Contacts list.

  > **Note:** `.vscode/launch.json` in this environment points `program` at `D:\IIS Express\iisexpress.exe`
  > (installed to a custom D: drive location because C: was full). The default install location on most
  > machines is `C:\Program Files\IIS Express\iisexpress.exe` (or the 32-bit path,
  > `C:\Program Files (x86)\IIS Express\iisexpress.exe`) — update `program` in `launch.json` to match
  > wherever IIS Express actually lives on yours.

## Project Structure

```
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
│   ├── Web.config      # Razor MVC host config (pageBaseType, MvcWebRazorHostFactory)
│   ├── Home/
│   │   ├── Index.cshtml
│   │   ├── Create.cshtml
│   │   └── Edit.cshtml
│   └── Shared/
│       └── _Layout.cshtml   # loads Bootstrap/jQuery from CDN, not local Scripts/Content
├── packages.config
├── Web.config
├── PhonebookApp.csproj
├── Global.asax
├── Global.asax.cs
├── DatabaseSetup.sql
└── CLAUDE.md
```

## Architectural Notes

- **Data access** is pure ADO.NET (`SqlConnection` / `SqlCommand` / `SqlDataReader`) against predefined
  stored procedures only — no ORM, no inline SQL, all parameters passed via `SqlParameter`.
- **Pagination** is performed entirely at the database level using `OFFSET` / `FETCH NEXT` inside
  `sp_GetContactsPaged`; the application never loads the full table into memory.
- See `CLAUDE.md` for the complete set of architectural and coding rules this project must adhere to.
