# Script name:   	check_ms_netstat.ps1
# Version:			0.14.08.19
# Created on:    	19/08/2014																			
# Author:        	D'Haese Willem
# Purpose:       	Checks Microsoft Netstat for number of connections
# On Github:		https://github.com/willemdh/check_ms_netstat
# To do:			
#   Everything
# History:       	
#	19/08/2014 => Testing
# How to:
#	1) Put the script in the NSCP scripts folder
#	2) In the nsclient.ini configuration file, define the script like this:
#		check_ms_netstat=cmd /c echo scripts\check_ms_netstat.ps1 $ARG1$; exit $LastExitCode | powershell.exe -command -
#	3) Make a command in Nagios like this:
#		check_ms_win_tasks => $USER1$/check_nrpe -H $HOSTADDRESS$ -p 5666 -t 60 -c check_ms_netstat -a $ARG1$
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
	[string]$NetStruct.Hostname = "localhost"
	[Int]$NetStruct.WarnHigh = $DefaultInt
    [Int]$NetStruct.CritHigh = $DefaultInt
    [Int]$NetStruct.WarnLow = $DefaultInt
    [Int]$NetStruct.CritLow = $DefaultInt
	
#region Functions

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
		[string]$ProcessName, 
		[net.ipaddress]$Address, 
		[int]$Port = -1,
		[int]$ProcessId = -1
	)

	$properties = 'Protocol','LocalAddress','LocalPort', 
				  'RemoteAddress','RemotePort','State','ProcessName','PID' 

    $netstatEntries = netstat -ano | Select-String -Pattern '\s+(TCP|UDP)'

	foreach($_ in $netstatEntries) {
	
        $item = $_.line.split(" ",[System.StringSplitOptions]::RemoveEmptyEntries) 

        if($item[1] -notmatch '^\[::') 
        {            
			($localAddress, $localPort) = Split-Ip-Port($item[1])			
			($remoteAddress, $remotePort) = Split-Ip-Port($item[2])

			$netProcessName = (Get-Process -Id $item[-1] -ErrorAction SilentlyContinue).Name
			
			# apply ProcessName filter
			if(![string]::IsNullOrEmpty($ProcessName) -and 
				[string]::Compare($ProcessName, $netProcessName, $true) -ne 0) {
				continue
			}

			# apply Port filter
			if($Port -ne -1 -and $localPort -ne $Port -and $remotePort -ne $Port) {
				continue
			}
			
			# apply Address filter
			if($Address -ne $null -and $localAddress -ne $Address -and $remoteAddress -ne $Address) {
				continue
			}
			
			# apply PID filter
			$netPID = $item[-1]
			if($ProcessId -ne -1 -and $ProcessId -ne $netPID) {
				continue
			}

			New-Object PSObject -Property @{ 
                PID = $netPID 
                ProcessName = $netProcessName 
                Protocol = $item[0] 
                LocalAddress = $localAddress 
                LocalPort = $localPort 
                RemoteAddress = $remoteAddress 
                RemotePort = $remotePort 
                State = if($item[0] -eq 'tcp') {$item[3]} else {$null} 
            } | Select-Object -Property $properties 
        } 
    } 
}

#endregion Functions

# Main function
if($Args.count -ge 1){$NetStruct = Process-Args $Args $NetStruct}
Get-Netstat $NetStruct

Get-Netstat -Address 78.22.126.184

# Get-NetworkStatistics -processname firefox