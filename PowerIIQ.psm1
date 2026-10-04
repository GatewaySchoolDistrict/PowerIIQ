#Requires -Version 7.1
# Validation types must be defined here before command files are parsed.
class TicketStatus : System.Management.Automation.IValidateSetValuesGenerator {
    [String[]] GetValidValues() {
        return $Script:_IIQConnectionInfo.Lookup.TicketStatus.keys
    }
}

class TicketAction : System.Management.Automation.IValidateSetValuesGenerator {
    [String[]] GetValidValues() {
        return $Script:_IIQConnectionInfo.Lookup.TicketAction.keys
    }
}

class TicketIssue : System.Management.Automation.IValidateSetValuesGenerator {
    [String[]] GetValidValues() {
        return $Script:_IIQConnectionInfo.Lookup.TicketIssue.keys
    }
}

# Initialize state independently for each module instance.
$script:_IIQConnectionInfo = @{
    APIToken = $null
    SiteID = $null
    BaseURL = $null
    ProductID = $null
    Status = $null
    UserID = $null
    Lookup = @{
        TicketStatus = @{}
        TicketAction = @{}
        TicketIssue = @{}
        CustomField = @{}
        CustomFieldR = @{}
    }
}

# Dot-source into module scope so commands share connection state.
foreach ($folder in @('Private', 'Public')) {
    foreach ($file in (Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot $folder) -Filter '*.ps1' -File | Sort-Object Name)) {
        . $file.FullName
    }
}

# Explicit exports also support importing the .psm1 directly.
Export-ModuleMember -Function @(
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
