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
# Department-to-security-group mapping
$DepartmentGroups = @{
    "IT"      = "IT-Support"
    "HR"      = "HR-Users"
    "Finance" = "Finance"
}
# Validate CSV file
if (-not (Test-Path $CSVPath)) {
    Write-Host "[ERROR] CSV file not found: $CSVPath" -ForegroundColor Red
    exit 1
}

# Import users from CSV
$Users = Import-Csv -Path $CSVPath

# Validate CSV is not empty
if (-not $Users -or $Users.Count -eq 0) {
    Write-Host "[ERROR] CSV contains no user records." -ForegroundColor Red
    exit 1
}

# Validate required columns
$RequiredColumns = @("FirstName", "LastName", "Username", "Department", "Title")
$CSVColumns = $Users[0].PSObject.Properties.Name

foreach ($Column in $RequiredColumns) {
    if ($Column -notin $CSVColumns) {
        Write-Host "[ERROR] Required CSV column missing: $Column" -ForegroundColor Red
        exit 1
    }
}

Write-Host "[VALIDATION] CSV structure and records verified." -ForegroundColor Green

# Track results
$CreatedUsers = @()
$SkippedUsers = @()

Write-Host "`nStarting Active Directory user provisioning..." -ForegroundColor Cyan
Write-Host "Target OU: $TargetOU`n"

# Validate individual user records
# Identify duplicate usernames in CSV
$DuplicateUsernames = $Users |
    Group-Object -Property Username |
    Where-Object { $_.Count -gt 1 } |
    Select-Object -ExpandProperty Name

Write-Host "`nChecking for duplicate usernames in CSV..." -ForegroundColor Cyan

foreach ($Duplicate in $DuplicateUsernames) {
    Write-Host "[DUPLICATE] Username appears more than once: $Duplicate" -ForegroundColor Red
}
$ValidUsers = @()
$InvalidUsers = @()

foreach ($User in $Users) {

    $ValidationErrors = @()
    # Reject duplicate usernames
    if ($DuplicateUsernames -contains $User.Username) {
        $ValidationErrors += "Duplicate username in CSV"
    }

    # Check required values
    foreach ($Field in $RequiredColumns) {
        if ([string]::IsNullOrWhiteSpace($User.$Field)) {
            $ValidationErrors += "Missing value: $Field"
        }
    }

    # Validate username format
    if (-not [string]::IsNullOrWhiteSpace($User.Username)) {
        if ($User.Username -notmatch '^[a-zA-Z0-9._-]{3,20}$') {
            $ValidationErrors += "Invalid username format"
        }
    }

    if ($ValidationErrors.Count -gt 0) {
        Write-Host "[INVALID] $($User.Username): $($ValidationErrors -join ', ')" -ForegroundColor Red
        $InvalidUsers += $User.Username
    }
    else {
        $ValidUsers += $User
    }
}

Write-Host "`nValid records: $($ValidUsers.Count)" -ForegroundColor Green
Write-Host "Invalid records: $($InvalidUsers.Count)" -ForegroundColor Red
foreach ($User in $ValidUsers) {
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
        # Assign security group based on department
        $Department = $User.Department

        if ($DepartmentGroups.ContainsKey($Department)) {

            $GroupName = $DepartmentGroups[$Department]

            try {
                Add-ADGroupMember -Identity $GroupName -Members $Username -ErrorAction Stop

                Write-Host "[GROUP ASSIGNED] $Username added to $GroupName." -ForegroundColor Green
            }
            catch {
                Write-Host "[GROUP ERROR] Could not add $Username to $GroupName : $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        else {
            Write-Host "[NO GROUP] No group mapping found for department: $Department" -ForegroundColor Yellow
        }
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
Write-Host "Invalid Records: $($InvalidUsers.Count)" -ForegroundColor Red
Write-Host "`nCreated Accounts:"
$CreatedUsers

Write-Host "`nSkipped Accounts:"
$SkippedUsers
Write-Host "`nInvalid Records:"
$InvalidUsers

Write-Host "`nProvisioning process complete." -ForegroundColor Cyan