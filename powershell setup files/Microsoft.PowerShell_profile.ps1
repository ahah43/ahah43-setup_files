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