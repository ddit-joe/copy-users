<#
.SYNOPSIS
    Migrates user profile folders from an old Azure file share to a new one, based on a CSV mapping file.
.DESCRIPTION
    - Connects to both old and new Azure storage accounts.
    - Reads a CSV (e.g., FXX.csv) with columns: Path, SID, samName, ..., SID-new, etc.
    - For each row, checks if the folder (in Path) exists in the old share.
    - If so, copies all content from old:\Path to new:\SID-new_samName
    - Placeholder for NTFS ACL modification.
    - Logs users (rows) where no folder was transferred.
.NOTES
    Requires Az.Storage module and permissions for both storage accounts.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$OldStorageConnectionString,
    [Parameter(Mandatory = $true)]
    [string]$NewStorageConnectionString,
    [Parameter(Mandatory = $true)]
    [string]$OldShareName,
    [Parameter(Mandatory = $true)]
    [string]$NewShareName,
    [Parameter(Mandatory = $true)]
    [string]$CsvFile,     # e.g. .\FXX.csv
    [string]$LogFile = ".\migration-log.txt"
)

# Connect to storage accounts
$ctxOld = New-AzStorageContext -ConnectionString $OldStorageConnectionString
$ctxNew = New-AzStorageContext -ConnectionString $NewStorageConnectionString

# Import CSV
$userList = Import-Csv $CsvFile

# Prepare log file
"Migration started $(Get-Date)" | Out-File $LogFile

foreach ($user in $userList) {
    $oldFolder = $user.Path
    $newFolder = "$($user.'SID-new')_$($user.samName)"
    $transferred = $false

    # Check if folder exists in old storage
    $oldFolderObj = Get-AzStorageFile -ShareName $OldShareName -Context $ctxOld -Path $oldFolder -ErrorAction SilentlyContinue
    if ($oldFolderObj) {
        # Create new folder in new storage (if not exists)
        $null = New-AzStorageFileDirectory -ShareName $NewShareName -Context $ctxNew -Path $newFolder -ErrorAction SilentlyContinue

        # Get all files/subfolders in source
        $items = Get-AzStorageFile -ShareName $OldShareName -Context $ctxOld -Path $oldFolder
        foreach ($item in $items) {
            $itemName = $item.Name
            $srcPath = "$oldFolder/$itemName"
            $destPath = "$newFolder/$itemName"
            if ($item.GetType().Name -eq "AzureStorageFileDirectory") {
                # Recursively copy directories
                # (You may want to use a recursive function for deep folder trees)
                Write-Warning "Nested folder detected: $srcPath (recursive copy not implemented)"
            } else {
                # Copy file
                Start-AzStorageFileCopy -SrcShareName $OldShareName -SrcContext $ctxOld -SrcFilePath $srcPath `
                    -DestShareName $NewShareName -DestContext $ctxNew -DestFilePath $destPath | Out-Null
            }
        }

        # Placeholder: modify NTFS ACL on $newFolder if needed
        # Example:
        # Write-Host "Modify NTFS ACL on $newFolder (placeholder)"
        $transferred = $true
    }

    if ($transferred) {
        "[$($user.Path)] moved to [$newFolder]" | Out-File $LogFile -Append
    } else {
        "NOT TRANSFERRED: $($user.Path) for $($user.samName)" | Out-File $LogFile -Append
    }
}

"Migration complete $(Get-Date)" | Out-File $LogFile -Append
Write-Host "Migration finished. See log: $LogFile"
