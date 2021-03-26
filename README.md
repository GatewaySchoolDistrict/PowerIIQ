Powershell script to interface with IncidentIQ.


Some Examples

`Import-Module PowerIIQ.psm1

Connect-IIQ -SiteID SITEGUID -BaseURL "https://DOMAIN.incidentiq.com/api/v1.0" -APIToken "APIKEY" -ProductID "PRODUCTGUID"


Get-IIQAsset -ViewID ViewGUIDHERE

Get-IIQTicket -TicketID  TicketGUIDHERE

Get-IIQAsset -AssetID AssetGUIDHERE

Get-IIQAsset -SerialNumber AssetSerialHERE

Get-IIQAsset -AssetTag AssetTagHERE


Get-IIQTicket:

Get-IIQTicket -AssetID 'AssetGUIDHERE' -Limit 20

Get-IIQTicket -AssetID AssetGUIDHERE,AssetGUIDHERE -State Open

Get-IIQTicket -TicketNumber TicketNumberHERE

Get-IIQTicket -AssetSerialNumber AssetSerialHERE

Get-IIQTicket -All

Get-IIQTicket -AssetTag AssetTagHERE 

Get-IIQTag -Tag HARDWARE_AGI_REPAIR

Get-IIQTicket -Agent AGENTUSER -State Open 

Get-IIQTicket -UpdatedFrom '2021-03-23' -UpdatedTo 2021-03-24 -State Open


Update-IIQTicket

Get-IIQTicket -TicketNumber 8621 | Update-IIQTicket -Comment "Test" -WhatIf

`



