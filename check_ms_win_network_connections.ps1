# Script name:  check_ms_win_network_connections.ps1
# Version:      v2.04.160811
# Created on:   19/08/2014
# Author:       Willem D'Haese
# Purpose:      Checks Microsoft Windows connections, allowing filters on IP address, portnumber or processname, returning number of 
#               established, listening, time_wait and close_wait TCP connections and total number of UDP connections.
# On Github:    https://github.com/willemdh/check_ms_win_network_connections
# On OutsideIT: https://outsideit.net/monitoring-windows-network-connections
# Recent History:
#   11/08/15 => Added -c parameter for established connections on high load servers (WillemRi)
#   13/10/15 => Name change to better reflect my other scripts naming conventions
#   26/07/16 => Cleanup and restructure, removed DefaultString
#   11/08/16 => Removed DefaultInt, regex arg
#   30/10/16 => Fixed bug in count and cleanup
# Copyright:
#   This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published
#   by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. This program is distributed 
#   in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A 
#   PARTICULAR PURPOSE. See the GNU General Public License for more details. You should have received a copy of the GNU General Public 
#   License along with this program.  If not, see <http://www.gnu.org/licenses/>.

#Requires –Version 2.0

$Struct = New-Object PSObject -Property @{
    Hostname = [string]'localhost';
    Ip = '';
    ProcessName = '';
    Port = '';
    ExitCode = [int]3;	
    WarnHigh = '';
    CritHigh = '';
    WarnLow = '';
    CritLow = '';
    ConUDP = [int]0;
    ConTCP = [int]0;
    ConTCPListening = [int]0;
    ConTCPTimeWait = [int]0;
    ConTCPCloseWait = [int]0;
    ConTCPEstablished = [int]0;
    ConTCPOther = [int]0;	
    OutputString = [string]'UNKNOWN: Error processing, no data returned.';
    Count = $false
}

#region Functions

Function Initialize-Args {
    Param ( 
        [Parameter(Mandatory=$True)]$Args
    )
    Try {
        For ( $i = 0; $i -lt $Args.count; $i++ ) { 
            $CurrentArg = $Args[$i].ToString()
            If ($i -lt $Args.Count-1) {
                $Value = $Args[$i+1];
                If ($Value.Count -ge 2) {
                    ForEach ($Item in $Value) {
                        Test-Strings $Item | Out-Null
                    }
                }
                Else {
                    $Value = $Args[$i+1];
                    Test-Strings $Value | Out-Null
                }
            } 
            Else {
                $Value = ''
            }
            Switch -regex -casesensitive ($CurrentArg) {
                "^(-H|--Hostname)$" {
                    If ($value -match '^[a-zA-Z.]+') {
                        If ($Value -ne ([System.Net.Dns]::GetHostByName((hostname.exe)).HostName).tolower() -and $Value -ne 'localhost') {
                            & ping.exe -n 1 $Value | out-null
                            If($? -eq $true) {
                                $Struct.Hostname = $Value
                                $i++
                            }
                            Else {
                                Throw "Ping to $Value failed! Please provide valid reachable hostname."
                            }
                        }
                        Else {
                            $Struct.Hostname = $Value
                            $i++
                        }
                    }
                    Else {
                        throw "Hostname `"$value`" does not meet regex requirements."
                    }
                }
                "^(-I|--IpAddress)$" {
                    If ($Value.Count -ge 2) {
                        ForEach ($Item in $Value) {
                            If ($Item -match '^([1-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])(\.([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])){3}$') {
                                $Struct.Ip += $Item
                            }
                            Else {
                                Throw "Ip `"$value`" does not meet regex requirements."
                            }
                        }
                    }
                    Else {
                        If ($Value -match '^([1-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])(\.([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])){3}$') {
                            $Struct.Ip = $Value 
                        }
                        Else {
                            Throw "Ip `"$value`" does not meet regex requirements."
                        }
                    }
                    $i++
                }
                "^(-P|--ProcessName)$" {
                    If ($Value.Count -ge 2) {
                        ForEach ($Item in $Value) {
                            If ($Item -match '^[a-zA-Z0-9 -_.]+$') {
                                $Struct.ProcessName += $Item
                            }
                            Else {
                                Throw "ProcessName `"$value`" does not meet regex requirements."
                            }
                        }
                    }
                    Else {
                        If ($Value -match '^[a-zA-Z0-9 -_.]+$') {
                            $Struct.ProcessName = $Value 
                        }
                        Else {
                            Throw "ProcessName `"$value`" does not meet regex requirements."
                        }
                    }
                    $i++
                }
                "^(-p|--Port)$" {
                    If ($Value.Count -ge 2) {
                        ForEach ($Item in $Value) {
                            If ($Item -match '^[\d]+$') {
                                $Struct.Port += $Item
                            }
                            Else {
                                Throw "Port `"$value`" does not meet regex requirements."
                            }
                        }
                    }
                    Else {
                        If ($Value -match '^[\d]+$') {
                            $Struct.Port = $Value 
                        }
                        Else {
                            Throw "Port `"$value`" does not meet regex requirements."
                        }
                    }
                    $i++
                }
                "^(-c|--Count)$" {
                    $Struct.Count = $True 
                    $i++
                }
                "^(-wl|--WarnLow)$" {
                    If (($value -match "^[\d]+$") -and ([int]$value -lt 100)) {
                        $Struct.WarnLow = $value
                    } 
                    Else {
                        Throw "WarnLow should be numeric and less than 100. Value given is $value."
                    }
                    $i++
                }
                "^(-wh|--WarnHigh)$" {
                    If (($value -match "^[\d]+$") -and ([int]$value -lt 100)) {
                        $Struct.WarnHigh = $value
                    } 
                    Else {
                        Throw "WarnHigh should be numeric and less than 100. Value given is $value."
                    }
                    $i++
                }
                "^(-cl|--CritLow)$" {
                    If (($value -match "^[\d]+$") -and ([int]$value -ge 0)) {
                        $Struct.CritLow = $value
                    } 
                    Else {
                        Throw "CritLow treshold should be numeric and less than 100. Value given is $value."
                    }
                    $i++
                 }
                "^(-ch|--CritHigh)$" {
                    If (($value -match "^[\d]+$") -and ([int]$value -ge 0)) {
                        $Struct.CritHigh = $value
                    } 
                    Else {
                        Throw "CritHigh treshold should be numeric and less than 100. Value given is $value."
                    }
                    $i++
                 }
                "^(-h|--Help)$" {
                    Write-Help
                }
                default {
                    throw "Illegal arguments detected: $_"
                 }
            }
        }
    } 
    Catch {
        Write-Host "CRITICAL: Argument: $CurrentArg Value: $Value Error: $_"
        Exit 2
    }
}
Function Test-Strings {
    Param ( [Parameter(Mandatory=$True)][string]$String )
    $BadChars=@("``", '|', ';', "`n")
    $BadChars | ForEach-Object {
        If ( $String.Contains("$_") ) {
            Write-Host "Error: String `"$String`" contains illegal characters."
            Exit $Struct.ExitCode
        }
    }
    Return $true
} 
Function Write-Help {
    Write-Host @"
check_ms_win_network_connections.ps1:
This script is designed to Checks Microsoft network connections, allowing filters on IP address, portnumber or processname, returning number of 
established, listening, time_wait and close_wait TCP connections and total number of UDP connections.
Arguments:
    -H  | --Hostname     => hostname of remote system, default is localhost, not yet tested on remote host.
    -I  | --IpAddress    => Optional IP adress to search for.
    -P  | --ProcessName  => Optional process name to search for.
    -p  | --Port         => Optional port number to search for.
    -wl | --WarnLow      => Warning threshold for minimum number connections.
    -cl | --CritLow      => Critical threshold for minimum number of connections.
    -wh | --WarnHigh     => Warning threshold for maximum number connections.
    -ch | --CritHigh     => Critical threshold for maximum number of connections.
    -h  | --Help         => Print this help output.
    -c  | --Count        => On servers with high amount of network connections, this option is recommended.
"@
    Exit $Struct.ExitCode;
} 
Function Find-IpPort {
    Param ([System.String]$IpStr)
    $Ip=$IpStr -as [ipaddress]
    If ( $Ip.AddressFamily -eq 'InterNetworkV6' ) { 
       $RetIp = $ipaddress.IPAddressToString 
       $RetPort = $IpStr.split('\]:')[-1] 
    } 
    Else { 
        $RetIp = $IpStr.split(':')[0] 
        $RetPort = $IpStr.split(':')[-1] 
    }  
    Return @($RetIp, $RetPort)
}

Function Get-Connections {
    If ( $Struct.count -eq $true ) {
        $Struct.ConTCP = (netstat.exe -ano | ? {($_ -match 'TCP')}).Count
        $OutputStringOk = "OK: {TCP: (Total: $($Struct.ConTCP))}"
        $OutputPerfdata = " | 'TCP Total'=$($Struct.ConTCP)"
    }
    Else {
        $NetstatEntries = netstat.exe -ano | Select-String -Pattern '(TCP|UDP)'
        If ( $Struct.ProcessName ) {
            $ProcessList = get-process | Select-Object id,name
        }
        $AllDefault = $false
        If ( ! $Struct.Ip -and ! $Struct.Port -and ! $Struct.ProcessName ) {
            $AllDefault = $true
        }
    ForEach ( $_ in $NetstatEntries ) {
        $ProcessNameThere = $false
        $IpThere = $false
        $PortThere = $false
        $NetstatEntry = $_.line.split(' ',[System.StringSplitOptions]::RemoveEmptyEntries) 
        If ( $NetstatEntry[1] -notmatch '^\[::' ) {
            ($LocalIp, $LocalPort) = Find-IpPort($NetstatEntry[1])
            ($RemoteIp, $RemotePort) = Find-IpPort($NetstatEntry[2])
            $NetPID = $NetstatEntry[-1]
            If ( $Struct.ProcessName ) {
                $NetProcName = ($ProcessList | Where-Object {$_.id -eq $NetstatEntry[-1]}).Name
                If([string]::Compare($Struct.ProcessName, $NetProcName, $true) -eq 0) {
                    $ProcessNameThere = $true
                }
            }
            If ( $Struct.Port ) {
                If ( ($LocalPort -eq $Struct.Port) -or ($RemotePort -eq $Struct.Port) ) {
                    $PortThere = $true
                }
            }
            If ( $Struct.Ip ) {
                If(($LocalIp -eq $Struct.Ip) -or ($RemoteIp -eq $Struct.Ip)) {
                    $IpThere = $true
                }
            }
            If ( $ProcessNameThere -or $PortThere -or $IpThere -or $AllDefault) {
                $ObjNetstat = New-Object -TypeName PSCustomObject -Property @{
                    'PID' = $NetPID
                    'ProcessName' = $NetProcName
                    'Protocol' = $NetstatEntry[0]
                    'LocalAddress' = $LocalIp
                    'LocalPort' = $LocalPort
                    'RemoteAddress' = $RemoteIp 
                    'RemotePort' = $RemotePort 
                    'State' = if($NetstatEntry[0] -eq 'tcp') {$NetstatEntry[3]} else {$null} 
                }
                If ( $ObjNetstat.Protocol -eq 'UDP' ) {
                    $Struct.ConUDP += 1
                }
                ElseIf ($ObjNetstat.Protocol -eq 'TCP') {
                    $Struct.ConTCP += 1
                    If ( $ObjNetstat.State -eq 'ESTABLISHED' ) {
                        $Struct.ConTCPEstablished += 1
                    }
                    ElseIf ( $ObjNetstat.State -eq 'LISTENING' ) {
                        $Struct.ConTCPListening += 1
                    }
                    ElseIf ($ObjNetstat.State -eq 'TIME_WAIT' ) {
                        $Struct.ConTCPTimeWait += 1
                    }
                    ElseIf ($ObjNetstat.State -eq 'CLOSE_WAIT' ) {
                        $Struct.ConTCPCloseWait += 1
                    }
                    Else {
                        $Struct.ConTCPOther += 1
                    }
                }
                Else {
                    Write-Host 'Unknown protocl detected, nor TCP, nor UDP.'
                    Exit $Struct.ExitCode
                }
            }
        }
    }
    $FormConTCP = '{0:D5}' -f ($Struct.ConTCP)
	$OutputStringOk = "OK: {TCP: (Total: ${FormConTCP})(Established: $($Struct.ConTCPEstablished))(Listening: $($Struct.ConTCPListening))(Time_Wait: $($Struct.ConTCPTimeWait))(Close_Wait: $($Struct.ConTCPCloseWait))(Other: $($Struct.ConTCPOther))}{UDP: (Total: $($Struct.ConUDP))}"
	$OutputPerfdata +=  " | 'TCP Total'=$($Struct.ConTCP), 'UDP Total'=$($Struct.ConUDP), 'TCP Established'=$($Struct.ConTCPEstablished), 'TCP Listening'=$($Struct.ConTCPListening), 'TCP Time Wait'=$($Struct.ConTCPTimeWait), 'TCP Close Wait'=$($Struct.ConTCPCloseWait), 'TCP Other'=$($Struct.ConTCPOther)"
	}
	if ($Struct.CritLow -and $Struct.ConTCP -lt $Struct.CritLow) {
		$Struct.ExitCode = 2
		Write-Host "CRITICAL: Number of TCP Connections lower then critlow threshold of $($Struct.CritLow)! $OutputPerfdata"
		exit $Struct.ExitCode
	}
	elseif ($Struct.WarnLow -and $Struct.ConTCP -lt $Struct.WarnLow) {
		$Struct.ExitCode = 1
		Write-Host "WARNING: Number of TCP Connections lower then warnlow threshold of $($Struct.WarnLow)! $OutputPerfdata"
		exit $Struct.ExitCode
	}
	elseif ($Struct.CritHigh -and $Struct.ConTCP -gt $Struct.CritHigh) {
		$Struct.ExitCode = 2
		Write-Host "CRITICAL: Number of TCP Connections higher then crithigh threshold of $($Struct.CritHigh)! $OutputPerfdata"
		exit $Struct.ExitCode
	}
	elseif ($Struct.WarnHigh -and $Struct.ConTCP -gt $Struct.WarnHigh) {
		$Struct.ExitCode = 1
		Write-Host "WARNING: Number of TCP Connections lower then warnlow threshold of $($Struct.WarnHigh)! $OutputPerfdata"
		exit $Struct.ExitCode
	}
	else {
		$Struct.ExitCode = 0
		Write-Host "$OutputStringOk $OutputPerfdata"
		exit $Struct.ExitCode
	}
}

#endregion Functions

# Main block

If ( $Args ) {
    If ( ! ( $Args[0].ToString()).StartsWith("$") ) {
        If ( $Args.count -ge 1 ) {
            Initialize-Args $Args
        }
    }
    Else {
        Write-Host "CRITICAL: Seems like something is wrong with your parameters: Args: $Args."
        Exit 2
    }
}
Get-Connections
Write-Host 'UNKNOWN: Script exited in an abnormal way. Please debug...'
exit $Struct.ExitCode