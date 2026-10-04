<#
.Synopsis
   Gets tickets from IncidentIQ
.EXAMPLE
   Get-IIQTicket -AssetID '416b71e3-502a-426f-9cf5-184e535384b4'
.EXAMPLE
   Get-IIQTicket -AssetID 416b71e3-502a-426f-9cf5-184e535384b4,c0c01df5-3e92-46a9-8abd-126732886085
.EXAMPLE
    Get-IIQTicket -TicketNumber 123456
.EXAMPLE
    Get-IIQTicket -AssetSerialNumber SN123987
.EXAMPLE
    Get-IIQTicket -AssetTag 2743955
.EXAMPLE
    Get-IIQTicket -AssetTag '2743955' -AssetSerialNumber SN123987,SN456987 -AssetID 416b71e3-502a-426f-9cf5-184e535384b4
.NOTES
   Search logic roughly matches web interface where chained rules use and logic except for assets which combine with or
#>
function Get-IIQTicket {
    [cmdletbinding()]
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName, ValueFromPipeline, ParameterSetName = "TicketID")]
        [guid]$TicketID,
        [Parameter(Mandatory = $false, ParameterSetName = "TicketSearch")]
        [guid[]]$AssetID,
        [Parameter(Mandatory = $false, ParameterSetName = "TicketSearch")]
        [int]$PageSize = 100,
        [Parameter(Mandatory = $false, ParameterSetName = "TicketSearch")]
        [ValidateSet("Open", "Closed", "All")]
        [string[]]$State,
        [Parameter(Mandatory = $false, ParameterSetName = "TicketSearch")]
        [ValidateNotNullOrEmpty()]
        [string[]]$AssetSerialNumber,
        [Parameter(Mandatory = $false, ParameterSetName = "TicketSearch")]
        [ValidateNotNullOrEmpty()]
        [string[]]$AssetTag,
        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = "TicketSearch")]
        [string[]]$TicketNumber,
        [Parameter(Mandatory = $false, ParameterSetName = "TicketSearch")]
        [ValidateNotNullOrEmpty()]
        [string[]]$Tag,
        [Parameter(Mandatory = $false, ParameterSetName = "TicketSearch")]
        [ValidateNotNullOrEmpty()]
        [string[]]$Agent,
        [Parameter(Mandatory = $false, ParameterSetName = "TicketSearch")]
        [ValidateNotNullOrEmpty()]
        [string[]]$Requestor,
        [Parameter(Mandatory = $false, ParameterSetName = "TicketSearch")]
        [datetime]$UpdatedFrom,
        [Parameter(Mandatory = $false, ParameterSetName = "TicketSearch")]
        [datetime]$UpdatedTo,
        [Parameter(Mandatory = $false, ParameterSetName = "TicketSearch")]
        [switch]$All,
        [hashtable]$Facet,
        [switch]$Timeline
    )
    Begin {}
    Process {
        if ($PSCmdlet.ParameterSetName -eq "TicketSearch" ) {
            $filters = @()
            foreach ($item in $AssetSerialNumber) {
                Get-IIQAsset -SerialNumber $item | ForEach-Object {
                    if ($_ -eq $null) { continue }
                    $AssetID += $_.AssetId
                }
            }
            foreach ($item in $AssetTag) {
                Get-IIQAsset -AssetTag $item | ForEach-Object {
                    if ($_ -eq $null) { continue }
                    $AssetID += $_.AssetId
                }
            }
            foreach ($guid in $AssetID) {
                $filters += New-IIQFacetObject -Facet asset -Id $guid
            }
            foreach ($item in $State) {
                if ($item -eq "Open") { $guid = "00000000-0000-0000-0000-000000000000" }
                if ($item -eq "Closed") { $guid = "11111111-1111-1111-1111-111111111111" }
                $filters += New-IIQFacetObject -Facet ticketstate -Name $item -Id $guid
            }     
            foreach ($item in $TicketNumber) {
                if ($item -match "^!") { $Negative = $true; $item = $item -replace "^!", "" } else { $Negative = $false }
                $filters += New-IIQFacetObject -Facet ticketnumber -Value $item -Negative $Negative
            }
            foreach ($item in $Tag) {
                Get-IIQTag -Tag $item | ForEach-Object {
                    if ($_ -eq $null) { continue }
                    $TagID += $_.TagId
                    $filters += New-IIQFacetObject -Facet tag -Id $TagID
                }
            }
            foreach ($item in $Agent) {
                if ($item -as [guid] -eq $null) {
                    Get-IIQUser -Search $item | ForEach-Object {
                        if ($_ -eq $null) { continue }
                        $filters += New-IIQFacetObject -Facet agent -Id $_.UserId
                    }
                }
                else {
                    $filters += New-IIQFacetObject -Facet agent -Id $item    
                }
            }
            foreach ($item in $Requestor) {
                if ($item -as [guid] -eq $null) {
                    Get-IIQUser -Search $item | ForEach-Object {
                        if ($_ -eq $null) { continue }
                        $filters += New-IIQFacetObject -Facet user -Id $_.UserId
                    }
                }
                else {
                    $filters += New-IIQFacetObject -Facet user -Id $item    
                }
            }
            if($null -ne $UpdatedTo -or $null -ne $UpdatedFrom){
                if($null -eq $UpdatedFrom){$UpdatedFrom=Get-Date}
                if($null -eq $UpdatedTo){$UpdatedTo=Get-Date}
                $FacetValue="daterange:{0:MM/dd/yyyy}-{1:MM/dd/yyyy}" -f $UpdatedFrom,$UpdatedTo
                $filters += New-IIQFacetObject -Facet modifieddate -Value $FacetValue
            }
            foreach ($item in $Facet) {
                $filters += $item
            }
        
            if ($filters.Length -eq 0 -and $All -ne $true) { return }
            $Parameters = @{
                "ProductId"       = $_IIQConnectionInfo.ProductID
                "Schema"          = "All"
                "OnlyShowDeleted" = $false
                "Filters"         = $filters
                "FilterByProduct" = $true
            }

            Get-IIQObject -Path '/tickets' -Data $Parameters -Method POST -PageSize $PageSize -Verbose:$VerbosePreference | ForEach-Object {
                if ($null -ne $_) {
                    if ($Timeline -eq $true) {
                        $_ | Add-Member -NotePropertyName "Timeline" -NotePropertyValue (Get-IIQObject -Path "/tickets/$($_.TicketId)/timeline" -Verbose:$VerbosePreference)
                        #$_ | Add-Member -MemberType ScriptProperty -Name Timeline -Value {Get-IIQObject -Path "/tickets/$($this.TicketId)/timeline"} -PassThru
                    }
                    $_
                }
            }
        }
        elseif ($PSCmdlet.ParameterSetName -eq "TicketID" ) {
            Get-IIQObject "/tickets/$TicketID" -Verbose:$VerbosePreference | ForEach-Object {
                if ($null -ne $_){
                    if ($Timeline -eq $true) {
                        $_ | Add-Member -NotePropertyName "Timeline" -NotePropertyValue (Get-IIQObject -Path "/tickets/$($_.TicketId)/timeline" -Verbose:$VerbosePreference)
                        #$_ | Add-Member -MemberType ScriptProperty -Name Timeline -Value {Get-IIQObject -Path "/tickets/$($this.TicketId)/timeline"} -PassThru
                    }
                    $_
                }
            }
        }
    }
    End {}
}
