#Requires -Version 7.1
# Run in a fresh PowerShell process: pwsh -NoProfile -File ./Tests/Module.Smoke.Tests.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

# Parse every source file without making any network requests.
foreach ($file in (Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object { $_.Extension -in '.ps1', '.psm1', '.psd1' })) {
    $tokens = $null
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseInput((Get-Content -LiteralPath $file.FullName -Raw), [ref]$tokens, [ref]$parseErrors)
    Assert-True ($parseErrors.Count -eq 0) "Parse errors in $($file.FullName): $parseErrors"
}
$manifestPath = Join-Path $root 'PowerIIQ.psd1'
$null = Test-ModuleManifest $manifestPath
$expected = @(
    'Connect-IIQ', 'Disconnect-IIQ', 'Get-IIQAsset', 'Get-IIQFilterItem',
    'Get-IIQObject', 'Get-IIQPart', 'Get-IIQTag', 'Get-IIQTicket', 'Get-IIQUser',
    'Invoke-IIQMethod', 'New-IIQFacetObject', 'New-IIQTicket',
    'Update-IIQAsset', 'Update-IIQAutoComplete', 'Update-IIQTicket'
) | Sort-Object
foreach ($entryPoint in @('PowerIIQ.psm1', 'PowerIIQ.psd1')) {
    $module = Import-Module (Join-Path $root $entryPoint) -Force -PassThru
    try {
        $actual = @($module.ExportedFunctions.Keys | Sort-Object)
        Assert-True (($actual -join ',') -eq ($expected -join ',')) "Unexpected exports from $entryPoint"
        foreach ($name in $expected) {
            $null = (Get-Command $name -Module PowerIIQ -ErrorAction Stop).Parameters
        }
        $disconnected = $false
        try { Invoke-IIQMethod -Path '/offline' | Out-Null } catch { $disconnected = $_.Exception.Message -like '*Connect*first*' }
        Assert-True $disconnected 'Disconnected requests must fail before contacting the API.'
        $facet = New-IIQFacetObject -Facet asset -Id '22222222-2222-2222-2222-222222222222'
        Assert-True ($facet.Facet -eq 'asset' -and $facet.Id -eq [guid]'22222222-2222-2222-2222-222222222222') 'Facet construction changed.'

        # Replace transport inside this module only. Queue deterministic API responses.
        & $module {
            $script:TestCalls = [System.Collections.Generic.List[object]]::new()
            $script:TestResponses = [System.Collections.Generic.Queue[object]]::new()
            function script:Invoke-RestMethod {
                [CmdletBinding()]
                param($Uri, $Method, $Headers, $ContentType, $Body)
                $script:TestCalls.Add(@{ Uri = $Uri; Method = $Method; Headers = $Headers; Body = $Body })
                if ($script:TestResponses.Count -eq 0) { throw 'Unexpected API call in offline test.' }
                $script:TestResponses.Dequeue()
            }
            $script:TestResponses.Enqueue([pscustomobject]@{ Items = @(@{ UserID = '33333333-3333-3333-3333-333333333333'; ProductId = '44444444-4444-4444-4444-444444444444' }) })
        }
        Connect-IIQ -APIToken 'offline-token' -SiteID '11111111-1111-1111-1111-111111111111' -BaseURL 'https://offline.invalid/api/v1.0' -NoAutocomplete
        $stateValid = & $module { $script:_IIQConnectionInfo.UserID -eq '33333333-3333-3333-3333-333333333333' -and $script:_IIQConnectionInfo.ProductID -eq '44444444-4444-4444-4444-444444444444' }
        Assert-True $stateValid 'Login did not populate shared connection state.'
        & $module { $script:TestResponses.Enqueue([pscustomobject]@{ Items = @('updated') }) }
        $null = Invoke-IIQMethod -Path '/assets/example' -Method POST -Data @{ Name = 'Example' } -OnlySetMappedProperties
        $requestValid = & $module {
            $call = $script:TestCalls[1]
            $call.Uri -eq 'https://offline.invalid/api/v1.0/assets/example' -and
            $call.Headers.Authorization -eq 'Bearer offline-token' -and
            $call.Headers.ApiFlags -eq 'OnlySetMappedProperties' -and
            ($call.Body | ConvertFrom-Json).Name -eq 'Example'
        }
        Assert-True $requestValid 'Request URL, headers, or JSON serialization changed.'
        Invoke-IIQMethod -Path '/assets/example' -Method DELETE -WhatIf | Out-Null
        Assert-True ((& $module { $script:TestCalls.Count }) -eq 2) 'WhatIf must suppress the transport call.'
        & $module {
            foreach ($index in 0..2) {
                $script:TestResponses.Enqueue([pscustomobject]@{ Items = @("page-$index"); Paging = @{ PageIndex = $index; PageCount = 3 } })
            }
        }
        $pages = @(Get-IIQObject -Path '/assets' -PageSize 2)
        Assert-True (($pages -join ',') -eq 'page-0,page-1,page-2') 'Pagination lost results.'
        $pagingValid = & $module {
            $script:TestCalls[2].Uri.EndsWith('/assets?$s=2') -and
            $script:TestCalls[3].Uri.EndsWith('/assets?$s=2&$p=1') -and
            $script:TestCalls[4].Uri.EndsWith('/assets?$s=2&$p=2')
        }
        Assert-True $pagingValid 'Pagination query parameters changed.'
        Disconnect-IIQ
        $cleared = & $module { $null -eq $script:_IIQConnectionInfo.APIToken -and $null -eq $script:_IIQConnectionInfo.UserID -and $script:_IIQConnectionInfo.Lookup.Count -eq 0 }
        Assert-True $cleared 'Disconnect must clear credentials and lookup state.'
        & $module { $script:TestResponses.Enqueue([pscustomobject]@{ Items = @() }) }
        $failedLogin = $false
        try { Connect-IIQ -APIToken 'offline-token' -SiteID '11111111-1111-1111-1111-111111111111' -BaseURL 'https://offline.invalid' -NoAutocomplete } catch { $failedLogin = $_.Exception.Message -like '*Error Connecting*' }
        Assert-True $failedLogin 'Empty login responses must fail.'
        Assert-True ((& $module { $null -eq $script:_IIQConnectionInfo.APIToken })) 'Failed login must clear credentials.'
        Write-Output "PASS: $entryPoint exports, state, transport, WhatIf, paging, and failed login"
    } finally {
        Remove-Module $module -Force
    }
}
Write-Output 'All offline module checks passed.'
