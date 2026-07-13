# Project Guide — How This App Works

This is a walkthrough for anyone new to this codebase — what the app does, how a request travels
through it end to end, what every file is responsible for, and exactly where every dependency lives
on disk. It assumes you know basic C# but not necessarily ASP.NET MVC, ADO.NET, or this specific
legacy-style project setup.

For install/build/run *commands*, see [`README.md`](README.md). This file is about *understanding*
the code, not running it.

---

## 1. What this app is, in one paragraph

It's a phonebook: a web page listing contacts (name, phone, email, address) with search and paging,
and buttons to add, edit, and delete contacts. It's built the "old" way on purpose — **ASP.NET MVC 5
on .NET Framework 4.5**, no modern frameworks, no ORM (no Entity Framework/Dapper), raw SQL via
**ADO.NET** and **stored procedures** only. If you've only worked with modern .NET (Core/5+) or
Node/React-style apps, the biggest adjustment is: there is no client-side framework, no API layer,
and no auto-generated SQL. Every screen is rendered as HTML on the server (via **Razor**, ASP.NET's
`.cshtml` templating language), and every database call goes through a hand-written stored procedure.

## 2. Glossary (skip if you already know these)

| Term | What it means here |
|---|---|
| **ASP.NET MVC** | The web framework. "MVC" = Model-View-Controller: `Models/` hold data shapes, `Views/` hold HTML templates, `Controllers/` hold the logic that connects a URL to a Model and picks a View. |
| **Razor (`.cshtml`)** | A templating syntax that mixes HTML with C#. `@` starts a C# expression/block inside HTML. |
| **ADO.NET** | The low-level, no-ORM way of talking to SQL Server from .NET: you open a `SqlConnection`, build a `SqlCommand`, and read results with a `SqlDataReader`. This project uses *only* this — no Entity Framework. |
| **Stored Procedure (SP)** | A named, pre-compiled block of SQL stored *inside* SQL Server itself (not in this codebase's C#/text files as raw queries). The C# code calls SPs by name and passes parameters; it never builds SQL strings. |
| **`SqlParameter`** | How a value (e.g. a contact's name) is safely passed into a SQL command, instead of gluing strings together. This is what prevents SQL injection — see `ContactRepository.cs`. |
| **IIS Express** | A lightweight local web server (Windows-only) used to run and debug the site while developing, instead of a full production IIS install. |
| **MSBuild** | The command-line tool that compiles the `.csproj` into a `.dll` (the actual compiled app). |
| **NuGet** | .NET's package manager — where the MVC framework itself, jQuery, Bootstrap, etc. come from. |

## 3. The big picture: how a request flows through the system

```
 Browser (you)
     │  e.g. GET http://localhost:8080/Home/Index?page=2&searchTerm=john
     ▼
 IIS Express  (hosts the app, listens on a port)
     │
     ▼
 Global.asax.cs → RouteConfig        (decides: URL "/Home/Index" means
     │                                 controller = HomeController, action = Index)
     ▼
 Controllers/HomeController.cs        (the "traffic cop" — reads the request,
     │                                 calls the repository, picks a View)
     ▼
 Repositories/ContactRepository.cs    (talks to the database using ADO.NET —
     │                                 opens a SqlConnection, calls a stored
     │                                 procedure, reads results into Contact
     │                                 objects)
     ▼
 SQL Server Express (PhonebookDb)     (runs the stored procedure — e.g.
     │                                 sp_GetContactsPaged — and returns rows)
     ▼
 back up through ContactRepository → HomeController
     │
     ▼
 Views/Home/Index.cshtml              (Razor template turns the C# objects
     │                                 into an HTML page)
     ▼
 Browser renders the HTML page you see
```

Everything below the "Global.asax.cs" line is C# code in this repo. Everything above it is
infrastructure (IIS Express, your browser) that isn't part of the source code — it's installed
separately (see section 5).

## 4. Walking through one real feature: clicking "Delete"

This is the clearest way to see every layer working together.

1. **`Views/Home/Index.cshtml`** — each contact row has a button:
   `<button class="btn-danger btn-delete" data-id="@contact.Id">Delete</button>`.
   The `@contact.Id` is Razor injecting the real database Id into the HTML at render time.

2. Also in `Index.cshtml`, inside `@section scripts { ... }`, jQuery is wired up to listen for
   clicks on any `.btn-delete` button. On click, it shows a `confirm()` dialog, then sends an
   **AJAX POST** (a background HTTP request, no page reload) to `/Home/Delete` with the contact's
   `id`.

3. **`Controllers/HomeController.cs`** — the `Delete(int? id)` action method receives that POST.
   It calls `_repo.DeleteContact(id.Value)` and wraps the result in JSON:
   `{"success": true}` or `{"success": false, "message": "..."}`.

4. **`Repositories/ContactRepository.cs`** — `DeleteContact(int id)` opens a `SqlConnection`,
   builds a `SqlCommand` that calls the `sp_DeleteContact` stored procedure, passes `id` as a
   `SqlParameter` (never as raw SQL text), and reads back how many rows were actually deleted.

5. **`DatabaseSetup.sql`** — this is where `sp_DeleteContact` is *defined*. It lives inside SQL
   Server itself, not as a C# string. The procedure runs `DELETE FROM Contacts WHERE Id = @Id;`
   and reports back the row count via `SELECT @@ROWCOUNT`.

6. The JSON response travels back to the browser. The jQuery code from step 2 reads
   `response.success` — if `true`, it fades out and removes that table row (no full page reload);
   if `false`, it shows an alert.

**Create** and **Edit** follow the same shape, except they're normal (non-AJAX) form posts that
redirect back to the Index page, and **Index**'s initial page load follows the same shape as steps
3–5 but calling `sp_GetContactsPaged` instead.

## 5. File-by-file guide

### Root
| File | What it's for |
|---|---|
| `PhonebookApp.csproj` | The project file. Lists every source file MSBuild needs to compile (`<Compile Include>`), every static/content file to publish (`<Content Include>`), and every DLL reference (`<Reference>`) — including exact paths into the `packages\` folder for NuGet DLLs. **If you add a new `.cs` or `.cshtml` file, it must be added here or MSBuild silently ignores it** (this isn't a modern SDK-style project with automatic file globbing). |
| `Web.config` | App-wide configuration: the database connection string (`PhonebookDbConnection`), ASP.NET compilation settings, and IIS handler mappings. Read at runtime by `ConfigurationManager`. |
| `packages.config` | Declares which NuGet packages this project depends on and their versions (see section 6). |
| `Global.asax` / `Global.asax.cs` | The application's entry point. `Global.asax` just points to the `MvcApplication` class in `Global.asax.cs`, whose `Application_Start()` runs once when the app starts and registers the URL routing rules (which URL patterns map to which controller/action). |
| `DatabaseSetup.sql` | A standalone SQL script — **not run automatically**. You run it once against SQL Server Express to create the `Contacts` table and all 5 stored procedures. Safe to re-run (drops and recreates procedures, but only creates the table if it doesn't already exist). |
| `README.md` | Setup/build/run instructions for this specific machine's quirks. |
| `CLAUDE.md` | The architectural rules this project must follow (no ORM, no inline SQL, etc.) — the "constitution" for how code in this repo should be written. |

### `Models/` — plain data shapes, no logic
| File | What it's for |
|---|---|
| `Contact.cs` | Represents one contact record. Has validation rules as C# attributes (`[Required]`, `[StringLength]`, `[RegularExpression]` for phone format, `[EmailAddress]`) — ASP.NET MVC checks these automatically before `ModelState.IsValid` is true in the controller. |
| `PagedResult.cs` | A generic wrapper (`PagedResult<T>`) used to hand a page of results *plus* pagination info (`TotalCount`, `CurrentPage`, `PageSize`, computed `TotalPages`) from the repository to the view in one object. |

### `Repositories/` — the only layer allowed to talk to the database
| File | What it's for |
|---|---|
| `IContactRepository.cs` | An interface — just a list of method signatures (`GetContactsPaged`, `GetContactById`, `InsertContact`, `UpdateContact`, `DeleteContact`) with no implementation. This exists so `HomeController` depends on "some way to fetch contacts" rather than directly on ADO.NET/SQL Server — useful for testing and for swapping implementations later. |
| `ContactRepository.cs` | The actual implementation, using raw ADO.NET (`SqlConnection`, `SqlCommand`, `SqlParameter`, `SqlDataReader`), all wrapped in `using` blocks so connections always close. Each method calls exactly one stored procedure by name — never builds a SQL string. This is the **only file in the codebase that contains SQL Server connection/command code**. |

### `Controllers/`
| File | What it's for |
|---|---|
| `HomeController.cs` | Every URL in this app is handled here (there's only one controller). Each public method is an "action": `Index` (list/search/page), `Create` (GET shows the empty form, POST saves it), `Edit` (GET shows the form pre-filled, POST saves changes), `Delete` (POST-only, returns JSON for the AJAX call). It creates its own `ContactRepository` instance and never touches SQL directly — it only calls repository methods. |

### `Views/` — HTML templates (Razor)
| File | What it's for |
|---|---|
| `Views/Web.config` | Not app configuration — this tells ASP.NET *how to compile `.cshtml` files* (treat them as MVC views, make `Html.*`/`Url.*` helpers available) and blocks browsers from requesting a `.cshtml` file directly as a URL. |
| `Views/Shared/_Layout.cshtml` | The shared page shell (`<html>`, nav bar, CSS/JS `<script>` tags) that every other view renders inside of, via `@RenderBody()`. Loads Bootstrap and jQuery **from a CDN** (see section 6 — not from local files). |
| `Views/Home/Index.cshtml` | The contact list page: search box, table of contacts, pagination links, and the AJAX delete script. |
| `Views/Home/Create.cshtml` | The "add a contact" form. |
| `Views/Home/Edit.cshtml` | The "edit a contact" form — same fields as Create, plus a hidden `Id` field so the controller knows which record to update. |

### `.vscode/`
| File | What it's for |
|---|---|
| `tasks.json` | Defines the build pipeline you run from VS Code (`Ctrl+Shift+B`): restore NuGet packages → install .NET 4.5 reference assemblies → compile with MSBuild. See section 6 for why the last two steps exist on this machine specifically. |
| `launch.json` | Tells VS Code how to start IIS Express when you press `F5`, and where `iisexpress.exe` lives on this machine. |

## 6. Dependencies — what they are and exactly where they live

This app has two *kinds* of dependency: things bundled with the app (NuGet packages, restored into
this project's own folder) and things installed separately on this machine (dev tools). Neither is
committed to source control (well — there's no git repo here, but conceptually the `packages\`,
`bin\`, and `obj\` folders are generated/downloaded, not hand-written).

### 6a. NuGet packages (declared in `packages.config`, restored into `packages\`)

| Package | Version | Restored to (relative to project root) | Used for |
|---|---|---|---|
| Microsoft.AspNet.Mvc | 5.2.7 | `packages\Microsoft.AspNet.Mvc.5.2.7\lib\net45\System.Web.Mvc.dll` | The MVC framework itself (`Controller`, `ActionResult`, routing, Razor view engine glue). |
| Microsoft.AspNet.Razor | 3.2.7 | `packages\Microsoft.AspNet.Razor.3.2.7\lib\net45\System.Web.Razor.dll` | Compiles `.cshtml` files into C# behind the scenes. |
| Microsoft.AspNet.WebPages | 3.2.7 | `packages\Microsoft.AspNet.WebPages.3.2.7\lib\net45\*.dll` | Supporting infrastructure Razor/MVC are built on. |
| Microsoft.Web.Infrastructure | 1.0.0.0 | `packages\Microsoft.Web.Infrastructure.1.0.0.0\lib\net40\Microsoft.Web.Infrastructure.dll` | Low-level ASP.NET pre-application-start hooks that MVC needs internally. |
| jQuery | 3.6.0 | `packages\jQuery.3.6.0\...` | **Present but currently unused at runtime** — the app actually loads jQuery from a CDN (see 6b), not this local copy. Kept in `packages.config` as a documented version pin / offline fallback. |
| bootstrap | 3.4.1 | `packages\bootstrap.3.4.1\...` | Same as jQuery above — present in `packages\` but the live site loads Bootstrap from a CDN instead. |

Every DLL a package provides that the app actually needs at compile/run time is wired up explicitly
in `PhonebookApp.csproj` under `<Reference Include="..."><HintPath>...</HintPath></Reference>`. If a
reference is missing `<Private>True</Private>`, MSBuild won't copy that DLL into `bin\`, and you'll
get a runtime "Could not load file or assembly" error even though the build succeeds — this exact
bug happened with `Microsoft.Web.Infrastructure.dll` and was fixed by adding `<Private>True</Private>`.

**How to restore these:** run the `Restore NuGet Packages` VS Code task, or manually:
`nuget restore PhonebookApp.csproj -PackagesDirectory packages`

### 6b. Front-end libraries actually used by the browser (loaded from CDN, not local files)

`Views/Shared/_Layout.cshtml` loads these directly from the internet at page-load time — there is
**no local copy shipped with the app** for these, despite jQuery/Bootstrap also appearing in
`packages.config` above (that's a leftover from an earlier local-file setup; the CDN links are what
actually run):

| Library | Version | Loaded from |
|---|---|---|
| Bootstrap (CSS) | 3.4.1 | `https://stackpath.bootstrapcdn.com/bootstrap/3.4.1/css/bootstrap.min.css` |
| jQuery | 3.6.0 | `https://code.jquery.com/jquery-3.6.0.min.js` |
| Bootstrap (JS) | 3.4.1 | `https://stackpath.bootstrapcdn.com/bootstrap/3.4.1/js/bootstrap.min.js` |
| jQuery Validate | 1.19.3 | `https://cdnjs.cloudflare.com/ajax/libs/jquery-validate/1.19.3/jquery.validate.min.js` |
| jQuery Unobtrusive Validation | 3.2.12 | `https://cdnjs.cloudflare.com/ajax/libs/jquery-validation-unobtrusive/3.2.12/jquery.validate.unobtrusive.min.js` |

**Practical implication:** if this machine (or the one running the app) has no internet access, the
page will load but with no styling and no client-side validation/AJAX, since the browser can't fetch
those `<script>`/`<link>` tags.

### 6c. Developer tools installed separately on this machine (not part of the app itself)

These aren't NuGet packages — they're tools you need installed to build/run the app at all. Their
locations below are **specific to this machine's setup** (this environment had some non-standard
install locations — see `README.md` for the full story of why):

| Tool | Location on this machine | Used for |
|---|---|---|
| MSBuild | `D:\BuildTools\MSBuild\Current\Bin\MSBuild.exe` | Compiles the project. Needs `/p:VSToolsPath=D:\BuildTools\MSBuild\Microsoft\VisualStudio\v18.0` passed explicitly so it can find `Microsoft.WebApplication.targets` (the build logic for web projects). |
| .NET Framework 4.5 reference assemblies | `packages\Microsoft.NETFramework.ReferenceAssemblies.net45.1.0.3\build\.NETFramework\v4.5\` | Compile-time only — the actual `mscorlib.dll`/`System.Web.dll`/etc. the compiler checks your code against. This machine has no system-wide v4.5 Developer/Targeting Pack installed (only v4.8), so these are pulled from a NuGet package instead and pointed at via `/p:FrameworkPathOverride=...`. |
| IIS Express | `D:\IIS Express\iisexpress.exe` | The local web server that actually runs the compiled app so you can browse to it. Installed to a custom D: drive path here because C: was full — the default location on most machines is `C:\Program Files\IIS Express\iisexpress.exe`. |
| NuGet CLI | `D:\NuGet\nuget.exe` | Downloads/restores the packages listed in `packages.config`. |
| SQL Server Express | Local instance `.\SQLEXPRESS` (Windows service `MSSQL$SQLEXPRESS`) | Hosts the `PhonebookDb` database that `DatabaseSetup.sql` creates the schema/procedures in, and that `ContactRepository.cs` connects to via the connection string in `Web.config`. |

All of the above (except NuGet packages) are configured for you already in `.vscode/tasks.json` and
`.vscode/launch.json` — you shouldn't need to type these paths yourself day to day; they're documented
here so you understand *why* those config files look the way they do, and what to change if you move
this project to a different machine.

## 7. A couple of non-obvious things worth knowing

- **`SET NOCOUNT ON` + `ExecuteNonQuery()` gotcha:** `sp_UpdateContact` and `sp_DeleteContact` both
  end with `SELECT @@ROWCOUNT AS AffectedRows;`, and `ContactRepository.cs` reads that via
  `ExecuteScalar()` rather than trusting `ExecuteNonQuery()`'s return value. This looks unusual if
  you've used ADO.NET before — it's because stored procedures with `SET NOCOUNT ON` (a performance
  best practice) cause `ExecuteNonQuery()` to return `-1` instead of the real row count in this
  environment, which silently broke "success" detection on Update/Delete until it was found and fixed.
- **`int?` (nullable) route parameters on `Delete` and `Edit`:** both actions take `int? id` instead
  of `int id`. If a malformed URL (e.g. `/Home/Delete/abc`) can't convert to a plain `int`, ASP.NET
  MVC throws before your action code even runs — using `int?` lets that case bind to `null` instead
  of crashing, so the action can handle it gracefully (return a clean "not found"/"invalid" response)
  instead of showing a raw error page to the user.
- **No `App_Start/` folder:** in a typical "File → New Project" ASP.NET MVC 5 template, routing lives
  in `App_Start\RouteConfig.cs`. Here, the equivalent `RouteConfig` class is defined directly inside
  `Global.asax.cs` instead — same job, just not split into a separate folder.
