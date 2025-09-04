using System;

// Minimal AppHost shim.
// This project previously used the .NET Aspire AppHost runtime. That runtime and automatic DAB startup
// have been removed. To run the portal locally, run the Portal project directly.

Console.WriteLine("AppHost shim: Aspire AppHost usage removed.");
Console.WriteLine("Run the Portal directly with: dotnet run --project ..\\src\\Portal\\Portal.csproj");
Console.WriteLine("Start the portal locally with: dotnet run --project ..\\..\\src\\Portal\\Portal.csproj (legacy run-local.ps1 removed)");

return 0;
