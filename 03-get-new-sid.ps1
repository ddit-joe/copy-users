# Requires: Import-Module ActiveDirectory
# Usage: Run this on a domain-joined machine with RSAT/AD module, and with permissions to read AD users.

$csvPath,
$outCsvPath = ".\user-mapping-with-sid.csv"

# Import the CSV
$userList = Import-Csv $csvPath

foreach ($user in $userList) {
    $sidNew = ""
    if ($user.AAD_FirstName -and $user.AAD_LastName) {
        # Try to find user by first and last name in AD
        $adUser = Get-ADUser -Filter { GivenName -eq $($user.AAD_FirstName) -and Surname -eq $($user.AAD_LastName) } -Properties ObjectSID -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($adUser) {
            $sidNew = $adUser.ObjectSID.Value
        }
    }
    # Add or update SID-new
    $user."SID-new" = $sidNew
}

# Export the updated CSV
$userList | Export-Csv -NoTypeInformation -Path $outCsvPath

Write-Host "Updated mapping with SID-new exported to $outCsvPath"
