[CmdletBinding()]
param(
    [string]$WikiRemote = 'https://github.com/skeolan/Loner-Spacer.wiki.git',
    [string]$WikiPath = (Join-Path $env:TEMP 'Loner-Spacer-wiki-publish'),
    [switch]$Push,
    [switch]$SkipSourceCleanCheck
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$repositoryUrl = 'https://github.com/skeolan/Loner-Spacer'

function Invoke-Git {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,
        [string]$WorkingDirectory = $repoRoot
    )

    $output = & git -C $WorkingDirectory @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed:`n$($output -join "`n")"
    }
    if ($null -ne $output) {
        return $output
    }
}

function ConvertTo-UrlPath {
    param([Parameter(Mandatory)][string]$Path)

    return (($Path -replace '\\', '/') -split '/' | ForEach-Object {
        [Uri]::EscapeDataString($_)
    }) -join '/'
}

function ConvertTo-Anchor {
    param([string]$Heading)

    if ([string]::IsNullOrWhiteSpace($Heading)) {
        return ''
    }

    $anchor = $Heading.ToLowerInvariant()
    $anchor = [regex]::Replace($anchor, '[^\p{L}\p{Nd}\s_-]', '')
    $anchor = [regex]::Replace($anchor, '[\s_]+', '-')
    $anchor = [regex]::Replace($anchor, '-{2,}', '-')
    return $anchor.Trim('-')
}

function Get-FirstHeading {
    param([Parameter(Mandatory)][string]$Path)

    $heading = Get-Content -LiteralPath $Path | Where-Object { $_ -match '^#\s+(.+)$' } | Select-Object -First 1
    if ($null -eq $heading) {
        return [IO.Path]::GetFileNameWithoutExtension($Path)
    }
    return ([regex]::Match($heading, '^#\s+(.+)$')).Groups[1].Value.Trim()
}

function Get-WikiPageName {
    param([Parameter(Mandatory)][string]$SourceRelative)

    $normalized = $SourceRelative -replace '\\', '/'
    switch ($normalized) {
        'campaign/_player/character-Nova-Darkreach.md' { return 'Player-Nova-Darkreach' }
        'campaign/_player/ship-Horizon-Chaser.md' { return 'Player-Horizon-Chaser' }
        'campaign/lorebook/README.md' { return 'Lorebook' }
    }

    if ($normalized -match '^campaign/lorebook/(?<category>[^/]+)/README\.md$') {
        switch ($Matches.category) {
            'npcs' { return 'NPCs' }
            'factions' { return 'Factions' }
            'locations' { return 'Locations' }
            'threads' { return 'Threads' }
            'events' { return 'Events' }
            'setting' { return 'Setting' }
        }
    }

    if ($normalized -match '^campaign/lorebook/(?<category>[^/]+)/(?<file>[^/]+)\.md$') {
        $stem = $Matches.file
        switch ($Matches.category) {
            'npcs' { return "NPC-$stem" }
            'factions' { return "Faction-$stem" }
            'locations' { return "Location-$stem" }
            'threads' { return "Thread-$stem" }
            'events' { return "Event-$($stem -replace '\.', '-')" }
            'setting' { return "Setting-$stem" }
        }
    }

    throw "No wiki page naming rule exists for '$SourceRelative'."
}

function Get-AlertType {
    param([string]$Type)

    switch ($Type.ToUpperInvariant()) {
        { $_ -in @('TIP', 'HINT', 'CHECK', 'SUCCESS', 'DONE') } { return 'TIP' }
        { $_ -in @('IMPORTANT', 'QUESTION', 'TODO', 'HELP', 'FAQ') } { return 'IMPORTANT' }
        { $_ -in @('WARNING', 'CAUTION', 'ATTENTION') } { return 'WARNING' }
        { $_ -in @('DANGER', 'BUG', 'ERROR', 'FAILURE', 'FAIL', 'MISSING') } { return 'CAUTION' }
        default { return 'NOTE' }
    }
}

function Convert-PanelBody {
    param([string[]]$Lines)

    $result = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $Lines) {
        $value = $line.TrimEnd()
        if ($value -match '^\|?\s*\|\s*$' -or $value -match '^\|(?:\s*:?-{3,}:?\s*\|)+\s*$') {
            continue
        }
        if ($value -match '^\|\s*(.*?)\s*\|\s*$') {
            $cell = $Matches[1].Trim()
            if (-not [string]::IsNullOrWhiteSpace($cell)) {
                $result.Add("- $cell")
            }
            continue
        }
        $result.Add($value)
    }

    while ($result.Count -gt 0 -and [string]::IsNullOrWhiteSpace($result[0])) {
        $result.RemoveAt(0)
    }
    while ($result.Count -gt 0 -and [string]::IsNullOrWhiteSpace($result[$result.Count - 1])) {
        $result.RemoveAt($result.Count - 1)
    }
    return $result.ToArray()
}

function Convert-TrackBody {
    param([string[]]$Lines)

    $rows = [System.Collections.Generic.List[string]]::new()
    $currentTrack = ''
    foreach ($line in $Lines) {
        if ($line -match '^> \[![^\]]+\]\s*(?<title>.+)$') {
            $currentTrack = $Matches.title.Trim()
            continue
        }
        if (-not [string]::IsNullOrWhiteSpace($currentTrack) -and $line -match '^>\s*(?<state>[✅❌⬜🔀](?:\s+[✅❌⬜🔀])*)\s*$') {
            $rows.Add("| **$currentTrack** | $($Matches.state.Trim()) |")
            $currentTrack = ''
        }
    }

    return @('| **TRACK** | **STATE** |', '|:---|:---|') + $rows.ToArray()
}

function Add-Navigation {
    param(
        [Parameter(Mandatory)][string]$Markdown,
        [Parameter(Mandatory)][string]$SourceRelative,
        [Parameter(Mandatory)][string]$SourceRevision
    )

    $navigation = '[Home](Home) | [Nova Darkreach](Player-Nova-Darkreach) | [Horizon Chaser](Player-Horizon-Chaser) | [Lorebook](Lorebook)'
    $sourcePath = ConvertTo-UrlPath -Path $SourceRelative
    $provenance = "<sub>Published from [$SourceRelative]($repositoryUrl/blob/$SourceRevision/$sourcePath).</sub>"
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in ($Markdown -split "`r?`n")) {
        $lines.Add($line)
    }

    $headingIndex = -1
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -match '^#\s+') {
            $headingIndex = $index
            break
        }
    }
    if ($headingIndex -lt 0) {
        throw "Generated Markdown for '$SourceRelative' has no H1 heading."
    }

    $lines.Insert($headingIndex + 1, '')
    $lines.Insert($headingIndex + 2, $navigation)
    $lines.Insert($headingIndex + 3, '')
    $lines.Add('')
    $lines.Add('---')
    $lines.Add('')
    $lines.Add($provenance)
    return ($lines -join "`n").TrimEnd() + "`n"
}

function Convert-SheetMarkdown {
    param(
        [Parameter(Mandatory)][string]$Markdown
    )

    $sourceLines = $Markdown -split "`r?`n"
    $output = [System.Collections.Generic.List[string]]::new()
    $output.Add($sourceLines[0])
    $output.Add('')
    $index = 1

    while ($index -lt $sourceLines.Count) {
        $line = $sourceLines[$index]
        if ($line -match '^> \[!MULTI-COLUMN') {
            $index++
            continue
        }
        if ($line -eq '>') {
            $index++
            continue
        }

        $marker = [regex]::Match($line, '^> > \[!(?<type>[^|\]]+)(?:\|[^\]]*)?\]\s*(?<title>.*)$')
        $prefix = '> >'
        if (-not $marker.Success) {
            $marker = [regex]::Match($line, '^> \[!(?<type>[^|\]]+)(?:\|[^\]]*)?\]\s*(?<title>.*)$')
            $prefix = '>'
        }

        if ($marker.Success) {
            $type = $marker.Groups['type'].Value
            $title = $marker.Groups['title'].Value.Trim()
            $body = [System.Collections.Generic.List[string]]::new()
            $index++
            while ($index -lt $sourceLines.Count) {
                $candidate = $sourceLines[$index]
                if ($prefix -eq '> >' -and $candidate -match '^> > \[!') { break }
                if ($prefix -eq '>' -and $candidate -match '^> \[!') { break }
                if ($prefix -eq '> >') {
                    if ($candidate -eq '>') { break }
                    if ($candidate -notmatch '^> >') { break }
                    $body.Add(($candidate -replace '^> > ?', ''))
                }
                else {
                    if ($candidate -notmatch '^>') { break }
                    $body.Add(($candidate -replace '^> ?', ''))
                }
                $index++
            }

            if ($title -eq 'DOSSIER') {
                foreach ($bodyLine in $body) {
                    $output.Add($bodyLine)
                }
                $output.Add('')
            }
            elseif ($title -match 'PROFILE$') {
                $output.Add("## $title")
                $output.Add('')
                foreach ($bodyLine in $body) {
                    $output.Add($bodyLine)
                }
                $output.Add('')
            }
            elseif ($title -eq 'TRACKS') {
                $output.Add('## TRACKS')
                $output.Add('')
                foreach ($trackLine in (Convert-TrackBody -Lines $body.ToArray())) {
                    $output.Add($trackLine)
                }
                $output.Add('')
            }
            else {
                $alertType = Get-AlertType -Type $type
                $panelLines = @(Convert-PanelBody -Lines $body.ToArray())
                $output.Add("> [!$alertType]")
                if ($title -ne '>') {
                    $output.Add("> **$title**")
                }
                if ($panelLines.Count -gt 0) {
                    $output.Add('>')
                    foreach ($panelLine in $panelLines) {
                        $output.Add("> $panelLine")
                    }
                }
                $output.Add('')
            }
            continue
        }

        if (-not [string]::IsNullOrWhiteSpace($line)) {
            $output.Add($line)
        }
        $index++
    }

    return ($output -join "`n").TrimEnd() + "`n"
}

function Get-ResolvedSourceRelative {
    param(
        [Parameter(Mandatory)][string]$SourceRelative,
        [Parameter(Mandatory)][string]$TargetPath
    )

    $sourceAbsolute = Join-Path $repoRoot ($SourceRelative -replace '/', [IO.Path]::DirectorySeparatorChar)
    $sourceDirectory = Split-Path -Parent $sourceAbsolute
    $decodedTarget = [Uri]::UnescapeDataString($TargetPath) -replace '/', [IO.Path]::DirectorySeparatorChar
    $targetAbsolute = [IO.Path]::GetFullPath((Join-Path $sourceDirectory $decodedTarget))
    return [IO.Path]::GetRelativePath($repoRoot, $targetAbsolute) -replace '\\', '/'
}

function Convert-Links {
    param(
        [Parameter(Mandatory)][string]$Markdown,
        [Parameter(Mandatory)][string]$SourceRelative,
        [Parameter(Mandatory)][hashtable]$PageMap,
        [Parameter(Mandatory)][string]$SourceRevision,
        [Parameter(Mandatory)][string]$SrdRevision
    )

    $srdResources = @{
        'the_shattered_reach' = @{ Path = 'content/geared_towards_loner/the_shattered_reach.md'; Title = 'The Shattered Reach' }
        'spacer' = @{ Path = 'content/geared_towards_loner/spacer.md'; Title = 'Loner: Spacer' }
        'galaxy_drifter' = @{ Path = 'content/geared_towards_loner/galaxy_drifter.md'; Title = 'Loner: Galaxy Drifter' }
        'loner-3e' = @{ Path = 'content/core/loner-3e.md'; Title = 'Loner Core Rules' }
    }

    $wikilinkPattern = '\[\[(?<target>[^\]|#]+)(?:#(?<fragment>[^\]|]+))?(?:\|(?<label>[^\]]+))?\]\]'
    $Markdown = [regex]::Replace($Markdown, $wikilinkPattern, {
        param($match)

        $identifier = $match.Groups['target'].Value.Trim().ToLowerInvariant()
        $fragment = $match.Groups['fragment'].Value.Trim()
        $label = $match.Groups['label'].Value.Trim()
        if ($srdResources.ContainsKey($identifier)) {
            $resource = $srdResources[$identifier]
            if ([string]::IsNullOrWhiteSpace($label)) { $label = $resource.Title }
            $url = "https://github.com/zotiquestgames/lonersrd/blob/$SrdRevision/$(ConvertTo-UrlPath $resource.Path)"
            if (-not [string]::IsNullOrWhiteSpace($fragment)) {
                $url += "#$(ConvertTo-Anchor $fragment)"
            }
            return "[$label]($url)"
        }

        throw "Unresolved Foam wikilink '$($match.Value)' in '$SourceRelative'."
    })

    $markdownLinkPattern = '(?<!!)\[(?<label>[^\]]+)\]\((?<target>[^)]+)\)'
    $Markdown = [regex]::Replace($Markdown, $markdownLinkPattern, {
        param($match)

        $label = $match.Groups['label'].Value
        $target = $match.Groups['target'].Value.Trim()
        if ($target -match '^(?:https?://|mailto:|#)') {
            return $match.Value
        }

        $fragment = ''
        $targetPath = $target
        $hashIndex = $target.IndexOf('#')
        if ($hashIndex -ge 0) {
            $targetPath = $target.Substring(0, $hashIndex)
            $fragment = $target.Substring($hashIndex + 1)
        }

        $resolved = Get-ResolvedSourceRelative -SourceRelative $SourceRelative -TargetPath $targetPath
        if ($PageMap.ContainsKey($resolved)) {
            $wikiTarget = $PageMap[$resolved]
            if (-not [string]::IsNullOrWhiteSpace($fragment)) {
                $wikiTarget += "#$fragment"
            }
            return "[$label]($wikiTarget)"
        }

        if ($resolved.StartsWith('reference/lonersrd/', [StringComparison]::OrdinalIgnoreCase)) {
            $srdPath = $resolved.Substring('reference/lonersrd/'.Length)
            $url = "https://github.com/zotiquestgames/lonersrd/blob/$SrdRevision/$(ConvertTo-UrlPath $srdPath)"
        }
        else {
            $url = "$repositoryUrl/blob/$SourceRevision/$(ConvertTo-UrlPath $resolved)"
        }
        if (-not [string]::IsNullOrWhiteSpace($fragment)) {
            $url += "#$fragment"
        }
        return "[$label]($url)"
    })

    $Markdown = $Markdown -replace '(?m)^> \[!NOTE\]-\s*OOC\s*$', "> [!NOTE]`n> **OOC**"
    return $Markdown
}

function Test-GeneratedWiki {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string[]]$PageNames
    )

    $pageSet = @{}
    foreach ($pageName in $PageNames) { $pageSet[$pageName] = $true }
    $failures = [System.Collections.Generic.List[string]]::new()

    foreach ($file in Get-ChildItem -LiteralPath $Path -Filter '*.md' -File) {
        $content = Get-Content -Raw -LiteralPath $file.FullName
        if ($content -match '\[\[') {
            $failures.Add("$($file.Name): unresolved Foam wikilink remains")
        }
        if ($content -match '\[!MULTI-COLUMN') {
            $failures.Add("$($file.Name): unsupported multi-column callout remains")
        }

        foreach ($match in [regex]::Matches($content, '(?<!!)\[[^\]]+\]\((?<target>[^)]+)\)')) {
            $target = $match.Groups['target'].Value.Trim()
            if ($target -match '^(?:https?://|mailto:|#)') { continue }
            $pageTarget = ($target -split '#', 2)[0]
            if (-not $pageSet.ContainsKey($pageTarget)) {
                $failures.Add("$($file.Name): unresolved wiki page '$pageTarget'")
            }
        }
    }

    if ($failures.Count -gt 0) {
        throw "Generated wiki validation failed:`n$($failures -join "`n")"
    }
}

Push-Location $repoRoot
try {
    & (Join-Path $PSScriptRoot 'Test-Campaign.ps1') | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Campaign validation failed.' }

    if (-not $SkipSourceCleanCheck) {
        $sourceStatus = Invoke-Git -Arguments @('status', '--porcelain')
        if ($sourceStatus) {
            throw 'The source repository has uncommitted changes. Commit or stash them before publishing, or use -SkipSourceCleanCheck for a local preview.'
        }
    }

    $sourceRevision = ([string](Invoke-Git -Arguments @('rev-parse', 'HEAD'))).Trim()
    $sourceShortRevision = ([string](Invoke-Git -Arguments @('rev-parse', '--short', 'HEAD'))).Trim()
    $srdRevision = ([string](Invoke-Git -Arguments @('rev-parse', 'HEAD:reference/lonersrd'))).Trim()

    $sourceItems = [System.Collections.Generic.List[object]]::new()
    $sourceItems.Add([pscustomobject]@{ Relative = 'campaign/_player/character-Nova-Darkreach.md'; Kind = 'sheet' })
    $sourceItems.Add([pscustomobject]@{ Relative = 'campaign/_player/ship-Horizon-Chaser.md'; Kind = 'sheet' })
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $repoRoot 'campaign/lorebook') -Filter '*.md' -File -Recurse | Sort-Object FullName) {
        $relative = [IO.Path]::GetRelativePath($repoRoot, $file.FullName) -replace '\\', '/'
        $sourceItems.Add([pscustomobject]@{ Relative = $relative; Kind = 'note' })
    }

    $pageMap = @{}
    $pageNames = [System.Collections.Generic.List[string]]::new()
    foreach ($item in $sourceItems) {
        $pageName = Get-WikiPageName -SourceRelative $item.Relative
        if ($pageNames.Contains($pageName)) {
            throw "Duplicate generated wiki page name '$pageName'."
       }
        $pageMap[$item.Relative] = $pageName
        $pageNames.Add($pageName)
    }
    foreach ($specialPage in @('Home', 'Player', '_Sidebar', '_Footer')) {
        $pageNames.Add($specialPage)
    }

    if (-not (Test-Path -LiteralPath (Join-Path $WikiPath '.git'))) {
        if (Test-Path -LiteralPath $WikiPath) {
            Remove-Item -LiteralPath $WikiPath -Recurse -Force
        }
        & git clone $WikiRemote $WikiPath
        if ($LASTEXITCODE -ne 0) { throw 'Could not clone the wiki repository.' }
    }
    else {
        $wikiStatus = Invoke-Git -WorkingDirectory $WikiPath -Arguments @('status', '--porcelain')
        if ($wikiStatus) { throw "Wiki working tree '$WikiPath' is not clean." }
        Invoke-Git -WorkingDirectory $WikiPath -Arguments @('pull', '--ff-only', 'origin', 'master') | Out-Null
    }

    Get-ChildItem -LiteralPath $WikiPath -Force | Where-Object { $_.Name -ne '.git' } | Remove-Item -Recurse -Force

    $homeMarkdown = @"
# Loner: Spacer Campaign

[Home](Home) | [Nova Darkreach](Player-Nova-Darkreach) | [Horizon Chaser](Player-Horizon-Chaser) | [Lorebook](Lorebook)

This wiki is a published reading view of the local *Loner: Spacer* campaign starring Nova Darkreach and the *Horizon Chaser* in the Quaternary Sector of *The Shattered Reach*.

## Player

- [Nova Darkreach](Player-Nova-Darkreach) -- risk-taking courier.
- [Horizon Chaser](Player-Horizon-Chaser) -- reliable courier spacecraft.

## Lorebook

- [NPCs](NPCs)
- [Setting](Setting)
- [Factions](Factions)
- [Locations](Locations)
- [Threads](Threads)
- [Events](Events)

## Source

The [main repository]($repositoryUrl) remains authoritative. This wiki is generated from [source revision ``$sourceShortRevision``]($repositoryUrl/commit/$sourceRevision).
"@
    Set-Content -LiteralPath (Join-Path $WikiPath 'Home.md') -Value $homeMarkdown -Encoding utf8

    $player = @"
# Player

[Home](Home) | [Nova Darkreach](Player-Nova-Darkreach) | [Horizon Chaser](Player-Horizon-Chaser) | [Lorebook](Lorebook)

- [Nova Darkreach](Player-Nova-Darkreach) -- current protagonist state.
- [Horizon Chaser](Player-Horizon-Chaser) -- current spacecraft state.
"@
    Set-Content -LiteralPath (Join-Path $WikiPath 'Player.md') -Value $player -Encoding utf8

    foreach ($item in $sourceItems) {
        $sourcePath = Join-Path $repoRoot ($item.Relative -replace '/', [IO.Path]::DirectorySeparatorChar)
        $markdown = Get-Content -Raw -LiteralPath $sourcePath
        if ($item.Kind -eq 'sheet') {
            $markdown = Convert-SheetMarkdown -Markdown $markdown
        }
        $markdown = Convert-Links -Markdown $markdown -SourceRelative $item.Relative -PageMap $pageMap -SourceRevision $sourceRevision -SrdRevision $srdRevision
        $markdown = Add-Navigation -Markdown $markdown -SourceRelative $item.Relative -SourceRevision $sourceRevision
        $destination = Join-Path $WikiPath "$($pageMap[$item.Relative]).md"
        Set-Content -LiteralPath $destination -Value $markdown -Encoding utf8
    }

    $sidebar = @"
## Campaign

- [Home](Home)
- [Player](Player)
  - [Nova Darkreach](Player-Nova-Darkreach)
  - [Horizon Chaser](Player-Horizon-Chaser)

## Lorebook

- [Lorebook Home](Lorebook)
    - [NPCs](NPCs)
    - [Setting](Setting)
    - [Factions](Factions)
    - [Locations](Locations)
    - [Threads](Threads)
    - [Events](Events)

## Elsewhere

- [Source Repository]($repositoryUrl)
"@
    Set-Content -LiteralPath (Join-Path $WikiPath '_Sidebar.md') -Value $sidebar -Encoding utf8

    $footer = "[Home](Home) | [Nova Darkreach](Player-Nova-Darkreach) | [Horizon Chaser](Player-Horizon-Chaser) | [Lorebook](Lorebook) | [Repository]($repositoryUrl) | [Source ``$sourceShortRevision``]($repositoryUrl/commit/$sourceRevision)"
    Set-Content -LiteralPath (Join-Path $WikiPath '_Footer.md') -Value $footer -Encoding utf8

    Test-GeneratedWiki -Path $WikiPath -PageNames $pageNames.ToArray()

    $gitName = ([string](Invoke-Git -Arguments @('config', 'user.name'))).Trim()
    $gitEmail = ([string](Invoke-Git -Arguments @('config', 'user.email'))).Trim()
    Invoke-Git -WorkingDirectory $WikiPath -Arguments @('config', 'user.name', $gitName) | Out-Null
    Invoke-Git -WorkingDirectory $WikiPath -Arguments @('config', 'user.email', $gitEmail) | Out-Null
    Invoke-Git -WorkingDirectory $WikiPath -Arguments @('add', '--all') | Out-Null

    & git -C $WikiPath diff --cached --quiet
    $hasChanges = $LASTEXITCODE -ne 0
    if ($hasChanges) {
        Invoke-Git -WorkingDirectory $WikiPath -Arguments @('commit', '-m', "Publish campaign wiki from $sourceShortRevision") | Out-Null
    }

    if ($Push) {
        Invoke-Git -WorkingDirectory $WikiPath -Arguments @('push', 'origin', 'master') | Out-Null
    }

    $summary = [ordered]@{
        ok = $true
        source_revision = $sourceRevision
        srd_revision = $srdRevision
        wiki_path = $WikiPath
        page_count = (Get-ChildItem -LiteralPath $WikiPath -Filter '*.md' -File).Count
        committed = $hasChanges
        pushed = [bool]$Push
    }
    $summary | ConvertTo-Json
}
finally {
    Pop-Location
}
