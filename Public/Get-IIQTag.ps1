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
