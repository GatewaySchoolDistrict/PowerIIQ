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
