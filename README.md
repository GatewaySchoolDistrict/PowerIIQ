# PowerIIQ
This project provides a PowerShell scripting interface for the IncidentIQ Helpdesk/Ticketing system https://www.incidentiq.com/.  This project was more for a learning experience then for actual production use.  There are no guarantees with this software.

## Note
Note: The current PowerIIQ module was tested under PowerShell 7.1.2 but does not appear to work in PowerShell 5.1 and I am not sure why.  A simplified invoke method is provided as an example if you wish to use an older version of PowerShell.

## Examples
Note: This is not a complete list of searches and filters implemented by the module.

### Loading and Connecting
```
Import-Module PowerIIQ.psm1
Connect-IIQ -SiteID SITEGUID -BaseURL "https://DOMAIN.incidentiq.com/api/v1.0" -APIToken "APIKEY" -ProductID "PRODUCTGUID"
```
### Asset examples
```
Get-IIQAsset -ViewID ViewGUIDHERE
Get-IIQAsset -AssetID AssetGUIDHERE
Get-IIQAsset -SerialNumber AssetSerialHERE
Get-IIQAsset -AssetTag AssetTagHERE -Timeline
Get-IIQAsset -ViewID ViewGUIDHERE  -Timeline | Where-Object {$_.Timeline.ActivityType -eq 5}
Get-IIQUser username | Get-IIQAsset
Get-IIQUser -ViewID ViewGUIDHERE -Assets | Where-Object {$_.Assets.Count -gt 1}
```
### Ticket examples
```
Get-IIQTicket -TicketID  TicketGUIDHERE
Get-IIQTicket -AssetID 'AssetGUIDHERE' -Limit 20
Get-IIQTicket -AssetID AssetGUIDHERE,AssetGUIDHERE -State Open
Get-IIQTicket -TicketNumber TicketNumberHERE
Get-IIQTicket -AssetSerialNumber AssetSerialHERE
Get-IIQTicket -All
Get-IIQTicket -AssetTag AssetTagHERE 
Get-IIQTicket -Agent AGENTUSER -State Open
Get-IIQTicket -UpdatedFrom '2021-03-23' -UpdatedTo 2021-03-24 -State Open
Get-IIQTicket -TicketNumber 8621 | Update-IIQTicket -Comment "Test" -WhatIf
Get-IIQTicket -TicketNumber 10487 | Update-IIQTicket -Action 'Provided training & support' -Status Resolved -Visible -SendEmails
```
### Other examples
```
Get-IIQTag -Tag HARDWARE_AGI_REPAIR
```

