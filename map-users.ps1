param(
    [string]$ConnectionString,
    [string]$OutputCsvPath = ".\user-mapping.csv",
    [string]$TenantId
)

# Ensure required module
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Users)) {
    Write-Error "Please install the Microsoft.Graph.Users module: Install-Module Microsoft.Graph.Users"
    exit 1
}

# Connect to Graph if not already connected
if (-not (Get-MgContext)) {
    if ($TenantId) {
        Connect-MgGraph -Scopes "User.Read.All" -TenantId $TenantId
    } else {
        Connect-MgGraph -Scopes "User.Read.All"
    }
}

if (-not $ConnectionString) {
    throw "Please provide the Azure Storage Account connection string using the -ConnectionString parameter."
}

# Create storage context using the connection string
$ctx = New-AzStorageContext -ConnectionString $ConnectionString

# List all directories in the File Share root
$folders = Get-AzStorageFile -ShareName $FileShareName -Context $ctx -Path "" | Where-Object { $_.GetType().Name -eq "AzureStorageFileDirectory" }

$userList = @()
foreach ($folder in $folders) {
    # Expects: S-1-12-1-xxxx-xxxx-xxxx-xxxx_username
    if ($folder.Name -match '^(S-1-12-1-\d+-\d+-\d+-\d+)_(.+)$') {
        $sid      = $matches[1]
        $samName  = $matches[2]
        $firstLet = $samName.Substring(0,1)
        $lastName = $samName.Substring(1)

        $userList += [PSCustomObject]@{
            Path       = $folder.Name
            SID         = $sid
            samName     = $samName
            FirstLetter = $firstLet
            LastName    = $lastName
        }
    }
}

# Mark duplicates
$samNameGroups = $userList | Group-Object samName
$dupes = $samNameGroups | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name }

foreach ($user in $userList) {
    $user | Add-Member -NotePropertyName "DuplicateSam" -NotePropertyValue ($(if ($dupes -contains $user.samName){"Yes"}else{"No"}))
}

# Get all users in Entra ID with needed properties for local filtering
Write-Host "Fetching all Entra ID users for local filtering (this may take a while for large tenants)..."
$aadUsersAll = Get-MgUser -All -Property displayName,givenName,surname,userPrincipalName

foreach ($user in $userList) {
    if ($user.DuplicateSam -eq "No") {
        $aadUsers = @($aadUsersAll | Where-Object {
            $_.surname -and (
                $_.surname.ToLower() -eq $user.LastName.ToLower() -or
                $_.surname.ToLower().StartsWith($user.LastName.ToLower())
            )
        })

        if ($aadUsers.Count -eq 1) {
            $aadUser = $aadUsers[0]
        }
        elseif ($aadUsers.Count -gt 1) {
            $aadUser = $aadUsers | Where-Object {
                $_.givenName -and $_.givenName.Substring(0,1).ToLower() -eq $user.FirstLetter.ToLower()
            } | Select-Object -First 1
            if (-not $aadUser) {
                $aadUser = $aadUsers | Select-Object -First 1
            }
        }
        else {
            $aadUser = $null
        }

        if ($aadUser) {
            $user | Add-Member -NotePropertyName "AAD_FirstName" -NotePropertyValue $aadUser.givenName
            $user | Add-Member -NotePropertyName "AAD_LastName" -NotePropertyValue $aadUser.surname
            $user | Add-Member -NotePropertyName "AAD_UPN" -NotePropertyValue $aadUser.userPrincipalName
            $user | Add-Member -NotePropertyName "AAD_Domain" -NotePropertyValue (($aadUser.userPrincipalName -split '@')[-1])
        } else {
            $user | Add-Member -NotePropertyName "AAD_FirstName" -NotePropertyValue ""
            $user | Add-Member -NotePropertyName "AAD_LastName" -NotePropertyValue ""
            $user | Add-Member -NotePropertyName "AAD_UPN" -NotePropertyValue ""
            $user | Add-Member -NotePropertyName "AAD_Domain" -NotePropertyValue ""
        }
    } else {
        $user | Add-Member -NotePropertyName "AAD_FirstName" -NotePropertyValue ""
        $user | Add-Member -NotePropertyName "AAD_LastName" -NotePropertyValue ""
        $user | Add-Member -NotePropertyName "AAD_UPN" -NotePropertyValue ""
        $user | Add-Member -NotePropertyName "AAD_Domain" -NotePropertyValue ""
    }
}
$userList | Select-Object Path, SID, samName, FirstLetter, LastName, DuplicateSam, AAD_FirstName, AAD_LastName, AAD_UPN, AAD_Domain | Export-Csv -NoTypeInformation -Path $OutputCsvPath

Write-Output "User mapping CSV exported to $OutputCsvPath"
