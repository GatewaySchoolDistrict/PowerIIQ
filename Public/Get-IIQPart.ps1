function Get-IIQPart {
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [string[]]$Keyword,
        [switch]$Inventory
    )
    Begin {}
    Process {

        $PostData=
        @{
            "FilterByProduct"=$true
            "RequestOptions"=@{
                "Paging"=@{
                    "PageIndex"=0
                    "PageSize"=6
                    "SortField"="Name"
                    "SortDirection"="Ascending"
                }
                "Filters"=@(
                    @{
                        "Facet"="keyword"
                        "Values"=@(
                            $Keyword
                        )
                    }
                )
            }
        }
        $Parts=Get-IIQObject -Path /inventory/items/query -Method POST -Data $PostData -PageSize 99999

        if (-not $Inventory){
            return $Parts
        }
        if ($Parts -ne $null){
            foreach($Part in $Parts){
                
            }
        }


    }
    End {}
}
