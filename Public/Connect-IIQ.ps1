function Connect-IIQ {
    param(  
        [Parameter(Mandatory = $true)][string]$APIToken,
        [Parameter(Mandatory = $true)][guid]$SiteID,
        [Parameter(Mandatory = $true)][string]$BaseURL,
        [guid]$ProductID,
        [switch]$NoAutocomplete,
        [switch]$Autocomplete
    )
    $_IIQConnectionInfo = @{
        APIToken  = $APIToken
        SiteID    = $SiteID
        BaseURL   = $BaseURL
        ProductID = $ProductID
        Status    = 'Connected'
        UserID    = $null
        Lookup    = @{}
    }
    New-Variable -Name _IIQConnectionInfo  -Value $_IIQConnectionInfo -Scope Script -Force

    $Result=Get-IIQObject -Path "/login"
    if ($null -ne $Result){
        $_IIQConnectionInfo.UserID = $Result.UserID
        if(-not $ProductID){$_IIQConnectionInfo.ProductID = $Result.ProductId}
        if(-not $NoAutocomplete -and $Autocomplete){ Update-IIQAutoComplete }
    } else {
        Disconnect-IIQ
        throw "Error Connecting to IIQ.  Check information and try again."
    }
}
