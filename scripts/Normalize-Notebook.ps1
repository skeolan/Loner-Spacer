[CmdletBinding()]
param(
    [string[]]$Path = @('.\campaign\chapters\*.ipynb')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$resolvedFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()

Push-Location $repositoryRoot
try {
    foreach ($pathPattern in $Path) {
        foreach ($file in @(Get-ChildItem -Path $pathPattern -File)) {
            if ($file.Extension -cne '.ipynb') {
                throw "Notebook path must end in .ipynb: $($file.FullName)"
            }
            if (-not ($resolvedFiles | Where-Object FullName -CEQ $file.FullName)) {
                $resolvedFiles.Add($file)
            }
        }
    }

    if ($resolvedFiles.Count -eq 0) {
        throw "No notebooks matched: $($Path -join ', ')"
    }

    $results = [System.Collections.Generic.List[object]]::new()
    foreach ($file in $resolvedFiles) {
        $original = Get-Content -LiteralPath $file.FullName -Raw
        $notebook = $original | ConvertFrom-Json
        $defaultCodeLanguage = ''
        if ($notebook.metadata.PSObject.Properties['language_info']) {
            $defaultCodeLanguage = [string]$notebook.metadata.language_info.name
        }

        foreach ($cell in @($notebook.cells)) {
            if (-not $cell.metadata.PSObject.Properties['language']) {
                $language = switch ([string]$cell.cell_type) {
                    'markdown' { 'markdown' }
                    'raw' { 'raw' }
                    'code' {
                        if (-not $defaultCodeLanguage) {
                            throw "Code cell has no notebook language_info.name: $($file.Name)"
                        }
                        $defaultCodeLanguage
                    }
                    default { throw "Unsupported cell type '$($cell.cell_type)': $($file.Name)" }
                }
                $cell.metadata | Add-Member -NotePropertyName language -NotePropertyValue $language
            }

            if (-not $cell.metadata.PSObject.Properties['id']) {
                if (-not $cell.PSObject.Properties['id']) {
                    throw "Cell has no stable ID to copy into metadata.id: $($file.Name)"
                }
                $cell.metadata | Add-Member -NotePropertyName id -NotePropertyValue ([string]$cell.id)
            }
        }

        $normalized = ($notebook | ConvertTo-Json -Depth 100) -replace "`r`n", "`n"
        $normalized += "`n"
        $changed = $original -cne $normalized
        if ($changed) {
            [IO.File]::WriteAllText($file.FullName, $normalized, [Text.UTF8Encoding]::new($false))
        }

        $results.Add([pscustomobject]@{
            path = ([IO.Path]::GetRelativePath($repositoryRoot, $file.FullName) -replace '\\', '/')
            cells = @($notebook.cells).Count
            changed = $changed
        })
    }

    [ordered]@{
        ok = $true
        notebooks = $results
    } | ConvertTo-Json -Depth 4
}
finally {
    Pop-Location
}