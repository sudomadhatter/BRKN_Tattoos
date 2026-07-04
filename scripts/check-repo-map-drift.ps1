#requires -Version 5
<#
  check-repo-map-drift.ps1 - detect-only repo-map drift nag (workspace-standard Part 3).

  Lists the project's real top-level folders, skips the standard ignore set, and flags any folder
  that is on disk but NOT named in docs/repo-map.md. It NAGS only; it never edits anything and
  always exits 0 (a drift nag must not block a session). It cannot write the one-line purpose a
  curated header needs -- that stays a human/agent job at end-of-task.

  Wired into .claude/settings.json as a SessionStart hook. Rebuild the map with:
      python scripts/generate_repo_map.py --ignore _bmad

  ASCII-only on purpose: PowerShell 5.1 reads a BOM-less file as Windows-1252, so non-ASCII here
  would corrupt the parse.
#>
$ErrorActionPreference = 'SilentlyContinue'

$root = Split-Path -Parent $PSScriptRoot              # <project>/scripts -> <project>
$map  = Join-Path $root 'docs/repo-map.md'

if (-not (Test-Path $map)) {
    Write-Output '[repo-map] docs/repo-map.md not found - run: python scripts/generate_repo_map.py --ignore _bmad'
    exit 0
}

# Mirror generate_repo_map.py: dot-folders are skipped automatically; these are the non-dot ignores
# plus _bmad (the BMAD module is excluded from the map via --ignore _bmad).
$ignore = @(
    'node_modules','venv','env','__pycache__','auth_keys',
    '_artifacts','_claude_artifacts','_opencode_artifacts',
    '_test_scripts','_debug_audio','dist','build','__tests__','_bmad'
)

$mapText = Get-Content -Raw -Encoding UTF8 $map
$dirs = Get-ChildItem -LiteralPath $root -Directory |
    Where-Object { $_.Name -notlike '.*' -and $ignore -notcontains $_.Name }

$missing = @()
foreach ($d in $dirs) {
    if ($mapText -notmatch [regex]::Escape($d.Name + '/')) { $missing += $d.Name }
}

if ($missing.Count -gt 0) {
    Write-Output ''
    Write-Output '[repo-map drift] top-level folders on disk but NOT in docs/repo-map.md:'
    foreach ($m in $missing) { Write-Output ('  - ' + $m + '/') }
    Write-Output '  -> rebuild: python scripts/generate_repo_map.py --ignore _bmad   (then add a one-line purpose to the curated header)'
}

exit 0
