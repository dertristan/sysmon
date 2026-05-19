<#
.SYNOPSIS
  Lightweight PowerShell system monitor (CPU, Memory, Top Processes)
.DESCRIPTION
  A live, non-blinking dashboard for monitoring system usage.
  Updates every 5 seconds by default.
#>

param (
    [int]$Interval = 5  # refresh rate in seconds
)

# --- Functions ------------------------------------------------------------

# Draw a simple horizontal bar
function New-Bar {
    param (
        [Parameter(Mandatory=$true)][double]$Value,
        [int]$Width = 20
    )
    $filled = [math]::Round(($Value / 100) * $Width)
    
    # Cast the hexadecimal values to [char] then to [string]
    $fullBlock = [string][char][int]"0x2588" # █
    $lightBlock = [string][char][int]"0x2591" # ░
    
    # Ensure the repeat count is an integer
    $empty = $Width - $filled
    
    return ($fullBlock * $filled + $lightBlock * $empty)
}

# Pad each line to terminal width so new content fully overwrites the previous frame.
function Write-Line {
    param(
        [string]$Text = "",
        $Color = $null
    )
    $w = [Console]::WindowWidth - 1
    if ($Text.Length -gt $w) { $Text = $Text.Substring(0, $w) }
    else                     { $Text = $Text.PadRight($w) }
    if ($null -ne $Color) { Write-Host $Text -ForegroundColor $Color }
    else                  { Write-Host $Text }
}
# -------------------------------------------------------------------------

[Console]::CursorVisible = $false
Clear-Host
$cores = (Get-Counter '\Processor(*)\% Processor Time').CounterSamples |
    Where-Object { $_.Path -notmatch "_Total" } |
    ForEach-Object { $_.InstanceName }

try {
    while ($true) {
        [Console]::SetCursorPosition(0,0)

	# --- CPU ----------------------------------------------------------
	Write-Line "=== System Monitor ==="
	try {
    	    $cpuAllSample = Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction Stop
            $cpuAll = $cpuAllSample.CounterSamples.CookedValue

            $cpuCoreSamples = Get-Counter ($cores | ForEach-Object { "\Processor($_)\% Processor Time" }) -ErrorAction Stop
            $cpuPerCore = $cpuCoreSamples.CounterSamples

            Write-Line ("{0,-7}: {1,6:N2}%  {2}" -f "Total", $cpuAll, (New-Bar $cpuAll))
            Write-Line ("-" * 36)
            foreach ($c in $cpuPerCore) {
                Write-Line ("Core {0,-2}: {1,6:N2}%  {2}" -f $c.InstanceName, $c.CookedValue, (New-Bar $c.CookedValue))
            }
	}
	catch {
    	    Write-Line "CPU data unavailable (counter error)"
	}


        # --- Memory -------------------------------------------------------
        $memFree = (Get-Counter '\Memory\Available MBytes').CounterSamples.CookedValue
        $totalMem = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1MB
        $usedMem = $totalMem - $memFree
        $memPercent = [math]::Round(($usedMem / $totalMem) * 100, 2)
        Write-Line ""
        Write-Line ("Memory: {0:N2}% ({1:N0} MB / {2:N0} MB)  {3}" -f $memPercent, $usedMem, $totalMem, (New-Bar $memPercent))

        # --- Top processes ------------------------------------------------
        $allProc = Get-Process

        $topCPU = $allProc | Sort-Object CPU -Descending | Select-Object -First 5
        Write-Line ""
        Write-Line "Top 5 CPU Processes:"
        Write-Line ("  {0,-25} {1,14}  {2,11}" -f "PROCESS", "CPU TIME", "MEMORY")
        $topCPU | ForEach-Object {
            Write-Line ("  {0,-25} {1,8:N1} CPU-s  {2,8:N1} MB" -f $_.ProcessName, $_.CPU, ($_.WorkingSet / 1MB))
        }

        $topMem = $allProc | Sort-Object WorkingSet -Descending | Select-Object -First 5
        Write-Line ""
        Write-Line "Top 5 Memory Processes:"
        $topMem | ForEach-Object {
            Write-Line ("  {0,-25} {1,8:N1} MB" -f $_.ProcessName, ($_.WorkingSet / 1MB))
        }

        Write-Line ""
        Write-Line "Press Ctrl+C to quit" -Color DarkGray

        # Blank-pad any rows below the last line so a shorter frame leaves no leftovers.
        $endRow = [Console]::CursorTop
        $lastVisible = [Console]::WindowTop + [Console]::WindowHeight - 1
        $blank = ' ' * ([Console]::WindowWidth - 1)
        for ($r = $endRow; $r -lt $lastVisible; $r++) {
            [Console]::SetCursorPosition(0, $r)
            [Console]::Write($blank)
        }
        [Console]::SetCursorPosition(0, $endRow)

        Start-Sleep -Seconds $Interval
    }
}
finally {
    [Console]::CursorVisible = $true
    Write-Host "`nMonitoring stopped."
}
