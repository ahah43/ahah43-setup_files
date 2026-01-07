$cacheDir = "$HOME\.ps_cache"
$themeCache = "$cacheDir\ahah43-blue-owl.omp.json"

function Update-ProfileFromGitHub
{
    Write-Host "Updating PowerShell profile from GitHub..." -ForegroundColor Cyan

    $githubBlobUrl = "https://github.com/ahah43/ahah43-setup_files/blob/main/powershell%20setup%20files/Microsoft.PowerShell_profile.ps1"

    # Convert GitHub blob URL to raw URL
    $rawUrl = $githubBlobUrl `
        -replace '^https://github.com/', 'https://raw.githubusercontent.com/' `
        -replace '/blob/', '/'

    $profilePath = $PROFILE
    $profileDir  = Split-Path $profilePath
    $tempFile    = "$profilePath.tmp"

    if (-not (Test-Path $profileDir))
    {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }

    Write-Host "Fetching profile..." -NoNewline

    try
    {
        Invoke-WebRequest `
            -Uri $rawUrl `
            -OutFile $tempFile `
            -TimeoutSec 5 `
            -ErrorAction Stop

        # Sanity checks
        if ((Get-Item $tempFile).Length -eq 0)
        {
            throw "Downloaded profile is empty."
        }

        # Reject HTML (common GitHub mistake)
        if (Select-String -Path $tempFile -Pattern '<html' -Quiet)
        {
            throw "Downloaded content is HTML, not a PowerShell profile."
        }

        Move-Item -Path $tempFile -Destination $profilePath -Force
        Write-Host " Updated." -ForegroundColor Green
    } catch
    {
        if (Test-Path $tempFile)
        {
            Remove-Item $tempFile -Force
        }

        Write-Warning "Profile update failed. Local profile left unchanged."
        Write-Verbose $_
    }
}

# function newSessionOhMyPosh{
#     $themeCache = "$cacheDir\ahah43-blue-owl.omp.json"
#     # oh-my-posh init pwsh --config "$themeCache" | Invoke-Expression
#     oh-my-posh init pwsh --config "$themeCache" > "$cacheDir\posh-init.ps1"
# }

function Update-ohMyPosh-json
{
    if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue))
    {
        Write-Warning "oh-my-posh not found. Skipping prompt cache."
        return
    }
    # Write-Host "Rebuilding profile cache..." -ForegroundColor Cyan
    # $themeCache = "$cacheDir\ahah43-blue-owl.omp.json"
    $remoteTheme = "https://raw.githubusercontent.com/ahah43/ahah43-setup_files/main/oh-my-posh%20setup/ahah43-blue-owl.omp.json"

    if (-not (Test-Path $cacheDir))
    {
        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
    }

    Write-Host "Checking GitHub for updated theme..." -NoNewline

    try
    {
        Invoke-WebRequest `
            -Uri $remoteTheme `
            -OutFile $themeCache `
            -UseBasicParsing `
            -TimeoutSec 5 `
            -ErrorAction Stop

        Write-Host " Updated." -ForegroundColor Green
    } catch
    {
        Write-Host " Offline." -ForegroundColor Yellow

        if (-not (Test-Path $themeCache))
        {
            Write-Error "No local theme cache found and GitHub unreachable."
            return
        }

        Write-Warning "Updated Using last cached local theme."
    }

    oh-my-posh init pwsh --config "$themeCache" > "$cacheDir\posh-init.ps1"
    Write-Host "oh-my-posh theme Cache update complete." -ForegroundColor Cyan
}

function Update-uv
{
    if (-not (Get-Command uv -ErrorAction SilentlyContinue))
    {
        Write-Warning "uv not found. Skipping prompt cache."
        return
    }
    uv generate-shell-completion powershell > "$cacheDir\uv-completion.ps1"
    Write-Host "uv Cache update complete." -ForegroundColor Cyan

}
function Update-uvx
{
    if (-not (Get-Command uvx -ErrorAction SilentlyContinue))
    {
        Write-Warning "uvx not found. Skipping prompt cache."
        return
    }
    uvx --generate-shell-completion powershell > "$cacheDir\uvx-completion.ps1"
    Write-Host "uvx Cache update complete." -ForegroundColor Cyan
}

function Update-scoopSearch
{
    if (-not (Get-Command scoop-search -ErrorAction SilentlyContinue))
    {
        Write-Warning "scoop-search not found. Skipping prompt cache."
        return
    }
    & scoop-search --hook > "$cacheDir\scoop-search-hook.ps1"
    Write-Host "scoop-search Cache update complete." -ForegroundColor Cyan
}

function Update-Cache
{
    Write-Host "Rebuilding profile cache..." -ForegroundColor Cyan
    # Update-ohMyPosh-json
    Update-uv
    Update-uvx
    Update-scoopSearch
    Write-Host "Cache update complete." -ForegroundColor Cyan
    Write-Warning "tip: Run this command to restart PowerShell: psRestart"

}


if (-not (Test-Path "$cacheDir\uv-completion.ps1"))
{
    Write-Host "Initial setup: Generating profile cache..." -ForegroundColor Yellow
    Update-Cache
}

# LOAD CACHED SETTINGS (Ultra Fast)
function LoadCachedSettingsFile
{
    param(
        [Parameter(Mandatory)]
        [string]$CachedFilePath,

        [Parameter(Mandatory)]
        [string]$RequiredCommand
    )

    if (-not (Get-Command $RequiredCommand -ErrorAction SilentlyContinue))
    {
        Write-Warning "Skipping $CachedFilePath (missing dependency: $RequiredCommand)"
        return
    }

    if (-not (Test-Path $CachedFilePath))
    {
        Write-Warning "Cached file not found: $CachedFilePath"
        return
    }

    try
    {
        . $CachedFilePath
    } catch
    {
        Write-Warning "Failed to load cached file: $CachedFilePath"
        Write-Verbose $_
    }
}


$lastUpdate = (Get-Item "$cacheDir\uv-completion.ps1").LastWriteTime
if ($lastUpdate -lt (Get-Date).AddDays(-1))
{
    Update-Cache
}

# Write-Host "--- Start Profile Load ---" -ForegroundColor Cyan
# $ProfileTimer = [System.Diagnostics.Stopwatch]::StartNew()

# Write-Host ("(' ProfileTimer  ',{1})," -f $MyInvocation.ScriptLineNumber, $ProfileTimer.ElapsedMilliseconds)

function dirTree
{
    <#
    .SYNOPSIS
    Prints a directory's subtree structure, optionally with exclusions.

    .DESCRIPTION
    Prints a given directory's subdirectory structure recursively in tree form,
    so as to visualize the directory hierarchy similar to cmd.exe's built-in
    'tree' command, but with the added ability to exclude subtrees by directory
    names.

    NOTE: Symlinks to directories are not followed; a warning to that effect is
            issued.

    .PARAMETER Path
    The target directory path; defaults to the current directory.
    You may specify a wildcard pattern, but it must resolve to a single directory.

    .PARAMETER Exclude
    One or more directory names that should be excluded from the output; wildcards
    are permitted. Any directory that matches anywhere in the target hierarchy
    is excluded, along with its subtree.
    If -IncludeFiles is also specified, the exclusions are applied to the files'
    names as well.

    .PARAMETER IncludeFiles
    By default, only directories are printed; use this switch to print files
    as well.

    .PARAMETER Ascii
    Uses ASCII characters to visualize the tree structure; by default, graphical
    characters from the OEM character set are used.

    .PARAMETER IndentCount
    Specifies how many characters to use to represent each level of the hierarchy.
    Defaults to 4.

    .PARAMETER Force
    Includes hidden items in the output; by default, they're ignored.

    .NOTES
    Directory symlinks are NOT followed, and a warning to that effect is issued.

    .EXAMPLE
    tree

    Prints the current directory's subdirectory hierarchy.

    .EXAMPLE
    tree ~/Projects -Ascii -Force -Exclude node_modules, .git

    Prints the specified directory's subdirectory hierarchy using ASCII characters
    for visualization, including hidden subdirectories, but excluding the
    subtrees of any directories named 'node_modules' or '.git'.
    #>

    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(Position = 0)]
        [string] $Path = '.',
        [string[]] $Exclude,
        [ValidateRange(1, [int]::MaxValue)]
        [int] $IndentCount = 4,
        [switch] $Ascii,
        [switch] $Force,
        [switch] $IncludeFiles
    )

    # Embedded recursive helper function for drawing the tree.
    function _tree_helper
    {

        param(
            [string]$literalPath,
            [string]$prefix
        )

        # Get all subdirs. and, if requested, also files.
        $items = Get-ChildItem -Directory:(-not $IncludeFiles) -LiteralPath $LiteralPath -Force:$Force

        # Apply exclusion filter(s), if specified.
        if ($Exclude -and $items)
        {
            $items = $items.Where({ $name = $_.Name; -not $Exclude.Where({ $name -like $_ },'First') })
        }

        if (-not $items)
        { return
        } # no subdirs. / files, we're done

        $i = 0
        foreach ($item in $items)
        {
            $isLastSibling =++ $i -eq $items.Count
            # Print this dir.
            $prefix + $(if ($isLastSibling)
                { $chars.last
                } else
                { $chars.interior
                }) + $chars.hline * ($indentCount - 1) + $item.Name
            # Recurse, if it's a subdir (rather than a file).
            if ($item.PSIsContainer)
            {
                if ($item.LinkType)
                { Write-Warning "Not following dir. symlink: $item"; continue
                }
                $subPrefix = $prefix + $(if ($isLastSibling)
                    { $chars.space * $indentCount
                    } else
                    { $chars.vline + $chars.space * ($indentCount - 1)
                    })
                _tree_helper $item.FullName $subPrefix
            }
        }
    } # function _tree_helper

    # Hashtable of characters used to draw the structure
    $ndx = [bool] $Ascii
    $chars = @{
        interior = ('├','+')[$ndx]
        last = ('└','\\')[$ndx]
        hline = ('─','-')[$ndx]
        vline = ('|','|')[$ndx]
        space = " "
    }

    # Resolve the path to a full path and verify its existence and expected type.
    $literalPath = (Resolve-Path $Path).Path
    if (-not $literalPath -or -not (Test-Path -PathType Container -LiteralPath $literalPath) -or $literalPath.Count -gt 1)
    { throw "$Path must resolve to a single, existing directory."
    }

    # Print the target path.
    $literalPath

    # Invoke the helper function to draw the tree.
    _tree_helper $literalPath

}

# Write-Host ("(' dirTree  ',{1})," -f $MyInvocation.ScriptLineNumber, $ProfileTimer.ElapsedMilliseconds)

function linux
{
    param (
        [Parameter(HelpMessage = "Restart the 'Ubuntu' distribution before starting.")]
        [switch]$Restart,

        [Parameter(HelpMessage = "Terminate the 'Ubuntu' distribution and exit.")]
        [switch]$Kill
    )

    $distroName = "Ubuntu"

    if ($Kill)
    {
        Write-Host "Terminating $distroName..."
        wsl --terminate $distroName
        wsl --shutdown
        return # Stop execution here
    }

    if ($Restart)
    {
        Write-Host "Restarting $distroName..."
        wsl --terminate $distroName
    }

    # This part now runs for `linux` (by itself) and `linux -Restart`
    Write-Host "Starting $distroName..."
    wsl -d $distroName
}
# Write-Host ("(' linux  ',{1})," -f $MyInvocation.ScriptLineNumber, $ProfileTimer.ElapsedMilliseconds)

# function psRestart
# {
#     param (
#         # If this switch is included, the new session will be as admin
#         [switch]$Admin
#     )
#     if ($Admin)
#     {
#         # Run this if 'ps-restart -Admin' is typed
#         Start-Process -FilePath "pwsh.exe" -ArgumentList "-NoExit" -Verb RunAs
#     } else
#     {
#         # Run this if just 'ps-restart' is typed
#         Start-Process -FilePath "pwsh.exe" -ArgumentList "-NoExit"
#     }

#     exit
# }


function psRestart
{
    param ([switch]$Admin)
    $arguments = "-NoExit -Command Set-Location '$PWD'"
    if ($Admin)
    {
        Start-Process pwsh -ArgumentList $arguments -Verb RunAs
    } else
    {
        Start-Process pwsh -ArgumentList $arguments
    }
    exit
}
# Write-Host ("(' psRestart  ',{1})," -f $MyInvocation.ScriptLineNumber, $ProfileTimer.ElapsedMilliseconds)
# Enhanced PowerShell Experience
# Enhanced PSReadLine Configuration
$PSReadLineOptions = @{
    EditMode = 'Windows'
    HistoryNoDuplicates = $true
    HistorySearchCursorMovesToEnd = $true
    Colors = @{
        Command = '#87CEEB'  # SkyBlue (pastel)
        Parameter = '#98FB98'  # PaleGreen (pastel)
        Operator = '#FFB6C1'  # LightPink (pastel)
        Variable = '#DDA0DD'  # Plum (pastel)
        String = '#FFDAB9'  # PeachPuff (pastel)
        Number = '#B0E0E6'  # PowderBlue (pastel)
        Type = '#F0E68C'  # Khaki (pastel)
        Comment = '#D3D3D3'  # LightGray (pastel)
        Keyword = '#8367c7'  # Violet (pastel)
        Error = '#FF6347'  # Tomato (keeping it close to red for visibility)
    }
    PredictionSource = 'HistoryAndPlugin'
    PredictionViewStyle = 'ListView'
    BellStyle = 'None'
}
Set-PSReadLineOption @PSReadLineOptions

# Custom key handlers
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteChar
Set-PSReadLineKeyHandler -Chord 'Ctrl+w' -Function BackwardDeleteWord
Set-PSReadLineKeyHandler -Chord 'Alt+d' -Function DeleteWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+LeftArrow' -Function BackwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+z' -Function Undo
Set-PSReadLineKeyHandler -Chord 'Ctrl+y' -Function Redo

# Custom functions for PSReadLine
Set-PSReadLineOption -AddToHistoryHandler {
    param($line)
    $sensitive = @('password', 'secret', 'token', 'apikey', 'connectionstring')
    $hasSensitive = $sensitive | Where-Object { $line -match $_ }
    return ($null -eq $hasSensitive)
}

# Improved prediction settings
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -MaximumHistoryCount 10000

# Write-Host ("(' PSReadLineOptions  ',{1})," -f $MyInvocation.ScriptLineNumber, $ProfileTimer.ElapsedMilliseconds)
###################################################
###################################################
# # type ./, you’ll see a dropdown list of paths, just like the history list.
# if (Get-Module -ListAvailable -Name CompletionPredictor) {
#     Import-Module CompletionPredictor
# }
#


# git commands
function g
{
    param (
        [Parameter(HelpMessage = "Add changes to the staging area.")]
        [switch]$Add,

        [Parameter(HelpMessage = "Commit changes to the repository.")]
        [switch]$AddCommit,

        [Parameter(HelpMessage = "Commit and push changes to the repository.")]
        [switch]$AddCommitPush,

        [Parameter(HelpMessage = "Show the status of the repository. (-Status or blank")]
        [switch]$Status,

        [string]$msg
    )
    if ($Add)
    {
        git add .
        return
    }
    if ($AddCommit)
    {
        g -Add
        git commit -m "$msg"
        return
    }
    if ($AddCommitPush)
    {
        g -AddCommit "$msg"
        git push
        return
    }
    # if ($Status)
    # {
    git status
    # return
    # }

}

# Write-Host ("(' git  ',{1})," -f $MyInvocation.ScriptLineNumber, $ProfileTimer.ElapsedMilliseconds)
###################################################
###################################################
#function y
#{
#    $tmp = [System.IO.Path]::GetTempFileName()
#    yazi $args --cwd-file = "$tmp"
#    $cwd = Get-Content -Path $tmp -Encoding UTF8
#    if (-not [String]::IsNullOrEmpty($cwd) -and $cwd -ne $PWD.Path)
#    {
#        Set-Location -LiteralPath ([System.IO.Path]::GetFullPath($cwd))
#    }
#    Remove-Item -Path $tmp
#}

function y
{
    $tmp = (New-TemporaryFile).FullName
    yazi $args --cwd-file="$tmp"
    $cwd = Get-Content -Path $tmp -Encoding UTF8
    if (-not [String]::IsNullOrEmpty($cwd) -and $cwd -ne $PWD.Path)
    {
        Set-Location -LiteralPath (Resolve-Path -LiteralPath $cwd).Path
    }
    Remove-Item -Path $tmp
}
# Write-Host ("(' yazi  ',{1})," -f $MyInvocation.ScriptLineNumber, $ProfileTimer.ElapsedMilliseconds)
function findES
{
    param (
        [Parameter(HelpMessage = "search in this location only")]
        [switch]$Here,
        [switch]$Global,
        [string]$Query
    )
    if ($Here)
    {
        # es.exe -path "[Environment]::CurrentDirectory"  $Query
        & es.exe -path "." $Query
        return

    }
    # Global or blank
    es.exe $Query
}
# Write-Host ("(' ES  ',{1})," -f $MyInvocation.ScriptLineNumber, $ProfileTimer.ElapsedMilliseconds)



# # colored path, user, etc.
#oh-my-posh init pwsh | Invoke-Expression

# # oh my posh theme (disabled to use custom prompt with RAM usage)
# oh-my-posh init pwsh --config "C:\Users\AHAH43\Documents\ahah43-blue-owl.omp.json" | Invoke-Expression
# . "$HOME\.ps_cache\posh-init.ps1"
# #oh-my-posh init pwsh --config "C:\Users\AHAH43\AppData\Local\Programs\oh-my-posh\themes\clean-detailed.omp.json" | Invoke-Expression
# Write-Host ("(' oh-my-posh  ',{1})," -f $MyInvocation.ScriptLineNumber, $ProfileTimer.ElapsedMilliseconds)
# # Starship theme
##$ENV:STARSHIP_CONFIG = "C:\Users\AHAH43\Documents\starship.toml"
##Invoke-Expression (&starship init powershell)

# # Terminal-Icons is slowwwwwwwwwww
#Import-Module -Name Terminal-Icons


#Invoke-Expression (&scoop-search --hook)
# . ([ScriptBlock]::Create((& scoop-search --hook | Out-String)))
# . "$HOME\.ps_cache\scoop-search-hook.ps1"
# Write-Host ("(' scoop-search  ',{1})," -f $MyInvocation.ScriptLineNumber, $ProfileTimer.ElapsedMilliseconds)
#Invoke-Expression (& { (zoxide init powershell | Out-String) })
# (& uv generate-shell-completion powershell) | Out-String | Invoke-Expression
# . "$HOME\.ps_cache\uv-completion.ps1"
# Write-Host ("(' uv  ',{1})," -f $MyInvocation.ScriptLineNumber, $ProfileTimer.ElapsedMilliseconds)
# (& uvx --generate-shell-completion powershell) | Out-String | Invoke-Expression
# . "$HOME\.ps_cache\uvx-completion.ps1"
# Write-Host ("(' uvx  ',{1})," -f $MyInvocation.ScriptLineNumber, $ProfileTimer.ElapsedMilliseconds)
# fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression
# . "$HOME\.ps_cache\fnm-env.ps1"
# Write-Host ("(' fnm  ',{1})," -f $MyInvocation.ScriptLineNumber, $ProfileTimer.ElapsedMilliseconds)
# newSessionOhMyPosh



loadCachedSettingsFile -CachedFilePath "$cacheDir\scoop-search-hook.ps1" -RequiredCommand "scoop-search"
loadCachedSettingsFile -CachedFilePath "$cacheDir\uv-completion.ps1" -RequiredCommand "uv"
loadCachedSettingsFile -CachedFilePath "$cacheDir\uvx-completion.ps1" -RequiredCommand "uvx"
# loadCachedSettingsFile -CachedFilePath "$cacheDir\posh-init.ps1" -RequiredCommand "oh-my-posh"

# oh-my-posh init pwsh --config "$themeCache" | Invoke-Expression
