<#
.SYNOPSIS
  Lightweight PowerShell system monitor (CPU, Memory, GPU, Top Processes)
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
# GPU usage if supported
function Get-GPUUsage {
    try {
        $gpuCounters = (Get-Counter -ListSet "GPU Engine").Paths |
            Where-Object { $_ -match "engtype_3D" -and $_ -match "utilization_percentage" }
        if ($gpuCounters.Count -eq 0) { return "N/A" }
        $samples = Get-Counter $gpuCounters
        $avg = ($samples.CounterSamples | Measure-Object -Property CookedValue -Average).Average
        return ("{0:N1}%" -f $avg)
    } catch {
        return "N/A"
    }
}

# -------------------------------------------------------------------------

[Console]::CursorVisible = $false
$cores = (Get-Counter '\Processor(*)\% Processor Time').CounterSamples | 
    Where-Object { $_.Path -notmatch "_Total" } |
    ForEach-Object { $_.InstanceName }

try {
    while ($true) {
        [Console]::SetCursorPosition(0,0)

	# --- CPU ----------------------------------------------------------
	Write-Host "=== System Monitor ==="
	try {
    	    $cpuAllSample = Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction Stop
            $cpuAll = $cpuAllSample.CounterSamples.CookedValue

            $cpuCoreSamples = Get-Counter ($cores | ForEach-Object { "\Processor($_)\% Processor Time" }) -ErrorAction Stop
            $cpuPerCore = $cpuCoreSamples.CounterSamples

            Write-Host ("CPU Total : {0,6:N2}%  {1}" -f $cpuAll, (New-Bar $cpuAll))
            foreach ($c in $cpuPerCore) {
                Write-Host ("Core {0,-2}: {1,6:N2}%  {2}" -f $c.InstanceName, $c.CookedValue, (New-Bar $c.CookedValue))
            }
	}
	catch {
    	    Write-Host "CPU data unavailable (counter error)"
	}


        # --- Memory -------------------------------------------------------
        $memFree = (Get-Counter '\Memory\Available MBytes').CounterSamples.CookedValue
        $totalMem = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1MB
        $usedMem = $totalMem - $memFree
        $memPercent = [math]::Round(($usedMem / $totalMem) * 100, 2)
        Write-Host ""
        Write-Host ("Memory    : {0,6:N2}% ({1,8:N0} MB / {2,8:N0} MB)  {3}" -f $memPercent, $usedMem, $totalMem, (New-Bar $memPercent))

        # --- GPU ----------------------------------------------------------
        $gpu = Get-GPUUsage
        Write-Host ("GPU Usage : {0}" -f $gpu)

        # --- Top processes ------------------------------------------------
        $proc = Get-Process | Sort-Object CPU -Descending | Select-Object -First 5
        Write-Host ""
        Write-Host "Top 5 CPU Processes:"
        $proc | ForEach-Object {
            Write-Host ("  {0,-25} {1,8:N1} CPU {2,8:N1} MB" -f $_.ProcessName, $_.CPU, ($_.WorkingSet / 1MB))
        }

        Start-Sleep -Seconds $Interval
    }
}
finally {
    [Console]::CursorVisible = $true
    Write-Host "`nMonitoring stopped."
}
