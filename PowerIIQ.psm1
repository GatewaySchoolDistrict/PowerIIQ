#https://apihub.incidentiq.com/?version=latest - Old
#https://incidentiq.api-docs.io/1.0.0 - Not complete





function Connect-IIQ{
    param(  
        [Parameter(Mandatory=$true)][string]$APIToken,
        [Parameter(Mandatory=$true)][guid]$SiteID,
        [Parameter(Mandatory=$true)][string]$BaseURL,
        [Parameter(Mandatory=$true)][guid]$ProductID
        )
    $_IIQConnectionInfo=@{
        APIToken=$null
        SiteID=$null
        BaseURL=$null
        ProductID=$null
        Status=$null
    }
    New-Variable -Name _IIQConnectionInfo  -Value $_IIQConnectionInfo -Scope Script -Force
    $_IIQConnectionInfo.APIToken=$APIToken
    $_IIQConnectionInfo.SiteID=$SiteID
    $_IIQConnectionInfo.BaseURL=$BaseURL
    $_IIQConnectionInfo.Status='Connected'
}
function Disconnect-IIQ{
    if ($_IIQConnectionInfo.Status -eq 'Connected'){
        $_IIQConnectionInfo.APIToken=$null
        $_IIQConnectionInfo.SiteID=$null
        $_IIQConnectionInfo.BaseURL=$null
        $_IIQConnectionInfo.ProductID=$null
        $_IIQConnectionInfo.Status=$null
    }
}
function Invoke-IIQMethod {
    param(  
    [Parameter(
        Mandatory=$true
        )
    ][string]$Path,
    #[Parameter(Mandatory=$true)]
    [ValidateSet("GET","PUT","POST","DELETE")]
    [string]$Method="GET",
    [switch]$OnlySetMappedProperties,
    $Data
    )

    Invoke-IIQMethodV1 -Path $Path -Method $Method -OnlySetMappedProperties:$OnlySetMappedProperties -Data $Data

}
function Invoke-IIQMethodV1 {
    param(  
    [Parameter(
        Mandatory=$true
        )
    ][string]$Path,
    #[Parameter(Mandatory=$true)]
    [ValidateSet("GET","PUT","POST","DELETE")]
    [string]$Method="GET",
    [switch]$OnlySetMappedProperties,
    $Data
    )



    if ($_IIQConnectionInfo.Status -ne 'Connected'){throw "Connect wiht Connect-IIQ first"}

    $apitoken=$_IIQConnectionInfo.APIToken
    $siteid=$_IIQConnectionInfo.SiteID
    $baseurl=$_IIQConnectionInfo.BaseURL

    $authheaders = @{
        'SiteId' = $siteid
        'Authorization' = "Bearer $apitoken"
        'Client' = 'ApiClient'
    }

    if ($OnlySetMappedProperties -eq $true){
        $authheaders+=@{"ApiFlags"="OnlySetMappedProperties"}
    }


    if ($Data -is [hashtable]){
        $json=$Data | ConvertTo-Json -Depth 10
    } else {
        $json=$Data
    }
    
    $url="$baseurl$Path"
    Write-Verbose "Rest URL: $url"
    if ($Method -in 'GET','DELETE'){
        Invoke-RestMethod $url -Method $Method -Headers $authheaders -ContentType "application/json" -Verbose:$false
    } else {
        Invoke-RestMethod $url -Method $Method -Headers $authheaders  -ContentType "application/json" -Body $json -Verbose:$false
    }
}
function Get-IIQObject {
    param(  
        [Parameter(Mandatory=$true)][string]$Path,
        [ValidateSet("GET","POST")]
        [string]$Method="GET",
        [bool]$Paging=$true,
        $data
    )

    Write-Verbose "IIQObject $Method  $Path"
    $RawResults=Invoke-IIQMethod -Method $Method -Path $Path -Data $data
    if ($RawResults.Item -ne $null -and $RawResults.Item.Length -gt 0){
        $CompiledResults=$RawResults.Item
    } elseif ($RawResults.Items -ne $null -and $RawResults.Items.Length -gt 0){
        $CompiledResults=$RawResults.Items
    } else {
        $CompiledResults=$null
    }


    if ($RawResults.Paging -eq $null){
        Write-Verbose "No paging info found returning results"
        $CompiledResults
    } elseif ($RawResults.Paging.PageCount -eq 1 -or $Paging -eq $false){
        Write-Verbose "No need to page returning results"
        $CompiledResults
    } else {
        Write-Verbose "Paging required"
        
        $CurrentPage=$RawResults.Paging.PageIndex+1
        do {
            $PercentComplete=($CurrentPage/$RawResults.Paging.PageCount)*100
            Write-Progress -Activity "Paging $Method Request $Path" -Status "Page $CurrentPage of $($RawResults.Paging.PageCount)" -PercentComplete $PercentComplete
            Write-Verbose $RawResults.Paging
            $NewPath="$Path&`$p=$CurrentPage"
            $RawResults=Invoke-IIQMethod -Method $Method -Path $NewPath -Data $data
            $CompiledResults+=$RawResults.Items
            $CurrentPage=$RawResults.Paging.PageIndex+1
            if($cursorColumn -eq 1){throw "Error while paging results"}
        } while ($CurrentPage -lt $RawResults.Paging.PageCount)
        Write-Progress -Activity "Paging $Method Request $Path" -Completed
        $CompiledResults
    }


}
function Get-IIQTicket{
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory=$true, ParameterSetName="TicketID")]
        [guid]$TicketID,
        [Parameter(Mandatory=$false, ParameterSetName="TicketSearch")]
        [guid[]]$AssetID,
        [Parameter(Mandatory=$false, ParameterSetName="TicketSearch")]
        [int]$Limit=100,
        [Parameter(Mandatory=$false, ParameterSetName="TicketSearch")]
        [ValidateSet("Open","Closed","All")]
        [string[]]$State,
        [Parameter(Mandatory=$false, ParameterSetName="TicketSearch")]
        [ValidateNotNullOrEmpty()]
        [string[]]$AssetSerialNumber,
        [Parameter(Mandatory=$false, ParameterSetName="TicketSearch")]
        [ValidateNotNullOrEmpty()]
        [string[]]$AssetTag,
        [Parameter(Mandatory=$false, ParameterSetName="TicketSearch")]
        [uint[]]$TicketNumber,
        [Parameter(Mandatory=$false, ParameterSetName="TicketSearch")]
        [ValidateNotNullOrEmpty()]
        [string[]]$Tag,
        [Parameter(Mandatory=$false, ParameterSetName="TicketSearch")]
        [switch]$All
    )

    if ($PSCmdlet.ParameterSetName -eq "TicketID" ){
        Get-IIQObject "/tickets/$TicketID"
    }

    if ($PSCmdlet.ParameterSetName -eq "TicketSearch" ){
        $filters=@()

        foreach($item in $AssetSerialNumber){
            Get-IIQAsset -SerialNumber $item | ForEach-Object{
                if ($_ -eq $null) {continue}
                $AssetID+=$_.AssetId
            }
        }
        foreach($item in $AssetTag){
            Get-IIQAsset -AssetTag $item | ForEach-Object{
                if ($_ -eq $null) {continue}
                $AssetID+=$_.AssetId
            }
        }
        foreach($guid in $AssetID){
            $filters+=New-IIQFacetObject -Facet asset -Id $guid
        }
        foreach($item in $State){
            if ($item -eq "Open"){$guid="00000000-0000-0000-0000-000000000000"}
            if ($item -eq "Closed"){$guid="11111111-1111-1111-1111-111111111111"}
            $filters+=New-IIQFacetObject -Facet ticketstate -Name $item -Id $guid
        }     
        foreach($item in $TicketNumber){
            $filters+=New-IIQFacetObject -Facet ticketnumber -Value $item
        }
        foreach($item in $Tag){
            Get-IIQTag -Tag $item | ForEach-Object{
                if ($_ -eq $null) {continue}
                $TagID+=$_.Id
                $filters+=New-IIQFacetObject -Facet tag -Id $TagID
            }
        }

        if($filters.Length -eq 0 -and $All -ne $true){return}
        $Parameters=@{
            "ProductId"=$_IIQConnectionInfo.ProductID
            "Schema"="All"
            "OnlyShowDeleted"=$false
            "Filters"=$filters
            "FilterByProduct"=$true
        }
        $Path='/tickets?$s='+$Limit
        Get-IIQObject -Path $Path -Data $Parameters -Method POST
    }
}
function Get-IIQAsset{
    [cmdletbinding()]
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName, ParameterSetName="AssetID")]
        [guid[]]$AssetID,
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName,ValueFromPipeline,  ParameterSetName="AssetTag")]
        [string[]]$AssetTag,
        [Parameter(Mandatory=$true, ParameterSetName="SerialNumber")]
        [string[]]$SerialNumber,
        [Parameter(Mandatory=$true, ParameterSetName="ViewID")]
        [guid]$ViewID,
        [Parameter(Mandatory=$false, ParameterSetName="ViewID")]
        [int]$Limit=100
    )
    Begin {
        #Write-Host "Initialize stuff in Begin block"
    }
    Process {
        #Write-host "Stuff in Process block to perform"
        #Write-Host $AssetId
        switch ($PSCmdlet.ParameterSetName) {
            "AssetID" { Get-IIQObject "/assets/$AssetID" }
            "AssetTag" { Get-IIQObject "/assets/assettag/$AssetTag" }
            "SerialNumber" { Get-IIQObject "/assets/serial/$SerialNumber" }
            "ViewID" { 
                Get-IIQObject -Method POST -Path "/assets/?`$s=$Limit" -Data "{""OnlyShowDeleted"":false,""Filters"":[{""Facet"":""View"",""Id"":""$ViewID""}],""FilterByViewPermission"":true}"
            }
            Default {throw "No Parameter set defined"}
        }
    }
    End {
        #Write-Host "Final work in End block"
    }
}

function Get-IIQTag {
    [cmdletbinding()]
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName, ParameterSetName = "TagID")]
        [guid[]]$TagID,
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName, ValueFromPipeline, ParameterSetName = "Tag")]
        [string[]]$Tag
    )
    Begin {
        #Write-Host "Initialize stuff in Begin block"
    }
    Process {
        foreach ($item in $Tag) {
            $searchoobject = @{
                "Facets"        = @("tag")
                "Query"         = $item
                "ResultsFilter" = @{
                    "EntityName"  = "tickets"
                    "ShowAll"     = $false
                    "ShowDeleted" = $false
                }
            }
        
            switch ($PSCmdlet.ParameterSetName) {
                "TagID" { Get-IIQObject "/assets/$TagID" }
                "Tag" { Get-IIQObject -Method POST -Path '/filters'  -data  $searchoobject }
                Default { throw "No Parameter set defined" }
            }
        }
    }
    End {
        #Write-Host "Final work in End block"
    }
}

function Get-IIQUser {
    [cmdletbinding()]
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName, ParameterSetName = "UserID")]
        [guid[]]$UserID,
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName, ValueFromPipeline, ParameterSetName = "Search")]
        [string[]]$Search,
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName, ValueFromPipeline, ParameterSetName = "Username")]
        [string[]]$Username
    )
        
    switch ($PSCmdlet.ParameterSetName) {
        "UserID" { Get-IIQObject "/users/$UserID" }
        "Search" { Get-IIQObject -Method POST "/search" -data "{""Query"":""$Search"",""Facets"":4,""Limit"":20}" }
        #"Username" { Get-IIQObject -Method POST -Path '/filters'  -data  $searchoobject }
        Default { throw "No Parameter set defined" }
    }
}

function New-IIQFacetObject {
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Facet,
        [string]$Name="",
        [guid]$Id,
        [string]$Value,
        [bool]$Negative=$false,
        [string]$SortOrder="",
        [bool]$Selected=$true,
        [bool]$IsUnassigned=$false,
        [uint]$GroupIndex=0
    )
    $FacetObject=@{
        "Facet"=$Facet
        "Name"=$Name
        "Id"=$Id
        "Value"=$Value
        "Negative"=$Negative
        "SortOrder"=$SortOrder
        "Selected"=$Selected
        "IsUnassigned"=$IsUnassigned
        "GroupIndex"=$GroupIndex
    }
    return $FacetObject
}




Export-ModuleMember -Function Invoke-IIQMethod
Export-ModuleMember -Function Get-IIQObject
Export-ModuleMember -Function Get-IIQTicket
Export-ModuleMember -Function Get-IIQAsset
Export-ModuleMember -Function Get-IIQTag
Export-ModuleMember -Function Get-IIQUser
Export-ModuleMember -Function Connect-IIQ
Export-ModuleMember -Function Disconnect-IIQ