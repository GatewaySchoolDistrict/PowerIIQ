function Update-IIQAsset {
    [CmdletBinding(SupportsShouldProcess = $True)]
    #[CmdletBinding(DefaultParameterSetName = 'Comment', SupportsShouldProcess = $True)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [guid]$AssetID,
        [Parameter(ValueFromPipelineByPropertyName)]$OwnerId,
        [Parameter(ValueFromPipelineByPropertyName)]$AssetTag,
        [Parameter(ValueFromPipelineByPropertyName)]$SerialNumber,
        [Parameter(ValueFromPipelineByPropertyName)]$ExternalID,
        [Parameter(ValueFromPipelineByPropertyName)]$CanOwnerManage,
        [Parameter(ValueFromPipelineByPropertyName)]$StatusTypeId,
        [Parameter(ValueFromPipelineByPropertyName)]$Name,
        [Parameter(ValueFromPipelineByPropertyName)]$ModelId,
        [Parameter(ValueFromPipelineByPropertyName)]$LocationId,
        [Parameter(ValueFromPipelineByPropertyName)]$LocationDetails,
        [Parameter(ValueFromPipelineByPropertyName)]$Notes,
        [Parameter(ValueFromPipelineByPropertyName)]$PurchasePoNumber,
        [Parameter(ValueFromPipelineByPropertyName)]$WarrantyInfo,
        [Parameter(ValueFromPipelineByPropertyName)]$Vendor,
        [Parameter(ValueFromPipelineByPropertyName)]$InsuranceInfo,
        [Parameter(ValueFromPipelineByPropertyName)]$StorageUnitNumber,
        [Parameter(ValueFromPipelineByPropertyName)]$LastInventoryDate,
        [Parameter(ValueFromPipelineByPropertyName)]$LocationRoomId,
        [Parameter(ValueFromPipelineByPropertyName)]$StorageLocationId,
        [Parameter(ValueFromPipelineByPropertyName)]$FundingSourceId,
        [Parameter(ValueFromPipelineByPropertyName)]$LastVerificationDateTime,
        [switch]$OnlySetMappedProperties,
        [Parameter(ValueFromPipelineByPropertyName)][switch]$Force,
        [array][Parameter(ValueFromPipelineByPropertyName)]$LinkAsset,
        [array][Parameter(ValueFromPipelineByPropertyName)]$UnLinkAsset
    )
    Begin {
        if ($PSBoundParameters.ContainsKey("OwnerId")){
            if ($null -ne $OwnerId -and $null -eq ($OwnerId -as [guid])){throw "OwnerID assignment is invalid"}
        }
    }
    Process {
        if (-not $Force){
            $ReferenceAsset=Get-IIQAsset -AssetID $AssetID
        }
        if ($null -eq $ReferenceAsset -and -not $Force){
            Write-Error "Update-IIQAsset: Asset $AssetID not found!"
            return
        }
        if ($PSBoundParameters.ContainsKey("OwnerId")){
            if($ReferenceAsset.OwnerId -ne $OwnerID -or $Force -eq $true){
                Write-Verbose "Updating Asset's Owner: $OwnerId"
                Get-IIQObject -Method POST -Path "/assets/$AssetID/owner" -Data @{OwnerId=$OwnerId}
            } else {
                Write-Verbose "Update-IIQAsset: No owner change"
            }
        }
        if ($PSBoundParameters.ContainsKey("LinkAsset")){
            $guids=Get-VariableArrayHelper -Data $LinkAsset -ObjectProperty AssetID -Type guid
            [array]$LinkedAssetGUIDs=
            foreach($guid in $guids){
                @{ChildAssetId=$guid}
            }
            if ($LinkedAssetGUIDs.Length -gt 0){
                Get-IIQObject -Method POST -Path "/assets/linked/to/$($ReferenceAsset.AssetID)" -Data $LinkedAssetGUIDs
            }
        }
        if ($PSBoundParameters.ContainsKey("UnLinkAsset")){
            $guids=Get-VariableArrayHelper -Data $UnLinkAsset -ObjectProperty AssetID -Type guid
            [array]$LinkedAssetGUIDs=
            foreach($guid in $guids){
                @{ChildAssetId=$guid}
            }
            if ($LinkedAssetGUIDs.Length -gt 0){
                Get-IIQObject -Method DELETE -Path "/assets/linked/to/$($ReferenceAsset.AssetID)" -Data $LinkedAssetGUIDs
            }
        }
        $AssetUpdates=$ReferenceAsset
        $PropertiesToSync=@("CanOwnerManage","StatusTypeId","AssetTag",
            "SerialNumber","ExternalId","Name","ModelId","LocationId",
            "LocationDetails","Notes","PurchasePoNumber","WarrantyInfo",
            "Vendor","InsuranceInfo","StorageUnitNumber","LastInventoryDate"
            "LocationRoomId","FundingSourceId", "LastVerificationDateTime"
            "StorageLocationId")
        foreach ($Prop in $PropertiesToSync){
            if ($PSBoundParameters.ContainsKey($Prop)){
                $Value=Get-Variable $Prop -ValueOnly
                if($Prop -match 'Date'){
                    if($null -ne ($Value -as [datetime])){
                        $Value='{0:yyyy-MM-ddTHH:mm:ss.fffZ}' -f ($Value -as [datetime])
                        if (('{0:yyyy-MM-ddTHH:mm:ss.fffZ}' -f $ReferenceAsset.$Prop) -ne $Value -or $Force){
                            $AssetUpdates[$Prop]=$Value
                        }
                        continue
                    } elseif($null -eq $Value){
                        $Value=$null
                    } else {
                        continue
                    }
                }
                if ($ReferenceAsset.$Prop -ne $Value -or $Force){
                    $AssetUpdates[$Prop]=$Value
                }
            }
        }
        if ($AssetUpdates.Count -gt 0){
            if($null -eq $AssetUpdates["AssetTag"]){
                #The asset tag is needed for updates so include it if it is missing from the update
                $AssetUpdates["AssetTag"]=$ReferenceAsset.AssetTag
            }
            if($null -eq $AssetUpdates["SerialNumber"]){
                #Set serial due to bug where it sometimes clears it out
                $AssetUpdates["SerialNumber"]=$ReferenceAsset.SerialNumber
            }
            Write-Verbose "Updating Asset's Properties"
            Get-IIQObject -Method POST -Path "/assets/$AssetID" -Data $AssetUpdates -OnlySetMappedProperties:$OnlySetMappedProperties
        } else {
            Write-Verbose "Update-IIQAsset: No asset changes found"
            return $ReferenceAsset
        }
    }
    End {}
}
