﻿#https://apihub.incidentiq.com/?version=latest - Old
#https://incidentiq.api-docs.io/1.0.0 - Not complete





function Connect-IIQ {
    param(  
        [Parameter(Mandatory = $true)][string]$APIToken,
        [Parameter(Mandatory = $true)][guid]$SiteID,
        [Parameter(Mandatory = $true)][string]$BaseURL,
        [guid]$ProductID,
        [switch]$NoAutocomplete,
        [switch]$Autocomplete
    )
    $_IIQConnectionInfo = @{
        APIToken  = $APIToken
        SiteID    = $SiteID
        BaseURL   = $BaseURL
        ProductID = $ProductID
        Status    = 'Connected'
        UserID    = $null
        Lookup    = @{}
    }
    New-Variable -Name _IIQConnectionInfo  -Value $_IIQConnectionInfo -Scope Script -Force

    $Result=Get-IIQObject -Path "/login"
    if ($null -ne $Result){
        $_IIQConnectionInfo.UserID = $Result.UserID
        if(-not $ProductID){$_IIQConnectionInfo.ProductID = $Result.ProductId}
        if(-not $NoAutocomplete -and $Autocomplete){ Update-IIQAutoComplete }
    } else {
        Disconnect-IIQ
        throw "Error Connecting to IIQ.  Check information and try again."
    }
}
function Disconnect-IIQ {
    if ($_IIQConnectionInfo.Status -eq 'Connected') {
        $_IIQConnectionInfo.APIToken = $null
        $_IIQConnectionInfo.SiteID = $null
        $_IIQConnectionInfo.BaseURL = $null
        $_IIQConnectionInfo.ProductID = $null
        $_IIQConnectionInfo.Status = $null
        $_IIQConnectionInfo.UserID    = $null
        $_IIQConnectionInfo.Lookup  = @{}
    }
}
function Update-IIQAutoComplete {
    $_IIQConnectionInfo.Lookup.TicketStatus    =   @{}
    $_IIQConnectionInfo.Lookup.TicketAction    =   @{}
    $_IIQConnectionInfo.Lookup.CustomField     =   @{}
    $_IIQConnectionInfo.Lookup.CustomFieldR    =   @{}
    $_IIQConnectionInfo.Lookup.TicketIssue     =   @{}

    $workflow=Get-IIQObject /workflows
    Get-IIQObject "/tickets/$($workflow.WorkflowId)/statuses" | ForEach-Object {$_IIQConnectionInfo.Lookup.TicketStatus.Add($_.StatusName,$_.WorkflowStepId)}
    Get-IIQObject /resolutions/actions | ForEach-Object {$_IIQConnectionInfo.Lookup.TicketAction.Add($_.Name,$_.ResolutionActionId)}
    Get-IIQObject /issues/types | ForEach-Object {
        if ($_IIQConnectionInfo.Lookup.TicketIssue[$_.Name] -eq $null){
            $_IIQConnectionInfo.Lookup.TicketIssue.Add($_.Name,$_.IssueTypeId)
        } else{
            $Tiebreaker=$_.IssueTypeId.Substring($_.IssueTypeId.Length-4,4)
            $_IIQConnectionInfo.Lookup.TicketIssue.Add("$($_.Name) - $Tiebreaker",$_.IssueTypeId)
        }
    }
    Get-IIQObject /custom-fields/types | ForEach-Object {
        if ($_.App.Name){$name="$($_.App.Name):$($_.Name)"} else {$name=$_.Name}
        $_IIQConnectionInfo.Lookup.CustomField.Add($Name,$_.CustomFieldTypeId)
        $_IIQConnectionInfo.Lookup.CustomFieldR.Add($_.CustomFieldTypeId,$Name)
    }
}
function Invoke-IIQMethod {
    [CmdletBinding(SupportsShouldProcess)]
    param(  
        [Parameter(Mandatory = $true)][string]$Path,
        [ValidateSet("GET", "PUT", "POST", "DELETE")]
        [string]$Method = "GET",
        [switch]$OnlySetMappedProperties,
        $Data
    )
    Invoke-IIQMethodV1 -Path $Path -Method $Method -OnlySetMappedProperties:$OnlySetMappedProperties -Data $Data
}
function Invoke-IIQMethodV1 {
    [CmdletBinding(SupportsShouldProcess)]
    param(  
        [Parameter(Mandatory = $true)]
        [string]$Path,
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
        Write-Verbose "Header: ApiFlags=OnlySetMappedProperties"
        $authheaders += @{"ApiFlags" = "OnlySetMappedProperties" }
    }


    if ($Data -is [hashtable] -or $Data -is [System.Collections.Specialized.OrderedDictionary] -or $Data -is [array] -or $Data -is [pscustomobject]) {
        $json = ConvertTo-Json -Depth 10 $Data
    }
    else {
        $json = $Data
    }
    
    $url = "$baseurl$Path"

    $Message="Invoke-IIQMethodV1: Performing $Method at $url with $json"
    Write-Verbose $Message

    if ($PSCmdlet.ShouldProcess($Message, $Message, 'Invoke-IIQMethodV1:')) {
        if ($Method -in 'GET') {
            Invoke-RestMethod $url -Method $Method -Headers $authheaders -ContentType "application/json" -Verbose:$false
        }
        else {
            Invoke-RestMethod $url -Method $Method -Headers $authheaders  -ContentType "application/json" -Body $json -Verbose:$false
        }
    }
}
function Get-IIQObject {
    [CmdletBinding(SupportsShouldProcess)]
    param(  
        [Parameter(Mandatory = $true)][string]$Path,
        [ValidateSet("GET", "POST", "DELETE")]
        [string]$Method = "GET",
        [switch]$NoPaging,
        [switch]$OnlySetMappedProperties,
        [int]$PageSize=-1,
        $Data
    )

    $Paging = -not $NoPaging
    if ($PageSize -ge 0) {
        if ($Path -match '\$s=') {
            Write-Verbose "Page size overridden in path"    
        }
        elseif ($Path -match '\?') {
            $Path = $Path + '&$s=' + $PageSize
        }
        else {
            $Path = $Path + '?$s=' + $PageSize
        }
    }

    Write-Verbose "IIQObject $Method  $Path"
    $RawResults = Invoke-IIQMethod -Method $Method -Path $Path -Data $Data -OnlySetMappedProperties:$OnlySetMappedProperties
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
        
        $CompiledResults
        $CurrentPage = $RawResults.Paging.PageIndex + 1
        do {
            $PercentComplete = ($CurrentPage / $RawResults.Paging.PageCount) * 100
            Write-Progress -Activity "Paging $Method Request $Path" -Status "Page $CurrentPage of $($RawResults.Paging.PageCount)" -PercentComplete $PercentComplete
            Write-Verbose $RawResults.Paging
            if ($Path -Like '*`?*'){$NewPath = "$Path&`$p=$CurrentPage"}else{$NewPath = "$Path`?`$p=$CurrentPage"}
            $RawResults = Invoke-IIQMethod -Method $Method -Path $NewPath -Data $data -OnlySetMappedProperties:$OnlySetMappedProperties
            $RawResults.Items
            $CurrentPage = $RawResults.Paging.PageIndex + 1
            if ($cursorColumn -eq 1) { throw "Error while paging results" }
        } while ($CurrentPage -lt $RawResults.Paging.PageCount)
        Write-Progress -Activity "Paging $Method Request $Path" -Completed
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
                    $TagID += $_.Id
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
                if ($_ -eq $null) { continue }
                if ($Timeline -eq $true) {
                    $_ | Add-Member -NotePropertyName "Timeline" -NotePropertyValue (Get-IIQObject -Path "/tickets/$($_.TicketId)/timeline" -Verbose:$VerbosePreference) -PassThru
                    #$_ | Add-Member -MemberType ScriptProperty -Name Timeline -Value {Get-IIQObject -Path "/tickets/$($this.TicketId)/timeline"} -PassThru
                }
                $_
            }
        }
        elseif ($PSCmdlet.ParameterSetName -eq "TicketID" ) {
            Get-IIQObject "/tickets/$TicketID" -Verbose:$VerbosePreference | ForEach-Object {
                if ($_ -eq $null) { continue }
                if ($Timeline -eq $true) {
                    $_ | Add-Member -NotePropertyName "Timeline" -NotePropertyValue (Get-IIQObject -Path "/tickets/$($_.TicketId)/timeline" -Verbose:$VerbosePreference) -PassThru
                    #$_ | Add-Member -MemberType ScriptProperty -Name Timeline -Value {Get-IIQObject -Path "/tickets/$($this.TicketId)/timeline"} -PassThru
                }
                $_
            }
        }
    }
    End {}
}
function Get-IIQAsset {
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName, ValueFromPipeline, ParameterSetName = "AssetID")]
        [guid]$AssetID,
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "AssetTag")]
        [string]$AssetTag,
        [Parameter(Mandatory = $true, ParameterSetName = "SerialNumber")]
        [string]$SerialNumber,
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName, ParameterSetName = "AssetSearch")]
        [Alias('UserID')]
        [guid]$OwnerID,
        [Parameter(Mandatory = $false, ParameterSetName = "AssetSearch")]
        [guid]$ViewID,
        [int]$PageSize = 100,
        [switch]$Timeline,
        [Parameter(Mandatory = $false, ParameterSetName = "AssetSearch")]
        [switch]$All
    )
    Begin {}
    Process {
        $Assets=$null
        switch ($PSCmdlet.ParameterSetName) {
            "AssetID" { $Assets = Get-IIQObject "/assets/$AssetID" }
            "AssetTag" { $Assets = Get-IIQObject "/assets/assettag/$AssetTag" }
            "SerialNumber" { $Assets = Get-IIQObject "/assets/serial/$SerialNumber" }
            "AssetSearch" {
                $filters = @()
                foreach ($guid in $ViewID) {
                    $filters += New-IIQFacetObject -Facet View -Id $guid
                }
                foreach ($guid in $OwnerID) {
                    $filters += New-IIQFacetObject -Facet User -Id $guid
                }
                if ($filters.Length -eq 0 -and $All -ne $true) { return }
                $Assets = Get-IIQObject -Path "/assets" -PageSize $PageSize -Method POST -Data @{"OnlyShowDeleted" = $false; "Filters" = $filters } -Verbose:$VerbosePreference
            }
            Default { throw "No Parameter set defined" }
        }
        if ($Timeline) {
            foreach ($Asset in $Assets) {
                $Asset | Add-Member -NotePropertyName "Timeline" -NotePropertyValue (Get-IIQObject -Path "/assets/$($Asset.AssetId)/activities" | ForEach-Object {$_.Details=ConvertFrom-Json $_.Details;$_}) -PassThru
            }
        } else{
            $Assets
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
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName, ValueFromPipeline, ParameterSetName = "UserID")]
        [guid]$UserID,
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "Search")]
        [string]$Search,
        [switch]$Assets,
        [Parameter(Mandatory = $false, ParameterSetName = "UserSearch")]
        [hashtable[]]$Facet=$null,
        [Parameter(Mandatory = $false, ParameterSetName = "UserSearch")]
        [switch]$All,
        [uint]$PageSize=100
    )
    Begin {}
    Process {
        $Users = switch ($PSCmdlet.ParameterSetName) {
            "UserID" { Get-IIQObject "/users/$UserID" }
            "Search" { 
                Get-IIQFilterItem -Facet user -Search $Search -EntityName users | ForEach-Object {
                    if ($_ -eq $null) { continue }
                    Get-IIQUser -UserID $_.Id
                }
            }
            "UserSearch" {
                $filters = @()
                if ($null -ne $Facet) { $filters += $Facet }
                if ($filters.Length -eq 0 -and $All -ne $true) { return }
                Get-IIQObject -Path "/users" -PageSize $PageSize -Method POST -Data @{"OnlyShowDeleted" = $false; "Filters" = $filters } -Verbose:$VerbosePreference
            }
            Default { throw "No Parameter set defined" }
        }
        if ($Assets) {
            foreach ($User in $Users) {
                $User | Add-Member -NotePropertyName "Assets" -NotePropertyValue (Get-IIQAsset -OwnerID $User.UserId)
            }
        }
        return $Users
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
        [uint]$GroupIndex = 0,
        [guid]$CustomFieldTypeId
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
    if ($CustomFieldTypeId){
        $FacetObject."CustomFieldTypeId" = $CustomFieldTypeId
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
function Update-IIQTicket {
    [CmdletBinding(SupportsShouldProcess = $True)]
    #[CmdletBinding(DefaultParameterSetName = 'Comment', SupportsShouldProcess = $True)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [guid]$TicketID,
        [string]$Comment,
        [switch]$Visible,
        [ValidateSet([TicketStatus])]
        [string]$Status,
        [guid]$StatusID,
        [Parameter(Mandatory = $false)]
        [guid]$UserId,
        [Parameter(Mandatory = $false)]
        [switch]$SendEmails,
        [Alias('ResolutionActionId')]
        [guid]$ActionID,
        [ValidateSet([TicketAction])]
        [string]$Action,
        [uint]$Effort,
        [datetime]$Date = (Get-Date),
        [ValidateScript({$null -ne ($_ -as [guid]) -or $null -ne $_.UserId})]
        $Assign
    )
    Begin {
        if ($null -eq $UserId) {
            $UserId = $_IIQConnectionInfo.UserID
        }
        if ($Status -notin $null,'' -and $null -eq $StatusID) {
            $StatusID = $_IIQConnectionInfo.Lookup.TicketStatus.$Status
        }
        if ($Action -notin $null,'' -and $null -eq $ActionID) {
            $ActionID = $_IIQConnectionInfo.Lookup.TicketAction.$Action
        }
        if ($null -ne $Assign){
            if ($null -ne $Assign.UserId){$Assign=$Assign.UserId}
            if ($null -ne ($_ -as [guid])){throw "Agent assignment is invalid"}
        }
    }
    Process {

            $actions = @()
            if ($ActionID -ne $null) {
                $actions += [ordered]@{
                    "`$type"               = "Spark.Shared.Models.TicketActivityAction, Spark.Shared"
                    "TicketActivityTypeId" = 8
                    "ActivityDate"         = '{0:yyyy-MM-ddTHH:mm:ss.fffZ}' -f $Date
                    "ByUserId"             = $UserId
                    "ResolutionActionId"   = $ActionID
                    "Notes"                = $Comment
                    "Effort"               = $Effort
                    "EffortIsValid"        = $true
                }
            } elseif ($Comment -notin $null,'') {
                $actions += [ordered]@{
                    "`$type"               = "Spark.Shared.Models.TicketActivityComment, Spark.Shared"
                    "TicketActivityTypeId" = 6
                    "ByUserId"             = $UserId
                    "Comments"             = $Comment
                }
            }

            if ($actions.length -gt 0){
            $Activity = [ordered]@{
                "TicketId"         = $TicketID
                "ActivityItems"    = $actions
                "IsPublic"         = [bool]$Visible
                "WaitForResponse"  = $false
                "TicketWasUpdated" = [bool]$SendEmails
            }
            $Path = "/tickets/$TicketID/activities/new"
            Get-IIQObject -Method POST -Path $Path -Data $Activity
        }

        if ($null -ne $StatusID) {
            $Path = "/tickets/$TicketID/status/$StatusID"
            Get-IIQObject -Method POST -Path $Path
        }

        if ($null -ne $Assign){
            Get-IIQObject -Method POST -Path "/tickets/$TicketID/assign" -data @{AssignToUserId=$Assign;TicketId=$TicketID}
        }
    }
    End {}
}
function Update-IIQAsset {
    [CmdletBinding(SupportsShouldProcess = $True)]
    #[CmdletBinding(DefaultParameterSetName = 'Comment', SupportsShouldProcess = $True)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [guid]$AssetID,
        [Parameter(ValueFromPipelineByPropertyName)]$OwnerId,
        [Parameter(ValueFromPipelineByPropertyName)]$AssetTag,
        [Parameter(ValueFromPipelineByPropertyName)]$SerialNumber,
        [Parameter(ValueFromPipelineByPropertyName)]$ExternalID,
        [Parameter(ValueFromPipelineByPropertyName)]$CanOwnerManage,
        [Parameter(ValueFromPipelineByPropertyName)]$StatusTypeId,
        [Parameter(ValueFromPipelineByPropertyName)]$Name,
        [Parameter(ValueFromPipelineByPropertyName)]$ModelId,
        [Parameter(ValueFromPipelineByPropertyName)]$LocationId,
        [Parameter(ValueFromPipelineByPropertyName)]$LocationDetails,
        [Parameter(ValueFromPipelineByPropertyName)]$Notes,
        [Parameter(ValueFromPipelineByPropertyName)]$PurchasePoNumber,
        [Parameter(ValueFromPipelineByPropertyName)]$WarrantyInfo,
        [Parameter(ValueFromPipelineByPropertyName)]$Vendor,
        [Parameter(ValueFromPipelineByPropertyName)]$InsuranceInfo,
        [Parameter(ValueFromPipelineByPropertyName)]$StorageUnitNumber,
        [Parameter(ValueFromPipelineByPropertyName)]$LastInventoryDate,
        [Parameter(ValueFromPipelineByPropertyName)]$LocationRoomId,
        [Parameter(ValueFromPipelineByPropertyName)]$StorageLocationId,
        [Parameter(ValueFromPipelineByPropertyName)]$FundingSourceId,
        [Parameter(ValueFromPipelineByPropertyName)]$LastVerificationDateTime,
        [Parameter(ValueFromPipelineByPropertyName)][switch]$Force,
        [array][Parameter(ValueFromPipelineByPropertyName)]$LinkAsset,
        [array][Parameter(ValueFromPipelineByPropertyName)]$UnLinkAsset
    )
    Begin {
        if ($PSBoundParameters.ContainsKey("OwnerId")){
            if ($null -ne $OwnerId -and $null -eq ($OwnerId -as [guid])){throw "OwnerID assignment is invalid"}
        }
    }
    Process {
        if (-not $Force){
            $ReferenceAsset=Get-IIQAsset -AssetID $AssetID
        }
        if ($null -eq $ReferenceAsset -and -not $Force){
            Write-Error "Update-IIQAsset: Asset $AssetID not found!"
            return
        }
        if ($PSBoundParameters.ContainsKey("OwnerId")){
            if($ReferenceAsset.OwnerId -ne $OwnerID -or $Force -eq $true){
                Write-Verbose "Updating Asset's Owner: $OwnerId"
                Get-IIQObject -Method POST -Path "/assets/$AssetID/owner" -Data @{OwnerId=$OwnerId}
            } else {
                Write-Verbose "Update-IIQAsset: No owner change"
            }
        }
        if ($PSBoundParameters.ContainsKey("LinkAsset")){
            $guids=Get-VariableArrayHelper -Data $LinkAsset -ObjectProperty AssetID -Type guid
            [array]$LinkedAssetGUIDs=
            foreach($guid in $guids){
                @{ChildAssetId=$guid}
            }
            if ($LinkedAssetGUIDs.Length -gt 0){
                Get-IIQObject -Method POST -Path "/assets/linked/to/$($ReferenceAsset.AssetID)" -Data $LinkedAssetGUIDs
            }
        }
        if ($PSBoundParameters.ContainsKey("UnLinkAsset")){
            $guids=Get-VariableArrayHelper -Data $UnLinkAsset -ObjectProperty AssetID -Type guid
            [array]$LinkedAssetGUIDs=
            foreach($guid in $guids){
                @{ChildAssetId=$guid}
            }
            if ($LinkedAssetGUIDs.Length -gt 0){
                Get-IIQObject -Method DELETE -Path "/assets/linked/to/$($ReferenceAsset.AssetID)" -Data $LinkedAssetGUIDs
            }
        }
        $AssetUpdates=@{}
        $PropertiesToSync=@("CanOwnerManage","StatusTypeId","AssetTag",
            "SerialNumber","ExternalId","Name","ModelId","LocationId",
            "LocationDetails","Notes","PurchasePoNumber","WarrantyInfo",
            "Vendor","InsuranceInfo","StorageUnitNumber","LastInventoryDate"
            "LocationRoomId","FundingSourceId", "LastVerificationDateTime"
            "StorageLocationId")
        foreach ($Prop in $PropertiesToSync){
            if ($PSBoundParameters.ContainsKey($Prop)){
                $Value=Get-Variable $Prop -ValueOnly
                if($Prop -match 'Date'){
                    if($null -ne ($Value -as [datetime])){
                        $Value='{0:yyyy-MM-ddTHH:mm:ss.fffZ}' -f ($Value -as [datetime])
                        if (('{0:yyyy-MM-ddTHH:mm:ss.fffZ}' -f $ReferenceAsset.$Prop) -ne $Value -or $Force){
                            $AssetUpdates[$Prop]=$Value
                        }
                        continue
                    } elseif($null -eq $Value){
                        $Value=$null
                    } else {
                        continue
                    }
                }
                if ($ReferenceAsset.$Prop -ne $Value -or $Force){
                    $AssetUpdates[$Prop]=$Value
                }
            }
        }
        if ($AssetUpdates.Count -gt 0){
            if($null -eq $AssetUpdates["AssetTag"]){
                #The asset tag is needed for updates so include it if it is missing from the update
                $AssetUpdates["AssetTag"]=$ReferenceAsset.AssetTag
            }
            if($null -eq $AssetUpdates["SerialNumber"]){
                #Set serial due to bug where it sometimes clears it out
                $AssetUpdates["SerialNumber"]=$ReferenceAsset.SerialNumber
            }
            Write-Verbose "Updating Asset's Properties"
            Get-IIQObject -Method POST -Path "/assets/$AssetID" -Data $AssetUpdates -OnlySetMappedProperties
        } else {
            Write-Verbose "Update-IIQAsset: No asset changes found"
            return $ReferenceAsset
        }
    }
    End {}
}
function New-IIQTicket{
    [CmdletBinding()]
    param(
        #Required
        [guid]$LocationId,
        [guid]$ForID,
        [guid]$IssueID,
        [switch]$Sensitive,
        [switch]$Urgent,

        [ValidateSet([TicketIssue])]
        [string]$Issue,

        #Not Required
        [guid]$AssetId,
        [string]$Description,
        [string]$Subject

        #[guid]$IssueCategoryID,
        #[guid]$IssueTypeId,
        #[guid]$TicketWizardCategoryId
    )


    if (!$ForID){
        $ForID=$_IIQConnectionInfo.UserID
    }

    if (!$IssueID -and $Issue){
        $IssueID = $_IIQConnectionInfo.Lookup.TicketIssue.$Issue
    } elseif (!$IssueID -and !$Issue ){
        throw "No Issue specified"
    }
    
    if (!$LocationId){
        $ForUser=Get-IIQUser -UserID $ForID
        if ($ForUser.Length -ne 1){
            throw "Location is not specified and could not find location for user"
        }
        $LocationId=$ForUser.Location.LocationId
    }


    $NewTicketData=@{

        #Required
        "HasSensitiveInformation"=$Sensitive.IsPresent
        "LocationId"=$LocationID
        "SourceId"=1
        "ForId"=$ForID
        "IssueId"=$IssueID
        "IsTraining"=$false
        "ProductId"=$_IIQConnectionInfo.ProductID
        "IsUrgent"=$Urgent.IsPresent

        #Not Required Section
        <#
        "TicketFollowers"=$null
        "Locations"=$null
        "Users"=$null
        "Teams"=$null
        "Roles"=$null
        "AssetGroups"=$null
        "Attachments"=@()
        "LocationRoom"=$null
        "TicketWizardCategoryId"=$TicketWizardCategoryId
        #"Assets"=@(if ($AssetId){@{"AssetId"=$AssetId}})
        #>
        "IssueDescription"=$Description
        "Subject"=$Subject
        "Assets"=@(
            if ($AssetId){
                @{"AssetId"=$AssetId}
            }
        )
        #Unknown
        #This AssetIds does not appear to do anything.
        #"AssetIds"=@($AssetId)
        #"IssueCategoryId"=$IssueCategoryID
        #"IssueTypeId"=$IssueTypeId
    }
    #return $NewTicketData
    Get-IIQObject -Path /tickets/new -data $NewTicketData -Method POST
}
function Get-VariableArrayHelper {
    [CmdletBinding()]
    param(
        $Data,
        [ValidateSet("guid", "int","string")]
        [string]$Type = "string",
        $ObjectProperty=$null
    )

    if ($Type -eq 'guid') {
        [array]$ReturnData=
        foreach($item in $Data) {
            if ($item.$ObjectProperty -ne $null -and $item.$ObjectProperty -as [guid] -ne $null) {
                [guid]$item.$ObjectProperty
            }elseif ($item -as [guid] -ne $null) {
                [guid]$item
            }elseif ($item.Length -gt 1){
                Get-VariableArrayHelper -Type $Type -ObjectProperty $ObjectProperty -Data $item
            }
        }
        return $ReturnData
    } elseif ($Type -eq 'int') {
        [array]$ReturnData=
        foreach($item in $Data) {
            if ($item.$ObjectProperty -ne $null -and $item.$ObjectProperty -as [int] -ne $null) {
                [int]$item.$ObjectProperty
            }elseif ($item -as [int] -ne $null) {
                [int]$item 
            }elseif ($item.Length -gt 1){
                Get-VariableArrayHelper -Type $Type -ObjectProperty $ObjectProperty -Data $item
            }
        }
        return $ReturnData
    } else{
        $ReturnData=
        foreach($item in $Data) {
            if ($item.$ObjectProperty -ne $null -and $item.$ObjectProperty -as [string] -ne $null) {
                [string]$item.$ObjectProperty
            }elseif ($item -as [string] -ne $null) {
                [string]$item
            }elseif ($item.Length -gt 1){
                Get-VariableArrayHelper -Type $Type -ObjectProperty $ObjectProperty -Data $item
            }
        }
        return $ReturnData
    }
}

#Autocompleters
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
Export-ModuleMember -Function Update-IIQAutoComplete
Export-ModuleMember -Function New-IIQTicket
Export-ModuleMember -Function Update-IIQAsset