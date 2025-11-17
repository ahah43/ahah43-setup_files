function dir-tree {
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
    function _tree_helper {

        param(
            [string]$literalPath,
            [string]$prefix
        )

        # Get all subdirs. and, if requested, also files.
        $items = Get-ChildItem -Directory:(-not $IncludeFiles) -LiteralPath $LiteralPath -Force:$Force

        # Apply exclusion filter(s), if specified.
        if ($Exclude -and $items) {
            $items = $items.Where({ $name = $_.Name; -not $Exclude.Where({ $name -like $_ },'First') })
        }

        if (-not $items) { return } # no subdirs. / files, we're done

        $i = 0
        foreach ($item in $items) {
            $isLastSibling =++ $i -eq $items.Count
            # Print this dir.
            $prefix + $(if ($isLastSibling) { $chars.last } else { $chars.interior }) + $chars.hline * ($indentCount - 1) + $item.Name
            # Recurse, if it's a subdir (rather than a file).
            if ($item.PSIsContainer) {
                if ($item.LinkType) { Write-Warning "Not following dir. symlink: $item"; continue }
                $subPrefix = $prefix + $(if ($isLastSibling) { $chars.space * $indentCount } else { $chars.vline + $chars.space * ($indentCount - 1) })
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
    if (-not $literalPath -or -not (Test-Path -PathType Container -LiteralPath $literalPath) -or $literalPath.Count -gt 1) { throw "$Path must resolve to a single, existing directory." }

    # Print the target path.
    $literalPath

    # Invoke the helper function to draw the tree.
    _tree_helper $literalPath

}



function linux {
    param (
        [Parameter(HelpMessage = "Restart the 'Ubuntu' distribution before starting.")]
        [switch]$Restart,

        [Parameter(HelpMessage = "Terminate the 'Ubuntu' distribution and exit.")]
        [switch]$Kill
    )

    $distroName = "Ubuntu"

    if ($Kill) {
        Write-Host "Terminating $distroName..."
        wsl --terminate $distroName
        wsl --shutdown
        return # Stop execution here
    }

    if ($Restart) {
        Write-Host "Restarting $distroName..."
        wsl --terminate $distroName
    }

    # This part now runs for `linux` (by itself) and `linux -Restart`
    Write-Host "Starting $distroName..."
    wsl -d $distroName
}


function ps-restart {
    param (
        # If this switch is included, the new session will be as admin
        [switch]$Admin
    )
    if ($Admin) {
        # Run this if 'ps-restart -Admin' is typed
        Start-Process -FilePath "pwsh.exe" -ArgumentList "-NoExit" -Verb RunAs
    } else {
        # Run this if just 'ps-restart' is typed
        Start-Process -FilePath "pwsh.exe" -ArgumentList "-NoExit"
    }

    exit
}

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
    PredictionSource = 'History'
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


###################################################
###################################################
# # type ./, you’ll see a dropdown list of paths, just like the history list.
# if (Get-Module -ListAvailable -Name CompletionPredictor) {
#     Import-Module CompletionPredictor
# }
#


# git commands
function git-add {
    git add .
}
function git-add-commit {
    git-add
    git commit -m "$args"
}
function git-add-commit-push {
    git-add-commit "$args"
    git push
}
function gs { git status }
###################################################
###################################################
function y {
    $tmp = [System.IO.Path]::GetTempFileName()
    yazi $args --cwd-file = "$tmp"
    $cwd = Get-Content -Path $tmp -Encoding UTF8
    if (-not [String]::IsNullOrEmpty($cwd) -and $cwd -ne $PWD.Path) {
        Set-Location -LiteralPath ([System.IO.Path]::GetFullPath($cwd))
    }
    Remove-Item -Path $tmp
}


function es_ {
    param (
        [string]$Query
    )
    # Make sure 'es.exe' is in your system's PATH
    # The '-p' flag tells Everything to match full paths
    # The '-r' flag tells Everything to search for subfolders and files in the specified path
    & es.exe -path "." $Query
}

# # colored path, user, etc.
#oh-my-posh init pwsh | Invoke-Expression

# # oh my posh theme (disabled to use custom prompt with RAM usage)
oh-my-posh init pwsh --config "C:\Users\AHAH43\Documents\ahah43-blue-owl.omp.json" | Invoke-Expression
#oh-my-posh init pwsh --config "C:\Users\AHAH43\AppData\Local\Programs\oh-my-posh\themes\clean-detailed.omp.json" | Invoke-Expression

# # Starship theme
##$ENV:STARSHIP_CONFIG = "C:\Users\AHAH43\Documents\starship.toml"
##Invoke-Expression (&starship init powershell)

# # Terminal-Icons is slowwwwwwwwwww
#Import-Module -Name Terminal-Icons


#Invoke-Expression (&scoop-search --hook)
. ([ScriptBlock]::Create((& scoop-search --hook | Out-String)))

#Invoke-Expression (& { (zoxide init powershell | Out-String) })
