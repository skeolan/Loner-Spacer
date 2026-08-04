[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repositoryRoot

$failures = [System.Collections.Generic.List[string]]::new()
$allowedEventCodes = @('COMM', 'JRNL', 'SYSL', 'NEWS', 'DATA')
$expectedEventHeaders = @(
    'Event-ID',
    'Event-Date',
    'Location',
    'Record-Type',
    'Record-Origin',
    'From',
    'To',
    'Channel',
    'Subject'
)

function Add-Failure {
    param([Parameter(Mandatory)][string]$Message)
    $failures.Add($Message)
}

try {
    $eventDirectory = '.\campaign\lorebook\events'
    $eventFiles = @(
        Get-ChildItem -LiteralPath $eventDirectory -File -Filter '*.md' |
            Where-Object Name -ne 'README.md' |
            Sort-Object Name
    )

    $eventIds = [System.Collections.Generic.List[string]]::new()
    $eventsByDate = @{}

    foreach ($file in $eventFiles) {
        if ($file.Name -notmatch '^(?<id>\d{4}\.\d{2}\.\d{2}\.\d{3})-(?<code>[A-Z]{4})-(?<description>[A-Za-z0-9-]+)\.md$') {
            Add-Failure "Event filename has invalid format: $($file.Name)"
            continue
        }

        $filenameId = $Matches.id
        $eventCode = $Matches.code
        $eventDate = $filenameId.Substring(0, 10)
        $eventSequence = [int]$filenameId.Substring(11, 3)

        if ($eventCode -notin $allowedEventCodes) {
            Add-Failure "Event filename uses unsupported code '$eventCode': $($file.Name)"
        }

        if (-not $eventsByDate.ContainsKey($eventDate)) {
            $eventsByDate[$eventDate] = [System.Collections.Generic.List[int]]::new()
        }
        $eventsByDate[$eventDate].Add($eventSequence)

        $lines = Get-Content -LiteralPath $file.FullName
        $secondFence = [array]::IndexOf($lines, '---', 1)
        if ($lines.Count -eq 0 -or $lines[0] -ne '---' -or $secondFence -lt 1) {
            Add-Failure "Event is missing YAML frontmatter: $($file.Name)"
            continue
        }

        $frontmatter = @($lines[1..($secondFence - 1)])
        $headerKeys = @(
            $frontmatter | ForEach-Object {
                if ($_ -match '^([^:]+):') {
                    $Matches[1]
                }
            }
        )

        if (($headerKeys -join '|') -cne ($expectedEventHeaders -join '|')) {
            Add-Failure "Event header schema or order is invalid: $($file.Name)"
        }

        $eventId = (($frontmatter | Where-Object { $_ -cmatch '^Event-ID: ' }) -replace '^Event-ID: ', '')
        if ($eventId -cne $filenameId) {
            Add-Failure "Event-ID does not match filename: $($file.Name)"
        }
        $eventIds.Add($eventId)

        if (-not ($frontmatter | Where-Object { $_ -cmatch '^Event-Date: \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} CE$' })) {
            Add-Failure "Event-Date has invalid format: $($file.Name)"
        }

        if (-not ($lines | Where-Object { $_ -ceq '> [!NOTE]- OOC' })) {
            Add-Failure "Event is missing collapsed OOC provenance: $($file.Name)"
        }
    }

    foreach ($duplicate in $eventIds | Group-Object | Where-Object Count -gt 1) {
        Add-Failure "Duplicate Event-ID: $($duplicate.Name)"
    }

    foreach ($entry in $eventsByDate.GetEnumerator()) {
        $sequences = @($entry.Value | Sort-Object)
        for ($index = 0; $index -lt $sequences.Count; $index++) {
            if ($sequences[$index] -ne ($index + 1)) {
                Add-Failure "Event sequence gap on $($entry.Key): expected $($index + 1), found $($sequences[$index])"
            }
        }
    }

    $managedDirectories = @(
        (Get-Item '.\campaign'),
        (Get-Item '.\reference'),
        (Get-Item '.\scripts')
    ) + @(
        Get-ChildItem '.\campaign', '.\reference' -Directory -Recurse |
            Where-Object { $_.FullName -notlike '*\reference\lonersrd*' }
    )

    foreach ($directory in $managedDirectories) {
        if (-not (Test-Path -LiteralPath (Join-Path $directory.FullName 'README.md'))) {
            Add-Failure "Managed directory is missing README.md: $($directory.FullName)"
        }
    }

    $markdownFiles = @(
        (Get-Item '.\README.md'),
        (Get-Item '.\.instructions.md')
    ) + @(
        Get-ChildItem '.\campaign', '.\reference', '.\scripts' -Filter '*.md' -File -Recurse |
            Where-Object { $_.FullName -notlike '*\reference\lonersrd\*' }
    )

    foreach ($file in $markdownFiles) {
        $text = Get-Content -LiteralPath $file.FullName -Raw
        foreach ($match in [regex]::Matches($text, '\]\(([^)]+)\)')) {
            $target = $match.Groups[1].Value -replace '#.*$', ''
            if (-not $target -or $target -match '^[a-z]+:') {
                continue
            }

            $decodedTarget = [uri]::UnescapeDataString($target)
            $resolvedTarget = Join-Path $file.DirectoryName $decodedTarget
            if (-not (Test-Path -LiteralPath $resolvedTarget)) {
                Add-Failure "Broken Markdown link in $($file.FullName): $target"
            }
        }
    }

    $notebooks = @(Get-ChildItem '.\campaign\chapters' -File -Filter '*.ipynb')
    foreach ($notebookFile in $notebooks) {
        try {
            $rawNotebook = Get-Content -LiteralPath $notebookFile.FullName -Raw
            $notebook = $rawNotebook | ConvertFrom-Json
            if ($notebook.nbformat -ne 4) {
                Add-Failure "Notebook has unsupported nbformat: $($notebookFile.Name)"
            }
            foreach ($cell in @($notebook.cells)) {
                if (-not $cell.cell_type -or $null -eq $cell.source) {
                    Add-Failure "Notebook cell is missing required fields: $($notebookFile.Name)"
                }
                # Experimental: standard notebook editing does not persist metadata.language.
                # if (-not $cell.metadata.language) {
                #     Add-Failure "Notebook cell is missing metadata.language: $($notebookFile.Name)"
                # }
                # Experimental: nbformat 4.5 stores IDs at cell.id, not metadata.id.
                # if (-not $cell.id -and -not $cell.metadata.id) {
                #     Add-Failure "Existing notebook cell is missing an ID: $($notebookFile.Name)"
                # }
            }
        }
        catch {
            Add-Failure "Notebook JSON is invalid: $($notebookFile.Name): $($_.Exception.Message)"
        }
    }

    foreach ($requiredScript in @(
        '.\scripts\Get-WorkspaceConfiguration.ps1',
        '.\scripts\New-NpcName.ps1',
        '.\scripts\Normalize-Notebook.ps1',
        '.\scripts\Publish-Wiki.ps1',
        '.\scripts\Roll-Dice.ps1',
        '.\scripts\Test-Campaign.ps1'
    )) {
        if (-not (Test-Path -LiteralPath $requiredScript)) {
            Add-Failure "Required script is missing: $requiredScript"
            continue
        }

        $tokens = $null
        $parseErrors = $null
        [System.Management.Automation.Language.Parser]::ParseFile(
            (Resolve-Path $requiredScript),
            [ref]$tokens,
            [ref]$parseErrors
        ) | Out-Null
        foreach ($parseError in @($parseErrors)) {
            Add-Failure "PowerShell syntax error in $requiredScript`: $($parseError.Message)"
        }
    }

    $stalePatterns = @(
        'Planetary Coalition',
        'planetary-coalition',
        'GSUN:',
        'Galactic Standard Universal',
        'Galactic Chronometry Authority'
    )
    $campaignFiles = @(Get-ChildItem '.\campaign' -File -Recurse)
    foreach ($pattern in $stalePatterns) {
        $staleTermMatches = @(
            $campaignFiles |
                Where-Object { $_.Name -ne 'setting-adoption.md' } |
                Select-String -Pattern $pattern -SimpleMatch
        )
        foreach ($match in $staleTermMatches) {
            Add-Failure "Stale campaign term '$pattern': $($match.Path):$($match.LineNumber)"
        }
    }

    if (Test-Path -LiteralPath '.\.venv\Scripts\python.exe') {
        & '.\.venv\Scripts\python.exe' -m pip check
        if ($LASTEXITCODE -ne 0) {
            Add-Failure 'Python dependency check failed.'
        }
    }
    else {
        Add-Failure 'Workspace Python environment is missing.'
    }

    $submoduleStatus = @(& git submodule status)
    if ($LASTEXITCODE -ne 0) {
        Add-Failure 'git submodule status failed.'
    }
    foreach ($line in $submoduleStatus) {
        if ($line -match '^[-+]') {
            Add-Failure "Submodule is uninitialized or at the wrong commit: $line"
        }
    }

    $submoduleChanges = @(& git -C reference/lonersrd status --short)
    if ($LASTEXITCODE -ne 0) {
        Add-Failure 'Submodule worktree status failed.'
    }
    if ($submoduleChanges.Count -gt 0) {
        Add-Failure 'The reference/lonersrd submodule worktree is dirty.'
    }

    & git diff --check
    if ($LASTEXITCODE -ne 0) {
        Add-Failure 'Unstaged whitespace check failed.'
    }

    & git diff --cached --check
    if ($LASTEXITCODE -ne 0) {
        Add-Failure 'Staged whitespace check failed.'
    }

    $summary = [ordered]@{
        ok = ($failures.Count -eq 0)
        event_files = $eventFiles.Count
        markdown_files = $markdownFiles.Count
        notebooks = $notebooks.Count
        managed_directories = $managedDirectories.Count
        failures = @($failures)
    }

    $summary | ConvertTo-Json -Depth 4
    if ($failures.Count -gt 0) {
        exit 1
    }
}
finally {
    Pop-Location
}