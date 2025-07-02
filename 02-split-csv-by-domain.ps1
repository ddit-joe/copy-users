# This script splits your user-mapping CSV into FXX.csv, DFN.csv, MFC.csv, and NoMatch.csv
# based on the value in the AAD_Domain column.

$inCsvPath = ".\user-mapping.csv"

# Import the main CSV
$userList = Import-Csv $inCsvPath

# Prepare arrays for each output
$fxx      = @()
$dfn      = @()
$mfc      = @()
$noMatch  = @()

foreach ($user in $userList) {
    $domain = ($user.AAD_Domain+"").ToLower()
    switch ($domain) {
        "redacted"           { $fxx    += $user }
        "redacted"           { $dfn    += $user }
        "redacted"             { $mfc    += $user }
        "redacted"                     { $noMatch+= $user }
        default                { $noMatch+= $user }
    }
}

# Use labels from input for output
$headers = ($userList | Select-Object -First 1 | Get-Member -MemberType NoteProperty).Name

$fxx     | Export-Csv -NoTypeInformation -Path .\FXX.csv      -Force
$dfn     | Export-Csv -NoTypeInformation -Path .\DFN.csv      -Force
$mfc     | Export-Csv -NoTypeInformation -Path .\MFC.csv      -Force
$noMatch | Export-Csv -NoTypeInformation -Path .\NoMatch.csv  -Force

Write-Host "Split complete: FXX.csv, DFN.csv, MFC.csv, NoMatch.csv"
