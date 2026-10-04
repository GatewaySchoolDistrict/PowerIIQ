function Disconnect-IIQ {
    if ($_IIQConnectionInfo.Status -eq 'Connected') {
        $_IIQConnectionInfo.APIToken = $null
        $_IIQConnectionInfo.SiteID = $null
        $_IIQConnectionInfo.BaseURL = $null
        $_IIQConnectionInfo.ProductID = $null
        $_IIQConnectionInfo.Status = $null
        $_IIQConnectionInfo.UserID    = $null
        $_IIQConnectionInfo.Lookup  = @{}
    }
}
