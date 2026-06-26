# =============================================================================
# PowerShell Profile
# =============================================================================

# --- Environment & Variables ---
$cacheDir = "$HOME\.ps_cache"

# Initialize FNM (Fast Node Manager) safely
if (Get-Command fnm -ErrorAction SilentlyContinue) {
    fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression
}

# --- PSReadLine Configuration ---
$PSReadLineOptions = @{
    EditMode                      = 'Windows'
    HistoryNoDuplicates           = $true
    HistorySearchCursorMovesToEnd = $true
    BellStyle                     = 'None'
    Colors                        = @{
        Command   = '#87CEEB'
        Parameter = '#98FB98'
        Operator  = '#FFB6C1'
        Variable  = '#DDA0DD'
        String    = '#FFDAB9'
        Number    = '#B0E0E6'
        Type      = '#F0E68C'
        Comment   = '#D3D3D3'
        Keyword   = '#8367c7'
        Error     = '#FF6347'
    }
}
Set-PSReadLineOption @PSReadLineOptions

# Custom Key Handlers
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

# Prevent sensitive data from entering history
Set-PSReadLineOption -AddToHistoryHandler {
    param($line)
    $sensitive = @('password', 'secret', 'token', 'apikey', 'connectionstring')
    $hasSensitive = $sensitive | Where-Object { $line -match $_ }
    return ($null -eq $hasSensitive)
}

# Version-Safe Prediction Settings
$psrl = Get-Module -Name PSReadLine -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
if ($psrl.Version -ge [version]'2.2.2') {
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -MaximumHistoryCount 10000
}

# Using eza instead of ls
if (Get-Command eza -ErrorAction SilentlyContinue) {
    function ls { eza --icons=always $args } # Bypasses built-in alias locks
    function ll { eza -l --icons=always --group-directories-first $args }
    function la { eza -la --icons=always --group-directories-first $args }
    function tree { eza --tree --icons=always $args }
}


# --- PSFzf Configuration ---
if (Get-Module -ListAvailable -Name PSFzf) {
    Import-Module PSFzf

    # Bind standard fzf shortcuts
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'

    # Optional: If you want to use Alt+c to quickly find and cd into a directory
    Set-PsFzfOption -PSReadlineChordProviderDirectory 'Alt+c'
}

# --- Custom Functions ---

function psRestart {
    param ([switch]$Admin)
    $arguments = "-NoExit -Command Set-Location '$PWD'"
    if ($Admin) {
        Start-Process pwsh -ArgumentList $arguments -Verb RunAs
    } else {
        Start-Process pwsh -ArgumentList $arguments
    }
    exit
}

function g {
    param (
        [Parameter(HelpMessage = "Add changes to the staging area.")][switch]$Add,
        [Parameter(HelpMessage = "Commit changes to the repository.")][switch]$AddCommit,
        [Parameter(HelpMessage = "Commit and push changes to the repository.")][switch]$AddCommitPush,
        [Parameter(HelpMessage = "Show the status of the repository.")][switch]$Status,
        [string]$msg
    )
    if ($Add) {
        git add .
        return
    }
    if ($AddCommit) {
        g -Add
        git commit -m "$msg"
        return
    }
    if ($AddCommitPush) {
        g -AddCommit "$msg"
        git push
        return
    }
    git status
}

function y {
    $tmp = (New-TemporaryFile).FullName
    yazi $args --cwd-file="$tmp"
    $cwd = Get-Content -Path $tmp -Encoding UTF8
    if (-not [String]::IsNullOrEmpty($cwd) -and $cwd -ne $PWD.Path) {
        Set-Location -LiteralPath (Resolve-Path -LiteralPath $cwd).Path
    }
    Remove-Item -Path $tmp
}

function findES {
    param (
        [Parameter(HelpMessage = "search in this location only")][switch]$Here,
        [switch]$Global,
        [string]$Query
    )
    if ($Here) {
        & es.exe -path "." $Query
        return
    }
    es.exe $Query
}

# This is a classic terminal addition. It creates a new directory and immediately moves you into it, saving you an extra cd command.
function mkcd {
    param([Parameter(Mandatory=$true)][string]$Path)
    New-Item -Path $Path -ItemType Directory -Force | Out-Null
    Set-Location $Path
}

# Reload the profile instantly in the current session
function reloadPS {
    . $PROFILE
    Write-Host "Profile reloaded!" -ForegroundColor Green
}

# --- Ultra-Fast Tool Caching ---

# Function to manually force a cache rebuild when you update your tools
function Update-TerminalCache {
    Write-Host "Rebuilding terminal cache (this takes a second)..." -ForegroundColor Cyan

    if (-not (Test-Path $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null }

    # 1. uv and uvx completions
    if (Get-Command uv -ErrorAction SilentlyContinue) {
        uv generate-shell-completion powershell > "$cacheDir\uv.ps1"
        uvx --generate-shell-completion powershell > "$cacheDir\uvx.ps1"
    }

    # 2. scoop-search hook
    if (Get-Command scoop-search -ErrorAction SilentlyContinue) {
        scoop-search --hook > "$cacheDir\scoop-search.ps1"
    }

    # 3. Oh My Posh init (Replace the config path with your custom theme if needed)
    if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
        oh-my-posh init pwsh --config "$HOME\Documents\ahah43-blue-owl.omp.json" > "$cacheDir\omp.ps1"
    }

    # 4. GitHub CLI completions
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        gh completion -s powershell > "$cacheDir\gh.ps1"
    }
    
    # 5. Zoxide (The missing piece!)
    if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    #        zoxide init powershell > "$cacheDir\zoxide.ps1"
        zoxide init powershell | Out-File -FilePath "$cacheDir\zoxide.ps1" -Encoding utf8
    }

    Write-Host "Cache generated! Run 'reloadPS' to apply." -ForegroundColor Green
}

# Auto-run the cache builder if it's your first time or files are missing
if (-not (Test-Path "$cacheDir\uv.ps1")) {
    Update-TerminalCache
}

# --- Load Cached Files Instantly ---
if (Test-Path "$cacheDir\uv.ps1") { . "$cacheDir\uv.ps1" }
if (Test-Path "$cacheDir\uvx.ps1") { . "$cacheDir\uvx.ps1" }
if (Test-Path "$cacheDir\scoop-search.ps1") { . "$cacheDir\scoop-search.ps1" }
if (Test-Path "$cacheDir\omp.ps1") { . "$cacheDir\omp.ps1" }
if (Test-Path "$cacheDir\gh.ps1") { . "$cacheDir\gh.ps1" }

# if (Test-Path "$cacheDir\zoxide.ps1") { . "$cacheDir\zoxide.ps1" }
if (Test-Path "$cacheDir\zoxide.ps1") { Invoke-Expression (Get-Content "$cacheDir\zoxide.ps1" -Raw) }
