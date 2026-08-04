[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string[]]$Dice
)

$ErrorActionPreference = 'Stop'
$results = @()

foreach ($specification in $Dice) {
    if ($specification -notmatch '^(?:(?<label>[^=]+)=)?(?<count>[1-9]\d*)d(?<sides>[2-9]\d*)$') {
        throw "Invalid dice specification '$specification'. Use Label=2d6 or 2d6."
    }

    $count = [int]$Matches.count
    $sides = [int]$Matches.sides
    $label = if ($Matches.label) { $Matches.label } else { $specification }

    if ($count -gt 100) {
        throw 'A dice pool cannot exceed 100 dice.'
    }

    if ($sides -gt 1000000) {
        throw 'A die cannot exceed 1,000,000 sides.'
    }

    $rolls = @(
        for ($index = 0; $index -lt $count; $index++) {
            [System.Security.Cryptography.RandomNumberGenerator]::GetInt32(1, $sides + 1)
        }
    )

    $results += [ordered]@{
        label = $label
        notation = "${count}d${sides}"
        rolls = $rolls
        total = ($rolls | Measure-Object -Sum).Sum
    }
}

ConvertTo-Json -InputObject $results -Depth 4 -Compress