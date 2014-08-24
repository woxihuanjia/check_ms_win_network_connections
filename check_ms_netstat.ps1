# Script name:   	check_ms_netstat.ps1
# Version:			0.14.08.23
# Created on:    	19/08/2014																			
# Author:        	D'Haese Willem
# Purpose:       	Checks Microsoft Netstat for number of connections
# On Github:		https://github.com/willemdh/check_ms_netstat
# To do:			
#   - Implement warning and critical threshold parameters
#	- Implement arrays for the parameters, so multiple values can be used
# History:       	
#	19/08/2014 => Testing
#	21/08/2014 => Output edit, perfdata
#	24/08/2014 => Implemented port, ip, process filters
# How to:
#	1) Put the script in the NSCP scripts folder
#	2) In the nsclient.ini configuration file, define the script like this:
#		check_ms_netstat=cmd /c echo scripts\check_ms_netstat.ps1 $ARG1$; exit $LastExitCode | powershell.exe -command -
#	3) Make a command in Nagios like this:
#		check_ms_netstat => $USER1$/check_nrpe -H $HOSTADDRESS$ -p 5666 -t 60 -c check_ms_netstat -a $ARG1$
#	4) Configure your service in Nagios:
#		- Make use of the above created command
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

# Function to check strings for invalid and potentially malicious chars

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
    Write-Host "`t-H or --Hostname => Optional hostname of system, default is localhost."
    Write-Host "`t-I or --IpAddress => Optional IP adress to search for."
	Write-Host "`t-P or --ProcessName => Optional Process Name to search for."
    Write-Host "`t-w or --Warning => Warning threshold for number connections, not yet implemented."
    Write-Host "`t-c or --Critial => Critical threshold for number of connections, not yet implemented."
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
	$OutputString = "Check of Netstat entries succeeded."
	$OutputString +=  " | 'TCP Connections'=$($NetStruct.ConTCP), 'UDP Connections'=$($NetStruct.ConUDP)"
	$NetStruct.ExitCode = 0
	
	Write-Host "$OutputString"
	exit $NetStruct.ExitCode
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
