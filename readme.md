# Nagios plugin to check number of connections with Netstat on a Microsoft Windows host

### Idea

Check MS Windows network connections by using this Powershell script to get all connections. The script will loop 
through all Netstat connections on a Microsoft Windows Server, apply filters passed as argument, such as an ip 
address, port or process name and return total count of each connection state, alerting if warning or critical 
threshold for TCP connections is reached.

### Screenshot

![Network Connections Highcharts Graph 01](/../screenshots/check-ms-win-network-connections-graph-01.png?raw=true "Network Connections Highcharts Graph 01")

### Status

Poduction ready.

### How To

Please visit http://outsideit.net/check-ms-win-network-connections for more information on how to use this plugin.

### Help

In case you find a bug or have a feature request, please make an issue on GitHub.

### On Nagios Exchange

https://exchange.nagios.org/directory/Plugins/Operating-Systems/Windows-NRPE/Check-Microsoft-Windows-Network-Connections/details

### Copyright

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public 
License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later 
version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the 
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more 
details at <http://www.gnu.org/licenses/>.

