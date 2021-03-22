Powershell script to interface with IncidentIQ.


Some Examples

`Import-Module PowerIIQ.psm1

Connect-IIQ -SiteID SITEGUID -BaseURL "https://DOMAIN.incidentiq.com/api/v1.0" -APIToken "APIKEY" -ProductID "PRODUCTGUID"


Get-IIQAsset -ViewID ViewGUIDHERE

Get-IIQTicket -TicketID  TicketGUIDHERE

Get-IIQAsset -AssetID AssetGUIDHERE

Get-IIQAsset -SerialNumber AssetSerialHERE

Get-IIQAsset -AssetTag AssetTagHERE

Get-IIQTicket -AssetID 'AssetGUIDHERE' -Limit 20

Get-IIQTicket -AssetID AssetGUIDHERE,AssetGUIDHERE

Get-IIQTicket -AssetID AssetGUIDHERE,AssetGUIDHERE -State Open

Get-IIQTicket -AssetID AssetGUIDHERE -State Closed

Get-IIQTicket -TicketNumber TicketNumberHERE

Get-IIQTicket -AssetSerialNumber AssetSerialHERE

Get-IIQTicket -All

Get-IIQTicket -AssetTag AssetTagHERE -All

Get-IIQTicket -AssetTag 'AssetTagHERE' -AssetSerialNumber AssetSerialHERE,AssetSerialHERE -AssetID AssetGUIDHERE -Limit 3
`


