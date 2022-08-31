Param(
        [Parameter(Mandatory=$false)]
        [String]$LogFilePath
    )

function Now {
    Param (
        [Switch]$ms,        # Append milliseconds
        [Switch]$ns         # Append nanoseconds
    )
    $Date = Get-Date
    $now = ""
    $now += "{0:0000}-{1:00}-{2:00} " -f $Date.Year, $Date.Month, $Date.Day
    $now += "{0:00}:{1:00}:{2:00}" -f $Date.Hour, $Date.Minute, $Date.Second
    $nsSuffix = ""
    if ($ns) {
        if ("$($Date.TimeOfDay)" -match "\.\d\d\d\d\d\d") {
            $now += $matches[0]
            $ms = $false
        } else {
            $ms = $true
            $nsSuffix = "000"
        }
    } 
    if ($ms) {
        $now += ".{0:000}$nsSuffix" -f $Date.MilliSecond
    }
    return $now
}


function Log {
    Param(
        [Parameter(Mandatory=$false, ValueFromPipeline=$true, Position=0)]
        [String]$string
    )
    
    if ($String.length) {
        $string = "$(Now) $pid $currentUserName $string"
    }

    if ($LogFilePath) {
        $string | Out-File -Encoding ASCII -Append -FilePath "$LogFilePath"
        $trimmed = Get-Content -Path "$LogFilePath" | Select-Object -Last 5000
        $trimmed | Out-File -Encoding ASCII -FilePath "$LogFilePath"
    }

    Write-Host $string
}


$subscriptions = Get-ChildItem -Path HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\EventCollector\Subscriptions | select Name

foreach ($sub in $subscriptions) {
    $sub = $sub."Name".split('\')[7]
    $eventsources = Get-childItem -Path HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\EventCollector\Subscriptions\$sub\EventSources | select name
    Log "Checking $($eventsources.count) event sources"

    foreach ($source in $eventsources) {
        $source = ($source."Name" -split '\\',2)[1]
        $regkey = Get-ItemProperty -Path HKLM:$source
        foreach ($reg in $regkey) {
            $LastHeartBeatTime = $reg.LastHeartBeatTime
            $date = [DateTime]::FromFileTime($LastHeartBeatTime)
            $today = Get-Date
            $timediff = New-Timespan -Start $date -End $today
            if ($timediff.Days -gt 30) {
                $wefclient = $reg.PSChildName
                Log "$wefclient has not checked in 30 days."
                Log "Removing $wefclient from $sub subscription.`n"
                Remove-Item $reg.PSPath -Force -Recurse
            }
        }
    }
}
