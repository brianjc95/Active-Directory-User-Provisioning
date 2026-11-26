
# Active Directory User Provisioning Automation — V4

## Project Overview

A PowerShell-based automation tool designed to bulk-create Active Directory user accounts from CSV input. The script validates user records, detects duplicate usernames, provisions accounts, assigns department-based security groups, and generates provisioning reports.

## Features

- Bulk user creation from CSV files.
- Validation of required CSV columns and user attributes.
- Username format validation.
- Duplicate username detection within CSV files.
- Detection and skipping of existing Active Directory accounts.
- Automated account placement in a designated Organizational Unit (OU).
- Department-based security group assignment.
- Handling of departments without configured group mappings.
- Error handling for account creation and group assignment.
- Timestamped CSV and TXT provisioning reports.
- Summary statistics for account creation, skipped records, invalid records, and failures.

## Lab Environment

| Component | Configuration |
|---|---|
| Operating System | Windows Server 2022 |
| Active Directory Domain | companyx.local |
| Domain Controller | DC01 |
| Destination OU | OU=LabUsers,OU=CompanyX |
| PowerShell | Windows PowerShell 5.1 |
| Virtualization | Oracle VirtualBox |

## Department-to-Group Mapping

| Department | Security Group |
|---|---|
| IT | IT-Support |
| HR | HR-Users |
| Finance | Finance |

Departments without a configured mapping are reported without preventing successful account creation.

## Development History

### V1 — Initial Provisioning
- Created multiple Active Directory accounts from CSV input.
- Populated account attributes and enabled new accounts.
- Skipped accounts that already existed.

### V2 — Validation and Duplicate Detection
- Added CSV file and required-column validation.
- Added required-field checks.
- Implemented username format validation.
- Detected duplicate usernames within CSV input.
- Separated valid and invalid records.

### V3 — Security Group Assignment
- Added department-to-security-group mapping.
- Automatically assigned new users to appropriate security groups.
- Added handling for departments without group mappings.
- Verified group membership independently.

### V4 — Reporting and Error Handling
- Added timestamped CSV and TXT reports.
- Recorded account creation, skipped records, and invalid records.
- Added separate group assignment status tracking.
- Added error handling for account lookup, account creation, and group assignment.
- Added provisioning and group assignment summary statistics.

## Testing and Validation

Testing was performed in a virtualized Active Directory lab.

| Test | Result |
|---|---|
| Existing account detection | Passed |
| New account creation | Passed |
| OU placement verification | Passed |
| Security group assignment | Passed |
| Unmapped department handling | Passed |
| Invalid username rejection | Passed |
| Duplicate username detection | Passed |
| CSV report generation | Passed |
| TXT report generation | Passed |
| Report content verification | Passed |

### Example Provisioning Results

- Created: 1
- Skipped: 3
- Invalid: 0
- Failed: 0
- Security groups assigned: 1

Example test account:
- Username: cwhite
- Department: IT
- Security Group: IT-Support
- Account Status: Enabled

## Reporting

Each execution generates timestamped reports under:

`C:\ADLab\V4\Reports`

CSV reports provide structured provisioning results, while TXT reports provide a human-readable summary and individual account details.

## Security Considerations

- Passwords are supplied through a SecureString variable rather than stored in the CSV or script.
- Existing accounts are skipped instead of overwritten.
- Security group assignment uses department-based mappings.
- Privileged administrative groups are not automatically assigned.
- Invalid records are rejected before provisioning.

## Limitations and Future Improvements

- Department-to-group mappings are currently maintained within the PowerShell script.
- Password handling currently relies on a SecureString variable supplied during the PowerShell session.
- Additional enhancements could include configurable OU mappings, email notifications, and centralized logging.

## Project Status

**Complete — V4 tested in a virtualized Active Directory environment.**
