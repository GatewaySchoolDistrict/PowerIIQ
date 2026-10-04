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
