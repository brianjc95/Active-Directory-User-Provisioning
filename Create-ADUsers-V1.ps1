# ==========================================
# Active Directory User Provisioning
# Version: 1.0
# Purpose: Bulk-create AD users from a CSV file
# ==========================================

# Import Active Directory module
Import-Module ActiveDirectory

# Define file and OU paths
$CSVPath = "C:\ADLab\companyx_ad_users.csv"
$TargetOU = "OU=LabUsers,OU=CompanyX,DC=CompanyX,DC=local"

# Import users from CSV
$Users = Import-Csv -Path $CSVPath

# Track results
$CreatedUsers = @()
$SkippedUsers = @()

Write-Host "`nStarting Active Directory user provisioning..." -ForegroundColor Cyan
Write-Host "Target OU: $TargetOU`n"

# Process each user in the CSV
foreach ($User in $Users) {

    $Username = $User.Username
    $FullName = "$($User.FirstName) $($User.LastName)"

    # Check whether the account already exists
    $ExistingUser = Get-ADUser -Filter "SamAccountName -eq '$Username'" `
        -ErrorAction SilentlyContinue

    if ($ExistingUser) {
        Write-Host "[SKIPPED] $Username already exists." -ForegroundColor Yellow
        $SkippedUsers += $Username
        continue
    }

    # Create the Active Directory account
    try {
        New-ADUser `
            -Name $FullName `
            -GivenName $User.FirstName `
            -Surname $User.LastName `
            -SamAccountName $Username `
            -UserPrincipalName "$Username@companyx.local" `
            -Department $User.Department `
            -Title $User.Title `
            -Path $TargetOU `
            -AccountPassword $SecurePassword `
            -Enabled $true `
            -ChangePasswordAtLogon $true `
            -ErrorAction Stop

        Write-Host "[CREATED] $Username successfully." -ForegroundColor Green
        $CreatedUsers += $Username
    }
    catch {
        Write-Host "[ERROR] Failed to create $Username : $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Display provisioning summary
Write-Host "`n==================================" -ForegroundColor Cyan
Write-Host "Provisioning Summary" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan

Write-Host "Users Created: $($CreatedUsers.Count)" -ForegroundColor Green
Write-Host "Users Skipped: $($SkippedUsers.Count)" -ForegroundColor Yellow

Write-Host "`nCreated Accounts:"
$CreatedUsers

Write-Host "`nSkipped Accounts:"
$SkippedUsers

Write-Host "`nProvisioning process complete." -ForegroundColor Cyan