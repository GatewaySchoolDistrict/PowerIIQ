function Get-IIQObject {
    [CmdletBinding(SupportsShouldProcess)]
    param(  
        [Parameter(Mandatory = $true)][string]$Path,
        [ValidateSet("GET", "POST", "DELETE")]
        [string]$Method = "GET",
        [switch]$NoPaging,
        [switch]$OnlySetMappedProperties,
        [int]$PageSize=-1,
        $Data
    )

    $Paging = -not $NoPaging
    if ($PageSize -ge 0) {
        if ($Path -match '\$s=') {
            Write-Verbose "Page size overridden in path"    
        }
        elseif ($Path -match '\?') {
            $Path = $Path + '&$s=' + $PageSize
        }
        else {
            $Path = $Path + '?$s=' + $PageSize
        }
    }

    Write-Verbose "IIQObject $Method  $Path"
    $RawResults = Invoke-IIQMethod -Method $Method -Path $Path -Data $Data -OnlySetMappedProperties:$OnlySetMappedProperties
    if ($null -ne $RawResults.Item -and $RawResults.Item.Length -gt 0) {
        $CompiledResults = $RawResults.Item
    }
    elseif ($null -ne $RawResults.Items -and $RawResults.Items.Length -gt 0) {
        $CompiledResults = $RawResults.Items
    }
    else {
        $CompiledResults = $null
    }


    if ($null -eq $RawResults.Paging) {
        Write-Verbose "No paging info found returning results"
        $CompiledResults
    }
    elseif ($RawResults.Paging.PageCount -le 1 -or $Paging -eq $false) {
        Write-Verbose "No need to page returning results"
        $CompiledResults
    }
    else {
        Write-Verbose "Paging required"
        Write-Verbose $RawResults.Paging
        
        $CompiledResults
        $CurrentPage = $RawResults.Paging.PageIndex + 1
        do {
            $PercentComplete = ($CurrentPage / $RawResults.Paging.PageCount) * 100
            Write-Progress -Activity "Paging $Method Request $Path" -Status "Page $CurrentPage of $($RawResults.Paging.PageCount)" -PercentComplete $PercentComplete
            Write-Verbose $RawResults.Paging
            if ($Path -Like '*`?*'){$NewPath = "$Path&`$p=$CurrentPage"}else{$NewPath = "$Path`?`$p=$CurrentPage"}
            $RawResults = Invoke-IIQMethod -Method $Method -Path $NewPath -Data $data -OnlySetMappedProperties:$OnlySetMappedProperties
            $RawResults.Items
            $CurrentPage = $RawResults.Paging.PageIndex + 1
            if ($cursorColumn -eq 1) { throw "Error while paging results" }
        } while ($CurrentPage -lt $RawResults.Paging.PageCount)
        Write-Progress -Activity "Paging $Method Request $Path" -Completed
    }
}
