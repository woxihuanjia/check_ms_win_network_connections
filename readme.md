# Nagios plugin to check TCP and UDP connections on a MS Windows Server

### Idea

Checks Microsoft Windows Server for UCP and UDP

### Status

Almost production ready. Please visit http://outsideit.net/nagios-plugins/check-netstat-connections/ for more information.

### How To

1) Put the script in the NSCP scripts folder  
2) In the nsclient.ini configuration file, define the script like this:  
	check_ms_netstat=cmd /c echo scripts\check_ms_netstat.ps1 $ARG1$; exit $LastExitCode | powershell.exe -command -  
3) Make a command in Nagios like this:  
	check_ms_netstat => $USER1$/check_nrpe -H $HOSTADDRESS$ -p 5666 -t 60 -c check_ms_netstat -a $ARG1$  
4) Configure your service in Nagios:  
	- Make use of the above created command  
	- Make sure you pass at least one argument
	- Example: '-H server.fqdn -wl 2 -cl 0 -wh 10 -ch 15'

### Help

If you happen to find a bug, please create an issue on GitHub. Please include console's output and reproduction 
step in your bug report. The script is highly adaptable if you want different output etc. 

### On Nagios Exchange

http://exchange.nagios.org/directory/Plugins/Operating-Systems/Windows-NRPE/Check-MS-Netstat-Connections/details

### History

 19/08/2014 => Testing 
 21/08/2014 => Output edit, perfdata 
 24/08/2014 => Implemented port, ip, process filters 
 18/09/2014 => Implemented wl, cl, wh and wh parameters for tcp 


### Copyright:
This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public 
License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later 
version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the 
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more 
details at <http://www.gnu.org/licenses/>.