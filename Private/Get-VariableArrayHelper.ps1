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
