function Invoke-IIQMethod {
    [CmdletBinding(SupportsShouldProcess)]
    param(  
        [Parameter(Mandatory = $true)][string]$Path,
        [ValidateSet("GET", "PUT", "POST", "DELETE")]
        [string]$Method = "GET",
        [switch]$OnlySetMappedProperties,
        $Data,
        $BaseURL

    )
    Invoke-IIQMethodV1 -Path $Path -Method $Method -OnlySetMappedProperties:$OnlySetMappedProperties -Data $Data -BaseURL:$BaseURL
}
