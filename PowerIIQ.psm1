#https://apihub.incidentiq.com/?version=latest - Old
#https://incidentiq.api-docs.io/1.0.0 - Not complete





function Connect-IIQ {
    param(  
        [Parameter(Mandatory = $true)][string]$APIToken,
        [Parameter(Mandatory = $true)][guid]$SiteID,
        [Parameter(Mandatory = $true)][string]$BaseURL,
        [Parameter(Mandatory = $true)][guid]$ProductID
    )
    $_IIQConnectionInfo = @{
        APIToken  = $null
        SiteID    = $null
        BaseURL   = $null
        ProductID = $null
        Status    = $null
    }
    New-Variable -Name _IIQConnectionInfo  -Value $_IIQConnectionInfo -Scope Script -Force
    $_IIQConnectionInfo.APIToken = $APIToken
    $_IIQConnectionInfo.SiteID = $SiteID
    $_IIQConnectionInfo.BaseURL = $BaseURL
    $_IIQConnectionInfo.Status = 'Connected'
}
function Disconnect-IIQ {
    if ($_IIQConnectionInfo.Status -eq 'Connected') {
        $_IIQConnectionInfo.APIToken = $null
        $_IIQConnectionInfo.SiteID = $null
        $_IIQConnectionInfo.BaseURL = $null
        $_IIQConnectionInfo.ProductID = $null
        $_IIQConnectionInfo.Status = $null
    }
}
function Invoke-IIQMethod {
    param(  
        [Parameter(
            Mandatory = $true
        )
        ][string]$Path,
        #[Parameter(Mandatory=$true)]
        [ValidateSet("GET", "PUT", "POST", "DELETE")]
        [string]$Method = "GET",
        [switch]$OnlySetMappedProperties,
        $Data
    )
    if ($VerbosePreference -eq "Continue") {
        $DataOutput = $Data | ConvertTo-Json -Depth 10
        Write-Verbose "Data: $DataOutput"
    }
    Invoke-IIQMethodV1 -Path $Path -Method $Method -OnlySetMappedProperties:$OnlySetMappedProperties -Data $Data

}
function Invoke-IIQMethodV1 {
    param(  
        [Parameter(
            Mandatory = $true
        )
        ][string]$Path,
        #[Parameter(Mandatory=$true)]
        [ValidateSet("GET", "PUT", "POST", "DELETE")]
        [string]$Method = "GET",
        [switch]$OnlySetMappedProperties,
        $Data
    )



    if ($_IIQConnectionInfo.Status -ne 'Connected') { throw "Connect wiht Connect-IIQ first" }

    $apitoken = $_IIQConnectionInfo.APIToken
    $siteid = $_IIQConnectionInfo.SiteID
    $baseurl = $_IIQConnectionInfo.BaseURL

    $authheaders = @{
        'SiteId'        = $siteid
        'Authorization' = "Bearer $apitoken"
        'Client'        = 'ApiClient'
    }

    if ($OnlySetMappedProperties -eq $true) {
        $authheaders += @{"ApiFlags" = "OnlySetMappedProperties" }
    }


    if ($Data -is [hashtable]) {
        $json = $Data | ConvertTo-Json -Depth 10
    }
    else {
        $json = $Data
    }
    
    $url = "$baseurl$Path"
    Write-Verbose "Rest URL: $url"
    if ($Method -in 'GET', 'DELETE') {
        Invoke-RestMethod $url -Method $Method -Headers $authheaders -ContentType "application/json" -Verbose:$false
    }
    else {
        Invoke-RestMethod $url -Method $Method -Headers $authheaders  -ContentType "application/json" -Body $json -Verbose:$false
    }
}
function Get-IIQObject {
    param(  
        [Parameter(Mandatory = $true)][string]$Path,
        [ValidateSet("GET", "POST")]
        [string]$Method = "GET",
        [bool]$Paging = $true,
        $data
    )

    Write-Verbose "IIQObject $Method  $Path"
    $RawResults = Invoke-IIQMethod -Method $Method -Path $Path -Data $data
    if ($null -ne $RawResults.Item -and $RawResults.Item.Length -gt 0) {
        $CompiledResults = $RawResults.Item
    }
    elseif ($null -ne $RawResults.Items -and $RawResults.Items.Length -gt 0) {
        $CompiledResults = $RawResults.Items
    }
    else {
        $CompiledResults = $null
    }


    if ($null -eq $RawResults.Paging) {
        Write-Verbose "No paging info found returning results"
        $CompiledResults
    }
    elseif ($RawResults.Paging.PageCount -le 1 -or $Paging -eq $false) {
        Write-Verbose "No need to page returning results"
        $CompiledResults
    }
    else {
        Write-Verbose "Paging required"
        Write-Verbose $RawResults.Paging
        
        $CurrentPage = $RawResults.Paging.PageIndex + 1
        do {
            $PercentComplete = ($CurrentPage / $RawResults.Paging.PageCount) * 100
            Write-Progress -Activity "Paging $Method Request $Path" -Status "Page $CurrentPage of $($RawResults.Paging.PageCount)" -PercentComplete $PercentComplete
            Write-Verbose $RawResults.Paging
            $NewPath = "$Path&`$p=$CurrentPage"
            $RawResults = Invoke-IIQMethod -Method $Method -Path $NewPath -Data $data
            $CompiledResults += $RawResults.Items
            $CurrentPage = $RawResults.Paging.PageIndex + 1
            if ($cursorColumn -eq 1) { throw "Error while paging results" }
        } while ($CurrentPage -lt $RawResults.Paging.PageCount)
        Write-Progress -Activity "Paging $Method Request $Path" -Completed
        $CompiledResults
    }


}
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
        [int]$Limit = 100,
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
                    $TagID += $_.Id
                    $filters += New-IIQFacetObject -Facet tag -Id $TagID
                }
            }
            foreach ($item in $Agent) {
                if ($null -eq $item -as [guid]) {
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
                if ($null -eq $item -as [guid]) {
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



        
            if ($filters.Length -eq 0 -and $All -ne $true) { return }
            $Parameters = @{
                "ProductId"       = $_IIQConnectionInfo.ProductID
                "Schema"          = "All"
                "OnlyShowDeleted" = $false
                "Filters"         = $filters
                "FilterByProduct" = $true
            }
            $Path = '/tickets?$s=' + $Limit


            Get-IIQObject -Path $Path -Data $Parameters -Method POST | ForEach-Object {
                if ($_ -eq $null) { continue }
                if ($Timeline -eq $true) {
                    $_ | Add-Member -NotePropertyName "Timeline" -NotePropertyValue (Get-IIQObject -Path "/tickets/$($_.TicketId)/timeline") -PassThru
                    #$_ | Add-Member -MemberType ScriptProperty -Name Timeline -Value {Get-IIQObject -Path "/tickets/$($this.TicketId)/timeline"} -PassThru
                }
                $_
            }
        }
        elseif ($PSCmdlet.ParameterSetName -eq "TicketID" ) {
            Get-IIQObject "/tickets/$TicketID" | ForEach-Object {
                if ($_ -eq $null) { continue }
                if ($Timeline -eq $true) {
                    $_ | Add-Member -NotePropertyName "Timeline" -NotePropertyValue (Get-IIQObject -Path "/tickets/$($_.TicketId)/timeline") -PassThru
                    #$_ | Add-Member -MemberType ScriptProperty -Name Timeline -Value {Get-IIQObject -Path "/tickets/$($this.TicketId)/timeline"} -PassThru
                }
                $_
            }
        }
    }
    End {}
}
function Get-IIQAsset {
    [cmdletbinding()]
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName, ValueFromPipeline, ParameterSetName = "AssetID")]
        [guid]$AssetID,
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "AssetTag")]
        [string]$AssetTag,
        [Parameter(Mandatory = $true, ParameterSetName = "SerialNumber")]
        [string]$SerialNumber,
        [Parameter(Mandatory = $true, ParameterSetName = "ViewID")]
        [guid]$ViewID,
        [Parameter(Mandatory = $false, ParameterSetName = "ViewID")]
        [int]$Limit = 100
    )
    Begin {}
    Process {
        switch ($PSCmdlet.ParameterSetName) {
            "AssetID" { Get-IIQObject "/assets/$AssetID" }
            "AssetTag" { Get-IIQObject "/assets/assettag/$AssetTag" }
            "SerialNumber" { Get-IIQObject "/assets/serial/$SerialNumber" }
            "ViewID" { 
                Get-IIQObject -Method POST -Path "/assets/?`$s=$Limit" -Data @{"OnlyShowDeleted" = $false; "Filters" = @(@{"Facet" = "View"; "Id" = $ViewID }); "FilterByViewPermission" = $true }
            }
            Default { throw "No Parameter set defined" }
        }
    }
    End {}
}

function Get-IIQTag {
    [cmdletbinding()]
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName, ValueFromPipeline, ParameterSetName = "TagID")]
        [guid]$TagID,
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "Tag")]
        [string]$Tag
    )
    Begin {}
    Process {
        switch ($PSCmdlet.ParameterSetName) {
            "TagID" { Get-IIQObject "/tags/$TagID" }
            "Tag" { 
                Get-IIQFilterItem -Facet tag -Search $Tag -EntityName tickets | ForEach-Object {
                    if ($_ -eq $null) { continue }
                    Get-IIQTag -TagID $_.Id
                }
            }
            Default { throw "No Parameter set defined" }
        }
    }
    End {}
}

function Get-IIQUser {
    [cmdletbinding()]
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName, ValueFromPipeline, ParameterSetName = "UserID")]
        [guid]$UserID,
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "Search")]
        [string]$Search
    )
    Begin {}
    Process {
        switch ($PSCmdlet.ParameterSetName) {
            "UserID" { Get-IIQObject "/users/$UserID" }
            "Search" { 
                Get-IIQFilterItem -Facet user -Search $Search -EntityName users | ForEach-Object {
                    if ($_ -eq $null) { continue }
                    Get-IIQUser -UserID $_.Id
                }
            }
            Default { throw "No Parameter set defined" }
        }
    }
    End {}
}

function New-IIQFacetObject {
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Facet,
        [string]$Name = "",
        [guid]$Id,
        [string]$Value,
        [bool]$Negative = $false,
        [string]$SortOrder = "",
        [bool]$Selected = $true,
        [bool]$IsUnassigned = $false,
        [uint]$GroupIndex = 0
    )
    $FacetObject = @{
        "Facet"        = $Facet
        "Name"         = $Name
        "Id"           = $Id
        "Value"        = $Value
        "Negative"     = $Negative
        "SortOrder"    = $SortOrder
        "Selected"     = $Selected
        "IsUnassigned" = $IsUnassigned
        "GroupIndex"   = $GroupIndex
    }
    return $FacetObject
}

function Get-IIQFilterItem {
    [cmdletbinding()]
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Facet,
        [Parameter(Mandatory = $true)]
        [string[]]$Search,
        [Parameter(Mandatory = $true)]
        [string]$EntityName
    )

    foreach ($item in $Search) {
        $SearchObject = @{
            "Facets"        = @($Facet)
            "Query"         = $item
            "ResultsFilter" = @{
                "EntityName"  = $EntityName
                "ShowAll"     = $false
                "ShowDeleted" = $false
            }
        }
        Get-IIQObject -Method POST -Path '/filters' -data $SearchObject
    }
}

function Update-IIQTicket{
    [cmdletbinding()]
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName, ValueFromPipeline, ParameterSetName = "TicketID")]
        [guid]$TicketID
    )
    Begin {}
    Process {}
    End {}
}



Export-ModuleMember -Function Invoke-IIQMethod
Export-ModuleMember -Function Get-IIQObject
Export-ModuleMember -Function Get-IIQTicket
Export-ModuleMember -Function Get-IIQAsset
Export-ModuleMember -Function Get-IIQTag
Export-ModuleMember -Function Get-IIQUser
Export-ModuleMember -Function Get-IIQFilterItem
Export-ModuleMember -Function New-IIQFacetObject
Export-ModuleMember -Function Connect-IIQ
Export-ModuleMember -Function Disconnect-IIQ
Export-ModuleMember -Function Update-IIQTicket