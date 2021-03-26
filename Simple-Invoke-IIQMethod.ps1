#https://apihub.incidentiq.com/?version=latest - Old
#https://incidentiq.api-docs.io/1.0.0 - Not complete


function Invoke-IIQMethod {
    param(
    [Parameter(Mandatory=$true)]
    [string]$Path,
    [Parameter(Mandatory=$true)]
    [ValidateSet("GET","PUT","POST","DELETE")]
    [string]$Method,
    [switch]$OnlySetMappedProperties,
    $Data
    )

    $apitoken="APITOKEN"
    $siteid="SITEID"
    $baseurl="https://domain.incidentiq.com/api/v1.0"
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
    if ($Method -in 'GET','DELETE'){
        Invoke-RestMethod $url -Method $Method -Headers $authheaders -ContentType "application/json"
    } else {
        Invoke-RestMethod $url -Method $Method -Headers $authheaders  -ContentType "application/json" -Body $json
    }
}





Invoke-IIQMethod -Method 'GET' -Path "/assets/serial/SERIALNUMBER"

$data=Invoke-IIQMethod -Method 'GET' -Path "/assets/serial/SERIALNUMBER"
$assetid=$data.Items[0].AssetId
$Parameters=@{
    "ProductId"="PRODUCTID"
    "Schema"="All"
    "OnlyShowDeleted"=$false
    "Filters"=@(@{
                "Facet"="Asset"
                "Id"=$assetid
            })
    "FilterByProduct"=$true
}
$data=Invoke-IIQMethod  -Method 'POST' -Path "/tickets?$s=20&$o=TicketClosedDate%20DESC" -Data $Parameters



