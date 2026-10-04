function New-IIQTicket{
    [CmdletBinding()]
    param(
        #Required
        [guid]$LocationId,
        [guid]$ForID,
        [guid]$IssueID,
        [switch]$Sensitive,
        [switch]$Urgent,

        #[ValidateSet([TicketIssue])]
        #[string]$Issue,

        #Not Required
        [guid]$AssetId,
        [string]$Description,
        [string]$Subject

        #[guid]$IssueCategoryID,
        #[guid]$IssueTypeId,
        #[guid]$TicketWizardCategoryId
    )


    if (!$ForID){
        $ForID=$_IIQConnectionInfo.UserID
    }

    if (!$IssueID -and $Issue){
        $IssueID = $_IIQConnectionInfo.Lookup.TicketIssue.$Issue
    } elseif (!$IssueID -and !$Issue ){
        throw "No Issue specified"
    }
    
    if (!$LocationId){
        $ForUser=Get-IIQUser -UserID $ForID
        if ($ForUser.Length -ne 1){
            throw "Location is not specified and could not find location for user"
        }
        $LocationId=$ForUser.Location.LocationId
    }


    $NewTicketData=@{

        #Required
        "HasSensitiveInformation"=$Sensitive.IsPresent
        "LocationId"=$LocationID
        "SourceId"=1
        "ForId"=$ForID
        "IssueId"=$IssueID
        "IsTraining"=$false
        "ProductId"=$_IIQConnectionInfo.ProductID
        "IsUrgent"=$Urgent.IsPresent

        #Not Required Section
        <#
        "TicketFollowers"=$null
        "Locations"=$null
        "Users"=$null
        "Teams"=$null
        "Roles"=$null
        "AssetGroups"=$null
        "Attachments"=@()
        "LocationRoom"=$null
        "TicketWizardCategoryId"=$TicketWizardCategoryId
        #"Assets"=@(if ($AssetId){@{"AssetId"=$AssetId}})
        #>
        "IssueDescription"=$Description
        "Subject"=$Subject
        "Assets"=@(
            if ($AssetId){
                @{"AssetId"=$AssetId}
            }
        )
        #Unknown
        #This AssetIds does not appear to do anything.
        #"AssetIds"=@($AssetId)
        #"IssueCategoryId"=$IssueCategoryID
        #"IssueTypeId"=$IssueTypeId
    }
    #return $NewTicketData
    Get-IIQObject -Path /tickets/new -data $NewTicketData -Method POST
}
