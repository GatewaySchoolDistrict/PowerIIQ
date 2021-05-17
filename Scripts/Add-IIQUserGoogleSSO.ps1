<#
.Synopsis
   Adds Google SSO info to existing accounts that did not match with a normal import
.EXAMPLE
   Get-IIQUser username | Add-IIQUserGoogleSSO
.NOTES
   This is used to match accounts that would not usually get matched with the GoogleSSO import and add the nessisary properties on to the user to support Google SSO
#>
function Add-IIQUserGoogleSSO {
    param(  
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName, ValueFromPipeline, ParameterSetName = "UserID")]
        [guid]$UserID
    )
    Begin {}
    Process {
        $User = Get-IIQUser -UserID $UserID
        $gappdata = Invoke-IIQMethod -Method POST -Path "/../../apps/googleSso/api/data/users/search" -Data @{"query" = $User.Email }
        if ($gappdata.Length -eq 1) {
            $DataUpdate = @{
                AuthenticatedBy = "googleSso"
                ExternalId = $gappdata.Id
                DataMappings    = @{
                    "Lookups" = $User.DataMappings.Lookups + @(
                        [pscustomobject]@{
                            "Key"   = "Id"
                            "AppId" = "googleSso"
                            "Value" = $gappdata.Id
                        },
                        [pscustomobject]@{
                            "Key"   = "Name"
                            "AppId" = "googleSso"
                            "Value" = $gappdata.Data.name.fullName
                        },
                        [pscustomobject]@{
                            "Key"   = "Email"
                            "AppId" = "googleSso"
                            "Value" = $gappdata.Data.primaryEmail
                        },
                        [pscustomobject]@{
                            "Key"   = "Username.1"
                            "AppId" = "googleSso"
                            "Value" = $gappdata.Data.primaryEmail
                        },
                        [pscustomobject]@{
                            "Key"   = "Username.2"
                            "AppId" = "googleSso"
                            "Value" = ($gappdata.Data.primaryEmail -split '@')[0]
                        }
                    ) | Sort-Object AppId,Key -Unique
                }
            }
            Get-IIQObject -Method POST -Path "/users/$($User.UserId)" -OnlySetMappedProperties -Data $DataUpdate
        }
        else {
            Write-Error "IIQ returned less then zero or more then one Google User"
        }
    }
    End {}
}