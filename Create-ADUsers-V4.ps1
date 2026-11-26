# ==========================================
# Active Directory User Provisioning
# Version: 4.0
# Purpose: Bulk-create AD users, validate
#          records, assign security groups,
#          and generate provisioning reports.
# ==========================================

# Import Active Directory module
Import-Module ActiveDirectory -ErrorAction Stop

# Define file and OU paths
$CSVPath = "C:\ADLab\companyx_ad_users.csv"
$TargetOU = "OU=LabUsers,OU=CompanyX,DC=CompanyX,DC=local"

# Reporting configuration
$ReportDirectory = "C:\ADLab\V4\Reports"
$TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"

if (-not (Test-Path $ReportDirectory)) {
    New-Item -Path $ReportDirectory -ItemType Directory -Force | Out-Null
}

$CSVReport = Join-Path $ReportDirectory "ProvisioningReport_$TimeStamp.csv"
$TXTReport = Join-Path $ReportDirectory "ProvisioningReport_$TimeStamp.txt"

# Track provisioning results
$ProvisioningResults = @()

# Department-to-security-group mapping
$DepartmentGroups = @{
    "IT"      = "IT-Support"
    "HR"      = "HR-Users"
    "Finance" = "Finance"
}

# Track account outcomes
$CreatedUsers = @()
$SkippedUsers = @()
$InvalidUsers = @()
$FailedUsers = @()

# Validate CSV file
if (-not (Test-Path $CSVPath)) {
    Write-Host "[ERROR] CSV file not found: $CSVPath" -ForegroundColor Red
    exit 1
}

# Import users from CSV
try {
    $Users = Import-Csv -Path $CSVPath -ErrorAction Stop
}
catch {
    Write-Host "[ERROR] Could not import CSV: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

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

Write-Host "[VALIDATION] CSV structure verified." -ForegroundColor Green

# Identify duplicate usernames in CSV
$DuplicateUsernames = @(
    $Users |
        Group-Object -Property Username |
        Where-Object { $_.Count -gt 1 } |
        Select-Object -ExpandProperty Name
)

Write-Host "`nChecking for duplicate usernames in CSV..." -ForegroundColor Cyan

foreach ($Duplicate in $DuplicateUsernames) {
    Write-Host "[DUPLICATE] Username appears more than once: $Duplicate" -ForegroundColor Red
}

# Validate individual user records
$ValidUsers = @()

foreach ($User in $Users) {

    $ValidationErrors = @()
    $Username = $User.Username
    $FullName = "$($User.FirstName) $($User.LastName)"

    # Reject duplicate usernames
    if ($DuplicateUsernames -contains $Username) {
        $ValidationErrors += "Duplicate username in CSV"
    }

    # Check required values
    foreach ($Field in $RequiredColumns) {
        if ([string]::IsNullOrWhiteSpace($User.$Field)) {
            $ValidationErrors += "Missing value: $Field"
        }
    }

    # Validate username format
    if (-not [string]::IsNullOrWhiteSpace($Username)) {
        if ($Username -notmatch '^[a-zA-Z0-9._-]{3,20}$') {
            $ValidationErrors += "Invalid username format"
        }
    }

    if ($ValidationErrors.Count -gt 0) {

        $ErrorDetails = $ValidationErrors -join "; "

        Write-Host "[INVALID] $Username : $ErrorDetails" -ForegroundColor Red
        $InvalidUsers += $Username

        $ProvisioningResults += [PSCustomObject]@{
            Timestamp   = Get-Date
            Username    = $Username
            FullName    = $FullName
            Department  = $User.Department
            Status      = "INVALID"
            Group       = ""
            GroupStatus = "NOT ATTEMPTED"
            Details     = $ErrorDetails
        }
    }
    else {
        $ValidUsers += $User
    }
}

Write-Host "`nValid records: $($ValidUsers.Count)" -ForegroundColor Green
Write-Host "Invalid records: $($InvalidUsers.Count)" -ForegroundColor Red

Write-Host "`nStarting Active Directory user provisioning..." -ForegroundColor Cyan
Write-Host "Target OU: $TargetOU`n"

# Provision valid users
foreach ($User in $ValidUsers) {

    $Username = $User.Username
    $FullName = "$($User.FirstName) $($User.LastName)"

    # Check whether the account already exists
    try {
        $ExistingUser = Get-ADUser -Filter "SamAccountName -eq '$Username'" -ErrorAction Stop
    }
    catch {
        Write-Host "[ERROR] Could not check $Username : $($_.Exception.Message)" -ForegroundColor Red
        $FailedUsers += $Username

        $ProvisioningResults += [PSCustomObject]@{
            Timestamp   = Get-Date
            Username    = $Username
            FullName    = $FullName
            Department  = $User.Department
            Status      = "FAILED"
            Group       = ""
            GroupStatus = "NOT ATTEMPTED"
            Details     = "Account lookup failed: $($_.Exception.Message)"
        }

        continue
    }

    if ($ExistingUser) {

        Write-Host "[SKIPPED] $Username already exists." -ForegroundColor Yellow
        $SkippedUsers += $Username

        $ProvisioningResults += [PSCustomObject]@{
            Timestamp   = Get-Date
            Username    = $Username
            FullName    = $FullName
            Department  = $User.Department
            Status      = "SKIPPED"
            Group       = ""
            GroupStatus = "NOT ATTEMPTED"
            Details     = "Account already exists in Active Directory"
        }

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

        # Create the initial result record
        $ResultEntry = [PSCustomObject]@{
            Timestamp   = Get-Date
            Username    = $Username
            FullName    = $FullName
            Department  = $User.Department
            Status      = "CREATED"
            Group       = ""
            GroupStatus = "NOT ATTEMPTED"
            Details     = "Account successfully created"
        }

        $ProvisioningResults += $ResultEntry

    }
    catch {

        Write-Host "[ERROR] Failed to create $Username : $($_.Exception.Message)" -ForegroundColor Red
        $FailedUsers += $Username

        $ProvisioningResults += [PSCustomObject]@{
            Timestamp   = Get-Date
            Username    = $Username
            FullName    = $FullName
            Department  = $User.Department
            Status      = "FAILED"
            Group       = ""
            GroupStatus = "NOT ATTEMPTED"
            Details     = "Account creation failed: $($_.Exception.Message)"
        }

        continue
    }

    # Assign security group based on department
    $Department = $User.Department

    if ($DepartmentGroups.ContainsKey($Department)) {

        $GroupName = $DepartmentGroups[$Department]

        try {

            Add-ADGroupMember -Identity $GroupName -Members $Username -ErrorAction Stop

            Write-Host "[GROUP ASSIGNED] $Username added to $GroupName." -ForegroundColor Green

            $ResultEntry.Group = $GroupName
            $ResultEntry.GroupStatus = "ASSIGNED"
            $ResultEntry.Details = "Account created and added to $GroupName"

        }
        catch {

            Write-Host "[GROUP ERROR] Could not add $Username to $GroupName : $($_.Exception.Message)" -ForegroundColor Red

            $ResultEntry.GroupStatus = "FAILED"
            $ResultEntry.Details = "Account created, but group assignment failed: $($_.Exception.Message)"
        }
    }
    else {

        Write-Host "[NO GROUP] No group mapping found for department: $Department" -ForegroundColor Yellow

        $ResultEntry.GroupStatus = "NO MAPPING"
        $ResultEntry.Details = "Account created; no group mapping exists for department: $Department"
    }
}

# Export CSV report
try {
    $ProvisioningResults |
        Export-Csv -Path $CSVReport -NoTypeInformation -Encoding UTF8 -ErrorAction Stop

    Write-Host "`n[REPORT] CSV report saved: $CSVReport" -ForegroundColor Green
}
catch {
    Write-Host "[REPORT ERROR] Could not save CSV report: $($_.Exception.Message)" -ForegroundColor Red
}

# Calculate summary counts
$CreatedCount = @($ProvisioningResults | Where-Object { $_.Status -eq "CREATED" }).Count
$SkippedCount = @($ProvisioningResults | Where-Object { $_.Status -eq "SKIPPED" }).Count
$InvalidCount = @($ProvisioningResults | Where-Object { $_.Status -eq "INVALID" }).Count
$FailedCount = @($ProvisioningResults | Where-Object { $_.Status -eq "FAILED" }).Count
$GroupAssignedCount = @($ProvisioningResults | Where-Object { $_.GroupStatus -eq "ASSIGNED" }).Count
$GroupFailedCount = @($ProvisioningResults | Where-Object { $_.GroupStatus -eq "FAILED" }).Count
$NoMappingCount = @($ProvisioningResults | Where-Object { $_.GroupStatus -eq "NO MAPPING" }).Count

# Build text report
$ReportLines = @(
    "=========================================="
    "Active Directory User Provisioning Report"
    "=========================================="
    "Run Date: $(Get-Date)"
    "Domain: companyx.local"
    "Target OU: $TargetOU"
    ""
    "PROVISIONING SUMMARY"
    "--------------------"
    "Created: $CreatedCount"
    "Skipped: $SkippedCount"
    "Invalid: $InvalidCount"
    "Failed: $FailedCount"
    ""
    "GROUP ASSIGNMENT SUMMARY"
    "------------------------"
    "Assigned: $GroupAssignedCount"
    "Failed: $GroupFailedCount"
    "No Mapping: $NoMappingCount"
    ""
    "ACCOUNT DETAILS"
    "---------------"
)

foreach ($Result in $ProvisioningResults) {
    $ReportLines += "[$($Result.Status)] $($Result.Username) | $($Result.FullName) | $($Result.Department)"
    $ReportLines += "Group: $($Result.Group) | Group Status: $($Result.GroupStatus)"
    $ReportLines += "Details: $($Result.Details)"
    $ReportLines += ""
}

try {
    $ReportLines | Out-File -FilePath $TXTReport -Encoding UTF8 -ErrorAction Stop
    Write-Host "[REPORT] TXT report saved: $TXTReport" -ForegroundColor Green
}
catch {
    Write-Host "[REPORT ERROR] Could not save TXT report: $($_.Exception.Message)" -ForegroundColor Red
}

# Display provisioning summary
Write-Host "`n==================================" -ForegroundColor Cyan
Write-Host "Provisioning Summary" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan

Write-Host "Users Created: $CreatedCount" -ForegroundColor Green
Write-Host "Users Skipped: $SkippedCount" -ForegroundColor Yellow
Write-Host "Invalid Records: $InvalidCount" -ForegroundColor Red
Write-Host "Failed Operations: $FailedCount" -ForegroundColor Red

Write-Host "`nGroups Assigned: $GroupAssignedCount" -ForegroundColor Green
Write-Host "Group Assignment Failures: $GroupFailedCount" -ForegroundColor Red
Write-Host "Departments Without Mapping: $NoMappingCount" -ForegroundColor Yellow

Write-Host "`nCreated Accounts:"
$CreatedUsers

Write-Host "`nSkipped Accounts:"
$SkippedUsers

Write-Host "`nInvalid Records:"
$InvalidUsers

Write-Host "`nFailed Accounts:"
$FailedUsers

Write-Host "`nProvisioning process complete." -ForegroundColor Cyan
