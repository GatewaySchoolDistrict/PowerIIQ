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
