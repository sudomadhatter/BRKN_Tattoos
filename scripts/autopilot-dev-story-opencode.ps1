<#
.SYNOPSIS
    Autopilot Dev-Story Loop (opencode engine) - a one-shot, fully-autonomous dev/QA TEAM that
    takes a single BMAD story from ready-for-dev to "developed + self-reviewed + self-fixed",
    using TWO continuous chats on the opencode engine: a Dev session and a QA session.

.DESCRIPTION
    The opencode-native sibling of autopilot-dev-story.ps1 (the Claude engine). Same 4-stage
    relay, same artifact-folder contract, same test gate, same story->review flip - only the
    worker call differs (opencode run instead of claude -p).

        Stage 1  Plan         Dev/Amelia  (NEW dev session)   -> implementation_plan.md
        Stage 2  Audit        QA/Murat    (NEW qa session)    -> self-audit-stress-test.md
        Stage 3  Implement    Dev/Amelia  (RESUME dev)        -> code + walkthrough.md
        Stage 4  Review+Fix   QA/Murat    (RESUME qa)         -> code-review.md + fixes -> Daniel

    MODEL SPLIT (the opencode variant's reason to exist):
      - Dev (Stages 1/3): opencode's SELECTED default model. Achieved by OMITTING -m, so the
        child inherits the default agent's configured model. Override per-run with -DevModel
        (forwarded as -m). Default -DevModel = "" (empty = omit -m).
      - QA  (Stages 2/4): pinned to -QaModel (default openrouter/z-ai/glm-5.2) at -QaVariant
        effort (default max). The strongest reasoning sits on the audit + review+fix lane, the
        last gates before the human.

    SESSION CONTINUITY: opencode mints ses_... ids server-side. This script captures the id from
    each "new" stage's event stream, persists it to _pipeline/sessions.json, and passes
    --session <id> on the resume stage. Because the ids are ours (read back from disk on a
    resume), a crashed run is still resumable.

    RESILIENCE (same model as the Claude engine):
      - Transient API errors retry before a stage fails (-MaxRetries, default 3, with backoff).
      - A hard failure stamps a loud CRASHED marker in _RUN-STATUS.md (never leaves "IN PROGRESS").
      - _RUN-STATUS.md is re-stamped after every stage with the running cost + current stage.
      - A crashed/partial run is RESUMABLE: completed stages auto-detect by artifact presence and
        skip; -ResumeFrom forces a start stage; -DryRun prints the resume plan for $0.
      - Exit codes: 0 ok/partial, 2 blocker, 3 crash, 4 tests-red/unverified, 5 cost-ceiling.

    HONEST GAPS vs the Claude engine (documented in the command doc):
      - NO per-stage cost cap. opencode run has no --max-budget-usd equivalent, so -MaxStageCost
        is dropped. The run-level -MaxCost still bounds total spend BETWEEN stages, but a single
        runaway stage cannot self-halt mid-flight.
      - The model-mismatch assertion is a no-op: the opencode event stream carries no `model`
        field, so served-vs-requested cannot be checked. (The assertion hook is kept but never
        fires; a real mismatch would surface as a stage error or wrong-quality output instead.)
      - --variant support is provider-specific. -QaVariant max is passed for the QA lane; if the
        provider rejects it, opencode errors and the stage retries then fails (fall back to
        -QaVariant high).

    The audit (Stage 2) NEVER hard-halts on findings: its fixes flow into Stage 3. The ONLY thing
    that stops the run mid-flight is a stage emitting a `PIPELINE_BLOCKER:` line (a genuinely
    unresolvable problem - contradictory ACs, missing dependency, a human-only product decision).

.PARAMETER Story
    Story identifier (e.g. "11.16") or a direct path to the story .md file.

.PARAMETER DevModel
    Model id for the Dev session (Stages 1, 3) in provider/model form (e.g.
    "openrouter/z-ai/glm-5.2"). DEFAULT EMPTY = omit -m = opencode's selected default model.
    Override per-run to pin a specific Dev model.

.PARAMETER QaModel
    Model id for the QA session (Stages 2, 4). Default: openrouter/z-ai/glm-5.2 (pinned).

.PARAMETER QaVariant
    opencode --variant (reasoning effort) for the QA stages. Default: max. (Provider-specific;
    high is the fallback if max is rejected.)

.PARAMETER MaxStage
    Stop after this stage (1-4). Default 4 = full run. Use 3 for the cheap trial that proves the
    opencode resume hop (Plan -> Audit -> Implement) before greenlighting Stage 4.

.PARAMETER ResumeFrom
    Force the pipeline to start at this stage (1-4). Default 0 = auto-detect from existing artifacts.

.PARAMETER MaxRetries
    Attempts per stage before a transient API error is treated as fatal. Default 3.

.PARAMETER MaxCost
    Spend ceiling in USD across the whole run. 0 disables it. Default 40. (No per-stage cap exists
    on this engine - see NOTES.)

.PARAMETER TestScope
    Which suite(s) the independent post-Stage-4 test gate runs: auto, backend, frontend, both, none.

.PARAMETER DryRun
    Print the resume plan (which stages are complete / would run) + the session ids, and exit.
    No CLI calls, no spend.

.EXAMPLE
    .\scripts\autopilot-dev-story-opencode.ps1 -Story 11.16

.EXAMPLE
    .\scripts\autopilot-dev-story-opencode.ps1 -Story 13.1 -MaxStage 3   # cheap trial (proves resume)

.EXAMPLE
    .\scripts\autopilot-dev-story-opencode.ps1 -Story 13.1 -DryRun        # show resume plan, $0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Story,

    # Dev (Stages 1/3): EMPTY = omit -m = opencode selected default. Override to pin a model.
    [string]$DevModel  = "",

    # QA (Stages 2/4): pinned to GLM 5.2 at max effort (the strongest reasoning on the last gate).
    [string]$QaModel   = "openrouter/z-ai/glm-5.2",
    [string]$QaVariant = "max",

    [ValidateRange(1,4)]
    [int]$MaxStage = 4,

    # 0 = auto-detect the first incomplete stage from artifacts on disk.
    [ValidateRange(0,4)]
    [int]$ResumeFrom = 0,

    [ValidateRange(1,5)]
    [int]$MaxRetries = 3,

    # Spend ceiling (USD). 0 = disabled. ON by default; a normal run is a few $.
    # NOTE: no per-stage cap on this engine (opencode has no --max-budget-usd).
    [double]$MaxCost = 40,

    [ValidateSet('auto','backend','frontend','both','none')]
    [string]$TestScope = 'auto',

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Read child-process (opencode) stdout as UTF-8 so captured JSON keeps special chars intact.
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$OutputEncoding = [System.Text.Encoding]::UTF8

# --- Resolve paths ----------------------------------------------------------------------
$RepoRoot = (Resolve-Path "$PSScriptRoot\..").Path
# Derive the project name from the repo folder so this script is project-agnostic (template-safe).
$ProjectName = (Split-Path $RepoRoot -Leaf)
$Opencode = (Get-Command opencode -ErrorAction SilentlyContinue).Source
if (-not $Opencode) {
    throw "opencode CLI not found. Install with: npm install -g opencode-ai"
}

# --- Resolve the story file -------------------------------------------------------------
if (Test-Path $Story) {
    $StoryFile = (Resolve-Path $Story).Path
} else {
    $storiesDir = Join-Path $RepoRoot "_bmad\bmm\stories"
    # Anchor the numeric id with dashes so "14.1" matches story-14-1-... but NOT story-14-10-...
    $pat = [regex]::Escape(($Story -replace '\.','-'))
    $candidates = Get-ChildItem $storiesDir -Filter *.md -ErrorAction SilentlyContinue |
        Where-Object { ($_.BaseName -replace '\.','-') -match "(^|-)$pat(-|$)" }
    if (-not $candidates) { throw "No story file matching '$Story' in $storiesDir" }
    if ($candidates.Count -gt 1) {
        throw "Ambiguous story '$Story' - matched: $($candidates.Name -join ', ')"
    }
    $StoryFile = $candidates[0].FullName
}

# --- Read the story's baseline commit (scope anchor for the multi-team tree) -------------
$BaselineCommit = ""
try {
    $storyHead = Get-Content -LiteralPath $StoryFile -TotalCount 15 -ErrorAction Stop
    foreach ($ln in $storyHead) {
        if ($ln -match '^\s*baseline_commit\s*:\s*(\S+)') { $BaselineCommit = $Matches[1]; break }
    }
} catch { }

# --- Canonical artifact folder (STABLE per story across days) ----------------------------
$storyBase = ([System.IO.Path]::GetFileNameWithoutExtension($StoryFile)) -replace '\.','-'
if ($storyBase -match '^story-(\d+(?:-\d+)*)') { $storyId = $Matches[1] }
else { $storyId = ($Story -replace '[^0-9A-Za-z]+','-').Trim('-') }
$slug    = "autopilot-$storyId"
$artifactsRoot = Join-Path $RepoRoot "_artifacts"

# Parent folder: a story nests under its EPIC bucket (epic = the leading number of the story id, e.g.
# 14-6 -> epic_14), per the artifacts-always-first rule (stories under their epic; system work under
# _main; random one-offs at the root). Fall back to the root if the id has no leading epic number.
if ($storyId -match '^(\d+)') { $parent = Join-Path $artifactsRoot ("epic_" + $Matches[1]) }
else                          { $parent = $artifactsRoot }

# Reuse an existing run folder for this story - search the epic bucket first, THEN the root (so runs
# minted before this fix, or a relocate-in-progress, are still found on resume); prefer one with a plan.
# The folder (and its epic parent) is CREATED later via New-Item -Force, so a dry run stays inert.
$candidates = @(Get-ChildItem $parent        -Directory -Filter "*_$slug" -ErrorAction SilentlyContinue) +
              @(Get-ChildItem $artifactsRoot -Directory -Filter "*_$slug" -ErrorAction SilentlyContinue)
$pick = $candidates | Where-Object { Test-Path (Join-Path $_.FullName "implementation_plan.md") } |
    Sort-Object Name -Descending | Select-Object -First 1
if (-not $pick) { $pick = $candidates | Sort-Object Name -Descending | Select-Object -First 1 }
if ($pick) {
    $Folder = $pick.FullName
} else {
    $dateTag = Get-Date -Format "yyyy-MM-dd"
    $Folder  = Join-Path $parent "${dateTag}_${slug}"
}
$LogDir  = Join-Path $Folder "_pipeline"

$decisionsLog = Join-Path $Folder "decisions-log.md"

# --- Per-team session ids ---------------------------------------------------------------
# opencode mints ses_... ids server-side. For a "new" stage we run WITHOUT --session, capture the
# sessionID from the event stream, and persist it. On resume we load the id from disk and pass
# --session <id>. A crashed run is resumable because the ids are on disk.
$sessionsFile = Join-Path $LogDir "sessions.json"
$DevSession = ""
$QaSession  = ""
if (Test-Path $sessionsFile) {
    try {
        $sj = Get-Content -Raw -LiteralPath $sessionsFile | ConvertFrom-Json
        $DevSession = [string]$sj.dev
        $QaSession  = [string]$sj.qa
    } catch { }
}
$DevName = "$slug-dev"
$QaName  = "$slug-qa"

$script:TotalCost = 0.0
$script:CurrentStageLabel = "startup"
$script:ModelMismatch = @()

# --- Run-status marker (so a partial/crashed run can never read as a finished story) ----
function Write-RunStatus {
    param([string]$Headline, [string]$Body)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $costLine = '$' + ("{0:n2}" -f $script:TotalCost)
    $lines = @(
        "# RUN STATUS - $Headline",
        "",
        "Last updated: $ts",
        "",
        $Body,
        "",
        "---",
        "- Story: $StoryFile",
        "- Total cost so far: $costLine",
        "- Engine: opencode (Dev=$($DevModel); QA=$($QaModel) variant=$($QaVariant))",
        "- This pipeline NEVER commits and NEVER marks the story done; human close-out is always required."
    )
    [System.IO.File]::WriteAllText((Join-Path $Folder "_RUN-STATUS.md"), (($lines -join "`r`n") + "`r`n"))
}

function Set-Progress {
    param([int]$Done, [string]$NextLabel)
    Write-RunStatus "IN PROGRESS - NOT FINISHED" "Completed through Stage $Done of 4. Next: $NextLabel. The 'Total cost so far' below reflects the stages run up to now. If this still says IN PROGRESS and nothing is actively running, the run crashed mid-flight - treat these artifacts as INCOMPLETE."
}

function Add-RunLog {
    param([string]$Text)
    try {
        $rl = Join-Path $LogDir "run.log"
        [System.IO.File]::AppendAllText($rl, $Text + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
    } catch { }
}

# --- Resume: a stage is "complete" iff its handoff artifact exists on disk ---------------
function Test-StageComplete {
    param([int]$N)
    switch ($N) {
        1 { return (Test-Path (Join-Path $Folder "implementation_plan.md")) }
        2 { return (Test-Path (Join-Path $Folder "self-audit-stress-test.md")) }
        3 { return (Test-Path (Join-Path $Folder "walkthrough.md")) }
        4 { return (Test-Path (Join-Path $Folder "code-review.md")) }
        default { return $false }
    }
}

$autoStart = 1
for ($s = 1; $s -le 4; $s++) {
    if (Test-StageComplete $s) { $autoStart = $s + 1 } else { break }
}
$startStage = if ($ResumeFrom -ge 1) { $ResumeFrom } else { $autoStart }
if ($startStage -lt 1) { $startStage = 1 }

# --- DryRun: print the resume plan + session ids and exit (no CLI calls, no spend) -------
if ($DryRun) {
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " AUTOPILOT DRY RUN - resume plan (opencode engine)" -ForegroundColor Cyan
    Write-Host "   Story  : $StoryFile"
    Write-Host "   Folder : $Folder"
    Write-Host "   Engine : opencode"
    Write-Host "   Dev    : $($DevModel)  (empty = opencode selected default)"
    Write-Host "   QA     : $($QaModel)  variant=$($QaVariant)"
    Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
    $names = @{1="Plan";2="Audit";3="Implement";4="Review+Fix"}
    for ($s = 1; $s -le 4; $s++) {
        $state = if ($s -lt $startStage) { "SKIP  (artifact present)" }
                 elseif ($s -gt $MaxStage) { "n/a   (beyond -MaxStage $MaxStage)" }
                 else { "RUN" }
        Write-Host ("   Stage {0} {1,-10} : {2}" -f $s, $names[$s], $state)
    }
    Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "   Would start at Stage $startStage (auto-detect=$autoStart, -ResumeFrom=$ResumeFrom)."
    $tsShow = $TestScope
    if ($TestScope -eq 'auto') {
        $tsShow = if ($BaselineCommit) { "auto (from baseline diff $BaselineCommit)" } else { "auto (no baseline -> both)" }
    }
    Write-Host "   Test gate : $tsShow"
    $mcShow = if ($MaxCost -gt 0) { '$' + ("{0:n2}" -f $MaxCost) } else { "disabled" }
    Write-Host "   Cost cap  : $mcShow (no per-stage cap on this engine)"
    Write-Host "   Sessions (read-back from disk = $(Test-Path $sessionsFile)):"
    $devShow = if ($DevSession) { $DevSession } else { "(captured when Stage 1 runs)" }
    $qaShow  = if ($QaSession)  { $QaSession }  else { "(captured when Stage 2 runs)" }
    Write-Host "     dev = $devShow  ($DevName)"
    Write-Host "     qa  = $qaShow  ($QaName)"
    Write-Host "============================================================" -ForegroundColor Cyan
    exit 0
}

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

Write-RunStatus "IN PROGRESS - NOT FINISHED" "The pipeline is running, or was interrupted. No stage is guaranteed complete. If this file still says IN PROGRESS and nothing is actively running, the run crashed or was killed mid-flight - treat these artifacts as INCOMPLETE, not a finished story."

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " AUTOPILOT DEV-STORY LOOP (opencode engine - two continuous teams)" -ForegroundColor Cyan
Write-Host "   Story    : $StoryFile"
    $devShow2 = if ($DevModel) { $DevModel } else { "(opencode selected default)" }
Write-Host "   Dev ($devShow2): session $DevName"
Write-Host "   QA  ($QaModel variant=$QaVariant): session $QaName"
Write-Host "   Folder   : $Folder"
Write-Host "   Start    : Stage $startStage (auto=$autoStart, -ResumeFrom=$ResumeFrom) | MaxRetries $MaxRetries"
Write-Host "============================================================" -ForegroundColor Cyan

# --- Parse-OcResult: opencode event-stream adapter --------------------------------------
# opencode run --format json emits NDJSON (one typed event per line). This walks the stream and
# collects what the relay needs. DEFENSIVE: unknown event types are ignored, never crash a stage.
# Captured shapes (from a real run):
#   {"type":"step_start","sessionID":"ses_...","part":{"messageID":"msg_...","type":"step-start",...}}
#   {"type":"text","sessionID":"ses_...","part":{"type":"text","text":"OK",...}}
#   {"type":"step_finish","sessionID":"ses_...","part":{"type":"step-finish","cost":0.0213,"tokens":{...},"reason":"stop",...}}
#   {"type":"error","sessionID":"ses_...","error":{"name":"...","data":{"message":"..."}}}
# NOTE: no `model` field is present in the stream, so the served-model mismatch check is a no-op.
function Parse-OcResult {
    param([string]$Raw)
    $r = [ordered]@{
        Result      = ""
        Cost        = 0.0
        Turns       = 0
        IsError     = $false
        SessionId   = ""
        ServedModel = ""   # not available in the opencode event stream
    }
    if (-not $Raw) { return $r }
    $textParts = @()
    $lines = $Raw -split "`r?`n" | Where-Object { $_.Trim() }
    foreach ($ln in $lines) {
        $ev = $null
        try { $ev = $ln | ConvertFrom-Json } catch { continue }
        if (-not $ev) { continue }
        if (-not $r.SessionId -and $ev.sessionID) { $r.SessionId = [string]$ev.sessionID }
        switch ($ev.type) {
            'text' {
                if ($ev.part -and $ev.part.text) { $textParts += [string]$ev.part.text }
            }
            'step_finish' {
                if ($ev.part) {
                    if ($ev.part.cost) { $r.Cost += [double]$ev.part.cost }
                    $r.Turns += 1
                }
            }
            'error' {
                $r.IsError = $true
            }
        }
    }
    $r.Result = ($textParts -join "")
    return $r
}

# --- Stage runner (with transient-error retry + session continuity) ---------------------
function Invoke-Stage {
    param(
        [int]$Num,
        [string]$Name,
        [string]$Model,            # "" = omit -m (opencode selected default)
        [string]$Variant,          # "" = omit --variant
        [string]$Prompt,
        [string]$SessionId,        # for Resume mode
        [ValidateSet('New','Resume')][string]$SessionMode,
        [string]$SessionName,
        [string]$Agent = ""           # "" = default_agent from opencode.json (plan); "build" for edit-capable stages
    )

    $script:CurrentStageLabel = "Stage $Num ($Name)"
    $modelLabel = if ($Model) { $Model } else { "(default)" }
    $variantLabel = if ($Variant) { " variant=$Variant" } else { "" }
    Write-Host ""
    Write-Host ">>> STAGE $Num/4 - $Name  [opencode | $modelLabel$variantLabel | session $SessionMode]" -ForegroundColor Yellow
    Add-RunLog ""
    Add-RunLog ">>> STAGE $Num/4 - $Name  [opencode | $modelLabel$variantLabel | session $SessionMode]"
    $logFile = Join-Path $LogDir ("stage{0}-{1}.json" -f $Num, ($Name.ToLower() -replace '[^a-z0-9]+','-'))

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        Push-Location $RepoRoot
        try {
            $cargs = @('run', $Prompt, '--auto', '--format', 'json')
            if ($Agent)               { $cargs += @('--agent', $Agent) }
            if ($Model)               { $cargs += @('-m', $Model) }
            if ($Variant -and $Model) { $cargs += @('--variant', $Variant) }
            if ($SessionMode -eq 'Resume') { $cargs += @('--session', $SessionId) }
            # New stage: no --session; the ses_ id is captured from the event stream below.
            $raw = $null | & $Opencode @cargs 2>$null | Out-String
        } finally {
            Pop-Location
        }
        $sw.Stop()

        # Always persist the latest raw output so even a final failure is inspectable (UTF-8 no BOM).
        [System.IO.File]::WriteAllText($logFile, $raw)

        $p = Parse-OcResult -Raw $raw

        $failed = $p.IsError -or (-not $p.Result -and -not $p.SessionId)
        if (-not $failed) {
            $cost = [double]$p.Cost
            $script:TotalCost += $cost
            Write-Host ("  done in {0:n0}s | cost `$" -f $sw.Elapsed.TotalSeconds + ("{0:n2}" -f $cost) + (" | turns {0}" -f $p.Turns)) -ForegroundColor DarkGray
            # Model-assertion: no-op on opencode (event stream carries no model field). Kept as a
            # hook so a future schema change can wire it without touching the call sites.
            if ($p.ServedModel -and $Model -and ($p.ServedModel -ne $Model)) {
                Write-Host ("  ! MODEL MISMATCH: requested {0} but served {1}" -f $Model, $p.ServedModel) -ForegroundColor Red
                $script:ModelMismatch += "Stage $Num ($Name): requested $Model, served $($p.ServedModel)"
            }
            Write-Host "  ---- result ----"
            Write-Host $p.Result
            Add-RunLog ("  done in {0:n0}s | cost `$" -f $sw.Elapsed.TotalSeconds + ("{0:n2}" -f $cost) + (" | turns {0}" -f $p.Turns))
            Add-RunLog "  ---- result ----"
            Add-RunLog ([string]$p.Result)
            # Return a combined object so the caller can read the captured session id.
            return $p
        }

        # Failed. Transient? (overload, rate-limit, 5xx, generic error, timeout, variant rejected)
        $errText = if ($p.Result) { $p.Result } else { $raw }
        $transient = $errText -match 'overloaded|API Error|partial response|rate.?limit|429|503|529|timeout|Unexpected server error|variant'
        if ($transient -and $attempt -lt $MaxRetries) {
            $backoff = @(5,15,30)[[Math]::Min($attempt - 1, 2)]
            Write-Host ("  ! transient error (attempt {0}/{1}) - retrying in {2}s..." -f $attempt, $MaxRetries, $backoff) -ForegroundColor DarkYellow
            Start-Sleep -Seconds $backoff
            continue
        }

        $why = if ($p.IsError) { "error event in stream" } else { "empty result (no text, no session id)" }
        throw "Stage $Num ($Name) failed after $attempt attempt(s): $why  (raw saved to $logFile)"
    }
}

function Test-Blocker { param([string]$Result)
    return [bool](($Result -split "\r?\n") | Where-Object { $_ -match '^\s*PIPELINE_BLOCKER' })
}
function Stop-OnBlocker { param([string]$Result, [int]$Num, [string]$Name)
    if (Test-Blocker $Result) {
        $line = (($Result -split "\r?\n") | Where-Object { $_ -match '^\s*PIPELINE_BLOCKER' })[0]
        Write-Host ""
        Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
        Write-Host " PAUSED at Stage $Num ($Name) - needs Daniel" -ForegroundColor Cyan
        Write-Host " $line" -ForegroundColor Cyan
        Write-Host " Artifacts: $Folder" -ForegroundColor Cyan
        Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
        Write-Host ("Total cost so far: `$" + ("{0:n2}" -f $script:TotalCost))
        Write-RunStatus "PAUSED - NEEDS DANIEL" "A stage emitted PIPELINE_BLOCKER at Stage $Num ($Name): $line  This is the team asking for a human decision (by design) - NOT a crash. Review the folder, resolve it, then re-run with no flags (finished stages auto-detect from the folder and skip)."
        exit 2
    }
}
function Assert-Artifact { param([string]$RelName, [string]$Hint = "")
    $p = Join-Path $Folder $RelName
    if (-not (Test-Path $p)) {
        Write-Host "  ! WARNING: expected artifact not found: $p" -ForegroundColor DarkYellow
        if ($Hint) { Write-Host "    $Hint" -ForegroundColor DarkYellow }
    }
}
function Stop-Trial { param([int]$LastStage)
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host " AUTOPILOT PARTIAL RUN - stopped after Stage $LastStage (-MaxStage $MaxStage)" -ForegroundColor Green
    Write-Host ("   Total cost: `$" + ("{0:n2}" -f $script:TotalCost))
    Write-Host "   Artifacts : $Folder"
    Write-Host "   Re-run without -MaxStage (or with a higher value) to continue the pipeline."
    Write-Host "============================================================" -ForegroundColor Green
    Write-RunStatus "PARTIAL - STOPPED EARLY, NOT A FINISHED STORY" "STOPPED after Stage $LastStage via -MaxStage $MaxStage. The pipeline did NOT run all stages and did NOT close out. Do NOT treat these artifacts as a completed or verified story. Re-run without -MaxStage (or with a higher value) to continue."
    exit 0
}

function Assert-CostBudget {
    if ($MaxCost -gt 0 -and $script:TotalCost -gt $MaxCost) {
        $spent = '$' + ("{0:n2}" -f $script:TotalCost)
        $cap   = '$' + ("{0:n2}" -f $MaxCost)
        Write-Host ""
        Write-Host "############################################################" -ForegroundColor Red
        Write-Host " COST CEILING HIT - $spent exceeds -MaxCost $cap" -ForegroundColor Red
        Write-Host " Artifacts: $Folder" -ForegroundColor Red
        Write-Host "############################################################" -ForegroundColor Red
        Write-RunStatus "HALTED - COST CEILING, NOT FINISHED" "Spend reached $spent which exceeds -MaxCost $cap. The run was halted to bound spend; artifacts here are INCOMPLETE. Raise -MaxCost (or pass 0 to disable) and resume with -ResumeFrom <next stage>."
        exit 5
    }
}

function Stop-OnRedTests {
    param([string]$Suite, [string]$LogPath)
    Write-Host ""
    Write-Host "############################################################" -ForegroundColor Red
    Write-Host " TESTS RED - $Suite failed the pipeline's independent test gate" -ForegroundColor Red
    Write-Host " Output: $LogPath" -ForegroundColor Red
    Write-Host "############################################################" -ForegroundColor Red
    Write-RunStatus "TESTS RED - NOT FINISHED" "The independent test gate ran $Suite after the agents finished and it FAILED. The story is NOT verified-green - see $LogPath. If the failures are a PARALLEL team's uncommitted WIP (not this story), confirm your story's own tests pass and re-run with -TestScope none. Otherwise resume with -ResumeFrom 4 so QA fixes it."
    exit 4
}

function Invoke-TestGate {
    param([string]$Scope)
    if ($Scope -eq 'none') {
        Write-Host ""
        Write-Host ">>> TEST GATE - skipped (-TestScope none)" -ForegroundColor DarkYellow
        return
    }

    $runBackend  = $false
    $runFrontend = $false
    switch ($Scope) {
        'backend'  { $runBackend = $true }
        'frontend' { $runFrontend = $true }
        'both'     { $runBackend = $true; $runFrontend = $true }
        default {
            if ($BaselineCommit) {
                $changed = @()
                Push-Location $RepoRoot
                try { $changed = & git diff --name-only $BaselineCommit 2>$null } catch { $changed = @() } finally { Pop-Location }
                if ($changed -match '^backend/')  { $runBackend = $true }
                if ($changed -match '^frontend/') { $runFrontend = $true }
            }
            if (-not $runBackend -and -not $runFrontend) { $runBackend = $true; $runFrontend = $true }
        }
    }

    Write-Host ""
    Write-Host ">>> TEST GATE - independent verification (backend=$runBackend frontend=$runFrontend)" -ForegroundColor Yellow

    if ($runBackend) {
        $log = Join-Path $LogDir "gate-tests-backend.txt"
        $venvPy = Join-Path $RepoRoot ".venv\Scripts\python.exe"
        $py = if (Test-Path $venvPy) { $venvPy } else { (Get-Command python -ErrorAction SilentlyContinue).Source }
        if (-not $py) {
            Write-Host " TESTS UNVERIFIED - no python interpreter for pytest" -ForegroundColor Red
            Write-RunStatus "TESTS UNVERIFIED - RUNNER MISSING" "The test gate could not find a Python interpreter (.venv or python on PATH) to run pytest, so COMPLETE would be unverified. Fix the env or pass -TestScope none (after confirming tests manually), then resume with -ResumeFrom 4."
            exit 4
        }
        Write-Host ">>> TEST GATE - backend: pytest backend/tests -q" -ForegroundColor Yellow
        Push-Location $RepoRoot
        try { & $py -m pytest backend/tests -q | Tee-Object -FilePath $log } finally { Pop-Location }
        if ($LASTEXITCODE -ne 0) { Stop-OnRedTests "backend (pytest)" $log }
    }

    if ($runFrontend) {
        $log = Join-Path $LogDir "gate-tests-frontend.txt"
        $npm = (Get-Command npm -ErrorAction SilentlyContinue).Source
        if (-not $npm) {
            Write-Host " TESTS UNVERIFIED - no npm for the frontend suite" -ForegroundColor Red
            Write-RunStatus "TESTS UNVERIFIED - RUNNER MISSING" "The test gate could not find npm on PATH to run the frontend suite, so COMPLETE would be unverified. Fix the env or pass -TestScope none (after confirming tests manually), then resume with -ResumeFrom 4."
            exit 4
        }
        Write-Host ">>> TEST GATE - frontend: npm test (vitest run)" -ForegroundColor Yellow
        Push-Location (Join-Path $RepoRoot "frontend")
        try { & $npm test | Tee-Object -FilePath $log } finally { Pop-Location }
        if ($LASTEXITCODE -ne 0) { Stop-OnRedTests "frontend (npm test / vitest)" $log }
    }

    Write-Host ">>> TEST GATE - PASS (suites green)" -ForegroundColor Green
}

function Set-StoryReview {
    try {
        $txt = [System.IO.File]::ReadAllText($StoryFile)
        $new = [regex]::Replace($txt, '(?im)^(Status:\s*)(ready-for-dev|in-progress)\s*$', '${1}review')
        if ($new -ne $txt) {
            [System.IO.File]::WriteAllText($StoryFile, $new)
            Write-Host ">>> STORY STATUS - story file flipped to review" -ForegroundColor Green
            Add-RunLog ">>> STORY STATUS - story file flipped to review"
        } else {
            Write-Host ">>> STORY STATUS - story file not at ready-for-dev/in-progress (left as-is)" -ForegroundColor DarkGray
        }

        $sprint = Join-Path $RepoRoot "_bmad-output\implementation-artifacts\sprint-status.yaml"
        $key    = ([System.IO.Path]::GetFileNameWithoutExtension($StoryFile)) -replace '^story-',''
        if (Test-Path $sprint) {
            $stxt = [System.IO.File]::ReadAllText($sprint)
            $pat  = '(?m)^(\s*' + [regex]::Escape($key) + ':\s*)(ready-for-dev|in-progress)(\b.*)$'
            $snew = [regex]::Replace($stxt, $pat, '${1}review${3}')
            if ($snew -ne $stxt) {
                [System.IO.File]::WriteAllText($sprint, $snew)
                Write-Host ">>> STORY STATUS - sprint-status.yaml '$key' flipped to review" -ForegroundColor Green
                Add-RunLog ">>> STORY STATUS - sprint-status.yaml '$key' flipped to review"
            } else {
                Write-Host ">>> STORY STATUS - sprint-status.yaml '$key' not at ready-for-dev (left as-is)" -ForegroundColor DarkGray
            }
        } else {
            Write-Host "  ! WARNING: sprint-status.yaml not found - story-file flip only" -ForegroundColor DarkYellow
        }
    } catch {
        Write-Host "  ! WARNING: could not auto-flip story to review: $($_.Exception.Message)" -ForegroundColor DarkYellow
        Write-Host "    The run SUCCEEDED; flip the story to review by hand at close-out." -ForegroundColor DarkYellow
    }
}

# --- Scope guidance injected into the dev (Stage 3) + review (Stage 4) prompts -----------
if ($BaselineCommit) {
    $scopeGuidance = @"
- SCOPE (multi-team tree): this story was cut at baseline commit $BaselineCommit. Your scope is EXACTLY
  the files the plan's "Files Touched" lists. Verify your own changes against that base with:
      git diff $BaselineCommit -- <those files>
  Any file changed in the working tree that is NOT in the plan's list is a PARALLEL team's uncommitted
  work - do NOT treat it as your scope, do NOT review it, and do NOT "fix" it.
"@
} else {
    $scopeGuidance = @"
- SCOPE (multi-team tree): work ONLY on the files THIS story changed (see the plan's "Files Touched").
  The working tree may contain unrelated uncommitted changes from parallel teammates - EXCLUDE those
  from your scope; do not review or "fix" them.
"@
}

# --- Team framing + decision-log protocol, prepended to every stage prompt ---------------
$teamPreamble = @"
=== AUTONOMOUS DEV/QA TEAM - YOU ARE NOT TALKING TO DANIEL ===
You are one teammate on $ProjectName's autonomous pipeline: TWO teams, each working in ONE
continuous chat, handing off through artifact files in this folder: $Folder
  Stage 1 PLAN        - Amelia (Dev team)
  Stage 2 AUDIT       - Murat (QA team)
  Stage 3 IMPLEMENT   - Amelia (Dev team)
  Stage 4 REVIEW+FIX  - Murat (QA team), the LAST agent before the human
Your output is consumed by the OTHER team's agent (or, for Stage 4, by Daniel).
- Address every handoff note, question, or assumption to the other team's agent - never to Daniel
  (the one EXCEPTION is Stage 4 below, which hands to Daniel).
- Resolve ambiguity yourself from the story + codebase; if it is a QA judgment, defer to the QA
  agent's findings. Daniel reviews only the final result at close-out.
- Escalate mid-run to the human ONLY via a single 'PIPELINE_BLOCKER: <reason>' line, and ONLY for a
  genuine product decision no teammate can make (contradictory ACs, a missing upstream dependency, a
  business call). A soft "I would normally confirm X with Daniel" is NOT a blocker - pick the safe
  default, proceed, and LOG it (see below).

=== SESSION CONTINUITY (a convenience, NOT a restriction) ===
Your team works in ONE continuous chat across its two stages (Dev = Stages 1 then 3; QA = Stages 2
then 4). If this is your team's SECOND stage, your earlier work and codebase research are ALREADY in
your context - build directly on them instead of rediscovering them. This is purely to save effort:
research anything the new task needs and NEVER skip investigation you require. The other team's
handoff document is on disk - always read it fresh.

=== DECISION LOG PROTOCOL (MANDATORY) ===
Whenever you make a choice you would otherwise have asked Daniel about - a default, an assumption, an
ambiguous-spec interpretation, a tradeoff, a dependency install, or accepting a known limitation -
APPEND an entry to this file (create it if it does not exist): $decisionsLog
Use EXACTLY this format:

### [Stage <N> - <Amelia|Murat>] <short decision title>
- Decision point: <what came up that a human might normally weigh in on>
- Options I had: <A> / <B> / <C>
- I chose: <X>
- Why: <rationale, citing the story / codebase / a specific AC>
- Deferred to: <story spec | codebase precedent | Murat's audit F# | Murat's review M#/L#>
- What Daniel would have supplied: <the human input this stands in for>
- Reversible at close-out?: <yes/no - how Daniel flips it if he disagrees>

Do NOT skip this. The decision log is how Daniel reviews what the team decided on his behalf.
=== END TEAM PROTOCOL ===
"@

# =======================================================================================
#  THE RELAY  (resume-aware; wrapped so any hard failure stamps a CRASHED marker)
# =======================================================================================
try {

# --- STAGE 1 - PLAN (Dev/Amelia, NEW dev session) ---------------------------------------
if ($startStage -le 1) {
    $prompt1 = @"
$teamPreamble

/sudo-dev-story-tests_AP plan

You are Amelia (Dev), Stage 1 of 4 (PLAN). Headless in $ProjectName.
- Shared run folder (write the plan here; create no new folder): $Folder
- Target story: $StoryFile
Your full stage instructions live in the /sudo-dev-story-tests_AP command above.
"@
    $p1 = Invoke-Stage -Num 1 -Name "Plan" -Model $DevModel -Variant "" -Prompt $prompt1 -SessionId "" -SessionMode New -SessionName $DevName
    # Capture the server-minted dev session id and persist it.
    if ($p1.SessionId) {
        $DevSession = $p1.SessionId
        [System.IO.File]::WriteAllText($sessionsFile, (@{ dev = $DevSession; qa = $QaSession } | ConvertTo-Json -Compress))
    } else {
        Write-Host "  ! WARNING: no session id captured from Stage 1 - Stage 3 resume will not be possible (will cold-start)." -ForegroundColor DarkYellow
    }
    Stop-OnBlocker -Result ([string]$p1.Result) -Num 1 -Name "Plan"
    Assert-Artifact "implementation_plan.md"
} else {
    Write-Host ""
    Write-Host ">>> STAGE 1/4 - Plan  [SKIPPED - artifact present]" -ForegroundColor DarkGray
}
if ($MaxStage -le 1) { Stop-Trial 1 }
Set-Progress 1 "Stage 2 Audit (Murat / QA)"
Assert-CostBudget

# --- STAGE 2 - AUDIT (QA/Murat, NEW qa session) -----------------------------------------
if ($startStage -le 2) {
    $prompt2 = @"
$teamPreamble

/sudo-self-audit_AP

You are Murat (QA), Stage 2 of 4 (PRE-DEV AUDIT). think hard. Headless in $ProjectName.
- Shared run folder (read the plan here; write the audit here): $Folder
- Target story: $StoryFile
Your full stage instructions live in the /sudo-self-audit_AP command above.
"@
    $p2 = Invoke-Stage -Num 2 -Name "Audit" -Model $QaModel -Variant $QaVariant -Prompt $prompt2 -SessionId "" -SessionMode New -SessionName $QaName
    if ($p2.SessionId) {
        $QaSession = $p2.SessionId
        [System.IO.File]::WriteAllText($sessionsFile, (@{ dev = $DevSession; qa = $QaSession } | ConvertTo-Json -Compress))
    } else {
        Write-Host "  ! WARNING: no session id captured from Stage 2 - Stage 4 resume will not be possible (will cold-start)." -ForegroundColor DarkYellow
    }
    Stop-OnBlocker -Result ([string]$p2.Result) -Num 2 -Name "Audit"
    Assert-Artifact "self-audit-stress-test.md" "If the audit landed under another name, rename it to self-audit-stress-test.md; a plain re-run skips the finished stages."
} else {
    Write-Host ""
    Write-Host ">>> STAGE 2/4 - Audit  [SKIPPED - artifact present]" -ForegroundColor DarkGray
}
if ($MaxStage -le 2) { Stop-Trial 2 }
Set-Progress 2 "Stage 3 Implement (Amelia / Dev)"
Assert-CostBudget

# --- STAGE 3 - IMPLEMENT (Dev/Amelia, RESUME dev session) -------------------------------
if ($startStage -le 3) {
    if (-not $DevSession) { throw "Stage 3 needs the dev session id but none is on disk. Re-run from Stage 1 (-ResumeFrom 1)." }
    $prompt3 = @"
$teamPreamble

/sudo-dev-story-tests_AP implement

You are Amelia (Dev), Stage 3 of 4 (IMPLEMENT). Headless in $ProjectName.
- Shared run folder (read plan + audit here; write the walkthrough here): $Folder
- Target story: $StoryFile
$scopeGuidance
Your full stage instructions live in the /sudo-dev-story-tests_AP command above.
"@
    $p3 = Invoke-Stage -Num 3 -Name "Implement" -Model $DevModel -Variant "" -Prompt $prompt3 -SessionId $DevSession -SessionMode Resume -SessionName $DevName -Agent "build"
    Stop-OnBlocker -Result ([string]$p3.Result) -Num 3 -Name "Implement"
    Assert-Artifact "walkthrough.md" "Amelia likely wrote the walkthrough under another name (e.g. stage3-implement.md). Rename it to walkthrough.md and re-run with -ResumeFrom 4 (the dev session resumes from cache)."
} else {
    Write-Host ""
    Write-Host ">>> STAGE 3/4 - Implement  [SKIPPED - artifact present]" -ForegroundColor DarkGray
}
if ($MaxStage -le 3) { Stop-Trial 3 }
Set-Progress 3 "Stage 4 Review+Fix (Murat / QA)"
Assert-CostBudget

# --- STAGE 4 - REVIEW + FIX (QA/Murat, RESUME qa session) - LAST agent before Daniel -----
if ($startStage -le 4) {
    if (-not $QaSession) { throw "Stage 4 needs the qa session id but none is on disk. Re-run from Stage 2 (-ResumeFrom 2)." }
    $prompt4 = @"
$teamPreamble

/sudo-code-review_AP

You are Murat (QA), Stage 4 of 4 (REVIEW + FIX) - the LAST agent before Daniel. think hard. Headless.
- Shared run folder (read plan + audit + walkthrough here; write code-review.md here): $Folder
- Target story: $StoryFile
$scopeGuidance
Your full stage instructions live in the /sudo-code-review_AP command above.
"@
    $p4 = Invoke-Stage -Num 4 -Name "Review" -Model $QaModel -Variant $QaVariant -Prompt $prompt4 -SessionId $QaSession -SessionMode Resume -SessionName $QaName -Agent "build"
    Stop-OnBlocker -Result ([string]$p4.Result) -Num 4 -Name "Review"
    Assert-Artifact "code-review.md" "If the review landed under another name, rename it to code-review.md; a plain re-run skips the finished stages."
} else {
    Write-Host ""
    Write-Host ">>> STAGE 4/4 - Review+Fix  [SKIPPED - artifact present]" -ForegroundColor DarkGray
}

# --- Independent test gate: the pipeline VERIFIES green; it does not trust pasted output --
Write-RunStatus "IN PROGRESS - TEST GATE" "All 4 stages complete; the pipeline is now running its independent test gate (pytest / vitest) before COMPLETE. If this persists with nothing running, the gate crashed - re-run with no flags (finished stages auto-detect from the folder and skip)."
Invoke-TestGate -Scope $TestScope

Set-StoryReview

# =======================================================================================
#  DONE - hand back to Daniel
# =======================================================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " AUTOPILOT COMPLETE (opencode engine)" -ForegroundColor Green
Write-Host ("   Total cost: `$" + ("{0:n2}" -f $script:TotalCost))
Write-Host "   Artifacts : $Folder"
Write-Host "   Story now : review  (story file + sprint-status; you own the review -> done flip)"
Write-Host "------------------------------------------------------------" -ForegroundColor Green
Write-Host " Your move:"
Write-Host "   1. Review $Folder\walkthrough.md (top: OUT-OF-SPEC DECISIONS + OPEN QUESTIONS FOR DANIEL)"
Write-Host "      and $Folder\decisions-log.md (the full record of what the team decided for you)"
Write-Host "   2. Ratify the out-of-spec calls, run /sudo-update-sprint-memory, flip review -> done."
Write-Host "   3. Commit when satisfied (the pipeline never commits)."
Write-Host "============================================================" -ForegroundColor Green
Add-RunLog ""
Add-RunLog (" AUTOPILOT COMPLETE | Total cost: `$" + ("{0:n2}" -f $script:TotalCost) + " | Story -> review")

if ($script:ModelMismatch.Count -gt 0) {
    Write-Host ""
    Write-Host ("  ! MODEL MISMATCH(es): " + ($script:ModelMismatch -join '; ')) -ForegroundColor Red
}
$modelNote = if ($script:ModelMismatch.Count -gt 0) { "  WARNING - model mismatch(es): " + ($script:ModelMismatch -join '; ') + "." } else { "" }
Write-RunStatus "PIPELINE COMPLETE - but NOT closed out" ("All stages ran and the independent test gate is green; the pipeline advanced the story to 'review' (story file + sprint-status), but does NOT commit and does NOT mark it 'done'. Human close-out REQUIRED: review walkthrough.md (OUT-OF-SPEC DECISIONS + OPEN QUESTIONS sections) + decisions-log.md, run /sudo-update-sprint-memory, flip review -> done, then commit. Until then the story is NOT finished. Engine: opencode." + $modelNote)

}
catch {
    $msg = $_.Exception.Message
    Write-Host ""
    Write-Host "############################################################" -ForegroundColor Red
    Write-Host " CRASHED at $script:CurrentStageLabel" -ForegroundColor Red
    Write-Host " $msg" -ForegroundColor Red
    Write-Host " Artifacts: $Folder" -ForegroundColor Red
    Write-Host " Re-run with no flags - finished stages auto-detect from the folder and skip." -ForegroundColor Red
    Write-Host "############################################################" -ForegroundColor Red
    Write-RunStatus "CRASHED - NOT FINISHED" "CRASHED at $script:CurrentStageLabel - $msg  This is a GENUINE error (e.g. the API failed after retries), not a verdict/format check. Re-run with no flags: finished stages auto-detect from the folder and skip, so nothing completed is re-spent. Engine: opencode."
    exit 3
}
