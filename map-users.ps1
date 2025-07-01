param(
    [string]$ConnectionString,
    [string]$FileShareName = "profiles",
    [string]$OutputCsvPath = ".\user-mapping.csv"
)

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
        $lastName = $samName

        $userList += [PSCustomObject]@{
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

# Export to CSV
$userList | Select-Object SID, samName, FirstLetter, LastName, DuplicateSam | Export-Csv -NoTypeInformation -Path $OutputCsvPath

Write-Output "User mapping CSV exported to $OutputCsvPath"
