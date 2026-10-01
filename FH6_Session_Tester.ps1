# FH6 Proximity VC Session Tester
# External, read-only multiplayer/session diagnostic for Windows.
# No injection, process-memory reading, game-file modification, or packet payload capture.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "SilentlyContinue"
$script:Running = $false
$script:ForzaExe = $null
$script:ForzaProcessName = "forzahorizon6"
$script:ForzaPid = $null
$script:RunDir = $null
$script:MainLog = $null
$script:SocketCsv = $null
$script:ProcessCsv = $null
$script:TextHits = $null
$script:PktEtl = $null
$script:PktTxt = $null
$script:StartedAt = $null
$script:LastProcessSet = @{}
$script:PktmonStarted = $false

$BaseDir = Join-Path $env:LOCALAPPDATA "ForzaSessionProbe"
New-Item -ItemType Directory -Force -Path $BaseDir | Out-Null

function Color([string]$hex) {
    [Drawing.ColorTranslator]::FromHtml($hex)
}

function Log([string]$msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $line = "[$ts] $msg"
    $txt.AppendText($line + [Environment]::NewLine)
    $txt.SelectionStart = $txt.TextLength
    $txt.ScrollToCaret()
    if ($script:Running -and $script:MainLog) {
        Add-Content -LiteralPath $script:MainLog -Value $line -Encoding UTF8
    }
}

function Is-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Relaunch-Admin {
    $arg = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell.exe -Verb RunAs -ArgumentList $arg
    exit
}

if (-not (Is-Admin)) {
    $r = [Windows.Forms.MessageBox]::Show(
        "Version 2 uses Windows Packet Monitor for metadata-only network diagnostics.`r`n`r`nIt needs Administrator permission. No packet payloads are captured.",
        "FH6 Proximity VC Session Tester",
        "OKCancel",
        "Information"
    )
    if ($r -eq [Windows.Forms.DialogResult]::OK) { Relaunch-Admin }
    exit
}

function Find-Forza {
    $procs = @(Get-Process | Where-Object {
        $_.ProcessName -match '(?i)^forzahorizon6$|forza.*horizon.*6'
    } | Sort-Object WorkingSet64 -Descending)

    if ($procs.Count -eq 0) { return $null }
    return $procs[0]
}

function Detect-Forza {
    $p = Find-Forza
    if (-not $p) {
        [Windows.Forms.MessageBox]::Show(
            "Forza Horizon 6 is not running yet. Launch it, then click Detect Running again.",
            "FH6 Proximity VC Session Tester","OK","Information"
        ) | Out-Null
        return
    }

    $script:ForzaPid = $p.Id
    $script:ForzaProcessName = $p.ProcessName
    try {
        $script:ForzaExe = $p.MainModule.FileName
        $pathBox.Text = $script:ForzaExe
    } catch {
        $pathBox.Text = "$($p.ProcessName).exe (Windows protected the install path)"
    }
    $gameStatus.Text = "● Detected $($p.ProcessName).exe   PID $($p.Id)"
    $gameStatus.ForeColor = Color "#188038"
    $startBtn.Enabled = $true
}

function Get-ProcessNameSafe([int]$pid) {
    try {
        $p = Get-Process -Id $pid -ErrorAction Stop
        return $p.ProcessName
    } catch { return "unknown" }
}

function Snapshot-Processes([string]$state) {
    $ts = Get-Date -Format "o"
    $rows = foreach ($p in Get-Process | Sort-Object Id) {
        # Windows PowerShell 5.1 does not allow try/catch directly as a
        # hashtable value expression, so resolve the path first.
        $procPath = ""
        try {
            $procPath = $p.Path
        } catch {
            $procPath = ""
        }

        [PSCustomObject]@{
            Timestamp = $ts
            State = $state
            PID = $p.Id
            Process = $p.ProcessName
            Path = $procPath
            WorkingSetMB = [math]::Round($p.WorkingSet64 / 1MB, 1)
        }
    }
    $rows | Export-Csv -LiteralPath $script:ProcessCsv -NoTypeInformation -Append
    Log "PROCESS SNAPSHOT [$state] count=$($rows.Count)"
}

function Snapshot-Sockets([string]$state) {
    $ts = Get-Date -Format "o"
    $rows = New-Object System.Collections.Generic.List[object]

    try {
        foreach ($c in Get-NetTCPConnection -ErrorAction SilentlyContinue) {
            $rows.Add([PSCustomObject]@{
                Timestamp = $ts
                StateLabel = $state
                Proto = "TCP"
                PID = $c.OwningProcess
                Process = Get-ProcessNameSafe $c.OwningProcess
                LocalAddress = $c.LocalAddress
                LocalPort = $c.LocalPort
                RemoteAddress = $c.RemoteAddress
                RemotePort = $c.RemotePort
                ConnectionState = $c.State
            })
        }
    } catch {}

    try {
        foreach ($u in Get-NetUDPEndpoint -ErrorAction SilentlyContinue) {
            $rows.Add([PSCustomObject]@{
                Timestamp = $ts
                StateLabel = $state
                Proto = "UDP"
                PID = $u.OwningProcess
                Process = Get-ProcessNameSafe $u.OwningProcess
                LocalAddress = $u.LocalAddress
                LocalPort = $u.LocalPort
                RemoteAddress = ""
                RemotePort = ""
                ConnectionState = "BOUND"
            })
        }
    } catch {}

    $rows | Export-Csv -LiteralPath $script:SocketCsv -NoTypeInformation -Append

    $interesting = @($rows | Where-Object {
        $_.Process -match '(?i)forza|xbox|gaming|gamebar|playfab|party|microsoft|store'
    })

    Log "SOCKET SNAPSHOT [$state] total=$($rows.Count) interesting=$($interesting.Count)"
    foreach ($r in $interesting | Sort-Object Process,Proto,LocalPort) {
        if ($r.Proto -eq "TCP") {
            Log ("  {0} pid={1} TCP {2}:{3} -> {4}:{5} [{6}]" -f `
                $r.Process,$r.PID,$r.LocalAddress,$r.LocalPort,$r.RemoteAddress,$r.RemotePort,$r.ConnectionState)
        } else {
            Log ("  {0} pid={1} UDP {2}:{3}" -f $r.Process,$r.PID,$r.LocalAddress,$r.LocalPort)
        }
    }
}

function Get-ForzaRoots {
    $roots = New-Object System.Collections.Generic.List[string]

    if ($script:ForzaExe -and (Test-Path -LiteralPath $script:ForzaExe)) {
        $roots.Add((Split-Path -Parent $script:ForzaExe))
    }

    foreach ($candidate in @(
        (Join-Path $env:LOCALAPPDATA "ForzaHorizon6"),
        (Join-Path $env:LOCALAPPDATA "Forza Horizon 6"),
        (Join-Path $env:USERPROFILE "Documents\My Games")
    )) {
        if (Test-Path -LiteralPath $candidate) { $roots.Add($candidate) }
    }

    $packages = Join-Path $env:LOCALAPPDATA "Packages"
    if (Test-Path -LiteralPath $packages) {
        Get-ChildItem -LiteralPath $packages -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '(?i)forza|horizon' } |
            ForEach-Object {
                foreach ($sub in @("LocalState","LocalCache","TempState")) {
                    $p = Join-Path $_.FullName $sub
                    if (Test-Path -LiteralPath $p) { $roots.Add($p) }
                }
            }
    }

    @($roots | Sort-Object -Unique)
}

function Scan-ForzaText([string]$state) {
    $keywords = '(?i)session|server|lobby|match|multiplayer|convoy|playfab|mpsd|xbox|relay|endpoint|join|presence|activity'
    $exts = @(".log",".txt",".json",".xml",".ini",".cfg")
    $cutoff = (Get-Date).AddMinutes(-30)
    $hits = 0

    Add-Content -LiteralPath $script:TextHits -Value "`r`n===== $state @ $(Get-Date -Format o) =====" -Encoding UTF8

    foreach ($root in Get-ForzaRoots) {
        try {
            $files = Get-ChildItem -LiteralPath $root -File -Recurse -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.LastWriteTime -ge $cutoff -and
                    $_.Length -le 8MB -and
                    $exts -contains $_.Extension.ToLowerInvariant()
                } |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 60

            foreach ($f in $files) {
                # Ignore the known custom radio mod so it doesn't pollute results.
                if ($f.FullName -match '(?i)fh6-radio') { continue }

                try {
                    $m = Select-String -LiteralPath $f.FullName -Pattern $keywords -AllMatches -ErrorAction Stop |
                         Select-Object -First 25
                    if ($m) {
                        $display = $f.FullName.Replace($env:USERPROFILE,"%USERPROFILE%")
                        Add-Content -LiteralPath $script:TextHits -Value "`r`nFILE: $display" -Encoding UTF8
                        foreach ($x in $m) {
                            $line = ($x.Line -replace '\s+',' ').Trim()
                            if ($line.Length -gt 500) { $line = $line.Substring(0,500) + "..." }
                            Add-Content -LiteralPath $script:TextHits -Value ("L{0}: {1}" -f $x.LineNumber,$line) -Encoding UTF8
                            $hits++
                        }
                    }
                } catch {}
            }
        } catch {}
    }
    Log "FORZA TEXT SCAN [$state] keyword_hits=$hits"
}

function Start-Pktmon {
    try { & pktmon stop | Out-Null } catch {}
    try { & pktmon filter remove | Out-Null } catch {}

    # 0x00E = component/counter info + src/dst metadata + selected NDIS metadata.
    # Critically, 0x010 (raw packet bytes) is NOT enabled.
    $args = @(
        "start",
        "--capture",
        "--comp","nics",
        "--type","flow",
        "--flags","0x00E",
        "--file-name",$script:PktEtl,
        "--file-size","96",
        "--log-mode","circular"
    )
    $out = & pktmon @args 2>&1
    if ($LASTEXITCODE -eq 0) {
        $script:PktmonStarted = $true
        Log "PKTMON STARTED metadata-only flags=0x00E file=$script:PktEtl"
    } else {
        $script:PktmonStarted = $false
        Log "PKTMON FAILED: $($out -join ' ')"
    }
}

function Stop-Pktmon {
    if (-not $script:PktmonStarted) { return }
    try {
        $out = & pktmon stop 2>&1
        Log "PKTMON STOPPED"
    } catch {
        Log "PKTMON STOP ERROR"
    }

    if (Test-Path -LiteralPath $script:PktEtl) {
        try {
            & pktmon etl2txt $script:PktEtl --out $script:PktTxt --brief 2>&1 | Out-Null
            if (Test-Path -LiteralPath $script:PktTxt) {
                Log "PKTMON TEXT CREATED"
            }
        } catch {
            Log "PKTMON ETL2TXT FAILED"
        }
    }
    $script:PktmonStarted = $false
}

function Mark-State([string]$state) {
    if (-not $script:Running) { return }
    Log "================ STATE: $state ================"
    Snapshot-Sockets $state
    Snapshot-Processes $state
    Scan-ForzaText $state
}

function Start-Capture {
    if (-not $script:ForzaPid) {
        $p = Find-Forza
        if ($p) {
            $script:ForzaPid = $p.Id
            $script:ForzaProcessName = $p.ProcessName
        }
    }

    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $script:RunDir = Join-Path $BaseDir "Capture_$stamp"
    New-Item -ItemType Directory -Force -Path $script:RunDir | Out-Null

    $script:MainLog = Join-Path $script:RunDir "probe.log"
    $script:SocketCsv = Join-Path $script:RunDir "socket_snapshots.csv"
    $script:ProcessCsv = Join-Path $script:RunDir "process_snapshots.csv"
    $script:TextHits = Join-Path $script:RunDir "forza_text_hits.txt"
    $script:PktEtl = Join-Path $script:RunDir "pktmon_metadata.etl"
    $script:PktTxt = Join-Path $script:RunDir "pktmon_metadata.txt"

    $script:Running = $true
    $script:StartedAt = Get-Date
    $startBtn.Text = "Stop + build bundle"
    $markBtn.Enabled = $true
    $stateBox.Enabled = $true
    $customBox.Enabled = $true
    $captureStatus.Text = "● Capturing"
    $captureStatus.ForeColor = Color "#188038"

    Log "CAPTURE START v2.1"
    Log "ForzaProcess=$script:ForzaProcessName pid=$script:ForzaPid"
    Log "MODE=external/read-only; no memory read; no injection; no game file changes"
    Log "PACKET_CAPTURE=metadata only; raw payload flag 0x010 disabled"

    Snapshot-Sockets "CAPTURE_START"
    Snapshot-Processes "CAPTURE_START"
    Scan-ForzaText "CAPTURE_START"
    Start-Pktmon
}

function Stop-Capture {
    if (-not $script:Running) { return }

    Mark-State "CAPTURE_STOP"
    Stop-Pktmon
    Log "CAPTURE STOP"

    $script:Running = $false
    $startBtn.Text = "Start capture"
    $markBtn.Enabled = $false
    $stateBox.Enabled = $false
    $customBox.Enabled = $false
    $captureStatus.Text = "● Processing bundle..."
    $captureStatus.ForeColor = Color "#D97706"

    $notes = @"
FH6 Proximity VC Session Tester capture bundle

Files:
- probe.log: timeline + interesting socket summaries
- socket_snapshots.csv: all TCP/UDP ownership snapshots at each state mark
- process_snapshots.csv: process table at each state mark
- forza_text_hits.txt: keyword matches from recently modified Forza text/config/log files
- pktmon_metadata.txt: Windows Packet Monitor flow metadata, if available

The packet capture intentionally excluded raw packet bytes/payloads.
The .etl remains in the local capture folder but is NOT included in this share bundle.
"@
    Set-Content -LiteralPath (Join-Path $script:RunDir "README_CAPTURE.txt") -Value $notes -Encoding UTF8

    $zip = "$($script:RunDir)_SHARE.zip"
    $include = @(
        (Join-Path $script:RunDir "probe.log"),
        (Join-Path $script:RunDir "socket_snapshots.csv"),
        (Join-Path $script:RunDir "process_snapshots.csv"),
        (Join-Path $script:RunDir "forza_text_hits.txt"),
        (Join-Path $script:RunDir "pktmon_metadata.txt"),
        (Join-Path $script:RunDir "README_CAPTURE.txt")
    ) | Where-Object { Test-Path -LiteralPath $_ }

    Compress-Archive -LiteralPath $include -DestinationPath $zip -Force

    $captureStatus.Text = "● Bundle ready"
    $captureStatus.ForeColor = Color "#188038"
    $openBtn.Enabled = $true

    [Windows.Forms.MessageBox]::Show(
        "Capture complete.`r`n`r`nSend this file back to the person who gave you the tester:`r`n$zip`r`n`r`nThe raw ETL stayed local and was not put in the share ZIP.",
        "FH6 Proximity VC Session Tester","OK","Information"
    ) | Out-Null

    Start-Process explorer.exe "/select,`"$zip`""
}

# ---------- UI ----------
$form = New-Object Windows.Forms.Form
$form.Text = "FH6 Proximity VC Session Tester"
$form.ClientSize = New-Object Drawing.Size(900,690)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.BackColor = Color "#F7F8FA"
$form.Font = New-Object Drawing.Font("Segoe UI",10)

$title = New-Object Windows.Forms.Label
$title.Text = "FH6 Session Tester"
$title.Font = New-Object Drawing.Font("Segoe UI Semibold",20)
$title.AutoSize = $true
$title.Location = New-Object Drawing.Point(28,20)
$title.ForeColor = Color "#202124"
$form.Controls.Add($title)

$sub = New-Object Windows.Forms.Label
$sub.Text = "v2 • deeper external session discovery • metadata only"
$sub.AutoSize = $true
$sub.Location = New-Object Drawing.Point(31,59)
$sub.ForeColor = Color "#5F6368"
$form.Controls.Add($sub)

$gamePanel = New-Object Windows.Forms.Panel
$gamePanel.Location = New-Object Drawing.Point(28,92)
$gamePanel.Size = New-Object Drawing.Size(844,112)
$gamePanel.BackColor = [Drawing.Color]::White
$gamePanel.BorderStyle = "FixedSingle"
$form.Controls.Add($gamePanel)

$gameHead = New-Object Windows.Forms.Label
$gameHead.Text = "FORZA HORIZON 6"
$gameHead.Font = New-Object Drawing.Font("Segoe UI Semibold",8.5)
$gameHead.ForeColor = Color "#68707A"
$gameHead.AutoSize = $true
$gameHead.Location = New-Object Drawing.Point(14,12)
$gamePanel.Controls.Add($gameHead)

$pathBox = New-Object Windows.Forms.TextBox
$pathBox.ReadOnly = $true
$pathBox.Location = New-Object Drawing.Point(16,38)
$pathBox.Size = New-Object Drawing.Size(548,27)
$pathBox.Text = "Launch FH6, then Detect Running. Or choose the .exe."
$gamePanel.Controls.Add($pathBox)

$detectBtn = New-Object Windows.Forms.Button
$detectBtn.Text = "Detect Running"
$detectBtn.Location = New-Object Drawing.Point(577,35)
$detectBtn.Size = New-Object Drawing.Size(120,32)
$detectBtn.FlatStyle = "Flat"
$detectBtn.BackColor = [Drawing.Color]::White
$gamePanel.Controls.Add($detectBtn)

$browseBtn = New-Object Windows.Forms.Button
$browseBtn.Text = "Choose EXE"
$browseBtn.Location = New-Object Drawing.Point(708,35)
$browseBtn.Size = New-Object Drawing.Size(117,32)
$browseBtn.FlatStyle = "Flat"
$browseBtn.BackColor = [Drawing.Color]::White
$gamePanel.Controls.Add($browseBtn)

$gameStatus = New-Object Windows.Forms.Label
$gameStatus.Text = "● Waiting for game"
$gameStatus.AutoSize = $true
$gameStatus.Location = New-Object Drawing.Point(16,79)
$gameStatus.ForeColor = Color "#5F6368"
$gamePanel.Controls.Add($gameStatus)

$capPanel = New-Object Windows.Forms.Panel
$capPanel.Location = New-Object Drawing.Point(28,218)
$capPanel.Size = New-Object Drawing.Size(844,188)
$capPanel.BackColor = [Drawing.Color]::White
$capPanel.BorderStyle = "FixedSingle"
$form.Controls.Add($capPanel)

$capHead = New-Object Windows.Forms.Label
$capHead.Text = "CAPTURE + STATE MARKERS"
$capHead.Font = New-Object Drawing.Font("Segoe UI Semibold",8.5)
$capHead.ForeColor = Color "#68707A"
$capHead.AutoSize = $true
$capHead.Location = New-Object Drawing.Point(14,12)
$capPanel.Controls.Add($capHead)

$startBtn = New-Object Windows.Forms.Button
$startBtn.Text = "Start capture"
$startBtn.Location = New-Object Drawing.Point(16,40)
$startBtn.Size = New-Object Drawing.Size(160,38)
$startBtn.FlatStyle = "Flat"
$startBtn.BackColor = Color "#202124"
$startBtn.ForeColor = [Drawing.Color]::White
$startBtn.Enabled = $false
$capPanel.Controls.Add($startBtn)

$stateBox = New-Object Windows.Forms.ComboBox
$stateBox.DropDownStyle = "DropDownList"
$stateBox.Location = New-Object Drawing.Point(192,45)
$stateBox.Size = New-Object Drawing.Size(250,30)
$stateBox.Items.AddRange(@(
    "ONLINE_FREEROAM_A",
    "OFFLINE_SOLO",
    "ONLINE_FREEROAM_B",
    "RANDOM_CONVOY",
    "LEFT_CONVOY",
    "ONLINE_RACE",
    "SOLO_RACE",
    "ELIMINATOR",
    "CUSTOM"
))
$stateBox.SelectedIndex = 0
$stateBox.Enabled = $false
$capPanel.Controls.Add($stateBox)

$customBox = New-Object Windows.Forms.TextBox
$customBox.Location = New-Object Drawing.Point(455,45)
$customBox.Size = New-Object Drawing.Size(205,27)
$customBox.Text = "optional custom label"
$customBox.Enabled = $false
$capPanel.Controls.Add($customBox)

$markBtn = New-Object Windows.Forms.Button
$markBtn.Text = "Mark state"
$markBtn.Location = New-Object Drawing.Point(675,40)
$markBtn.Size = New-Object Drawing.Size(150,38)
$markBtn.FlatStyle = "Flat"
$markBtn.BackColor = [Drawing.Color]::White
$markBtn.Enabled = $false
$capPanel.Controls.Add($markBtn)

$captureStatus = New-Object Windows.Forms.Label
$captureStatus.Text = "● Ready"
$captureStatus.AutoSize = $true
$captureStatus.Location = New-Object Drawing.Point(16,94)
$captureStatus.ForeColor = Color "#5F6368"
$capPanel.Controls.Add($captureStatus)

$privacy = New-Object Windows.Forms.Label
$privacy.Text = "No game memory. No injection. No raw packet payloads. Raw packet bytes are disabled in Pktmon."
$privacy.AutoSize = $true
$privacy.Location = New-Object Drawing.Point(16,121)
$privacy.ForeColor = Color "#5F6368"
$capPanel.Controls.Add($privacy)

$tip = New-Object Windows.Forms.Label
$tip.Text = "Best test: Freeroam A → Solo → Freeroam B → random convoy → leave convoy → online race → solo race."
$tip.AutoSize = $true
$tip.Location = New-Object Drawing.Point(16,148)
$tip.ForeColor = Color "#5F6368"
$capPanel.Controls.Add($tip)

$txt = New-Object Windows.Forms.TextBox
$txt.Location = New-Object Drawing.Point(28,422)
$txt.Size = New-Object Drawing.Size(844,220)
$txt.Multiline = $true
$txt.ScrollBars = "Vertical"
$txt.ReadOnly = $true
$txt.Font = New-Object Drawing.Font("Consolas",9)
$txt.BackColor = [Drawing.Color]::White
$form.Controls.Add($txt)

$openBtn = New-Object Windows.Forms.Button
$openBtn.Text = "Open captures folder"
$openBtn.Location = New-Object Drawing.Point(28,653)
$openBtn.Size = New-Object Drawing.Size(175,30)
$openBtn.Enabled = $true
$form.Controls.Add($openBtn)

$small = New-Object Windows.Forms.Label
$small.Text = "The share ZIP excludes the raw ETL. If v2 still can't isolate the session, keep the local ETL for a targeted v3."
$small.AutoSize = $true
$small.Location = New-Object Drawing.Point(220,660)
$small.ForeColor = Color "#7A818A"
$form.Controls.Add($small)

$dlg = New-Object Windows.Forms.OpenFileDialog
$dlg.Filter = "Forza executable (*.exe)|*.exe|Executable (*.exe)|*.exe"
$dlg.Title = "Select Forza Horizon 6 executable"

$detectBtn.Add_Click({ Detect-Forza })

$browseBtn.Add_Click({
    if ($dlg.ShowDialog() -eq [Windows.Forms.DialogResult]::OK) {
        $script:ForzaExe = $dlg.FileName
        $script:ForzaProcessName = [IO.Path]::GetFileNameWithoutExtension($dlg.FileName)
        $pathBox.Text = $script:ForzaExe
        $p = Find-Forza
        if ($p) { $script:ForzaPid = $p.Id }
        $gameStatus.Text = "● Selected $($script:ForzaProcessName).exe"
        $gameStatus.ForeColor = Color "#188038"
        $startBtn.Enabled = $true
    }
})

$startBtn.Add_Click({
    if ($script:Running) { Stop-Capture } else { Start-Capture }
})

$markBtn.Add_Click({
    $label = [string]$stateBox.SelectedItem
    if ($label -eq "CUSTOM") {
        $label = $customBox.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($label) -or $label -eq "optional custom label") {
            $label = "CUSTOM"
        }
        $label = ($label -replace '[^A-Za-z0-9_\- ]','_').ToUpperInvariant()
    }
    Mark-State $label
})

$openBtn.Add_Click({ Start-Process explorer.exe $BaseDir })

$timer = New-Object Windows.Forms.Timer
$timer.Interval = 2000
$timer.Add_Tick({
    $p = Find-Forza
    if ($p) {
        if ($script:ForzaPid -ne $p.Id) {
            $script:ForzaPid = $p.Id
            $script:ForzaProcessName = $p.ProcessName
            if ($script:Running) { Log "FORZA PID DETECTED/CHANGED pid=$($p.Id)" }
        }
        $gameStatus.Text = "● Running $($p.ProcessName).exe   PID $($p.Id)"
        $gameStatus.ForeColor = Color "#188038"
        $startBtn.Enabled = $true
    } elseif ($script:ForzaProcessName) {
        $gameStatus.Text = "● Waiting for $($script:ForzaProcessName).exe"
        $gameStatus.ForeColor = Color "#D97706"
    }

    if ($script:Running) {
        $elapsed = (Get-Date) - $script:StartedAt
        $captureStatus.Text = ("● Capturing   {0:mm\:ss}" -f $elapsed)
    }
})
$timer.Start()

$form.Add_FormClosing({
    if ($script:PktmonStarted) {
        try { & pktmon stop | Out-Null } catch {}
    }
})

[Windows.Forms.Application]::EnableVisualStyles()
[void]$form.ShowDialog()
