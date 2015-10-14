# Script name:      check_ms_win_network_connections.ps1
# Version:          v2.01.151014
# Created on:       19/08/2014
# Author:           D'Haese Willem
# Purpose:          Checks Microsoft Netstat, allowing filters on IP address, portnumber or processname, returning number of 
#                   established, listening, time_wait and close_wait TCP connections and total number of UDP connections.
# On Github:        https://github.com/willemdh/check_ms_win_network_connections
# On OutsideIT:     http://outsideit.net/check-ms-win-network-connections
# Recent History:
#	13/01/15 => Bug in hostname referring to task struct
#	17/03/15 => Cleanup with isesteroids recommendations
#	28/04/15 => Cleanup for first release on GitHub
#   11/08/15 => Added -c parameter for established connections on high load servers (WillemRi)
#	13/10/15 => Name change to better reflect my other scripts naming conventions
# Copyright:
#	This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published
#	by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. This program is distributed 
#	in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A 
#	PARTICULAR PURPOSE. See the GNU General Public License for more details. You should have received a copy of the GNU General Public 
#	License along with this program.  If not, see <http://www.gnu.org/licenses/>.

#Requires –Version 2.0

[String]$DefaultString = 'ABCD123'
[Int]$DefaultInt = -99

$NetStruct = New-Object PSObject -Property @{
    Hostname = [string]'localhost';
    Ip = $DefaultString;
	ProcessName = $DefaultString;
	Port = $DefaultInt;
    ExitCode = [int]3;	
	WarnHigh = $DefaultInt;
    CritHigh = $DefaultInt;
    WarnLow = $DefaultInt;
    CritLow =$DefaultInt;
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

    try {
        For ( $i = 0; $i -lt $Args.count; $i++ ) { 
		    $CurrentArg = $Args[$i].ToString()
            if ($i -lt $Args.Count-1) {
				$Value = $Args[$i+1];
				If ($Value.Count -ge 2) {
					foreach ($Item in $Value) {
						Protect-Strings $Item | Out-Null
					}
				}
				else {
	                $Value = $Args[$i+1];
					Protect-Strings $Value | Out-Null
				}	                             
            } else {
                $Value = ''
            };

            switch -regex -casesensitive ($CurrentArg) {
                "^(-H|--Hostname)$" {
					if ($Value -ne ([System.Net.Dns]::GetHostByName((hostname.exe)).HostName).tolower() -and $Value -ne 'localhost') {
						& ping.exe -n 1 $Value | out-null
						if($? -eq $true) {
							if (Test-PsRemoting $Value) {
								$NetStruct.Hostname = $Value
								$i++
							}
							else  {
								Write-Host "CRITICAL: Powershell remoting test on $Value failed! Please enable PSRemoting. (Not supported by plugin yet..)"
								exit 3
							}
		    			} 
						else {
		    				Write-Host "CRITICAL: Ping to $Value failed! Please provide valid reachable hostname!"
							exit 3
		    			}
					}
					else {
						$NetStruct.Hostname = $Value
						$i++
					}		
                }
				"^(-I|--IpAddress)$" {
					If ($Value.Count -ge 2) {
						foreach ($Item in $Value) {
		                		$NetStruct.Ip += $Item
		            		}
					}					
					else {
		                $NetStruct.Ip = $Value  
					}	
                    $i++
                }	
				"^(-P|--ProcessName)$" {
					If ($Value.Count -ge 2) {
						foreach ($Item in $Value) {
		                		$NetStruct.ProcessName += $Item
		            		}
					}					
					else {
		                $NetStruct.ProcessName = $Value  
					}	
                    $i++
                }
				"^(-p|--Port)$" {
					If ($Value.Count -ge 2) {
						foreach ($Item in $Value) {
		                		$NetStruct.Port += $Item
		            		}
					}					
					else {
		                $NetStruct.Port = $Value  
					}	
                    $i++
                }
				"^(-c|--Count)$" {
		                $NetStruct.Count = $True 
                  		$i++
             			}
                        
                "^(-wl|--WarnLow)$" {
                    if (($value -match "^[\d]+$") -and ([int]$value -ge 0)) {
                        $NetStruct.WarnLow = $value
                    } else {
                        throw "Warning treshold should be numeric and positive. Value given is $value"
                    }
                    $i++
                }
                "^(-wh|--WarnHigh)$" {
                    if (($value -match "^[\d]+$") -and ([int]$value -ge 0)) {
                        $NetStruct.WarnHigh = $value
                    } else {
                        throw "Warning treshold should be numeric and positive. Value given is $value"
                    }
                    $i++
                }
                "^(-cl|--CritLow)$" {
                    if (($value -match "^[\d]+$") -and ([int]$value -ge 0)) {
                        $NetStruct.CritLow = $value
                    } else {
                        throw "Warning treshold should be numeric and positive. Value given is $value"
                    }
                    $i++
                }
                "^(-ch|--CritHigh)$" {
                    if (($value -match "^[\d]+$") -and ([int]$value -ge 0)) {
                        $NetStruct.CritHigh = $value
                    } else {
                        throw "Warning treshold should be numeric and positive. Value given is $value"
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
    } catch {
		Write-Host "UNKNOWN: $_"
        Exit $NetStruct.ExitCode
	}	
}

# Function to check strings for invalid and potentially malicious chars

Function Protect-Strings {
    Param ( [Parameter(Mandatory=$True)][string]$String )
    $BadChars=@("``", '|', ';', "`n")
    $BadChars | ForEach-Object {
        If ( $String.Contains("$_") ) {
            Write-Host 'Unknown: String contains illegal characters.'
            Exit $NetStruct.ExitCode
        }
    }
    Return $true
} 

# Function to write help output

Function Write-Help {
	Write-Host @"
check_ms_netstat.ps1:
This script is designed to Checks Microsoft Netstat, allowing filters on IP address, portnumber or processname, returning number of 
established, listening, time_wait and close_wait TCP connections and total number of UDP connections.
Arguments:
    -H  | --Hostname     => Mandatory hostname of remote system, default is localhost, not yet tested on remote host.
    -I  | --IpAddress 	 => Optional IP adress to search for.
    -P  | --ProcessName  => Optional process name to search for.
    -p  | --Port		 => Optional port number to search for.
    -wl | --WarnLow      => Warning threshold for minimum number connections.
    -cl | --CritLow      => Critical threshold for minimum number of connections.
    -wh | --WarnHigh     => Warning threshold for maximum number connections.
    -ch | --CritHigh     => Critical threshold for maximum number of connections.
    -h  | --Help         => Print this help output.
	-c  | --Count	     => Counts Total TCP connection via netstat.	
"@
    Exit $NetStruct.ExitCode;
} 

function Test-PsRemoting 
{ 
    param( 
        [Parameter(Mandatory = $true)] 
        $computername 
    ) 
    
    try 
    { 
        $errorActionPreference = 'Stop' 
        $result = Invoke-Command -ComputerName $computername { 1 } 
    } 
    catch 
    { 
        Write-Verbose $_ 
        return $false 
    } 
    
    ## I’ve never seen this happen, but if you want to be sure..
    if($result -ne 1) 
    { 
        Write-Verbose "Remoting to $computerName returned an unexpected result." 
        return $false 
    } 
    
    $true    
}

function Find-Ip-Port {
    param ([System.String]$IpStr)

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
if($NetStruct.count -eq $true)
{
$NetStruct.ConTCP = (netstat -abn -proto TCP).count
$OutputStringOk = "OK: {TCP: (Total: $($NetStruct.ConTCP))}"
$OutputPerfdata = " | 'TCP Total'=$($NetStruct.ConTCP)"
}
else
{
    $NetstatEntries = netstat.exe -ano | Select-String -Pattern '(TCP|UDP)'
	if($NetStruct.ProcessName -ne $DefaultString){
		$ProcessList = get-process | Select-Object id,name
	}
	$AllDefault = $false
	if($NetStruct.Ip -eq $DefaultString -and $NetStruct.Port -eq $DefaultInt -and $NetStruct.ProcessName -eq $DefaultString) {
		$AllDefault = $true
	}

	foreach($_ in $NetstatEntries) {
		
		$ProcessNameThere = $false
		$IpThere = $false
		$PortThere = $false
	
        $NetstatEntry = $_.line.split(' ',[System.StringSplitOptions]::RemoveEmptyEntries) 

        if($NetstatEntry[1] -notmatch '^\[::') 
        {            
			($LocalIp, $LocalPort) = Find-Ip-Port($NetstatEntry[1])			
			($RemoteIp, $RemotePort) = Find-Ip-Port($NetstatEntry[2])
#			$NetProcName = (Get-Process -Id $NetstatEntry[-1] -ErrorAction SilentlyContinue).Name => gave too much load
			
			$NetPID = $NetstatEntry[-1]
			
			if($NetStruct.ProcessName -ne $DefaultString) {
				$NetProcName = ($ProcessList | ? {$_.id -eq $NetstatEntry[-1]}).Name
				if([string]::Compare($NetStruct.ProcessName, $NetProcName, $true) -eq 0) {
					$ProcessNameThere = $true
				}
			}

			if($NetStruct.Port -ne $DefaultInt) {
				if(($LocalPort -eq $NetStruct.Port) -or ($RemotePort -eq $NetStruct.Port)) {
					$PortThere = $true
				}
			}
			
			if($NetStruct.Ip -ne $DefaultString) {
				if(($LocalIp -eq $NetStruct.Ip) -or ($RemoteIp -eq $NetStruct.Ip)) {
					$IpThere = $true
				}
			}
		
			if ($ProcessNameThere -or $PortThere -or $IpThere -or $AllDefault) {
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
				if ($ObjNetstat.Protocol -eq 'UDP') {
					$NetStruct.ConUDP += 1
				}
				elseif ($ObjNetstat.Protocol -eq 'TCP') {
					$NetStruct.ConTCP += 1
					if ($ObjNetstat.State -eq 'ESTABLISHED') {
						$NetStruct.ConTCPEstablished += 1
					}
					elseif ($ObjNetstat.State -eq 'LISTENING') {
						$NetStruct.ConTCPListening += 1
					}
					elseif ($ObjNetstat.State -eq 'TIME_WAIT') {
						$NetStruct.ConTCPTimeWait += 1						
					}
					elseif ($ObjNetstat.State -eq 'CLOSE_WAIT') {
						$NetStruct.ConTCPCloseWait += 1						
					}
					else {
						$NetStruct.ConTCPOther += 1
					}
				}
				else {
					Write-Host 'Unknown protocl detected, nor TCP, nor UDP.'
					exit $NetStruct.ExitCode
				}
				
#	Use this line for troubleshooting:
#				Write-Host "TCP Total: $($NetStruct.ConTcp) , UDP Total: $($NetStruct.ConUDP) for $($NetStruct.ProcessName) $NetstatEntry "
			}
        } 
    }
	
	$FormConTCP = '{0:D5}' -f ($NetStruct.ConTCP)
	
	$OutputStringOk = "OK: {TCP: (Total: ${FormConTCP})(Established: $($NetStruct.ConTCPEstablished))(Listening: $($NetStruct.ConTCPListening))(Time_Wait: $($NetStruct.ConTCPTimeWait))(Close_Wait: $($NetStruct.ConTCPCloseWait))(Other: $($NetStruct.ConTCPOther))}{UDP: (Total: $($NetStruct.ConUDP))}"
	$OutputPerfdata +=  " | 'TCP Total'=$($NetStruct.ConTCP), 'UDP Total'=$($NetStruct.ConUDP), 'TCP Established'=$($NetStruct.ConTCPEstablished), 'TCP Listening'=$($NetStruct.ConTCPListening), 'TCP Time Wait'=$($NetStruct.ConTCPTimeWait), 'TCP Close Wait'=$($NetStruct.ConTCPCloseWait), 'TCP Other'=$($NetStruct.ConTCPOther)"
	}
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

# Main block

# Reuse threads

if ($PSVersionTable){$Host.Runspace.ThreadOptions = 'ReuseThread'}

# Main function

if($Args.count -ge 1){Initialize-Args $Args}
	
Get-Netstat

Write-Host 'UNKNWON: Script exited in an abnormal way. Please debug...'
exit $NetStruct.ExitCode