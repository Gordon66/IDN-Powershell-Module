Function get-IDNheaders {
<#
   .SYNOPSIS
        Script was built to generate needed varialbles for OAUTH Token generation 

   .DESCRIPTION
        Script was built to generate needed varialbles for OAUTH Token generation 

        Dependencies: 
        
        
        Constrains:
        
        
    .INPUTS 
        Instance = IDN (Tenant) Organisation
        
        
    .OUTPUTS:
        Creates Headers with a generated OUATH Token for authorization on aPAI calls 
    
        
    .PARAMETER  Global:Instance
        should contain the desired IDN target instance (tenant)
                        
    .EXAMPLE
        get-IDNheaders "ACME" 

    .NOTES
        Set-IDNData
        Version: 1.0
        Creator: Richard Sidor
        Date:    18-2-2019
            
        Changes
        -------------------------------------
        Date:      Version  Initials  Changes 
        18-2-2019   1.0      RS        Initial version

        
    .LINK
        https://api.identitynow.com/        
 #>

Param([Parameter(mandatory=$true,valuefrompipeline=$true,Position=0)]
[string]$global:instance = "YourTenantOrg" )

[string]$ent_url="https:`/`/$global:instance.identitynow.com`/api`/oauth`/token"
$gett = Invoke-WebRequest -Uri $ent_url -Body $global:payld -Headers $global:heads -Method POST
[string]$t = $($gett.Content | Out-String | ConvertFrom-Json).access_token
$Headers = @{Authorization = 'Bearer '+ $t}
return $Headers
}
Function get-IDNauthorisation {
<#
   .SYNOPSIS
        Script was built to generate needed varialbles for OAUTH Token generation 

   .DESCRIPTION
        Script was built to generate needed varialbles for OAUTH Token generation 

        Dependencies: 
        IDN local user credentials, API credentials          
        
        Constrains:
        
        
    .INPUTS 
        Instance = IDN (Tenant) Organisation
        IDN local admin credentials
        IDN API credentials
        
    .OUTPUTS:
        Creates variables with global scope for headers and payload for OAUTH Token generation $global:payld  $global:heads
    
        
    .PARAMETER  Global:Instance
        should contain the desired IDN target instance (tenant)
                        
    .EXAMPLE
        get-IDNauthorisation "ACME" 

    .NOTES
        Set-IDNData
        Version: 1.0
        Creator: Richard Sidor
        Date:    18-2-2019
            
        Changes
        -------------------------------------
        Date:      Version  Initials  Changes 
        18-2-2019   1.0      RS        Initial version

        
    .LINK
        https://api.identitynow.com/        
 #>
Param([Parameter(mandatory=$true,valuefrompipeline=$true,Position=0)]
[string]$global:instance = "YourTenantOrg" )

$global:heads = $null
$global:payld = $null

#credential input 
$crd = Get-Credential -Message "Please provide you IDN username and password" 
if (!($crd)) {write-output "Please enter IDN credentials." 
break}
$acrd = Get-Credential -Message "Please provide you API IDN username and password"
if (!($acrd)) {write-output "Please enter API credentials." 
break}
[string]$at = "$($acrd.GetNetworkCredential().username)`:$($acrd.GetNetworkCredential().password)"
[string]$at =[Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($at))
$global:heads = @{Authorization = "Basic $at"}

[array]$gett = @()

Function Get-StringHash([String]$String, [String]$HashName) { 
$StringBuilder = New-Object System.Text.StringBuilder 
[System.Security.Cryptography.HashAlgorithm]::Create($HashName).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($string))|foreach{[Void]$StringBuilder.Append($_.ToString("x2"))} 
$StringBuilder.ToString()
}

if ($global:heads) { 
remove-Variable at -Scope local
remove-Variable acrd -Scope local

$global:payld = @{grant_type ='password'
username = $($crd.GetNetworkCredential().username) 
password = $(Get-StringHash "$($($crd.GetNetworkCredential().password.tostring())+$(Get-StringHash "$($crd.GetNetworkCredential().username.ToLower().tostring())" "SHA256"))" "SHA256")}

if ($global:payld) {remove-Variable crd -Scope local}
    }
}
Function delete-idnroles {
<#
   .SYNOPSIS
        Script was built to delete selected IDN roles

   .DESCRIPTION
        Script was built to delete a set of selected IDN roles. User defines name fiter upon which group of roles from specified IDN instance and source is selected. 
        Roles have to be removed from users before running the cleanup in IDN.  
        Connection to IDN Url. Local IDN account and API credentials. 
          
        Constrains:
        You have to load functions get-idnauthorisation and get-idnheaders before running the script 
        
        
    .INPUTS 
        Filter - name filtering parameter to select group of access profiles 
        IDN and API Credentials
        
    .OUTPUTS:
        Deletion of the selected group of roles in IDN. Exports succeeded deletions and failed deletions as xml file on your desktop. 
      
    .PARAMETER  Global:Filter
        has to contain desired name mask for access profile group selection 

            
    .EXAMPLE
        delete-idrole YourTenantOrg GRBTAC*

    .NOTES
        delete-IDNroles
        Version: 1.2
        Creator: Richard Sidor
        Date:    05-02-2019
            
        Changes
        -------------------------------------
        Date:      Version  Initials  Changes 
        30-10-2018   1.0     RS       Initial version
        05-02-2019   1.2     RS       Authorisation part standardised with other scripts, correction of logging 
        
    .LINK
        https://api.identitynow.com/        
 #>

[CmdletBinding()]
Param([Parameter(mandatory=$true,valuefrompipeline=$true,Position=0)]
[string]$global:instance,
[Parameter(mandatory=$true,valuefrompipeline=$true,Position=1)]
[string]$global:filter 
)


$global:hds = $null
$global:pd = $null
[string]$global:Timestamp = (get-date).ToString('d-M-yyyy_HH-mm-ss')

[string]$summarypath = "$env:USERPROFILE\Desktop\$global:Timestamp\"
[string]$summaryfile = "$($global:instance)-role-deletion-summary.txt"

IF (!(test-path $summarypath)){try{new-item -ItemType Directory -path $summarypath
cls
}
catch {write-output "Not able to create report folder on your desktop." }
}


get-IDNauthorisation $global:instance


if ($global:pd) {remove-Variable crd -Scope local}

DO {

[array]$failed = @()
[array]$succeeded = @()

[array]$get = @()
[array]$global:roles = @()
[array]$global:delroles = @()


[int]$page=0
[int]$limit=250

[array]$get = @()

DO { 
$ent_Headers = get-IDNheaders $global:instance

[string]$url ="https://$global:instance.api`.identitynow.com/cc/api/role/list?start=$page&limit=250&sort=%5B%7B%22property%22%3A%22displayName%22%2C%22direction%22%3A%22ASC%22%7D%5D"
$get = Invoke-WebRequest -Uri $url -Headers $ent_Headers -Method GET 
$page +=249
[array]$global:roles += ($get.Content | Out-String | convertfrom-json)
[int]$perc = (($global:roles.Items).count/($global:roles | select count).count *100)
Write-Progress -Activity "Reading roles from IDN instance $($global:instance)" -Status "Percent complete...$perc`% of $(($global:roles | select count).count) records read" -PercentComplete $perc -Completed
} WHILE (($global:roles.Items).count -lt ($global:roles | select count).count)

$global:roles = $global:roles.items |sort displayname -Unique

if (!(test-path $summarypath$global:Timestamp-Roles-backup.xml)){ Export-Clixml -InputObject $global:roles -Path "$summarypath$global:Timestamp-Roles-backup.xml" -NoClobber}

"`r`n"*6
Write-output "The number of found roles in IDN: $($global:roles.count). Backup export done to file $($summarypath)$($global:Timestamp)-Roles-backup.xml" | Tee-object -FilePath  $summarypath$summaryfile -Append

if (!($global:filter)) {$global:filter = Read-Host "Please select filter (Role name mask) to select colletion of roles for deletion. (Mask characters avaliable:*)"}

if ($global:filter) {$global:delroles = $global:roles | select displayname,owner | ?{$_.Displayname -like "$global:filter"}}

if ($global:delroles) {
Write-output "The number of roles selected : $($global:delroles.count)" | Tee-object -FilePath  $summarypath$summaryfile -Append

$global:delroles

[string]$question = read-host "Proceed with deletion? y/n"
    while ($question -notmatch "[yYnN]{1}" -or $question.length -gt 1){
        if ($question -match "[nN]{1}" -and $question.length -eq 1) { 
        Write-output "Deletion aborted."
        Break}
        $question = read-host "Proceed with deletion? y/n"
    }

#deletion of connected roles 
if ($question -match "[yY]{1}" -and $question.length -eq 1){
[int]$counter=0

foreach ($dr in $global:delroles){
[int]$perc = (($Counter/$global:delroles.count) *100)
Write-Progress -Activity "Deleting roles from IDN instance $($global:instance) and source $($global:source)" -Status "Percent complete...$perc`% of $($global:delroles.count.tostring()) : Deleting $($dr.displayName)" -PercentComplete (($Counter/$global:delroles.count) *100) -Completed
 
$ent_Headers = get-IDNheaders $global:instance

[string]$url ="https:`/`/$global:instance`.api`.identitynow`.com`/cc`/api`/role`/delete`/$($dr.id)"
[string]$post = $dr | ConvertTo-Json

$get = Invoke-WebRequest -Uri $url -body $post -ContentType 'application/json' -Headers $ent_Headers -Method POST  

if($get.statuscode -eq 200){$succeeded +=$dr}
elseif ($get.statuscode -ne 200) {$failed +=$dr}
$counter++
}

Write-output "The number of deleted roles : $($succeeded.count)" | Tee-object -FilePath  $summarypath$summaryfile -Append
Write-output "The number of failed role deletions : $($failed.count)" | Tee-object -FilePath  $summarypath$summaryfile -Append

$failed | Export-Clixml -Path "$summarypath$global:Timestamp-failed-role_deletions.xml"
$succeeded | Export-Clixml -Path "$summarypath$global:Timestamp-succeeded-role_deletions.xml"

}
}
if (!($global:delroles)) {
Write-output "No roles for deletion were selected." | Tee-object -FilePath  $summarypath$summaryfile -Append}

$global:filter = $null

$question0 = Read-host "Do you want to delete additional role(s)? y/n"
    while ($question0 -notmatch "[yYnN]{1}" -or $question0.length -ne 1){
        if ($question0 -match "[nN]{1}" -and $question0.length -eq 1) { 
        Write-output "Exiting ...."
        break}
        $question0 = Read-host "Do you want to delete additional role(s)? y/n"
            }

} UNTIL($question0 -match "[nN]{1}" -and $question0.length -eq 1)

Write-host "Script has ended. Summary and export files can be found in : $($summarypath)" -foreground green

Remove-Variable pd -Scope global
Remove-Variable hds -Scope global
Remove-Variable instance -Scope global
Remove-Variable Timestamp -Scope global
}
Function delete-IDNsources{
<#
   .SYNOPSIS
        Script was built to delete IDN Source(s)

   .DESCRIPTION
        Script was built to delete set of selected (by name mask) IDN Source(s) and reset them in case if the deletion does not proceed succesfully. 

        Dependencies: 
          Connection to IDN Url. Local IDN account and API credentilas.       
        
        Constrains:
          You have to load functions get-idnauthorisation and get-idnheaders before running the script 

                
    .INPUTS 
        Filter = Name mask filter for selection of IDN sources, mask character *
               
    .OUTPUTS:
        Deletes a selection of IDN Source(s) and created summary txt file in folder on your desktop  
    
    .PARAMETER  Instance
        should contain the desired IDN (tenant) instance 

    .PARAMETER  Filter
        should define source name or mask or multiple sources 
                        
    .EXAMPLE
        delete-IDNsources yourtenant mask*

    .NOTES
        delete-IDNsources
        Version: 1.2
        Creator: Richard Sidor
        Date:    20-03-2019
            
        Changes
        -------------------------------------
        Date:      Version  Initials  Changes 
        31-01-2019 1.0      RS        Initial version
        20-03-2019 1.2      RS        Improved user interaction part 
        
    .LINK
        https://api.identitynow.com/        
 #>

Param([Parameter(mandatory=$false,valuefrompipeline=$true,Position=0)]
[string]$global:instance = "YourTenantOrg", 
[Parameter(mandatory=$false,valuefrompipeline=$true,Position=1)]
[string]$Filter = $null
)

[array]$fail = @()
[array]$success = @()
[array]$get = @()
[array]$sources = @()
[array]$delsources = @()

$global:hds = $null
$global:pd = $null

[string]$global:Timestamp = (get-date).ToString('d-M-yyyy_HH-mm-ss')

[string]$summarypath = "$env:USERPROFILE\Desktop\$global:Timestamp\"
[string]$summaryfile = "delete-summary.txt"

IF (!(test-path $summarypath)){try{new-item -ItemType Directory -path $summarypath
cls
}
catch {write-output "Not able to create report folder on your desktop." }
}

get-IDNauthorisation $global:instance

#Query for list of configured AD sources 
[int]$page=0
[int]$limit=250

[array]$get = @()

$ent_Headers = get-IDNheaders

DO { 
[string]$url ="https://$global:instance.api.identitynow.com/cc/api/source/list?start=$page&limit=250&sort=%5B%7B%22property%22%3A%22displayName%22%2C%22direction%22%3A%22ASC%22%7D%5D"
$get = Invoke-WebRequest -Uri $url -Headers $ent_Headers -Method GET 
$page +=249
[array]$sources += $get.Content | Out-String | convertfrom-json

<#
[int]$perc = (($sources.count/$get.Headers.'X-Total-Count') *100)
Write-Progress -Activity "Reading sources from IDN instance $($global:instance)" -Status "Percent complete...$($perc)`% of $($get.Headers.'X-Total-Count') sources read" -PercentComplete $($perc)
#>

} WHILE ($sources.count -lt $get.Headers.'X-Total-Count')

$sources = $sources | select id,name,description,owner,sourceConnectorName,sourceType |sort name -Unique

if ($sources){
DO{

Write-Host "Avaliable IDN sources for $($global:instance) are these $($sources.count):" | Tee-object -FilePath  $summarypath$summaryfile -Append
$sources | ft -Wrap | Tee-object -FilePath  $summarypath$summaryfile -Append


if (!($filter)) {$filter = Read-Host "Please select filter to select colletion of sources for deletion"}

$delsources = $sources | ?{$_.Name -like "$($filter)"} 

if ($delsources){

[boolean]$reset =$false

    Write-Host "Selected sources are:" | Tee-object -FilePath  $summarypath$summaryfile -Append
    $delsources | ft -wrap | Tee-object -FilePath  $summarypath$summaryfile -Append
    [string]$question = read-host "Do You want to proceed with deletion of the selected sources? y/n"
    while ($question.length -ne 1 -or $question -notmatch "[yYnN]{1}"){
    if ($question.length -eq 1 -and $question -match "[nN]{1}") { 
    Write-output "Deletion aborted."
    Break}
    $question = read-host "Do You want to proceed with deletion of the selected sources? y/n"
    }

if ($question.length -eq 1 -and $question -match "[yY]{1}") {
[int]$counter = 0

foreach ($id in $delsources){
$counter++
[int]$perc = ($counter/ $delsources.count) *100
Write-Progress -Activity "Deleting sources from IDN instance $($global:instance) - deleting source: $($id.id) - $($id.name)" -Status "Percent complete...$($perc)`% of $($delsources.count) sources deleted" -PercentComplete $($perc)


    try {$ent_Headers = get-IDNheaders
    Write-host "Deleting source: $($id.id) - $($id.name)." | Tee-object -FilePath  $summarypath$summaryfile -Append
    [string]$url = "https://$($global:instance).identitynow.com/api/source/delete/$($id.id)"
    $send = Invoke-WebRequest -Uri $url -Headers $ent_Headers -Method POST  
    start-Sleep -seconds 180
          }

    catch {
    $ent_Headers = get-IDNheaders
    Write-host "There was an error deleting source: $($id.id) - $($id.name). Triggering reset of the source." | Tee-object -FilePath  $summarypath$summaryfile -Append
    [string]$url = "https://$($global:instance).identitynow.com/api/source/reset/$($id.id)"
    $send = Invoke-WebRequest -Uri $url -Headers $ent_Headers -Method POST  
    if ($send.StatusCode -eq 200) {
    [boolean]$reset = $true
    Write-host "Source reset succesfully initiated: $($id.id) - $($id.name)" | Tee-object -FilePath  $summarypath$summaryfile -Append
    start-Sleep -seconds 180
        }
    }

finally { 
    
    switch ($reset){
   $true {  Write-host "Waiting for source reset to finish and retrying the deletion: : $($id.id) - $($id.name)"             
            $ent_Headers = get-IDNheaders            
            Write-host "Retrying deletion of the source after it has been reset: $($id.id) - $($id.name)" 
                [string]$url = "https://$($global:instance).identitynow.com/api/source/delete/$($id.id)"
                $send = Invoke-WebRequest -Uri $url -Headers $ent_Headers -Method POST  
            start-sleep -seconds 180
    
    #Query for list of configured AD sources 
    $sources = @()
    [int]$page=0
    [int]$limit=250

    [array]$get = @()

    $ent_Headers = get-IDNheaders

    DO { 
    [string]$url ="https://$global:instance.api.identitynow.com/cc/api/source/list?start=$page&limit=250&sort=%5B%7B%22property%22%3A%22displayName%22%2C%22direction%22%3A%22ASC%22%7D%5D"
    $get = Invoke-WebRequest -Uri $url -Headers $ent_Headers -Method GET 
    $page +=249
    [array]$sources += $get.Content | Out-String | convertfrom-json

    <#
    [int]$perc = (($sources.count/$get.Headers.'X-Total-Count') *100)
    Write-Progress -Activity "Reading sources from IDN instance $($global:instance)" -Status "Percent complete...$($perc)`% of $($get.Headers.'X-Total-Count') sources read" -PercentComplete $($perc)
    #>

    } WHILE ($sources.count -lt $get.Headers.'X-Total-Count')

    $sources = $sources | select id,name,description,owner,sourceConnectorName,sourceType |sort name -Unique

    if ($id.id -notin $sources.id) {Write-host "Source was succesfully deleted: $($id.id) - $($id.name)" }  
    elseif ($id.id -in $sources.id){Write-host "Source is still avaliable. Please check manually: $($id.id) - $($id.name)"  
                
        }
    }
   $false {    
    #Query for list of configured AD sources 
    $sources = @()
    [int]$page=0
    [int]$limit=250

    [array]$get = @()

    $ent_Headers = get-IDNheaders

    DO { 
        [string]$url ="https://$global:instance.api.identitynow.com/cc/api/source/list?start=$page&limit=250&sort=%5B%7B%22property%22%3A%22displayName%22%2C%22direction%22%3A%22ASC%22%7D%5D"
        $get = Invoke-WebRequest -Uri $url -Headers $ent_Headers -Method GET 
        $page +=249
        [array]$sources += $get.Content | Out-String | convertfrom-json

        <#
        [int]$perc = (($sources.count/$get.Headers.'X-Total-Count') *100)
        Write-Progress -Activity "Reading sources from IDN instance $($global:instance)" -Status "Percent complete...$($perc)`% of $($get.Headers.'X-Total-Count') sources read" -PercentComplete $($perc)
        #>

    } WHILE ($sources.count -lt $get.Headers.'X-Total-Count')

    $sources = $sources | select id,name,description,owner,sourceConnectorName,sourceType |sort name -Unique

    if ($id.id -notin $sources.id) {Write-host "Source was succesfully deleted: $($id.id) - $($id.name)" }  
    elseif ($id.id -in $sources.id) {  

                Write-host "Source is still avaliable. Waiting for source reset to finish and retrying the deletion."  
                $sources | ?{$_.id -like "$($id.id)"} 
                start-sleep -seconds 180

                [string]$url = "https://$($global:instance).identitynow.com/api/source/delete/$($id.id)"
                $send = Invoke-WebRequest -Uri $url -Headers $ent_Headers -Method POST  

                if ($send.StatusCode -eq 200) {Write-host "Retriggered the deletion of the source: $($id.id) - $($id.name)" | Tee-object -FilePath  $summarypath$summaryfile -Append}
                }           
            } 
        } 

      }
    }    
  }
}

$filter = $null

$question0 = Read-host "Do you want to delete additional source(s)? y/n"
    while ($question0.length -ne 1 -or $question0 -notmatch "[yYnN]{1}"){
        if ([int]$question0.length -eq 1 -and $question0 -match "[nN]{1}") { Write-output "Exiting ...."
        break}

        $question0 = Read-host "Do you want to delete additional source(s)? y/n"
            }

} UNTIL([int]$question0.length -eq 1 -and $question0 -match "[nN]{1}")
}

Write-host "Script has ended. Summary and export files can be found in : $($summarypath)" -foreground green

if ($global:pd){Remove-Variable pd -Scope global}
if ($global:hds){Remove-Variable hds -Scope global}
if ($global:instance){Remove-Variable instance -Scope global}
if ($global:delsources){Remove-Variable delsources -Scope global}
if ($global:source){Remove-Variable source -Scope global}
if ($global:Timestamp){Remove-Variable Timestamp -Scope global}

}
Function get-IDNConnectors {
<#
   .SYNOPSIS
        Script was built to export configuration files for connectors in an IDN Instance

   .DESCRIPTION
        Script was built to export zipped configuration files from IDN connectors for backup purposes. 
        The script will get a list of connectors and downloads the configuration files to folder "$env:USERPROFILE\Desktop\$global:Timestamp\". 
        You can use "-single" switch to imply that you want to export configuration file of a single connector. Script will let you choose the one you want to export from a table.    
        Otherwise the script will export configuration bundles of all connectors in you IDN instance along with overview file.  
                
        Dependencies: 
        Connection to IDN Url. Local IDN account and API credentilas. Loaded functions get-IDNauthorisation and get-IDNheaders from our module. 
          
        Constrains:
        
        
    .INPUTS 
        Instance - tenant organisation - name of the IDN instance YouTenantOrg set as default in case you will not provide any 
        IDN user and API user Credentials
        
    .OUTPUTS:
        List of the IDN connectors and their configuration files (JSON,XML) in folder $env:USERPROFILE\Desktop\$global:Timestamp\$($global:instance)-connectors-$Timestamp\

              
    .PARAMETER  Global:Instance
        has to contain desired IDN instance (YouTenantOrg)

        
    .EXAMPLE
        get-idnconnectors YouTenantOrg -single

    .NOTES
        get-idnconnectors 
        Version: 1.2
        Creator: Richard Sidor
        Date:    29-03-2019
            
        Changes
        -------------------------------------
        Date:      Version  Initials  Changes 
        13-11-2018  1.0      RS        Initial version
        29-03-2019  1.2      RS        Script standardised. Added error handling
    
    .LINK
        https://api.identitynow.com/        
 #>

[CmdletBinding()]
Param ([Parameter(mandatory=$true,valuefrompipeline=$true,Position=0)]
[string]$global:instance, 
[Parameter(mandatory=$false,valuefrompipeline=$false,Position=1)]
[switch]$single  
)

[array]$fail = @()
[array]$success = @()
[array]$get = @()
[array]$global:connectors = @()
[string]$global:Timestamp = (get-date).ToString('d-M-yyyy_HH-mm-ss')

[string]$global:summarypath = "$env:USERPROFILE\Desktop\$global:Timestamp\"
[string]$global:summaryfile = "$($global:instance)-Export_summary.txt"

IF (!(test-path $global:summarypath)){try{new-item -ItemType Directory -path $global:summarypath -Force
cls
}
catch {write-output "Not able to create report folder on your desktop." }
}

get-IDNauthorisation $global:instance


#Query for list of configured AD connectors  
$counter = 0

[int]$page=0
[int]$limit=250
[array]$get = @()

DO { 
$ent_Headers = get-IDNheaders $global:instance

[string]$url ="https://$global:instance.api`.identitynow.com/cc/api/connector/list?start=$page&limit=250&sort=%5B%7B%22property%22%3A%22displayName%22%2C%22direction%22%3A%22ASC%22%7D%5D"

$get = Invoke-WebRequest -Uri $url -Headers $ent_Headers -Method GET 
$page +=249
[array]$global:connectors += $get.Content | Out-String | convertfrom-json

[int]$perc = ($global:connectors.items.count / $global:connectors[0].total) * 100
Write-Progress -Activity "Getting list of connecotrs from IDN instance $($global:instance)" -Status "Percent complete...$($perc)`% of $($get.Headers.'X-Total-Count') connectors exported" -PercentComplete $($perc) 


} WHILE ($global:connectors.items.count -lt $global:connectors[0].total)

if ($Global:connectors){
$Global:connectors = $Global:connectors.items 
$Global:connectors | export-csv -path "$global:summarypath$global:instance-connectors-$Timestamp.csv" -Delimiter ";" -NoTypeInformation -noclobber}

if ($single) {$global:connectors = $global:connectors| out-gridview -PassThru -Title "Please select a desired source for export. "
 }

#Export of the selected connetor(s)
[int]$counter = 0

foreach ($id in $global:connectors) {
$ent_Headers = get-IDNheaders $global:instance
$counter ++ 
[int]$perc = ($counter / $global:connectors.count) * 100
Write-Progress -Activity "Exporting settings of connecotrs from IDN instance $($global:instance)" -Status "Percent complete...$($perc)`% of $($global:connectors.count) connectors exported" -PercentComplete $($perc) 

[string]$url = "https://$($global:instance).identitynow.com/api/connector/export/$($id.id)"

$get = Invoke-WebRequest -Uri $url -Headers $ent_Headers -Method GET -OutFile "$global:summarypath$($id.id).zip"

write-output "Exporting connector $($id.id) - $($id.name) - $($id.scriptname) "| Tee-object -FilePath  $global:summarypath$global:summaryfile -Append

}

Write-host "Script has ended. Summary and export files can be found in : $($global:summarypath)" -foreground green

if ($global:pd){Remove-Variable pd -Scope global}
if ($global:hds){Remove-Variable hds -Scope global}
if ($global:instance){Remove-Variable instance -Scope global}
if ($global:Timestamp){Remove-Variable Timestamp -Scope global}
if ($global:connectors){Remove-Variable connectors -Scope global}

}
Function get-IDNidprofiles {
<#
   .SYNOPSIS
        Script was built to get list of IDN identity profiles and export their configuration to files 
         
   .DESCRIPTION
        Script was built to get list of IDN identity profiles and export their configuration to files in folder on this path C:\temp\profiles\$($global:instance)-IDprofiles-$global:Timestamp

        Dependencies: 
        Connection to IDN Url. IDN account and API credentilas. Loaded functions get-IDNauthorisation and get-IDNheaders from our module. 
          
        Constrains:
        
        
    .INPUTS 
        Instance - name of the IDN instance YourTenantOrg set as default in case you will not provide any 
        IDN user and API user Credentials
        
    .OUTPUTS:
        List of the IDN identity profiles and their configuration files (JSON,XML) in folder defined in C:\temp\profiles\$($global:instance)-IDprofiles-$($global:Timestamp)\ and in a global variable $global:IDNidprofiles

              
    .PARAMETER  Global:Instance
        has to contain desired IDN instance (YourTenantOrgn)

        
    .EXAMPLE
        get-IDNidprofiles YourTenantOrg

    .NOTES
        delete-IDNData
        Version: 1.0
        Creator: Richard Sidor
        Date:    11-2-2019
            
        Changes
        -------------------------------------
        Date:      Version  Initials  Changes 
        11-2-2019  1.0      RS        Initial version
    
    .LINK
        https://api.identitynow.com/        
 #>

[CmdletBinding()]
Param([Parameter(mandatory=$false,valuefrompipeline=$true,Position=0)]
[string]$global:instance = "YourTenantOrg" )

[string]$global:Timestamp = (get-date).ToString('d-M-yyyy_HH-mm-ss')

[array]$get = @()
[array]$global:IDNidprofiles = @()
$result = @()

[string]$summarypath = "C:\temp\profiles\$($global:instance)-IDprofiles-$($global:Timestamp)\"
[string]$summaryfile = "Export_summary.txt"

if (!(test-path -path $summarypath)) {new-item -ItemType Directory -path $summarypath | Out-Null
cls}


get-IDNauthorisation $global:instance
 

#Query for list of configured ID profiles 
#Query for list of configured AD profiles 

try{
    $get = @()
    $ent_Headers = get-IDNheaders
     Write-Host "Getting list of identity profiles from tenant organisation: $($global:instance)" | tee-object -FilePath $summarypath$summaryfile -Append
    
    [string]$url ="https://$global:instance.api`.identitynow.com/cc/api/profile/list"
    
    $get = Invoke-WebRequest -Uri $url -Headers $ent_Headers -Method GET 
    
    $global:IDNidprofiles = $get.Content | Out-String | convertfrom-json}
    
    catch {Write-Host "Could not retrieve IDN profiles from: $($url)" | tee-object -FilePath $summarypath$summaryfile -Append}
    
    
    if ($single) {$global:IDNidprofiles = $global:IDNidprofiles| out-gridview -PassThru -Title "Please select a desired IDN identity profile for export. "
     }
    
    if ($global:IDNidprofiles){
    Write-Host "Total number of found IDN profiles: $($global:IDNidprofiles.count)" | tee-object -FilePath $summarypath$summaryfile -Append
    $global:IDNidprofiles | export-csv -path $summarypath$($global:instance)-IDprofiles-$global:Timestamp.csv -Delimiter ";" -NoTypeInformation
    $global:IDNidprofiles | select id,name,description,identityCount,source | ft -wrap | tee-object -FilePath $summarypath$summaryfile -Append
    
    $ent_Headers = get-IDNheaders
    
    $counter = 0
    
        foreach ($prof in $global:IDNidprofiles){
            
            Write-Host "Exporting identity profile: $($prof.id) - $($prof.name)" | tee-object -FilePath $summarypath$summaryfile -Append
    
            [string]$url ="https://$global:instance.api`.identitynow.com/cc/api/profile/get/$($prof.id)"
            $get = Invoke-WebRequest -Uri $url -Headers $ent_Headers -Method GET 
            $get.Content > $summarypath$($prof.id).json
            $counter++
    
            [int]$perc = ($counter / $global:IDNidprofiles.items.count ) *100
            Write-Progress -Activity "Exporting identity profiles from IDN instance $($global:instance): $($prof.id) - $($prof.name)" -Status "Percent complete...$($perc)`% of $($global:IDNidprofiles.items.count) ID profiles exported" -PercentComplete $($perc)
    
            }
         }
    if (!($global:IDNidprofiles)){Write-Host "No IDN profiles found in this IDN instance (tenant)!" | tee-object -FilePath $summarypath$summaryfile -Append
    break}
    
    Write-host "Export has ended. Summary and export files can be found in : $($summarypath)" -foreground green
    
    Remove-Variable pd -Scope global
    Remove-Variable hds -Scope global
    Remove-Variable instance -Scope global
    Remove-Variable Timestamp -Scope global
    Remove-Variable IDNidprofiles -Scope global
}
Function get-IDNSources {
<#
   .SYNOPSIS
        Script was built to export and backup configuration files for sources in an IDN Instance

   .DESCRIPTION
        Script was built to export configuration Json and XML files from IDN Sources for backup purposes. 
        The script will get a list of sources and downloads the configuration files to folder C:\temp\sources\$($global:instance)-Sources. 
        
        Dependencies: 
        Connection to IDN Url. Local IDN account and API credentilas. 
          
        Constrains:
        You have to load functions get-idnauthorisation and get-idnheaders before running the script 
        
    .INPUTS 
        Instance - tenant organisation - name of the IDN instance YourTenantOrg set as default in case you will not provide any 
        IDN user and API user Credentials
        
    .OUTPUTS:
        List of the IDN Sources and their configuration files (JSON,XML) in folder C:\temp\sources\$($global:instance)-Sources-$Timestamp\

              
    .PARAMETER  Global:Instance
        has to contain desired IDN instance (YourTenantOrgn)

        
    .EXAMPLE
        get-idnsources YourTenantOrg

    .NOTES
        delete-IDNData
        Version: 1.2
        Creator: Richard Sidor
        Date:    21-1-2019
            
        Changes
        -------------------------------------
        Date:      Version  Initials  Changes 
        13-11-2018 1.0      RS        Initial version
        21-1-2019  1.2      RS        Added error handling
    
    .LINK
        https://api.identitynow.com/        
 #>

[CmdletBinding()]
Param([Parameter(mandatory=$false,valuefrompipeline=$true,Position=0)]
[string]$global:instance = "YourTenantOrg" )

[string]$Timestamp = (get-date).ToString('d-M-yyyy_HH-mm-ss')
[string]$summarypath = "C:\temp\sources\$($global:instance)-Sources-$Timestamp\"
[string]$summaryfile = "$($global:instance)-Export_summary.txt"

if (!(test-path -path $summarypath)) {new-item -ItemType Directory -path $summarypath | Out-Null}

[array]$get = @()
[array]$global:sources = @()
[array]$global:source = @()

$global:hds = $null
$global:pd = $null
[string]$global:Timestamp = (get-date).ToString('d-M-yyyy_HH-mm-ss')

get-IDNauthorisation $global:instance

#Query for list of configured AD sources 
$counter = 0

[int]$page=0
[int]$limit=250
[array]$get = @()

DO { 
$ent_Headers = get-IDNheaders $global:instance

[string]$url ="https://$global:instance.api`.identitynow.com/cc/api/source/list?start=$page&limit=250&sort=%5B%7B%22property%22%3A%22displayName%22%2C%22direction%22%3A%22ASC%22%7D%5D"

$get = Invoke-WebRequest -Uri $url -Headers $ent_Headers -Method GET 

$page +=249

$source = $get.Content | Out-String | convertfrom-json

[array]$global:sources += $source

[int]$perc = ($global:sources.count / $get.Headers.'X-Total-Count') *100

Write-Progress -Activity "Exporting sources from IDN instance $($global:instance): $($source.name) - ID $($sourcename.id)" -Status "Percent complete...$($perc)`% of $($get.Headers.'X-Total-Count') sources exported" -PercentComplete $($perc)

} WHILE ($global:sources.count -lt $get.Headers.'X-Total-Count')


Write-Host "Number of found IDN sources: $($Global:sources.count)" | tee-object -FilePath $summarypath$summaryfile -Append
$Global:sources | export-csv -path $summarypath$($global:instance)-Sources-$Timestamp.csv -Delimiter ";" -NoTypeInformation

$global:sources | select name,id,owner,sourceConnectorName,sourcetype | ft -wrap | tee-object -FilePath $summarypath$summaryfile -Append

$question0 = Read-host "Do you want to export a single source? y/n"

while ($question0 -notmatch "[yYnN]{1}"){

if ($question0 -match "[nN]{1}") { 
Write-output "Proceeding with export of all sources."| tee-object -FilePath $summarypath$summaryfile -Append
Continue}
$question0 = Read-host "Do you want to export a single source? y/n"
}

if ($question0 -match "[yY]{1}") { 
$global:sources = $global:sources | out-gridview -PassThru -Title "Please select a desired source for export. "
Write-output "Proceeding with export of a single source: $($global:countries) "| tee-object -FilePath $summarypath$summaryfile -Append
}

if ($Global:sources) {
Write-output "Source(s) selected for export:"| tee-object -FilePath $summarypath$summaryfile -Append
$global:sources | select name,id,owner,sourceConnectorName,sourcetype | ft -wrap | tee-object -FilePath $summarypath$summaryfile -Append


foreach ($id in $global:sources.id) {

$ent_Headers = get-IDNheaders $global:instance

[string]$url = "https://$($global:instance).identitynow.com/api/source/get/$($id)"
$get = Invoke-WebRequest -Uri $url -Headers $ent_Headers -Method GET -OutFile $summarypath$($id).json


    if ($?) {write-host "JSON Configuration of the source $($id) exported fine." | tee-object -FilePath $summarypath$summaryfile -Append }
    elseif ($? -eq $false) {write-host "There was a problem with JSON export of the sources confiration: $($id)." | tee-object -FilePath $summarypath$summaryfile -Append}         
    
[string]$url = "https://$($global:instance).identitynow.com/cc/api/source/export/$($id)"
$get = Invoke-WebRequest -Uri $url -Headers $ent_Headers -Method GET -OutFile $summarypath$($id).xml

    if ($?) {write-host "XML Configuration of the source $($id) exported fine." | tee-object -FilePath $summarypath$summaryfile -Append} 
    elseif ($? -eq $false) {write-host "There was a problem with XML export of the sources confiration: $($id)." | tee-object -FilePath $summarypath$summaryfile -Append}
               
    }
 }
Remove-Variable pd -Scope global
Remove-Variable hds -Scope global
}
Function reset-IDNsources{

<#
   .SYNOPSIS
        Script was built to reset IDN Source(s)

   .DESCRIPTION
        Script was built to reset IDN Source(s). You can enter one ID or array of IDs delimited by ","  

        Dependencies: 
                
        Constrains:
                
    .INPUTS 
        Instance = IDN Organisation
        Filter = Name mask filter for selection of IDN sources 
        IDN IDs = local IDN user credentials 
        IDN API credentials 
        
        
    .OUTPUTS:
        resets selectio of IDN Source(s) 
    
    .PARAMETER  Instance
        should contain the desired IDN target instance 
    .PARAMETER  Filter
        should define source name or mask or multiple sources 
                        
    .EXAMPLE
        reset-source 

    .NOTES
        Set-IDNData
        Version: 1.2
        Creator: Richard Sidor
        Date:    25-02-2019
            
        Changes
        -------------------------------------
        Date:      Version  Initials  Changes 
        07-02-2019 1.0      RS        Initial version
        25-02-2019 1.2      RS        Added array of multiple sources as input 
        
    .LINK
        https://api.identitynow.com/        
 #>

Param([Parameter(mandatory=$false,valuefrompipeline=$true,Position=0)]
[string]$global:instance = "YourTenantOrg", 
[Parameter(mandatory=$false,valuefrompipeline=$true,Position=1)]
[string[]]$Filter = "",
[Parameter(mandatory=$false,valuefrompipeline=$false)]
[switch]$Grid
)

[string]$summarypath = "$env:USERPROFILE\Desktop\$global:Timestamp\"
[string]$summaryfile = "reset-summary.txt"

[string]$global:Timestamp = (get-date).ToString('d-M-yyyy_HH-mm-ss')
IF (!(test-path $summarypath)){try{new-item -ItemType Directory -path $summarypath
cls
}
catch {write-output "Not able to reset report folder on your desktop." }
}


get-IDNauthorisation $global:instance

DO{
[array]$sources = @()
[array]$resetsources = @()
[array]$fail = @()
[array]$success = @()

[array]$get = @()

#Query for list of configured AD sources 
[int]$counter = 0

[int]$page=0
[int]$limit=250

[array]$get = @()

DO { 
$ent_Headers = get-IDNheaders $global:instance

[string]$url ="https://$global:instance.api`.identitynow.com/cc/api/source/list?start=$page&limit=250&sort=%5B%7B%22property%22%3A%22displayName%22%2C%22direction%22%3A%22ASC%22%7D%5D"
$get = Invoke-WebRequest -Uri $url -Headers $ent_Headers -Method GET 
$page +=249

<#
[int]$perc = (($sources.count/$get.Headers.'X-Total-Count') *100)
Write-Progress -Activity "Reading sources from IDN instance $($global:instance)" -Status "Percent complete...$($perc)`% of $($get.Headers.'X-Total-Count') sources read" -PercentComplete $($perc)
#>

[array]$sources += $get.Content | Out-String | convertfrom-json


} WHILE ($sources.count -lt $get.Headers.'X-Total-Count')

Write-Host "Avaliable IDN sources for $($global:instance) are these $($sources.count):" | Tee-object -FilePath  $summarypath$summaryfile -Append
$sources = $sources | select id,name,description,owner,sourceConnectorName,sourceType,externalID |sort name -Unique | Tee-object -FilePath  $summarypath$summaryfile -Append
$sources | select id,name,description,owner,sourceConnectorName | ft -wrap

if ($grid) {$filter = ($sources | select id,name,description,owner,sourceConnectorName | Out-GridView -PassThru).id}

if ($filter) {$filter = $($filter) -split ","}
elseif (!($filter)) {[string[]]$filter = [string]$(Read-Host "Please select ID(s) of source(s) to reset") -split ","}

Foreach ($f in $filter) {
$f = $($f -replace ' ','')
if ($f -match "^[0-9]+${6}" ){
$resetsources += $sources | ?{$_.id -like "$f"} }
}

Write-Host "Selected sources for reset are: " | Tee-object -FilePath  $summarypath$summaryfile -Append
$resetsources | ft -wrap >>$summarypath$summaryfile 
$resetsources | select id,name,description,owner.name,sourceConnectorName | ft -wrap

if ($resetsources){
    [string]$question = read-host "Proceed with reset of these sources? y/n"
    while ($question -notmatch "[yYnN]{1}"){
    if ($question -match "[nN]{1}") { 
    Write-output "Reset aborted."
    Break}
    $question = read-host "Proceed with reset? y/n"
    }

if ($question -match "[yY]{1}") {

$ent_Headers = get-IDNheaders $global:instance

[int]$counter = 0

    foreach ($i in $resetsources){
    $counter++
    [int]$perc = ($counter/ [int]$resetsources.count) *100
    Write-Progress -Activity "Reseting sources from IDN instance $($global:instance)" -Status "Percent complete...$($perc)`% of $($resetsources.count) sources reset" -PercentComplete $($perc)

    Write-host "Reseting source $($i.name) - $($i.id)"
    [string]$url = "https://$($global:instance).identitynow.com/api/source/reset/$($i.id)" | Tee-object -FilePath  $summarypath$summaryfile -Append
    $send = Invoke-WebRequest -Uri $url -Headers $ent_Headers -Method POST -ea Stop    
    Write-host "Waiting for reset to finish ..."
    sleep -Seconds 150

    switch ($send.StatusCode){
    200 {Write-host "Source with ID $($i.id) was succesfully reset" | Tee-object -FilePath  $summarypath$summaryfile -Append}
    default {Write-host "Error resetting source with ID $($i.id)" | Tee-object -FilePath  $summarypath$summaryfile -Append}
          }
    
        }
    }
}
$filter = $null

$question0 = Read-host "Do you want to reset another source? y/n"
    while ($question0 -notmatch "[yYnN]{1}"){
        if ($question0 -match "[nN]{1}") { 
        Write-output "Exiting ...."
        break}
        $question0 = Read-host "Do you want to reset another source? y/n"
            }

}UNTIL($question0 -match "[nN]{1}")

Remove-Variable pd -Scope global
Remove-Variable hds -Scope global
}