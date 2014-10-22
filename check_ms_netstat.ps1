# Script name:   	check_ms_netstat.ps1
# Version:			0.14.10.22
# Created on:    	19/08/2014																			
# Author:        	D'Haese Willem
# Purpose:       	Checks Microsoft Netstat for number of connections
# On Github:		https://github.com/willemdh/check_ms_netstat
# On OutsideIT:		http://outsideit.net/check_ms_netstat
# Recent History:       	
#	19/08/2014 => Testing
#	21/08/2014 => Output edit, perfdata
#	24/08/2014 => Implemented port, ip, process filters
#	18/09/2014 => Implemented wl, cl, wh and wh parameters for tcp
#	22/10/2014 => Updated documentation and ok output with more relevant information
# Copyright:
#	This program is free software: you can redistribute it and/or modify it under the terms of the
# 	GNU General Public License as published by the Free Software Foundation, either version 3 of 
#   the License, or (at your option) any later version.
#   This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; 
#	without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
# 	See the GNU General Public License for more details.You should have received a copy of the GNU
#   General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.

#Requires –Version 2.0

[String]$DefaultString = "ABCD123"
[Int]$DefaultInt = -99

$NetStruct = @{}
	[string]$NetStruct.Hostname = $DefaultString
	[string]$NetStruct.Ip = $DefaultString
	[string]$NetStruct.ProcessName = $DefaultString
	[int]$NetStruct.Port = $DefaultInt
	#([System.Net.Dns]::GetHostaddresses("server".split('.')[0]))[0].ipaddresstostring
	[int]$NetStruct.ExitCode = 3
	[int]$NetStruct.UnkArgCount = 0
	[int]$NetStruct.KnownArgCount = 0
	[Int]$NetStruct.WarnHigh = $DefaultInt
    [Int]$NetStruct.CritHigh = $DefaultInt
    [Int]$NetStruct.WarnLow = $DefaultInt
    [Int]$NetStruct.CritLow = $DefaultInt
	[Int]$NetStruct.ConUDP = 0
	[Int]$NetStruct.ConTCP = 0
	
#region Functions

Function Process-Args {
    Param ( 
        [Parameter(Mandatory=$True)]$Args,
        [Parameter(Mandatory=$True)]$Return
    )
	
# Loop through all passed arguments

    For ( $i = 0; $i -lt $Args.count-1; $i++ ) {     
        $CurrentArg = $Args[$i].ToString()
        $Value = $Args[$i+1]
        If (($CurrentArg -cmatch "-H") -or ($CurrentArg -match "--Hostname")) {
            If (Check-Strings $Value) {
                $Return.Hostname = $Value  
				$Return.KnownArgCount+=1
            }
        }
		ElseIf (($CurrentArg -cmatch "-I") -or ($CurrentArg -match "--IpAddress")) {
            If (Check-Strings $Value) {
                $Return.Ip = $Value  
				$Return.KnownArgCount+=1
            }
        }
		ElseIf (($CurrentArg -cmatch "-P") -or ($CurrentArg -match "--ProcessName")) {
            If (Check-Strings $Value) {
                $Return.ProcessName = $Value  
				$Return.KnownArgCount+=1
            }
        }
		ElseIf (($CurrentArg -cmatch "-p") -or ($CurrentArg -match "--Port")) {
            If (Check-Strings $Value) {
                $Return.Port = $Value  
				$Return.KnownArgCount+=1
            }
        }
		ElseIf (($CurrentArg -cmatch "-wl") -or ($CurrentArg -match "--WarnLow")) {
            If (Check-Strings $Value) {
                $Return.WarnLow = $Value  
				$Return.KnownArgCount+=1
            }
        }
		ElseIf (($CurrentArg -cmatch "-wh") -or ($CurrentArg -match "--WarnHigh")) {
            If (Check-Strings $Value) {
                $Return.WarnHigh = $Value  
				$Return.KnownArgCount+=1
            }
        }
		ElseIf (($CurrentArg -cmatch "-cl") -or ($CurrentArg -match "--CritLow")) {
            If (Check-Strings $Value) {
                $Return.CritLow = $Value  
				$Return.KnownArgCount+=1
            }
        }
		ElseIf (($CurrentArg -cmatch "-ch") -or ($CurrentArg -match "--CritHigh")) {
            If (Check-Strings $Value) {
                $Return.CritHigh = $Value  
				$Return.KnownArgCount+=1
            }
        }
        ElseIf (($CurrentArg -cmatch "-h")-or ($CurrentArg -match "--help")) { 
			$Return.KnownArgCount+=1
			Write-Help
			Exit $Return.ExitCode
		}				
       	else {
			$Return.UnkArgCount+=1
		}
    }		
	$ArgHelp = $Args[0].ToString()	
	if (($ArgHelp -match "--help") -or ($ArgHelp -cmatch "-h") ) {
		Write-Help 
		Exit $Return.ExitCode
	}	
	if ($Return.UnkArgCount -ge $Return.KnownArgCount) {
		Write-Host "Unknown: Illegal arguments detected!"
        Exit $Return.ExitCode
	}
	if ($Return.Hostname -eq $DefaultString) {
		$Return.Hostname = ([System.Net.Dns]::GetHostByName((hostname)).HostName).tolower()
	}
    Return $Return
}

Function Check-Strings {
    Param ( [Parameter(Mandatory=$True)][string]$String )
    # `, `n, |, ; are bad, I think we can leave {}, @, and $ at this point.
    $BadChars=@("``", "|", ";", "`n")
    $BadChars | ForEach-Object {
        If ( $String.Contains("$_") ) {
            Write-Host "Unknown: String contains illegal characters."
            Exit $NetStruct.ExitCode
        }
    }
    Return $true
} 

Function Write-Help {
    Write-Host "check_ms_netstat.ps1:`n`tThis script is designed to check MS Netstat connections."
    Write-Host "Arguments:"
    Write-Host "`t-H or --Hostname => Mandatory hostname of system."
    Write-Host "`t-I or --IpAddress => Optional IP adress to search for."
	Write-Host "`t-p or --ProcessName => Optional port number to search for."	
	Write-Host "`t-P or --ProcessName => Optional process name to search for."
    Write-Host "`t-wl or --WarnLow => Warning threshold for minimum number connections."
    Write-Host "`t-cl or --CritLow => Critical threshold for minimum number of connections."
	Write-Host "`t-wh or --WarnHigh => Warning threshold for maximum number connections."
    Write-Host "`t-ch or --CritHigh => Critical threshold for maximum number of connections."
    Write-Host "`t-h or --Help => Print this help output."
} 

function Split-Ip-Port([string]$IpStr) {
	$Ip=$IpStr -as [ipaddress]
	if ($Ip.AddressFamily -eq 'InterNetworkV6') 
    { 
       $RetIp = $ipaddress.IPAddressToString 
       $RetPort = $IpStr.split('\]:')[-1] 
    } 
    else 
    { 
        $RetIp = $IpStr.split(':')[0] 
        $RetPort = $IpStr.split(':')[-1] 
    }  
	return @($RetIp, $RetPort);
}

function Get-Netstat 
{ 
	param(
		[Parameter(Mandatory=$True)]$NetStruct,
		[net.ipaddress]$Address, 
		[int]$Port = -1,
		[int]$ProcessId = -1
	)

	$properties = 'Protocol','LocalAddress','LocalPort','RemoteAddress','RemotePort','State','ProcessName','PID' 

    $NetstatEntries = netstat -ano | Select-String -Pattern '\s+(TCP|UDP)'

	foreach($_ in $NetstatEntries) {
	
        $NetstatEntry = $_.line.split(" ",[System.StringSplitOptions]::RemoveEmptyEntries) 

        if($NetstatEntry[1] -notmatch '^\[::') 
        {            
			($LocalIp, $LocalPort) = Split-Ip-Port($NetstatEntry[1])			
			($RemoteIp, $RemotePort) = Split-Ip-Port($NetstatEntry[2])

			$NetProcName = (Get-Process -Id $NetstatEntry[-1] -ErrorAction SilentlyContinue).Name
			$NetPID = $NetstatEntry[-1]
			
			if(($NetStruct.ProcessName -ne $DefaultString) -and [string]::Compare($NetStruct.ProcessName, $NetProcName, $true) -ne 0) {
				continue
			}

			if(($NetStruct.Port -ne $DefaultInt) -and ($LocalPort -ne $NetStruct.Port) -and ($RemotePort -ne $NetStruct.Port)) {
				continue
			}
			
			if(($NetStruct.Ip -ne $DefaultString) -and ($LocalIp -ne $NetStruct.Ip) -and ($RemoteIp -ne $NetStruct.Ip)) {
				continue
			}

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
			if ($ObjNetstat.Protocol -eq "UDP") {
				$NetStruct.ConUDP += 1
			}
			elseif ($ObjNetstat.Protocol -eq "TCP") {
				$NetStruct.ConTCP += 1
			}
        } 
    }
	$OutputStringOk = "OK: $($NetStruct.ConTCP) TCP Connections, $($NetStruct.ConUDP) UDP Connections."
	$OutputPerfdata +=  " | 'TCP Connections'=$($NetStruct.ConTCP), 'UDP Connections'=$($NetStruct.ConUDP)"
	
	if ($NetStruct.CritLow -ne $DefaultInt -and $NetStruct.ConTCP -lt $NetStruct.CritLow) {
		$NetStruct.ExitCode = 2
		Write-Host "CRITICAL: Number of TCP Connections lower then critlow threshold of $($NetStruct.CritLow)! $OutputPerfdata"
		exit $NetStruct.ExitCode
	}
	elseif ($NetStruct.WarnLow -ne $DefaultInt -and $NetStruct.ConTCP -lt $NetStruct.WarnLow) {
		$NetStruct.ExitCode = 1
		Write-Host "WARNING: Number of TCP Connections lower then warnlow threshold of $($NetStruct.WarnLow)! $OutputPerfdata"
		exit $NetStruct.ExitCode
	}
	elseif ($NetStruct.CritHigh -ne $DefaultInt -and $NetStruct.ConTCP -gt $NetStruct.CritHigh) {
		$NetStruct.ExitCode = 2
		Write-Host "CRITICAL: Number of TCP Connections higher then crithigh threshold of $($NetStruct.CritHigh)! $OutputPerfdata"
		exit $NetStruct.ExitCode
	}
	elseif ($NetStruct.WarnHigh -ne $DefaultInt -and $NetStruct.ConTCP -gt $NetStruct.WarnHigh) {
		$NetStruct.ExitCode = 1
		Write-Host "WARNING: Number of TCP Connections lower then warnlow threshold of $($NetStruct.WarnHigh)! $OutputPerfdata"
		exit $NetStruct.ExitCode
	}
	else {
		$NetStruct.ExitCode = 0
		Write-Host "$OutputStringOk $OutputPerfdata"
		exit $NetStruct.ExitCode
	}
}

#endregion Functions

# Main function
if($Args.count -ge 1){
	$NetStruct = Process-Args $Args $NetStruct
}
if ($NetStruct.Hostname -eq $DefaultString) {
	$NetStruct.Hostname = ([System.Net.Dns]::GetHostByName((hostname)).HostName).tolower()
}

Get-Netstat -NetStruct $NetStruct
