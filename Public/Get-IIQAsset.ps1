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
        [switch]$All,
        [Parameter(Mandatory = $false, ParameterSetName = "AssetSearch")]
        [hashtable[]]$Facet=$null
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
                if ($null -ne $Facet) { $filters += $Facet }
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
