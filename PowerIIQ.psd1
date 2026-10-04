@{
    RootModule = 'PowerIIQ.psm1'
    ModuleVersion = '0.1.0'
    GUID = '04bb17c9-4c4a-44aa-87f0-fd8742932da5'
    Author = 'PowerIIQ contributors'
    Description = 'PowerShell interface for IncidentIQ helpdesk, tickets, and assets.'
    PowerShellVersion = '7.1'
    CompatiblePSEditions = @('Core')
    FunctionsToExport = @(
    'Connect-IIQ',
    'Disconnect-IIQ',
    'Update-IIQAutoComplete',
    'Invoke-IIQMethod',
    'Get-IIQObject',
    'Get-IIQTicket',
    'Get-IIQAsset',
    'Get-IIQTag',
    'Get-IIQUser',
    'New-IIQFacetObject',
    'Get-IIQFilterItem',
    'Update-IIQTicket',
    'Update-IIQAsset',
    'New-IIQTicket',
    'Get-IIQPart'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{ PSData = @{ Tags = @('IncidentIQ', 'Helpdesk', 'Tickets', 'Assets') } }
}
