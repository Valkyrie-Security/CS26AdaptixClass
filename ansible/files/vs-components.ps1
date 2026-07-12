$vsInstaller  = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\setup.exe"
$vsInstallPath = "C:\Program Files\Microsoft Visual Studio\2022\Community"
$vsComponents = @(
    # Workloads
    "Microsoft.VisualStudio.Workload.NativeDesktop",                    # Desktop development with C++ (IDE workload — includes x64 Native Tools Command Prompt)
    "Microsoft.VisualStudio.Workload.VCTools",                          # C++ build tools (standalone)

    # MSVC toolsets
    "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",               # MSVC v143 - VS 2022 C++ x64/x86 (latest)
    "Microsoft.VisualStudio.Component.VC.v142.x86.x64",                # MSVC v142 - VS 2019 C++ x64/x86
    "Microsoft.VisualStudio.Component.VC.v141.x86.x64",                # MSVC v141 - VS 2017 C++ x64/x86
    "Microsoft.VisualStudio.Component.VC.140",                          # MSVC v140 - VS 2015 C++

    # Windows SDKs
    "Microsoft.VisualStudio.Component.Windows11SDK.26100",              # Windows 11 SDK (10.0.26100)
    "Microsoft.VisualStudio.Component.Windows11SDK.22621",              # Windows 11 SDK (10.0.22621)
    "Microsoft.VisualStudio.Component.Windows10SDK.19041",              # Windows 10 SDK (10.0.19041)

    # C++ tools
    "Microsoft.VisualStudio.Component.VC.CMake.Project",               # C++ CMake tools for Windows
    "Microsoft.VisualStudio.Component.VC.ATL",                         # C++ ATL for latest v143
    "Microsoft.VisualStudio.Component.VC.ATLMFC",                      # C++ MFC for latest v143
    "Microsoft.VisualStudio.Component.VC.CLI.Support",                 # C++/CLI support for v143
    "Microsoft.VisualStudio.Component.VC.Modules.x86.x64",             # C++ Modules for v143
    "Microsoft.VisualStudio.Component.VC.ASAN",                        # C++ AddressSanitizer
    "Microsoft.VisualStudio.Component.VC.Vcpkg",                       # vcpkg package manager
    "Microsoft.VisualStudio.Component.VC.Redist.14.Latest",            # C++ 2022 Redistributable
    "Microsoft.VisualStudio.Component.VC.BuildInsights",               # Build Insights
    "Microsoft.VisualStudio.ComponentGroup.NativeDesktop.Llvm.Clang",  # C++ Clang tools for Windows

    # Build tools
    "Microsoft.VisualStudio.Component.MSBuild",                        # MSBuild
    "Microsoft.VisualStudio.Component.TestTools.BuildTools",           # Testing tools core features

    # .NET
    "Microsoft.Net.Component.4.8.SDK",                                 # .NET Framework 4.8 SDK
    "Microsoft.Net.Component.4.7.2.TargetingPack"                      # .NET Framework 4.7.2 targeting pack
)

$modifyArgs = @("modify", "--installPath", $vsInstallPath, "--quiet", "--norestart") +
    ($vsComponents | ForEach-Object { @("--add", $_) })

Write-Host "Adding VS2022 Community components..."
& $vsInstaller @modifyArgs
if ($LASTEXITCODE -ne 0) {
    Write-Warning "VS2022 component install exited with code: $LASTEXITCODE"
}
