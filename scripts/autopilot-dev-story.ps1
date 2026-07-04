<#
.SYNOPSIS
    Autopilot Dev-Story Loop (v2) - a one-shot, fully-autonomous dev/QA TEAM that takes a single
    BMAD story from ready-for-dev to "developed + self-reviewed + self-fixed", using TWO
    continuous chats: a Dev session and a QA session (models come from -DevModel / -AuditModel).

.DESCRIPTION
    Drives four headless `claude -p` subprocesses across TWO PERSISTENT SESSIONS. Each team does
    its codebase deep-dive once and RESUMES its own session for its second stage, so it never
    re-researches from scratch. Handoff between the two teams still happens through artifact files
    in a single canonical folder. The orchestration is plain PowerShell (no LLM coordinator tax).

        Stage 1  Plan         Dev/Amelia  (NEW dev session)  -> implementation_plan.md
        Stage 2  Audit        QA/Murat    (NEW qa session)   -> self-audit-stress-test.md
        Stage 3  Implement    Dev/Amelia  (RESUME dev)       -> code + walkthrough.md
        Stage 4  Review+Fix   QA/Murat    (RESUME qa)        -> code-review.md + fixes -> Daniel

    Continuity is implemented with deterministic session ids: the script generates one UUID per
    team up front (persisted to _pipeline/sessions.json), passes --session-id on the first call and
    --resume on the second. Because the ids are ours, a crashed run is still resumable.

    QA owns the final loop: Stage 4 reviews, APPLIES fixes itself (strongest model, full context),
    re-runs tests, and - being the last agent before the human - spotlights every off-spec decision
    and any open question for Daniel in the final report.

    Resilience:
      - Transient API errors (stream idle timeout, overloaded, 429/503/529) are RETRIED before a
        stage is allowed to fail (-MaxRetries, default 3, with backoff).
      - A hard failure stamps a loud CRASHED marker in _RUN-STATUS.md (never leaves "IN PROGRESS").
      - _RUN-STATUS.md is re-stamped after every stage with the running cost + current stage, so an
        "ask status" mid-run is accurate.
      - A crashed/partial run is RESUMABLE: completed stages are auto-detected by artifact presence
        and skipped (the saved session ids are reused); -ResumeFrom forces a start stage; -DryRun
        prints the resume plan for $0.
      - Exit codes: 0 ok/partial, 2 blocker, 3 crash, 4 tests-red/unverified, 5 cost-ceiling.

    Integrity gates beyond artifact presence: the script (a) feeds the story's baseline_commit to the
    dev/review stages so scope is git-verifiable in this multi-team tree, (b) enforces the positive
    PIPELINE_*_OK verdict (not just the blocker), (c) runs the test suite(s) ITSELF after Stage 4 and
    refuses to stamp COMPLETE on red, (d) halts if spend crosses -MaxCost, and (e) checks each stage's
    modelUsage against the requested model.

    The audit (Stage 2) NEVER hard-halts on findings: its fixes flow into Stage 3. The ONLY thing
    that stops the run mid-flight is a stage emitting a `PIPELINE_BLOCKER:` line (a genuinely
    unresolvable problem - contradictory ACs, missing dependency, a human-only product decision).

    CLAUDE-ONLY. This relies on the `claude` CLI and cannot run under Gemini/opencode.

.PARAMETER Story
    Story identifier (e.g. "11.16") or a direct path to the story .md file.

.PARAMETER DevModel
    Model id for the Dev session (Stages 1, 3). Default: claude-opus-4-8.

.PARAMETER AuditModel
    Model id for the QA session (Stages 2, 4). Default: claude-fable-5 (strongest tier; the QA lane is the last gate before the human).

.PARAMETER DevEffort
    Reasoning effort for the Dev session (Stages 1, 3), passed to the CLI as --effort. Default: max.
    Levels: low, medium, high, xhigh, max. On Opus 4.8 this (not prompt keywords) sets thinking depth.

.PARAMETER AuditEffort
    Reasoning effort for QA Stage 2 (pre-dev audit), passed to the CLI as --effort. Default: high.
    Levels: low, medium, high, xhigh, max. May differ from -ReviewEffort even though both share one QA session.

.PARAMETER ReviewEffort
    Reasoning effort for QA Stage 4 (final review+fix, the last gate before the human). Default: xhigh (one below max).
    Levels: low, medium, high, xhigh, max. Effort is per-call, so this may differ from -AuditEffort with no cache cost.

.PARAMETER MaxStage
    Stop after this stage (1-4). Default 4 = full run. Use 2 for a cheap plan+audit trial.

.PARAMETER ResumeFrom
    Force the pipeline to start at this stage (1-4). Default 0 = auto-detect from existing artifacts.

.PARAMETER MaxRetries
    Attempts per stage before a transient API error is treated as fatal. Default 3.

.PARAMETER MaxCost
    Spend ceiling in USD across the whole run. 0 disables it. Default 40 (ON; raised from 30 for the
    Fable QA lane, Daniel 2026-07-02). If total cost crosses this between stages, the run halts with a
    HALTED - COST CEILING marker (exit 5).

.PARAMETER MaxStageCost
    Per-stage spend cap in USD, enforced INSIDE each claude call via --max-budget-usd - so a single
    runaway stage halts itself mid-flight instead of only being caught by -MaxCost between stages.
    0 disables. Default 15. A budget-cut stage ends without its artifact -> the run stops
    CRASHED-resumable; re-run with a higher -MaxStageCost to give that stage more room.

.PARAMETER TestScope
    Which suite(s) the independent post-Stage-4 test gate runs: auto (derive from the baseline diff -
    backend-only / frontend-only / both, with a shared-contract change forcing both), backend,
    frontend, both, or none. Default auto. A red suite stamps TESTS RED and exits 4.

.PARAMETER DryRun
    Print the resume plan (which stages are complete / would run) + the session ids, and exit.
    No CLI calls, no spend.

.EXAMPLE
    .\scripts\autopilot-dev-story.ps1 -Story 11.16

.EXAMPLE
    .\scripts\autopilot-dev-story.ps1 -Story 13.1 -ResumeFrom 4    # re-run only the review+fix leg

.EXAMPLE
    .\scripts\autopilot-dev-story.ps1 -Story 13.1 -DryRun          # show resume plan, spend nothing
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Story,

    # Dev (Stages 1/3): Opus 4.8. Reasoning depth is set explicitly via -DevEffort (below), not prompt keywords.
    [string]$DevModel  = "claude-opus-4-8",
    # QA (Stages 2/4): strongest available - Fable 5 on the audit + review+fix lane (Daniel 2026-07-02).
    [string]$AuditModel = "claude-fable-5",

    # Reasoning effort per STAGE, passed to the CLI as --effort. This is the explicit depth control for
    # Fable 5 / Opus 4.8 (thinking is always-on; depth = effort), superseding the old "think hard" prompt
    # keyword convention. Effort is a per-call setting, so Stage 2 (audit) and Stage 4 (review) can differ
    # even though they share ONE QA session - unlike the MODEL, which must stay constant across a resumed
    # session or the model-scoped cache is invalidated. Defaults (Daniel 2026-07-02): Dev max, audit high,
    # review xhigh - max effort on the cheaper Opus lane, dialed back on the pricier Fable QA lane.
    [ValidateSet('low','medium','high','xhigh','max')]
    [string]$DevEffort    = "max",     # Dev lane: Plan (1) + Implement (3)  - Opus at max
    [ValidateSet('low','medium','high','xhigh','max')]
    [string]$AuditEffort  = "high",    # QA Stage 2: pre-dev audit
    [ValidateSet('low','medium','high','xhigh','max')]
    [string]$ReviewEffort = "xhigh",   # QA Stage 4: final review+fix (last gate before the human)

    [ValidateRange(1,4)]
    [int]$MaxStage = 4,

    # 0 = auto-detect the first incomplete stage from artifacts on disk.
    [ValidateRange(0,4)]
    [int]$ResumeFrom = 0,

    [ValidateRange(1,5)]
    [int]$MaxRetries = 3,

    # Spend ceiling (USD). 0 = disabled. ON by default as a runaway safety net; a normal run is a few $.
    [double]$MaxCost = 40,

    # Per-stage cap (USD), enforced INSIDE each claude call via --max-budget-usd. 0 = disabled.
    [double]$MaxStageCost = 15,

    # Which suite(s) the independent post-Stage-4 test gate runs. auto = derive from the baseline diff.
    [ValidateSet('auto','backend','frontend','both','none')]
    [string]$TestScope = 'auto',

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Read child-process (claude CLI) stdout as UTF-8 so the captured JSON keeps em-dashes / section
# signs / arrows intact instead of mojibake (TUNING-2). Guarded: some hosts have no console.
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$OutputEncoding = [System.Text.Encoding]::UTF8

# --- Resolve paths ----------------------------------------------------------------------
$RepoRoot = (Resolve-Path "$PSScriptRoot\..").Path
# Derive the project name from the repo folder so this script is project-agnostic (template-safe).
$ProjectName = (Split-Path $RepoRoot -Leaf)
$Claude   = (Get-Command claude -ErrorAction SilentlyContinue).Source
if (-not $Claude) { $Claude = Join-Path $env:APPDATA "npm\claude.ps1" }
if (-not (Test-Path $Claude)) {
    throw "claude CLI not found. Install with: npm install -g @anthropic-ai/claude-code"
}

# --- Preflight: self-register workspace trust for the headless children -----------------
# Headless `claude -p` enforces the workspace-trust gate. The child's cwd is $RepoRoot (we
# Push-Location to it per stage), and Resolve-Path returns the canonical on-disk path with an
# UPPERCASE drive letter. The trust gate is keyed on that exact string in ~/.claude.json under
# projects["<forward-slash path>"].hasTrustDialogAccepted. If the repo is ever moved/re-cased
# (e.g. the opencode-compat refactor that relocated this project), the old trust grant no longer
# matches and every stage dies with "this workspace has not been trusted". We make the script
# trust-proof: ensure the exact key the child will look up is trusted, idempotently.
#
# IMPORTANT: we do NOT use ConvertFrom-Json here. PowerShell's JSON parser compares object keys
# CASE-INSENSITIVELY, so a real-world .claude.json that contains both "c:/.../foo" and "C:/.../foo"
# (a common artifact of moving/re-casing a repo) makes ConvertFrom-Json THROW on "duplicate keys",
# which would disable this preflight on exactly the machines that need it most. Instead we do a
# surgical TEXT splice: if our exact key is already present, do nothing; otherwise inject a minimal
# trusted entry right after the top-level "projects": { brace. This never reads/round-trips the whole
# document, so duplicate/case-variant keys elsewhere are harmless. The CLI fills in any missing
# per-project defaults itself.
function Set-WorkspaceTrust {
    param([string]$ProjectPath)
    $cfg = Join-Path $env:USERPROFILE ".claude.json"
    if (-not (Test-Path $cfg)) { return }   # nothing to do if no config yet
    # claude stores project keys with forward slashes, drive letter as Resolve-Path returns it.
    $key = ($ProjectPath -replace '\\','/')
    try {
        $raw = Get-Content -LiteralPath $cfg -Raw -ErrorAction Stop
    } catch {
        Write-Host "! WARNING trust-preflight: could not read $cfg ($($_.Exception.Message)); skipping" -ForegroundColor Yellow
        return
    }
    # Our exact key already in the file (we add it trusted, so presence == done). Case-sensitive.
    if ($raw -cmatch ('"' + [regex]::Escape($key) + '"\s*:')) { return }
    $entry = '"' + $key + '": { "hasTrustDialogAccepted": true, "allowedTools": [], "mcpContextUris": [], "mcpServers": {}, "enabledMcpjsonServers": [], "disabledMcpjsonServers": [] }'
    if ($raw -match '"projects"\s*:\s*\{\s*\}') {
        # empty projects object -> single entry, no trailing comma
        $new = [regex]::Replace($raw, '"projects"\s*:\s*\{\s*\}', '"projects": {' + "`n    " + $entry + "`n  }", 1)
    } else {
        $m = [regex]::Match($raw, '"projects"\s*:\s*\{')
        if (-not $m.Success) {
            Write-Host "! WARNING trust-preflight: no projects block in $cfg; skipping" -ForegroundColor Yellow
            return
        }
        $idx = $m.Index + $m.Length
        # insert our entry first, with a trailing comma before the (existing) next entry
        $new = $raw.Substring(0, $idx) + "`n    " + $entry + ',' + $raw.Substring($idx)
    }
    try {
        Copy-Item $cfg "$cfg.autopilot.bak" -Force -ErrorAction SilentlyContinue
        $enc = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($cfg, $new, $enc)
        Write-Host ">>> trust-preflight: granted workspace trust for $key" -ForegroundColor Cyan
    } catch {
        Write-Host "! WARNING trust-preflight: could not write $cfg ($($_.Exception.Message)); run may still gate" -ForegroundColor Yellow
    }
}
Set-WorkspaceTrust -ProjectPath $RepoRoot

# --- Resolve the story file -------------------------------------------------------------
if (Test-Path $Story) {
    $StoryFile = (Resolve-Path $Story).Path
} else {
    $storiesDir = Join-Path $RepoRoot "_bmad\bmm\stories"
    # Anchor the numeric id with dashes so "14.1" matches story-14-1-... but NOT story-14-10-...
    # Filenames are inconsistent (story-8.14 uses a dot, story-14-1 uses dashes), so normalize BOTH
    # the id and each filename to dashes, then boundary-match (^|-)<id>(-|$).
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
# Every story's frontmatter carries "baseline_commit: <sha>" = the tree state the story was cut
# against. Feeding it to the dev/review stages turns "trust the plan's file list" into a
# git-verifiable scope boundary. If absent, the stages fall back to the soft scope wording.
$BaselineCommit = ""
try {
    $storyHead = Get-Content -LiteralPath $StoryFile -TotalCount 15 -ErrorAction Stop
    foreach ($ln in $storyHead) {
        if ($ln -match '^\s*baseline_commit\s*:\s*(\S+)') { $BaselineCommit = $Matches[1]; break }
    }
} catch { }

# --- Closed-story short-circuit (do this BEFORE any folder/session/stage setup) ----------
# A story marked `Status: done` has already been closed by a human - the pipeline never sets `done`
# itself (it only ever advances ready-for-dev/in-progress -> review). Re-running would just redo
# finished work, so do NOTHING: no folder, no sessions, no stages - say it's already done and exit
# clean (0). Re-open the story (Status -> ready-for-dev/review) to run it again. Checked here, before
# the canonical-folder block, so a done story is fully inert (and stays $0 even without -DryRun).
$StoryStatus = ""
try {
    foreach ($ln in (Get-Content -LiteralPath $StoryFile -TotalCount 15 -ErrorAction Stop)) {
        if ($ln -match '^\s*Status\s*:\s*(\S+)') { $StoryStatus = $Matches[1]; break }
    }
} catch { }
if ($StoryStatus -match '^(?i:done)$') {
    Write-Host ""
    Write-Host ">>> STORY ALREADY DONE - nothing to do." -ForegroundColor Yellow
    Write-Host "    Story : $StoryFile"
    Write-Host "    Status: $StoryStatus  (the pipeline never sets 'done' itself, so a human already closed this story)"
    Write-Host "    Re-open it (set Status back to ready-for-dev/review) if you really want to re-run the pipeline."
    exit 0
}

# --- Canonical artifact folder (STABLE per story across days) ----------------------------
# Reuse an existing run folder for this story if one exists (so a resume the next day finds the
# prior artifacts); prefer one that already holds a plan; only mint a fresh date-stamped folder when
# there is none. The folder is CREATED later (after the DryRun early-exit) so a dry run stays inert.
# Slug from the RESOLVED story id (e.g. "story-14-1-sully-..." -> "14-1") so the folder is always the
# clean "autopilot-14-1" whether launched as "14.1", "14-1", or a full path. Normalize dots to dashes
# first (story-8.14 -> 8-14), then take the leading numeric-dash id; fall back to slugifying the arg.
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
# The folder (and its epic parent) is CREATED later via New-Item -Force, after the DryRun exit, so a
# dry run stays inert.
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

# --- Per-story run lock (concurrency: each STORY is its own run) --------------------------
# $lockFile holds the orchestrator PID - it blocks a SECOND run of the SAME story while one is
# live; DIFFERENT stories run in parallel freely (each writes to its own story folder, log, and
# session store, all keyed by the story id).
$lockFile = Join-Path $LogDir ".run.lock"

# --- Per-team session ids (E1) ----------------------------------------------------------
# One UUID per team, persisted to _pipeline/sessions.json. The id is MINTED when its "new session"
# stage (1 = dev, 2 = qa) actually runs, and saved then - so a forced redo (-ResumeFrom) or a crash
# during a session-creating stage always gets a CLEAN id (no --session-id collision). On resume,
# the ids of already-run stages are loaded back from disk here so their continuation can --resume.
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
        "- Orchestrator PID: $PID  (LIVENESS: if the headline above says IN PROGRESS / TEST GATE but PID $PID is not a running process, the run died mid-flight - treat these artifacts as CRASHED, then re-run with no flags to resume the finished stages)",
        "- This pipeline NEVER commits and NEVER marks the story done; human close-out is always required."
    )
    # WriteAllText = clean UTF-8 (no BOM) so downstream readers (e.g. python json.load) don't choke (F5).
    [System.IO.File]::WriteAllText((Join-Path $Folder "_RUN-STATUS.md"), (($lines -join "`r`n") + "`r`n"))
}

# Re-stamp IN PROGRESS with the running cost + where we are, after each stage (E6 / TUNING-1).
function Set-Progress {
    param([int]$Done, [string]$NextLabel)
    Write-RunStatus "IN PROGRESS - NOT FINISHED" "Completed through Stage $Done of 4. Next: $NextLabel. The 'Total cost so far' below reflects the stages run up to now. If this still says IN PROGRESS and nothing is actively running, the run crashed mid-flight - treat these artifacts as INCOMPLETE."
}

# Mirror the human-readable transcript INTO the run folder (R2-A) so the run is self-contained: a
# reader can open just the folder and see the whole story (stage headers + each stage's result + the
# final banner) without hunting for the global _autopilot-run.log, which lives OUTSIDE the folder and
# was the thing that sent Daniel to the wrong directory. AppendAllText with UTF8Encoding($false) =
# clean UTF-8, no BOM (same encoding discipline as _RUN-STATUS / sessions.json). Best-effort: a logging
# hiccup never affects the run.
function Add-RunLog {
    param([string]$Text)
    try {
        $rl = Join-Path $LogDir "run.log"
        [System.IO.File]::AppendAllText($rl, $Text + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
    } catch { }
}

# Process-identity for the run lock. A bare PID is unsafe: the OS REUSES a dead orchestrator's PID for
# an unrelated process, which would make a stale lock look "alive" and falsely refuse a re-run. We bind
# the lock to PID + the process START TIME (ticks); a reused PID has a different start time => stale.
function Get-ProcStartTicks {
    param([int]$ProcId)
    if ($ProcId -le 0) { return $null }
    try { return [string]((Get-Process -Id $ProcId -ErrorAction Stop).StartTime.Ticks) } catch { return $null }
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

# Effective start stage = max(explicit -ResumeFrom, first stage whose artifact is missing).
$autoStart = 1
for ($s = 1; $s -le 4; $s++) {
    if (Test-StageComplete $s) { $autoStart = $s + 1 } else { break }
}
# -ResumeFrom (>=1) is an explicit override (lets you force a redo from an earlier stage);
# 0 means trust auto-detect.
$startStage = if ($ResumeFrom -ge 1) { $ResumeFrom } else { $autoStart }
if ($startStage -lt 1) { $startStage = 1 }

# --- DryRun: print the resume plan + session ids and exit (no CLI calls, no spend) -------
if ($DryRun) {
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " AUTOPILOT DRY RUN - resume plan" -ForegroundColor Cyan
    Write-Host "   Story  : $StoryFile"
    Write-Host "   Folder : $Folder"
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
    $scShow = if ($MaxStageCost -gt 0) { '$' + ("{0:n2}" -f $MaxStageCost) + "/stage" } else { "disabled" }
    Write-Host "   Cost cap  : $mcShow (stage cap: $scShow)"
    Write-Host "   Sessions (read-back from disk = $(Test-Path $sessionsFile)):"
    $devShow = if ($DevSession) { $DevSession } else { "(minted when Stage 1 runs)" }
    $qaShow  = if ($QaSession)  { $QaSession }  else { "(minted when Stage 2 runs)" }
    Write-Host "     dev = $devShow  ($DevName)"
    Write-Host "     qa  = $qaShow  ($QaName)"
    Write-Host "============================================================" -ForegroundColor Cyan
    exit 0
}

# Real run (not a dry run): create the folder/_pipeline now and mark it in-progress.
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

# --- Per-story run lock: refuse to double-run the SAME story (different stories run in parallel) ---
# Lock body = "<pid>|<startTicks>". A run is "still live" only if that PID is up AND its start time
# matches (defeats PID reuse). Anything else - dead PID, reused PID, our own PID, garbage - is stale
# and reclaimed.
if (Test-Path $lockFile) {
    $oPid = 0; $oTicks = ""
    try {
        $parts = ((Get-Content -Raw -LiteralPath $lockFile).Trim() -split '\|', 2)
        [void][int]::TryParse($parts[0], [ref]$oPid)
        if ($parts.Count -ge 2) { $oTicks = $parts[1] }
    } catch { $oPid = 0 }
    if ($oPid -ne 0 -and $oPid -ne $PID) {
        $liveTicks = Get-ProcStartTicks $oPid
        if ($null -ne $liveTicks -and $liveTicks -eq $oTicks) {
            Write-Host ""
            Write-Host "############################################################" -ForegroundColor Red
            Write-Host " ALREADY RUNNING - story $storyId is locked by live PID $oPid" -ForegroundColor Red
            Write-Host " A run for THIS story is already in progress." -ForegroundColor Red
            Write-Host " Lock: $lockFile" -ForegroundColor Red
            Write-Host " Different stories run in parallel fine; the SAME story cannot double-run." -ForegroundColor Red
            Write-Host " If that process is actually dead, delete that lock file and re-run." -ForegroundColor Red
            Write-Host "############################################################" -ForegroundColor Red
            exit 7
        }
    }
    # Stale lock (dead/reused PID, or it's us) - reclaim it.
}
[System.IO.File]::WriteAllText($lockFile, ("{0}|{1}" -f $PID, (Get-ProcStartTicks $PID)))

Write-RunStatus "IN PROGRESS - NOT FINISHED" "The pipeline is running, or was interrupted. No stage is guaranteed complete. If this file still says IN PROGRESS and nothing is actively running, the run crashed or was killed mid-flight - treat these artifacts as INCOMPLETE, not a finished story."

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " AUTOPILOT DEV-STORY LOOP (v2 - two continuous teams)" -ForegroundColor Cyan
Write-Host "   Story    : $StoryFile"
Write-Host "   Dev ($DevModel @ $DevEffort): session $DevName   QA ($AuditModel @ audit:$AuditEffort review:$ReviewEffort): session $QaName"
Write-Host "   Folder   : $Folder"
Write-Host "   Start    : Stage $startStage (auto=$autoStart, -ResumeFrom=$ResumeFrom) | MaxRetries $MaxRetries"
Write-Host "============================================================" -ForegroundColor Cyan

# --- Stage runner (with transient-error retry + session continuity) ---------------------
function Invoke-Stage {
    param(
        [int]$Num,
        [string]$Name,
        [string]$Model,
        [string]$Effort,
        [string]$Prompt,
        [string]$SessionId,
        [ValidateSet('New','Resume')][string]$SessionMode,
        [string]$SessionName
    )

    $script:CurrentStageLabel = "Stage $Num ($Name)"
    Write-Host ""
    Write-Host ">>> STAGE $Num/4 - $Name  [$Model | session $SessionMode]" -ForegroundColor Yellow
    Add-RunLog ""
    Add-RunLog ">>> STAGE $Num/4 - $Name  [$Model | session $SessionMode]"
    $logFile = Join-Path $LogDir ("stage{0}-{1}.json" -f $Num, ($Name.ToLower() -replace '[^a-z0-9]+','-'))

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        Push-Location $RepoRoot
        try {
            $cargs = @(
                '-p', $Prompt,
                '--model', $Model,
                '--permission-mode', 'bypassPermissions',
                '--output-format', 'json'
            )
            # Reasoning effort for this stage (depth control on Fable 5 / Opus 4.8; see -DevEffort/-AuditEffort).
            if ($Effort) { $cargs += @('--effort', $Effort) }
            # Per-stage runaway cap: the CLI halts its own call once THIS stage's spend crosses the
            # cap, so a stuck stage can't blow far past -MaxCost before the between-stage check fires.
            if ($MaxStageCost -gt 0) {
                $cargs += @('--max-budget-usd', $MaxStageCost.ToString([System.Globalization.CultureInfo]::InvariantCulture))
            }
            # Continuity: assign our id on the first call of a team, resume it on the second.
            if ($SessionMode -eq 'New') {
                $cargs += @('--session-id', $SessionId, '--name', $SessionName)
            } else {
                $cargs += @('--resume', $SessionId)
            }
            # Empty stdin avoids the 3s "no stdin" wait; 2>$null drops PS native-stderr wrapping.
            $raw = $null | & $Claude @cargs 2>$null | Out-String
        } finally {
            Pop-Location
        }
        $sw.Stop()

        # Always persist the latest raw output so even a final failure is inspectable.
        # WriteAllText -> UTF-8 WITHOUT BOM (PS 5.1 Set-Content -Encoding utf8 adds a BOM that trips python json.load).
        # Self-heal + non-fatal: the stage's `claude` call already SUCCEEDED and cost money; a headless
        # agent that wiped the untracked _pipeline dir mid-stage (e.g. a `git clean -fd` during scope
        # checks) must NOT crash an otherwise-good stage over a DIAGNOSTIC write. Recreate the dir if it
        # vanished; if the write still fails, warn and carry on (the artifact-presence check is what gates).
        try {
            if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Force -Path $LogDir | Out-Null }
            [System.IO.File]::WriteAllText($logFile, $raw)
        } catch {
            Write-Host "  ! WARNING: could not write stage log $logFile ($($_.Exception.Message)); continuing" -ForegroundColor DarkYellow
        }

        $j = $null
        try { $j = $raw | ConvertFrom-Json } catch { $j = $null }

        $failed = ($null -eq $j) -or [bool]$j.is_error
        if (-not $failed) {
            $cost = [double]$j.total_cost_usd
            $script:TotalCost += $cost
            Write-Host ("  done in {0:n0}s | cost `$" -f $sw.Elapsed.TotalSeconds + ("{0:n2}" -f $cost) + (" | turns {0}" -f $j.num_turns)) -ForegroundColor DarkGray
            # Model-assertion (#5): modelUsage is keyed by the model that ACTUALLY served the request.
            $served = @()
            if ($j.modelUsage) { $served = @($j.modelUsage.PSObject.Properties.Name) }
            if ($served.Count -gt 0 -and ($served -notcontains $Model)) {
                Write-Host ("  ! MODEL MISMATCH: requested {0} but served {1}" -f $Model, ($served -join ', ')) -ForegroundColor Red
                $script:ModelMismatch += "Stage $Num ($Name): requested $Model, served $($served -join ', ')"
            }
            Write-Host "  ---- result ----"
            Write-Host $j.result
            Add-RunLog ("  done in {0:n0}s | cost `$" -f $sw.Elapsed.TotalSeconds + ("{0:n2}" -f $cost) + (" | turns {0}" -f $j.num_turns))
            Add-RunLog "  ---- result ----"
            Add-RunLog ([string]$j.result)
            return [string]$j.result
        }

        # Failed. Transient? (stream idle timeout, overload, rate-limit, 5xx, generic API Error)
        $errText = if ($null -eq $j) { $raw } else { "$($j.result) $($j.api_error_status)" }
        # Budget-cut by -MaxStageCost (--max-budget-usd)? Deliberate halt - NEVER retry (a retry
        # would pay the stage cap again). Stop CRASHED-resumable with a targeted message instead.
        if ($MaxStageCost -gt 0 -and $errText -match 'budget') {
            throw ("Stage $Num ($Name) hit the per-stage budget cap (-MaxStageCost `$" + ("{0:n2}" -f $MaxStageCost) + ") and was halted mid-work; its artifact was NOT finished. Re-run with a higher -MaxStageCost (or 0 to disable) - finished stages auto-skip.  (raw saved to $logFile)")
        }
        $transient = $errText -match 'Stream idle timeout|overloaded|API Error|partial response|rate.?limit|429|503|529|timeout'
        if ($transient -and $attempt -lt $MaxRetries) {
            $backoff = @(5,15,30)[[Math]::Min($attempt - 1, 2)]
            Write-Host ("  ! transient error (attempt {0}/{1}) - retrying in {2}s..." -f $attempt, $MaxRetries, $backoff) -ForegroundColor DarkYellow
            Start-Sleep -Seconds $backoff
            continue
        }

        $why = if ($null -eq $j) { "unparseable CLI output" } else { "is_error - $($j.result)" }
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
# NOTE: Assert-Verdict (the literal PIPELINE_*_OK token gate) was REMOVED. It crashed complete,
# tests-green stages over a missing string (the model phrases its verdict naturally). This pipeline is
# human-in-the-loop: Daniel reviews the folder, so the run trusts the artifacts on disk, not a token.
function Assert-Artifact { param([string]$RelName, [string]$Hint = "", [switch]$Soft)
    $p = Join-Path $Folder $RelName
    if (Test-Path $p) { return }
    if ($Soft) {
        # Stage 4 ONLY: a dedicated downstream check (REVIEW INCOMPLETE / exit 6) handles a missing
        # code-review.md AFTER the independent test gate, so here it's a warning, not a crash.
        Write-Host "  ! WARNING: expected artifact not found: $p" -ForegroundColor DarkYellow
        if ($Hint) { Write-Host "    $Hint" -ForegroundColor DarkYellow }
        return
    }
    # Stages 1-3: a missing handoff artifact is a HARD STOP - never "continue to the next stage". A
    # corrupted stage (e.g. Stage 1 wrote no implementation_plan.md - the 14-7 failure) must not advance
    # and burn spend on empty downstream work. Throwing lands in the relay's catch, which stamps CRASHED
    # in _RUN-STATUS.md (resumable: re-run with no flags and the finished stages auto-detect + skip).
    $msg = "Stage handoff artifact missing: $p"
    if ($Hint) { $msg += "  ($Hint)" }
    throw $msg
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

function Get-PytestPython {
    # Project venv lives at backend\.venv (not repo-root .venv); check both before falling back to
    # PATH, so a headless gate (-NoProfile, no activation) still finds pytest instead of a system python.
    $venvCandidates = @(
        (Join-Path $RepoRoot "backend\.venv\Scripts\python.exe"),
        (Join-Path $RepoRoot ".venv\Scripts\python.exe")
    )
    $venvPy = $venvCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($venvPy) { return $venvPy }
    $sys = Get-Command python -ErrorAction SilentlyContinue
    if ($sys) { return $sys.Source }
    return $null
}

function Read-JUnitFailures {
    # Return a string[] of "classname::name" for every testcase with a <failure> or <error> child.
    # Used to diff the post-implementation RED set against the pre-implementation baseline snapshot so
    # the gate fails only on NEW regressions, not tests that were already red before this story.
    param([string]$XmlPath)
    if (-not (Test-Path $XmlPath)) { return @() }
    try { [xml]$doc = Get-Content -LiteralPath $XmlPath -Raw -ErrorAction Stop } catch { return @() }
    $ids = New-Object System.Collections.Generic.List[string]
    foreach ($tc in $doc.SelectNodes('//testcase')) {
        $bad = $false
        foreach ($c in $tc.ChildNodes) {
            if ($c.LocalName -eq 'failure' -or $c.LocalName -eq 'error') { $bad = $true; break }
        }
        if ($bad) { $ids.Add(([string]$tc.classname) + '::' + ([string]$tc.name)) }
    }
    # Emit the ids as a flat stream; every caller wraps the call in @() to collect a clean string[].
    # (Do NOT use the ',' array-wrap operator here - on a multi-element result it double-wraps into a
    # single object holding the whole array, which breaks the -notcontains diff and the .Count.)
    return $ids.ToArray()
}

function Convert-ToPytestNodeId {
    # junit "classname::name" (classname = dotted module[.Class...]) -> pytest "path/file.py::[Class::]name".
    # The module/class boundary is ambiguous in dotted form, so find the LONGEST dotted prefix that maps to
    # a real .py file on disk; any remainder is the class path. Returns $null if no file prefix resolves.
    param([string]$Id)
    $sep = $Id.IndexOf('::')
    if ($sep -lt 0) { return $null }
    $cls  = $Id.Substring(0, $sep)
    $name = $Id.Substring($sep + 2)
    $parts = $cls -split '\.'
    for ($k = $parts.Count; $k -ge 1; $k--) {
        $fileRel = ($parts[0..($k-1)] -join '/') + '.py'
        if (Test-Path (Join-Path $RepoRoot $fileRel)) {
            if ($k -lt $parts.Count) {
                $classParts = $parts[$k..($parts.Count-1)]
                return $fileRel + '::' + ($classParts -join '::') + '::' + $name
            }
            return $fileRel + '::' + $name
        }
    }
    return $null
}

function Confirm-NewFailures {
    # Flaky-test guard. Re-run the new-failure tests in ISOLATION; return only those that STILL fail (real
    # regressions). A test that passes on the isolated re-run was order/state-dependent flaky in the full
    # suite - it is dropped from the gate verdict (but logged loudly). Unmappable ids are kept (fail-closed).
    param([string[]]$NewIds, [string]$Py)
    $nodeIds = @(); $unmapped = @()
    foreach ($id in $NewIds) {
        $n = Convert-ToPytestNodeId $id
        if ($n) { $nodeIds += $n } else { $unmapped += $id }
    }
    if ($nodeIds.Count -eq 0) { return $NewIds }   # mapped nothing; keep all (fail-closed)
    Write-Host (">>> TEST GATE - confirming " + $NewIds.Count + " new failure(s) via isolated re-run (flaky guard)") -ForegroundColor Yellow
    $confirmJunit = Join-Path $LogDir "gate-confirm-backend.xml"
    Push-Location $RepoRoot
    try { & $Py -m pytest @nodeIds -q -p no:cacheprovider --junitxml=$confirmJunit 2>&1 | Out-Null } finally { Pop-Location }
    $stillRed  = @(Read-JUnitFailures $confirmJunit)
    $confirmed = @($NewIds | Where-Object { ($stillRed -contains $_) -or ($unmapped -contains $_) })
    $flaky     = @($NewIds | Where-Object { $confirmed -notcontains $_ })
    if ($flaky.Count -gt 0) {
        Write-Host (">>> TEST GATE - " + $flaky.Count + " new failure(s) cleared as FLAKY (passed isolated re-run):") -ForegroundColor DarkYellow
        foreach ($f in ($flaky | Select-Object -First 25)) { Write-Host ("     ~ " + $f) -ForegroundColor DarkYellow }
        Add-RunLog ("Flaky (passed isolated re-run, dropped from gate): " + ($flaky -join '; '))
    }
    return $confirmed
}

function Test-BackendInScope {
    # Does this run's TestScope include the BACKEND (pytest) suite? Used to skip the backend baseline
    # for frontend-only / none stories (OPT-2: the gate already auto-scopes; the baseline must match it,
    # or a frontend-only story pays ~100s of backend pytest for a snapshot the gate will never read).
    # KEEP IN SYNC with Invoke-TestGate's auto-derivation below.
    if ($TestScope -eq 'none' -or $TestScope -eq 'frontend') { return $false }
    if ($TestScope -eq 'backend' -or $TestScope -eq 'both')  { return $true }
    # auto: derive from what the story changed since its baseline commit (same rules as the gate).
    if ($BaselineCommit) {
        $changed = @()
        Push-Location $RepoRoot
        try { $changed = & git diff --name-only $BaselineCommit 2>$null } catch { $changed = @() } finally { Pop-Location }
        $contractRe = '(?i)((^|/)schemas?(/|\.py$|\.ts$)|(^|/)models\.py$|openapi|\.proto$|(^|/)contracts?/|\.generated\.(ts|js|py)$|api[._-]?types)'
        if (($changed -match '^backend/') -or ($changed -match $contractRe)) { return $true }
        if ($changed -match '^frontend/') { return $false }   # frontend-only -> no backend baseline needed
    }
    return $true   # no baseline / no signal -> can't scope safely, capture it (matches the gate's fail-safe)
}

# --- Pre-implementation RED baseline: async start (OPT-1) + synchronous fallback -------------
# The baseline pytest (~100s) only has to snapshot the tree BEFORE Stage 3 writes code. Stages 1 (Plan)
# and 2 (Audit) are pure LLM turns that never touch the test runner, so we KICK IT OFF as a background
# job at the top of the relay and JOIN it just before Stage 3 - hiding its ~100s entirely behind the
# planning stages, with the SAME pre-story-tree guarantee (1-2 write no code). Start/Complete are a
# matched pair: if the async path is skipped (resume with a cached snapshot, no runner, out of scope, or
# a plan/audit-only trial), Complete falls back to the original synchronous Capture-BaselineRedSet, so
# behavior is byte-identical to before.
$script:BaselineJob   = $null
$script:BaselineJunit = $null
$script:BaselineSnap  = $null

function Start-BaselineRedSet {
    # Launch the baseline pytest concurrently with Stages 1-2. Leaves $script:BaselineJob = $null (so
    # Complete does the synchronous capture) when out of backend scope, snapshot already cached (resume),
    # or no python runner. The caller guards this to only fire when Stage 3 will actually run this pass.
    if (-not (Test-BackendInScope)) { return }
    $snap = Join-Path $LogDir "baseline-red-backend.txt"
    if (Test-Path $snap) { return }        # already captured earlier in this (resumed) run
    $py = Get-PytestPython
    if (-not $py) { return }               # no runner; Complete -> Capture will degrade + warn
    $junit = Join-Path $LogDir "baseline-junit-backend.xml"
    $txt   = Join-Path $LogDir "baseline-red-backend-output.txt"
    try {
        $script:BaselineJob = Start-Job -Name "baseline-red" -ScriptBlock {
            param($Py, $Root, $Junit, $Txt)
            Set-Location $Root
            & $Py -m pytest backend/tests -q -p no:cacheprovider --junitxml=$Junit 2>&1 |
                Out-File -FilePath $Txt -Encoding utf8
        } -ArgumentList $py, $RepoRoot, $junit, $txt
        $script:BaselineJunit = $junit
        $script:BaselineSnap  = $snap
        Write-Host ""
        Write-Host ">>> TEST GATE - baseline snapshot started in background (runs during Plan/Audit, ~100s hidden)" -ForegroundColor DarkCyan
    } catch {
        $script:BaselineJob = $null        # Start-Job failed -> Complete falls back to synchronous capture
    }
}

function Complete-BaselineRedSet {
    # Join the async baseline (started at the top of the relay). If none was started, run the original
    # synchronous capture, which itself no-ops on the cached/no-runner/out-of-scope paths.
    if (-not $script:BaselineJob) { Capture-BaselineRedSet; return }
    Write-Host ""
    Write-Host ">>> TEST GATE - joining pre-implementation baseline (ran during Plan/Audit)..." -ForegroundColor DarkCyan
    Wait-Job    $script:BaselineJob | Out-Null
    Receive-Job $script:BaselineJob 2>&1 | Out-Null   # drain output/errors so Remove-Job is clean
    Remove-Job  $script:BaselineJob -Force
    $script:BaselineJob = $null
    $fails = @(Read-JUnitFailures $script:BaselineJunit)
    [System.IO.File]::WriteAllLines($script:BaselineSnap, $fails, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host (">>> TEST GATE - baseline: " + $fails.Count + " test(s) already red before this story (the gate will ignore these)") -ForegroundColor DarkCyan
    Add-RunLog (">>> TEST GATE - baseline snapshot (async): " + $fails.Count + " pre-existing red test(s) recorded")
}

function Capture-BaselineRedSet {
    # Snapshot the working tree's RED set BEFORE Stage 3 writes any code, so the gate can tell a true
    # regression (green-before, red-now) from a failure that was ALREADY red (unrelated WIP / pre-existing
    # breakage). Captured once per run, cached in the run folder so a resume reuses the pre-work baseline
    # (re-capturing at gate time would be contaminated by the story's own changes). Backend (pytest) only
    # for now; the frontend suite still uses the raw gate.
    if (-not (Test-BackendInScope)) { return }   # OPT-2: skip for none/frontend-only (matches the gate's scope)
    $snap = Join-Path $LogDir "baseline-red-backend.txt"
    if (Test-Path $snap) { return }   # already captured earlier in this (resumed) run
    $py = Get-PytestPython
    if (-not $py) { return }           # no runner; the gate will degrade + warn
    Write-Host ""
    Write-Host ">>> TEST GATE - baseline snapshot (pre-implementation pytest, ~100s, once)" -ForegroundColor DarkCyan
    $junit = Join-Path $LogDir "baseline-junit-backend.xml"
    $txt   = Join-Path $LogDir "baseline-red-backend-output.txt"
    Push-Location $RepoRoot
    try { & $py -m pytest backend/tests -q -p no:cacheprovider --junitxml=$junit 2>&1 | Tee-Object -FilePath $txt | Out-Null } finally { Pop-Location }
    $fails = @(Read-JUnitFailures $junit)
    [System.IO.File]::WriteAllLines($snap, $fails, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host (">>> TEST GATE - baseline: " + $fails.Count + " test(s) already red before this story (the gate will ignore these)") -ForegroundColor DarkCyan
    Add-RunLog (">>> TEST GATE - baseline snapshot: " + $fails.Count + " pre-existing red test(s) recorded")
}

function Stop-OnRedTests {
    param([string]$Suite, [string]$LogPath, [string[]]$NewFailures = @())
    Write-Host ""
    Write-Host "############################################################" -ForegroundColor Red
    Write-Host " TESTS RED - $Suite failed the pipeline's independent test gate" -ForegroundColor Red
    Write-Host " Output: $LogPath" -ForegroundColor Red
    if ($NewFailures.Count -gt 0) {
        Write-Host (" " + $NewFailures.Count + " NEW failure(s) since the pre-implementation baseline:") -ForegroundColor Red
        foreach ($f in ($NewFailures | Select-Object -First 25)) { Write-Host ("   - " + $f) -ForegroundColor Red }
        Add-RunLog ("NEW failures since baseline (" + $NewFailures.Count + "): " + ($NewFailures -join '; '))
    }
    Write-Host "############################################################" -ForegroundColor Red
    if ($NewFailures.Count -gt 0) {
        $detail = "The independent gate found " + $NewFailures.Count + " test(s) that were GREEN before this story's changes and are RED now - true regressions from this run. See $LogPath (the NEW failures are listed in run.log). Resume with -ResumeFrom 4 so QA fixes them, then re-run."
    } else {
        $detail = "The independent test gate ran $Suite after the agents finished and it FAILED. The story is NOT verified-green - see $LogPath. If the failures are a PARALLEL team's uncommitted WIP (not this story), confirm your story's own tests pass and re-run with -TestScope none. Otherwise resume with -ResumeFrom 4 so QA fixes it."
    }
    Write-RunStatus "TESTS RED - NOT FINISHED" $detail
    exit 4
}

function Invoke-TestGate {
    param([string]$Scope)
    if ($Scope -eq 'none') {
        Write-Host ""
        Write-Host ">>> TEST GATE - skipped (-TestScope none)" -ForegroundColor DarkYellow
        return
    }

    # Resolve which suites to run.
    $runBackend  = $false
    $runFrontend = $false
    switch ($Scope) {
        'backend'  { $runBackend = $true }
        'frontend' { $runFrontend = $true }
        'both'     { $runBackend = $true; $runFrontend = $true }
        default {
            # auto: derive scope from what the story changed since its baseline commit. Backend-only
            # diff -> pytest only; frontend-only -> vitest only; a change to a shared cross-stack
            # contract (schemas / models / OpenAPI / generated types) escalates to BOTH, because a
            # contract drift can red the suite on the side that did NOT change. No baseline / no
            # signal -> run everything (can't scope safely).
            if ($BaselineCommit) {
                $changed = @()
                Push-Location $RepoRoot
                try { $changed = & git diff --name-only $BaselineCommit 2>$null } catch { $changed = @() } finally { Pop-Location }
                if ($changed -match '^backend/')  { $runBackend = $true }
                if ($changed -match '^frontend/') { $runFrontend = $true }
                # Shared API-contract files only - tuned to real contracts, NOT general backend/frontend code.
                $contractRe = '(?i)((^|/)schemas?(/|\.py$|\.ts$)|(^|/)models\.py$|openapi|\.proto$|(^|/)contracts?/|\.generated\.(ts|js|py)$|api[._-]?types)'
                if ($changed -match $contractRe) {
                    $runBackend = $true; $runFrontend = $true
                    Write-Host ">>> TEST GATE - shared contract changed -> running BOTH suites" -ForegroundColor DarkCyan
                }
            }
            if (-not $runBackend -and -not $runFrontend) { $runBackend = $true; $runFrontend = $true }
        }
    }

    Write-Host ""
    Write-Host ">>> TEST GATE - independent verification (backend=$runBackend frontend=$runFrontend)" -ForegroundColor Yellow

    if ($runBackend) {
        $log   = Join-Path $LogDir "gate-tests-backend.txt"
        $junit = Join-Path $LogDir "gate-junit-backend.xml"
        $py = Get-PytestPython
        if (-not $py) {
            Write-Host " TESTS UNVERIFIED - no python interpreter for pytest" -ForegroundColor Red
            Write-RunStatus "TESTS UNVERIFIED - RUNNER MISSING" "The test gate could not find a Python interpreter (.venv or python on PATH) to run pytest, so COMPLETE would be unverified. Fix the env or pass -TestScope none (after confirming tests manually), then resume with -ResumeFrom 4."
            exit 4
        }
        Write-Host ">>> TEST GATE - backend: pytest backend/tests -q" -ForegroundColor Yellow
        Push-Location $RepoRoot
        try { & $py -m pytest backend/tests -q -p no:cacheprovider --junitxml=$junit | Tee-Object -FilePath $log } finally { Pop-Location }
        $gateCode = $LASTEXITCODE
        if ($gateCode -ne 0) {
            # Baseline-aware verdict: a non-zero exit only fails the gate if there are NEW failures vs the
            # pre-implementation snapshot. Tests that were already red before Stage 3 (unrelated WIP /
            # pre-existing breakage) are reported but never block a correct story.
            $snap = Join-Path $LogDir "baseline-red-backend.txt"
            if (Test-Path $snap) {
                $baseline = @(Get-Content -LiteralPath $snap -ErrorAction SilentlyContinue | Where-Object { $_ -ne '' })
                $nowRed   = @(Read-JUnitFailures $junit)
                $new      = @($nowRed | Where-Object { $baseline -notcontains $_ })
                $pre      = $nowRed.Count - $new.Count
                if ($new.Count -eq 0) {
                    Write-Host (">>> TEST GATE - backend GREEN vs baseline (" + $pre + " pre-existing red ignored, 0 new regressions)") -ForegroundColor Green
                    Add-RunLog (">>> TEST GATE - backend GREEN vs baseline (" + $pre + " pre-existing red ignored, 0 new)")
                } else {
                    # A "new" failure may just be order/state-dependent flakiness in the full-suite run.
                    # Re-run the new failures in isolation; only the ones that STILL fail block the gate.
                    $confirmed = @(Confirm-NewFailures -NewIds $new -Py $py)
                    if ($confirmed.Count -eq 0) {
                        Write-Host (">>> TEST GATE - backend GREEN vs baseline (" + $pre + " pre-existing red ignored; all " + $new.Count + " new failure(s) cleared as flaky)") -ForegroundColor Green
                        Add-RunLog (">>> TEST GATE - backend GREEN vs baseline (" + $pre + " pre-existing; " + $new.Count + " new cleared as flaky)")
                    } else {
                        Stop-OnRedTests "backend (pytest)" $log $confirmed
                    }
                }
            } else {
                Write-Host "! WARNING: no pre-implementation baseline snapshot found - using raw full-suite verdict" -ForegroundColor Yellow
                Stop-OnRedTests "backend (pytest)" $log
            }
        }
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

# --- Advance the story to 'review' on a green gate (R2-D) --------------------------------
# Reaching here means all stages ran AND the independent gate passed (RED/UNVERIFIED/PARTIAL all
# exited earlier). The dev+review work is genuinely complete and awaiting Daniel, so the story's
# lifecycle should sit at 'review' (the BMAD "Dev finishes -> review" step), NOT stay 'ready-for-dev'.
# Rules: NEVER 'done' (the human owns review->done); idempotent (only ready-for-dev/in-progress are
# advanced; review/done are left alone); best-effort (a flip failure NEVER crashes a finished run -
# the work already succeeded, Daniel can flip by hand). Mirrors the QA dual-write: story .md AND
# sprint-status.yaml, kept in sync.
function Set-StoryReview {
    try {
        # 1) Story .md frontmatter: Status: ready-for-dev|in-progress -> review.
        $txt = [System.IO.File]::ReadAllText($StoryFile)
        $new = [regex]::Replace($txt, '(?im)^(Status:\s*)(ready-for-dev|in-progress)\s*$', '${1}review')
        if ($new -ne $txt) {
            [System.IO.File]::WriteAllText($StoryFile, $new)
            Write-Host ">>> STORY STATUS - story file flipped to review" -ForegroundColor Green
            Add-RunLog ">>> STORY STATUS - story file flipped to review"
        } else {
            Write-Host ">>> STORY STATUS - story file not at ready-for-dev/in-progress (left as-is)" -ForegroundColor DarkGray
        }

        # 2) sprint-status.yaml: <story-key>: ready-for-dev|in-progress -> review (preserve comment).
        # Key = story filename without 'story-' prefix / '.md' (e.g. 14-2-delete-v1-dossier-skeletons).
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
        # Human-in-the-loop: never crash a finished, green run over a status-flip hiccup.
        Write-Host "  ! WARNING: could not auto-flip story to review: $($_.Exception.Message)" -ForegroundColor DarkYellow
        Write-Host "    The run SUCCEEDED; flip the story to review by hand at close-out." -ForegroundColor DarkYellow
    }
}

# --- Scope guidance injected into the dev (Stage 3) + review (Stage 4) prompts -----------
# With a baseline commit we make scope git-verifiable instead of "trust the plan's file list".
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

# Kick off the pre-implementation RED baseline NOW (OPT-1) so its ~100s runs CONCURRENTLY with the Plan
# and Audit stages instead of serially before Stage 3. Guarded to only fire when Stage 3 will actually
# run this pass: a plan/audit-only trial (-MaxStage < 3) or a resume past implement (-ResumeFrom > 3)
# needs no fresh baseline. Complete-BaselineRedSet (just before Stage 3) joins it or captures synchronously.
if ($startStage -le 3 -and $MaxStage -ge 3) { Start-BaselineRedSet }

# --- STAGE 1 - PLAN (Dev/Amelia, NEW dev session) ---------------------------------------
if ($startStage -le 1) {
    # Mint a fresh dev-session id for this run and persist it (clean id even on a forced redo).
    $DevSession = [guid]::NewGuid().ToString()
    [System.IO.File]::WriteAllText($sessionsFile, (@{ dev = $DevSession; qa = $QaSession } | ConvertTo-Json -Compress))
    $prompt1 = @"
$teamPreamble

/sudo-dev-story-tests_AP plan

You are Amelia (Dev), Stage 1 of 4 (PLAN). Headless in $ProjectName.
- Shared run folder (write the plan here; create no new folder): $Folder
- Target story: $StoryFile
Your full stage instructions live in the /sudo-dev-story-tests_AP command above.
"@
    $r1 = Invoke-Stage -Num 1 -Name "Plan" -Model $DevModel -Effort $DevEffort -Prompt $prompt1 -SessionId $DevSession -SessionMode New -SessionName $DevName
    Stop-OnBlocker -Result $r1 -Num 1 -Name "Plan"
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
    # Mint a fresh qa-session id for this run and persist it (preserving the dev id).
    $QaSession = [guid]::NewGuid().ToString()
    [System.IO.File]::WriteAllText($sessionsFile, (@{ dev = $DevSession; qa = $QaSession } | ConvertTo-Json -Compress))
    $prompt2 = @"
$teamPreamble

/sudo-self-audit_AP

You are Murat (QA), Stage 2 of 4 (PRE-DEV AUDIT). think hard. Headless in $ProjectName.
- Shared run folder (read the plan here; write the audit here): $Folder
- Target story: $StoryFile
Your full stage instructions live in the /sudo-self-audit_AP command above.
"@
    $r2 = Invoke-Stage -Num 2 -Name "Audit" -Model $AuditModel -Effort $AuditEffort -Prompt $prompt2 -SessionId $QaSession -SessionMode New -SessionName $QaName
    Stop-OnBlocker -Result $r2 -Num 2 -Name "Audit"
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
    # Join the pre-implementation RED baseline (kicked off at the top of the relay so it ran during
    # Plan/Audit). Complete falls back to a synchronous capture if no async job was started. Either way
    # the snapshot reflects the tree BEFORE this stage writes code, so the post-Stage-4 gate can ignore
    # already-red tests and fail only on regressions THIS run introduces.
    Complete-BaselineRedSet
    $prompt3 = @"
$teamPreamble

/sudo-dev-story-tests_AP implement

You are Amelia (Dev), Stage 3 of 4 (IMPLEMENT). Headless in $ProjectName.
- Shared run folder (read plan + audit here; write the walkthrough here): $Folder
- Target story: $StoryFile
$scopeGuidance
Your full stage instructions live in the /sudo-dev-story-tests_AP command above.
"@
    $r3 = Invoke-Stage -Num 3 -Name "Implement" -Model $DevModel -Effort $DevEffort -Prompt $prompt3 -SessionId $DevSession -SessionMode Resume
    Stop-OnBlocker -Result $r3 -Num 3 -Name "Implement"
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
You are RESUMING your own QA session. Amelia (Dev) has ALREADY finished Stage 3 - the implementation
and walkthrough.md are complete on disk. Do NOT re-run, re-verify, or re-summarize Stage 3, and do NOT
write as Amelia or narrate "implementing" - that work is done. Your ONLY job now is the REVIEW + FIX
pass, and your ONE required deliverable is code-review.md (the three-pass review) in the shared folder.
If you end this stage without writing code-review.md, you have FAILED it.
- Shared run folder (read plan + audit + walkthrough here; write code-review.md here): $Folder
- Target story: $StoryFile
$scopeGuidance
Your full stage instructions live in the /sudo-code-review_AP command above.
"@
    $r4 = Invoke-Stage -Num 4 -Name "Review" -Model $AuditModel -Effort $ReviewEffort -Prompt $prompt4 -SessionId $QaSession -SessionMode Resume
    Stop-OnBlocker -Result $r4 -Num 4 -Name "Review"
    Assert-Artifact "code-review.md" "If the review landed under another name, rename it to code-review.md; a plain re-run skips the finished stages." -Soft
} else {
    Write-Host ""
    Write-Host ">>> STAGE 4/4 - Review+Fix  [SKIPPED - artifact present]" -ForegroundColor DarkGray
}

# Stage 4's one required deliverable is code-review.md. Unlike stages 1-3 (a later stage or the human can
# recover a missing handoff), a missing review at the LAST stage means the review never happened and
# nothing downstream can recover it - so we must NOT advance the story to 'review' on a silent no-op.
$reviewOk = Test-Path (Join-Path $Folder "code-review.md")

# --- Independent test gate: the pipeline VERIFIES green; it does not trust pasted output --
# Only a full run reaches here (Stop-Trial exits earlier for -MaxStage < 4).
# Re-stamp BEFORE the gate (R2-B): the gate runs both suites (~100s) and Set-Progress last fired at
# Stage 3, so a "status?" query during the gate would otherwise read a full stage stale ("Next: Stage 4").
Write-RunStatus "IN PROGRESS - TEST GATE" "All 4 stages complete; the pipeline is now running its independent test gate (pytest / vitest) before COMPLETE. If this persists with nothing running, the gate crashed - re-run with no flags (finished stages auto-detect from the folder and skip)."
Invoke-TestGate -Scope $TestScope

# Gate is green (RED / UNVERIFIED / PARTIAL all exited earlier). Advance the story to 'review' ONLY if
# Stage 4 actually produced its review artifact; a green gate with no code-review.md means QA's review
# leg silently no-op'd, and flipping the story would falsely claim it was reviewed. (R2-D + review-gate)
if (-not $reviewOk) {
    Write-Host ""
    Write-Host "############################################################" -ForegroundColor Red
    Write-Host " REVIEW INCOMPLETE - Stage 4 produced no code-review.md" -ForegroundColor Red
    Write-Host " The independent test gate is GREEN, but QA's review artifact is missing, so the story" -ForegroundColor Red
    Write-Host " was NOT advanced to 'review'. Redo the review with:  -ResumeFrom 4" -ForegroundColor Red
    Write-Host "############################################################" -ForegroundColor Red
    Write-RunStatus "REVIEW INCOMPLETE - NOT FINISHED" "All 4 stages ran and the independent test gate is GREEN, but Stage 4 did NOT write code-review.md - QA's review did not complete, so the story was NOT advanced to 'review'. Re-run with -ResumeFrom 4 to redo the review (the qa session resumes from cache). Do not treat this story as reviewed until code-review.md exists."
    Add-RunLog " REVIEW INCOMPLETE - no code-review.md; story NOT advanced. Resume with -ResumeFrom 4."
    exit 6
}
Set-StoryReview

# =======================================================================================
#  DONE - hand back to Daniel
# =======================================================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " AUTOPILOT COMPLETE" -ForegroundColor Green
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
Write-RunStatus "PIPELINE COMPLETE - but NOT closed out" ("All stages ran and the independent test gate is green; the pipeline advanced the story to 'review' (story file + sprint-status), but does NOT commit and does NOT mark it 'done'. Human close-out REQUIRED: review walkthrough.md (OUT-OF-SPEC DECISIONS + OPEN QUESTIONS sections) + decisions-log.md, run /sudo-update-sprint-memory, flip review -> done, then commit. Until then the story is NOT finished." + $modelNote)

}
catch {
    # Any hard failure (retries exhausted, missing artifact, unexpected throw) lands here.
    $msg = $_.Exception.Message
    Write-Host ""
    Write-Host "############################################################" -ForegroundColor Red
    Write-Host " CRASHED at $script:CurrentStageLabel" -ForegroundColor Red
    Write-Host " $msg" -ForegroundColor Red
    Write-Host " Artifacts: $Folder" -ForegroundColor Red
    Write-Host " Re-run with no flags - finished stages auto-detect from the folder and skip." -ForegroundColor Red
    Write-Host "############################################################" -ForegroundColor Red
    Write-RunStatus "CRASHED - NOT FINISHED" "CRASHED at $script:CurrentStageLabel - $msg  This is a GENUINE error (e.g. the API failed after retries or a stage produced no handoff artifact), not a verdict/format check - those gates were removed. Re-run with no flags: finished stages auto-detect from the folder and skip, so nothing completed is re-spent."
    exit 3
}
finally {
    # Release the per-story run lock if WE own it (PID match). Best-effort: a hard kill that skips this
    # still self-heals - the next run reclaims the lock via the dead-PID check above. Never deletes
    # another run's lock.
    try {
        if ($lockFile -and (Test-Path $lockFile)) {
            $owner = 0
            try { [void][int]::TryParse(((Get-Content -Raw -LiteralPath $lockFile).Trim() -split '\|', 2)[0], [ref]$owner) } catch { $owner = 0 }
            if ($owner -eq $PID) { Remove-Item $lockFile -Force -ErrorAction SilentlyContinue }
        }
    } catch { }
}
