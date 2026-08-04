[CmdletBinding()]
param(
    [Parameter(Mandatory, ParameterSetName = 'Single')]
    [ValidateNotNullOrEmpty()]
    [string]$Locale,

    [Parameter(Mandatory, ParameterSetName = 'Mixed')]
    [ValidateNotNullOrEmpty()]
    [string]$GivenLocale,

    [Parameter(Mandatory, ParameterSetName = 'Mixed')]
    [ValidateNotNullOrEmpty()]
    [string]$FamilyLocale,

    [Parameter(ParameterSetName = 'Mixed')]
    [ValidateSet('GivenFamily', 'FamilyGiven')]
    [string]$DisplayOrder = 'GivenFamily',

    [Parameter(Mandatory)]
    [ValidateRange(0, 2147483647)]
    [int]$Seed
)

$ErrorActionPreference = 'Stop'

$supportedLocales = @(
    'ar_DZ',
    'bn_BD',
    'en_IN',
    'en_NG',
    'en_US',
    'es_ES',
    'fr_FR',
    'ha_NG',
    'he_IL',
    'hy_AM',
    'ig_NG',
    'it_IT',
    'ja_JP',
    'ka_GE',
    'ko_KR',
    'nl_NL',
    'pt_BR',
    'th_TH',
    'zh_CN',
    'zh_TW'
)

$requestedLocales = if ($PSCmdlet.ParameterSetName -eq 'Mixed') {
    @($GivenLocale, $FamilyLocale)
}
else {
    @($Locale)
}

foreach ($requestedLocale in $requestedLocales) {
    if ($requestedLocale -notin $supportedLocales) {
        throw "Unsupported locale '$requestedLocale'. Supported locales: $($supportedLocales -join ', ')"
    }
}

if ($PSCmdlet.ParameterSetName -eq 'Mixed' -and $GivenLocale -eq $FamilyLocale) {
    throw 'Mixed naming requires distinct given-name and family-name locales.'
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$pythonPath = Join-Path $repositoryRoot '.venv\Scripts\python.exe'
$requirementsPath = Join-Path $PSScriptRoot 'requirements.txt'

if (-not (Test-Path -LiteralPath $pythonPath)) {
    throw "Workspace Python environment not found at $pythonPath"
}

$requirements = Get-Content -LiteralPath $requirementsPath
$fakerRequirement = $requirements | Where-Object { $_ -match '^Faker==' } | Select-Object -First 1
$anyAsciiRequirement = $requirements | Where-Object { $_ -match '^anyascii==' } | Select-Object -First 1

if (-not $fakerRequirement -or -not $anyAsciiRequirement) {
    throw 'Pinned Faker or AnyAscii requirement not found.'
}

$expectedFakerVersion = $fakerRequirement.Split('==', 2)[1]
$expectedAnyAsciiVersion = $anyAsciiRequirement.Split('==', 2)[1]
$pythonCode = @'
import importlib.metadata
import json
import re
import sys

from anyascii import anyascii
from faker import Faker

mode = sys.argv[1]
seed = int(sys.argv[2])
expected_faker_version = sys.argv[3]
expected_anyascii_version = sys.argv[4]
actual_faker_version = importlib.metadata.version("Faker")
actual_anyascii_version = importlib.metadata.version("anyascii")

sys.stdout.reconfigure(encoding="utf-8")

if actual_faker_version != expected_faker_version:
    raise RuntimeError(
        f"Faker version mismatch: expected {expected_faker_version}, found {actual_faker_version}"
    )
if actual_anyascii_version != expected_anyascii_version:
    raise RuntimeError(
        f"AnyAscii version mismatch: expected {expected_anyascii_version}, found {actual_anyascii_version}"
    )


def render_ascii(value):
    return " ".join(anyascii(value).split())


def filename_slug(value):
    slug = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    if not slug:
        raise RuntimeError("ASCII rendering did not produce a usable filename slug")
    return slug

if mode == "single":
    locale = sys.argv[5]
    fake = Faker(locale)
    fake.seed_instance(seed)
    raw_result = fake.name()
    ascii_result = render_ascii(raw_result)
    result = {
        "mode": mode,
        "locale": locale,
        "faker_version": actual_faker_version,
        "ascii_renderer": "AnyAscii",
        "ascii_renderer_version": actual_anyascii_version,
        "seed": seed,
        "raw_result": raw_result,
        "ascii_result": ascii_result,
        "filename_slug": filename_slug(ascii_result),
    }
elif mode == "mixed":
    given_locale = sys.argv[5]
    family_locale = sys.argv[6]
    display_order = sys.argv[7]
    given_seed = seed
    family_seed = (seed + 1) % 2147483648

    given_fake = Faker(given_locale)
    family_fake = Faker(family_locale)
    given_fake.seed_instance(given_seed)
    family_fake.seed_instance(family_seed)

    given_name = given_fake.first_name()
    family_name = family_fake.last_name()
    given_name_ascii = render_ascii(given_name)
    family_name_ascii = render_ascii(family_name)
    if display_order == "GivenFamily":
        raw_result = f"{given_name} {family_name}"
        ascii_result = f"{given_name_ascii} {family_name_ascii}"
    else:
        raw_result = f"{family_name} {given_name}"
        ascii_result = f"{family_name_ascii} {given_name_ascii}"

    result = {
        "mode": mode,
        "given_locale": given_locale,
        "family_locale": family_locale,
        "display_order": display_order,
        "faker_version": actual_faker_version,
        "ascii_renderer": "AnyAscii",
        "ascii_renderer_version": actual_anyascii_version,
        "seed": seed,
        "given_seed": given_seed,
        "family_seed": family_seed,
        "given_name": given_name,
        "given_name_ascii": given_name_ascii,
        "family_name": family_name,
        "family_name_ascii": family_name_ascii,
        "raw_result": raw_result,
        "ascii_result": ascii_result,
        "filename_slug": filename_slug(ascii_result),
    }
else:
    raise RuntimeError(f"Unknown name-generation mode: {mode}")

print(json.dumps(result, ensure_ascii=True))
'@

if ($PSCmdlet.ParameterSetName -eq 'Mixed') {
    & $pythonPath -c $pythonCode 'mixed' $Seed $expectedFakerVersion $expectedAnyAsciiVersion $GivenLocale $FamilyLocale $DisplayOrder
}
else {
    & $pythonPath -c $pythonCode 'single' $Seed $expectedFakerVersion $expectedAnyAsciiVersion $Locale
}
if ($LASTEXITCODE -ne 0) {
    throw "Name generation failed with exit code $LASTEXITCODE"
}