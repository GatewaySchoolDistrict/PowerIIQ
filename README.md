# PowerIIQ
This project provides a PowerShell scripting interface for the IncidentIQ Helpdesk/Ticketing system https://www.incidentiq.com/.  This project was more for a learning experience then for actual production use.  There are no guarantees with this software.

## Note
The module requires PowerShell 7.1 or later (Core edition). Its dynamic validation classes require PowerShell 7; Windows PowerShell 5.1 is not supported. Simple-Invoke-IIQMethod.ps1 remains a standalone legacy example and is not loaded by the module.

## Examples
Note: This is not a complete list of searches and filters implemented by the module.

### Loading and Connecting
```
Import-Module ./PowerIIQ.psd1
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
Update-IIQAsset -OwnerId UserGUIDHERE -AssetID AssetGUIDHERE
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


## Module layout

- `PowerIIQ.psd1`: module metadata, minimum PowerShell version, and explicit public exports.
- `PowerIIQ.psm1`: bootstrap, module-scoped connection state, dynamic validation classes, and file loading.
- `Public/`: one file per exported command, retaining existing parameters and behavior.
- `Private/`: internal HTTP transport and array conversion helpers.
- `Scripts/`: optional scripts; load explicitly with `. ./Scripts/Add-IIQUserGoogleSSO.ps1` after importing the module.
- `Tests/`: offline regression checks with a mocked HTTP transport.

Import the manifest with `Import-Module ./PowerIIQ.psd1`. Direct imports of `PowerIIQ.psm1` remain supported. For installation, keep this entire directory together in a `PowerIIQ` folder under a path listed in `$env:PSModulePath`, then use `Import-Module PowerIIQ`.

Connection credentials and lookup data stay inside the module instance. Importing the module does not contact IncidentIQ. Call `Connect-IIQ` to log in and `Disconnect-IIQ` to clear connection state. Existing command implementations, API payloads, and endpoint behavior are preserved by this restructuring.

### Development and validation

Edit the matching command file in `Public/` or helper file in `Private/`. Keep public exports synchronized in both the manifest and bootstrap when adding or removing public commands. Define dynamic validation classes in the bootstrap so their types are available when command files are parsed. Use a fresh PowerShell process after editing classes.

Run the checks from the module directory:

```powershell
pwsh -NoProfile -File ./Tests/Module.Smoke.Tests.ps1
```

These checks require no Pester installation or API credentials. They validate parsing, both import entry points, the public command list, connection cleanup, request serialization and headers, `-WhatIf`, pagination, and failed login handling. Live IncidentIQ integration is not covered by the offline checks.
