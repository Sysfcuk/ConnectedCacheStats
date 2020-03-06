
<#
.SYNOPSIS
Outputs statistics form IIS log files relating to Microsoft Connected Cache

.DESCRIPTION 
Outputs statistics form IIS log files relating to Microsoft Connected Cache

.OUTPUTS
Outputs to an PowerShell object containing information on AWS instances.

.PARAMETER NumberOfLogs
Number of ISS logs to process, most recent first.

.PARAMETER IISLogPath
Path to IIS Log Directory

.PARAMETER DOUserAgent
Delivery optimization User Agent

.EXAMPLE
&.\Get-ConnectedCacheIISStats.ps1

.NOTES

Author:       Andy Cattle

Change Log:

03/03/2020: Initial Version

#>

Param (
    
        [Parameter(Mandatory=$false)]
        [int]$NumberOfLogs = 3,
        [Parameter(Mandatory=$false)]
        [string]$IISLogPath  = "C:\inetpub\logs\LogFiles\W3SVC1",
        [Parameter(Mandatory=$false)]
        [string]$DOUserAgent  = "Microsoft-Delivery-Optimization/10.0"
    
)

function Parse-IISLog {

    Param (
    
        [Parameter(Mandatory=$true, Position=0,
            ValueFromPipeline=$True,
            ValueFromPipelineByPropertyName=$true)]
        [Alias('FullName')]
        [string[]]$Path
    
    ) Process {

        foreach ($P in $Path) {

            Write-Verbose "Processing IIS Log File: $p"
            
            $Fields = (Get-Content $P `
                              | Select-Object -First 10 `
                              | Where-Object {$_ -match "\#Fields\: "}
                          ) -replace "\#Fields\: "  -split " "

            Get-Content $LatestLog.FullName `
                | Where-Object {$_[0] -ne "#"} `
                | ForEach-Object {
   
                $Entry = @{}

                $i = 0

                $_ -split " " | ForEach-Object {

                    $Entry[$Fields[$i++]] = $_

                }

                [pscustomobject]$Entry
        
            }
        }
    }
}

$LogsFiles = Get-ChildItem $IISLogPath

$DOData = $LogsFiles | Where-Object {$_.Name -like "u_ex*.log"} `
                     | Sort-Object Name -Descending | select -First $NumberOfLogs `
                     | Parse-IISLog -Verbose `
                     | Where-object {$DOUserAgent -contains $_."cs(User-Agent)"}

$DataByIP = $DOData | Group-Object c-ip | Select-Object @(
    @{
        Name = "IP Address"
        Expression = {$_."Name"}
    }
    @{
        Name = "Data GB"
        Expression = {
        
                $Bytes = $_.Group."sc-bytes" `
                    | Measure-Object -Sum `
                    | Select-Object -ExpandProperty Sum  `

                "{0:n2}" -f ($bytes / 1GB)
        
        }
    }
) | Sort-Object "IP Address"

$DataBySubnet = $DataByIP | ForEach-Object {
    [pscustomobject] @{
        "Subnet" = $_."IP Address" -replace "\d+\.\d+$","0.0"
        "Data GB" = $_."Data GB"
    }
} | Group-Object Subnet | Select-Object @(
    @{
        Name = "Subnet"
        Expression = {$_."Name"}
    }
    @{
        Name = "Data GB"
        Expression = {
        
                $GBytes = $_.Group."Data GB" `
                    | Measure-Object -Sum `
                    | Select-Object -ExpandProperty Sum  `

                "{0:n2}" -f $GBytes
        
        }
    }
) 

$TotalData = "{0:n2}" -f (($DOData."sc-bytes" `
                    | Measure-Object -Sum `
                    | Select-Object -ExpandProperty Sum) / 1GB)

Write-Host "Total Connected Cache Data: $($TotalData)GB" -ForegroundColor Yellow

Write-Host "`nData by Subnet (2 octets):" -ForegroundColor Cyan

$DataBySubnet | Format-Table -AutoSize

Write-Host "Data by IP Address:" -ForegroundColor Cyan

$DataByIP | Format-Table -AutoSize