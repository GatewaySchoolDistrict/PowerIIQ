function Update-IIQTicket {
    [CmdletBinding(SupportsShouldProcess = $True)]
    #[CmdletBinding(DefaultParameterSetName = 'Comment', SupportsShouldProcess = $True)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [guid]$TicketID,
        [string]$Comment,
        [switch]$Visible,
        [ValidateSet([TicketStatus])]
        [string]$Status,
        [guid]$StatusID,
        [Parameter(Mandatory = $false)]
        [guid]$UserId,
        [Parameter(Mandatory = $false)]
        [switch]$SendEmails,
        [Alias('ResolutionActionId')]
        [guid]$ActionID,
        [ValidateSet([TicketAction])]
        [string]$Action,
        [uint]$Effort,
        [datetime]$Date = (Get-Date),
        [ValidateScript({$null -ne ($_ -as [guid]) -or $null -ne $_.UserId})]
        $Assign
    )
    Begin {
        if ($null -eq $UserId) {
            $UserId = $_IIQConnectionInfo.UserID
        }
        if ($Status -notin $null,'' -and $null -eq $StatusID) {
            $StatusID = $_IIQConnectionInfo.Lookup.TicketStatus.$Status
        }
        if ($Action -notin $null,'' -and $null -eq $ActionID) {
            $ActionID = $_IIQConnectionInfo.Lookup.TicketAction.$Action
        }
        if ($null -ne $Assign){
            if ($null -ne $Assign.UserId){$Assign=$Assign.UserId}
            if ($null -ne ($_ -as [guid])){throw "Agent assignment is invalid"}
        }
    }
    Process {

            $actions = @()
            if ($ActionID -ne $null) {
                $actions += [ordered]@{
                    "`$type"               = "Spark.Shared.Models.TicketActivityAction, Spark.Shared"
                    "TicketActivityTypeId" = 8
                    "ActivityDate"         = '{0:yyyy-MM-ddTHH:mm:ss.fffZ}' -f $Date
                    "ByUserId"             = $UserId
                    "ResolutionActionId"   = $ActionID
                    "Notes"                = $Comment
                    "Effort"               = $Effort
                    "EffortIsValid"        = $true
                }
            } elseif ($Comment -notin $null,'') {
                $actions += [ordered]@{
                    "`$type"               = "Spark.Shared.Models.TicketActivityComment, Spark.Shared"
                    "TicketActivityTypeId" = 6
                    "ByUserId"             = $UserId
                    "Comments"             = $Comment
                }
            }

            if ($actions.length -gt 0){
            $Activity = [ordered]@{
                "TicketId"         = $TicketID
                "ActivityItems"    = $actions
                "IsPublic"         = [bool]$Visible
                "WaitForResponse"  = $false
                "TicketWasUpdated" = [bool]$SendEmails
            }
            $Path = "/tickets/$TicketID/activities/new"
            Get-IIQObject -Method POST -Path $Path -Data $Activity
        }

        if ($null -ne $StatusID) {
            $Path = "/tickets/$TicketID/status/$StatusID"
            Get-IIQObject -Method POST -Path $Path
        }

        if ($null -ne $Assign){
            Get-IIQObject -Method POST -Path "/tickets/$TicketID/assign" -data @{AssignToUserId=$Assign;TicketId=$TicketID}
        }
    }
    End {}
}
