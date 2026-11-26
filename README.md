
# Active Directory User Provisioning Automation

## Project Overview

A PowerShell automation project for bulk Active Directory user provisioning in a Windows Server lab environment.

The project evolved through four versions, progressing from basic CSV-based account creation to input validation, automated security group assignment, error handling, and provisioning reports.

## Features

- Bulk creation of Active Directory accounts from CSV files.
- Automated account placement in a designated Organizational Unit.
- Validation of required user information and username formats.
- Detection of duplicate usernames and existing accounts.
- Department-based security group assignment.
- Handling of unmapped departments.
- Error handling for account creation and group assignment.
- Timestamped CSV and TXT provisioning reports.

## Development History

| Version | Improvements |
|---|---|
| V1 | Initial bulk account provisioning |
| V2 | Input validation and duplicate detection |
| V3 | Department-based security group assignment |
| V4 | Reporting, error handling, and provisioning summaries |

## Lab Environment

- Windows Server 2022
- Active Directory Domain Services
- Domain: `companyx.local`
- Windows PowerShell 5.1
- Oracle VirtualBox

## Security Considerations

- Passwords are supplied separately using a SecureString variable.
- Passwords are not stored in the CSV input file or PowerShell scripts.
- Existing accounts are skipped rather than overwritten.
- Security group assignments follow predefined department mappings.
- Privileged administrative groups are not automatically assigned.

## Repository Structure

Each version is preserved separately to demonstrate the project's development and improvements.

The V4 folder contains additional documentation and sample provisioning reports.

## Project Status

**Complete — Four development iterations tested in a virtualized Active Directory environment.**
