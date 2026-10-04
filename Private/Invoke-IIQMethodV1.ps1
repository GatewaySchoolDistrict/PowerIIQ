function Invoke-IIQMethodV1 {
    [CmdletBinding(SupportsShouldProcess)]
    param(  
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [ValidateSet("GET", "PUT", "POST", "DELETE")]
        [string]$Method = "GET",
        [switch]$OnlySetMappedProperties,
        $Data,
        $BaseURL
    )
    
    if ($_IIQConnectionInfo.Status -ne 'Connected') { throw "Connect wiht Connect-IIQ first" }

    $apitoken = $_IIQConnectionInfo.APIToken
    $siteid = $_IIQConnectionInfo.SiteID
    $connbaseurl = $_IIQConnectionInfo.BaseURL

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
    
    if ($null -eq $BaseURL){
        $url = "$connbaseurl$Path"
    } else {
        $url = "$BaseURL$Path"
    }
    

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
