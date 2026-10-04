function Update-IIQAutoComplete {
    $_IIQConnectionInfo.Lookup.TicketStatus    =   @{}
    $_IIQConnectionInfo.Lookup.TicketAction    =   @{}
    $_IIQConnectionInfo.Lookup.CustomField     =   @{}
    $_IIQConnectionInfo.Lookup.CustomFieldR    =   @{}
    $_IIQConnectionInfo.Lookup.TicketIssue     =   @{}

    $workflow=Get-IIQObject /workflows
    Get-IIQObject "/tickets/$($workflow.WorkflowId)/statuses" | ForEach-Object {$_IIQConnectionInfo.Lookup.TicketStatus.Add($_.StepName,$_.WorkflowStepId)}
    Get-IIQObject /resolutions/actions | ForEach-Object {$_IIQConnectionInfo.Lookup.TicketAction.Add($_.Name,$_.ResolutionActionId)}
    <#
    Get-IIQObject /issues/types | ForEach-Object {
        if ($_IIQConnectionInfo.Lookup.TicketIssue[$_.Name] -eq $null){
            $_IIQConnectionInfo.Lookup.TicketIssue.Add($_.Name,$_.IssueTypeId)
        } else{
            $Tiebreaker=$_.IssueTypeId.Substring($_.IssueTypeId.Length-4,4)
            $_IIQConnectionInfo.Lookup.TicketIssue.Add("$($_.Name) - $Tiebreaker",$_.IssueTypeId)
        }
    }
    #>
    Get-IIQObject /custom-fields/types | ForEach-Object {
        if ($_.App.Name){$name="$($_.App.Name):$($_.Name)"} else {$name=$_.Name}
        $_IIQConnectionInfo.Lookup.CustomField.Add($Name,$_.CustomFieldTypeId)
        $_IIQConnectionInfo.Lookup.CustomFieldR.Add($_.CustomFieldTypeId,$Name)
    }
}
