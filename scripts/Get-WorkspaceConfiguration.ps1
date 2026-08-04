[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$folderSettingsPath = Join-Path $repositoryRoot '.vscode\settings.json'

$folderSettings = Get-Content -LiteralPath $folderSettingsPath -Raw |
    ConvertFrom-Json -AsHashtable

[ordered]@{
    workspace_mode = 'folder'
    workspace_root = $repositoryRoot
    folder_settings_path = $folderSettingsPath
    folder_settings = $folderSettings
} | ConvertTo-Json -Depth 20