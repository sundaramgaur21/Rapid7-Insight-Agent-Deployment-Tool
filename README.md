Rapid7 Insight Agent Deployment Tool
-------------------------------------
PowerShell automation tool for deploying Rapid7 Insight Agent across multiple Windows servers with built-in connectivity validation, MSI deployment, installation monitoring, detailed logging, and failure analysis.

Overview
-----------
The Rapid7 Insight Agent Deployment Tool is a fully automated PowerShell solution designed to deploy the Rapid7 Insight Agent to multiple Windows servers from a centralized workstation.
The script performs comprehensive pre-installation checks, validates connectivity requirements, copies the MSI package to remote servers, executes silent installations, analyzes installation logs, and generates detailed deployment reports in both TXT and CSV formats.
This tool is particularly useful during:
Rapid7 onboarding projects
Security agent deployments
Server provisioning activities
Compliance initiatives
Infrastructure modernization projects
Bulk software deployment campaigns
Security monitoring rollouts
Enterprise endpoint visibility initiatives

Features
---------
✅ Graphical server list file picker
✅ Graphical MSI package selector
✅ Automated connectivity validation
✅ Ping verification
✅ WinRM validation
✅ SMB connectivity testing
✅ RPC connectivity testing
✅ C$ administrative share validation
✅ PowerShell Remoting validation
✅ Remote MSI file copy with progress tracking
✅ Silent MSI installation
✅ Installation progress monitoring
✅ MSI exit code analysis
✅ Installation log analysis
✅ TXT reporting
✅ CSV reporting
✅ Failure classification
✅ Detailed deployment summary
✅ Single-threaded execution for controlled deployments

How It Works
-------------
-The script performs the following actions on each server:
-Loads the server list from a text file.
-Prompts the administrator to select the Rapid7 Insight Agent MSI package.
-Performs connectivity validation.
-Verifies network requirements.
-Confirms remote management accessibility.
-Copies the MSI package to the target server.
-Executes a silent MSI installation remotely.
-Monitors installation progress.
-Collects installation exit codes.
-Reviews installation logs.
-Classifies installation results.
-Generates CSV and TXT deployment logs.
-Displays a deployment summary.


Pre-Deployment Checks
-----------------------
Before attempting installation, the script validates the following:
Ping Validation
Verifies basic network connectivity to the target server.
Example:
Ping: OK

WinRM Validation
------------------
Confirms that Windows Remote Management is available.
Example:
WinRM: OK

SMB Connectivity
-----------------
Checks TCP Port 445 availability.
Example:
SMB Port 445: OK
RPC Connectivity
Checks TCP Port 135 availability.
Example:
RPC Port 135: OK

Administrative Share Validation
---------------------------------
Verifies access to the target server's administrative C$ share.
Example:
C$ Admin Share Access: OK
PowerShell Remoting Validation
Confirms remote command execution capability.
Example:
PowerShell Remoting: OK

Deployment Workflow
--------------------
Step 1 - Select Server List
The script prompts the user to select a text file containing server names.
Example:
SERVER01
SERVER02
SERVER03
Step 2 - Select MSI Package
The script prompts the user to select the Rapid7 Insight Agent MSI installer.
The original MSI filename is preserved throughout deployment.
Step 3 - Execute Pre-Checks
The script validates:
Ping
WinRM
SMB
RPC
C$ Share
PowerShell Remoting
Step 4 - Review Pre-Check Results
After all servers are validated, the script displays the results and prompts:
Continue with installation? (Y/N)
Step 5 - Copy MSI Package
The MSI file is copied to:
C:\Temp\Rapid7\
The script displays copy progress during transfer.
Step 6 - Run Installation
The script performs a silent MSI installation using:
msiexec.exe
The installation runs remotely and waits for completion before moving to the next server.
Step 7 - Analyze Installation Results
The script evaluates:
MSI exit codes
Installation logs
Connectivity issues
Rollback events
Token issues
Configuration failures
Step 8 - Generate Reports
Deployment results are written to:
C:\Temp\r7logs.txt
and
C:\Temp\r7logs.csv

Installation Status Categories
-----------------------------------
Success
-----------
Installation completed successfully.
Typical MSI Exit Codes:
0
3010
Example:
SERVER01
Installation completed successfully.

Failed
------
Installation encountered an error.
Examples:
MSI failure
Rollback detected
Token validation failure
Connectivity issue
Configuration failure
MSI copy failure

Skipped
--------
Installation was intentionally skipped due to failed prerequisites.
Examples:
SMB unavailable
WinRM unavailable

Installation Logging
----------------------
TXT Log
Location:
C:\Temp\r7logs.txt
Contains:
Server details
Connectivity checks
Installation status
Failure reasons
Deployment results

CSV Log
Location:
C:\Temp\r7logs.csv
Contains:
Server
Ping status
SMB status
WinRM status
Copy status
Install status
MSI exit code
Failure reason

Failure Analysis
----------------
The script automatically analyzes installation logs for common issues.

Detected Failure Types
-------------------------
MSI Fatal Error 1603
Rollback detected
Token failure
Connectivity issue
config.json generation failure
Missing MSI package
Installation exit code failures
Missing installation logs

Example Installation Summary
-----------------------------
Reachable servers: 25
Copied successfully: 24
Successfully installed: 23
Failed: 1
Skipped: 1
TXT Log: C:\Temp\r7logs.txt
CSV Log: C:\Temp\r7logs.csv

Prerequisites
---------------
PowerShell Version
------------------
PowerShell 5.1 or later.

Administrator Rights
--------------------
Run PowerShell as Administrator.

Network Access
---------------
The deployment workstation must have access to:
Target servers
Administrative shares
WinRM services
SMB services

Required Ports
--------------
ICMP
TCP 135 (RPC)
TCP 445 (SMB)
WinRM ports

PowerShell Remoting
-------------------
PowerShell Remoting must be enabled on target servers.
Example:
Enable-PSRemoting -Force

Server List Format
-------------------
Create a text file containing one server name per line.
Example:
SERVER01
SERVER02
SERVER03
SERVER04
SERVER05

Usage
------
Run the script:
.\Rapid7InsightAgentDeployment.ps1
Select the server list file.
Select the Rapid7 MSI package.
Review pre-deployment validation results.
Confirm installation when prompted.
Allow deployment to complete.
Review deployment logs.

Example Workflow
----------------
Rapid7 Agent Deployment Project
-Export server inventory into a text file.
-Launch the deployment script.
-Select the server list.
-Select the Rapid7 MSI package.
-Review all connectivity checks.
-Confirm deployment.
-Monitor installation progress.
-Review deployment summary.
-Review CSV and TXT reports.
-Investigate failed or skipped systems.


Benefits
---------
Automates large-scale Rapid7 deployments
Eliminates manual agent installation
Validates connectivity before deployment
Provides detailed deployment visibility
Captures installation failures automatically
Creates deployment audit records
Reduces deployment errors
Supports enterprise-scale rollouts

Use Cases
---------
Rapid7 Insight Agent deployment
Security onboarding projects
Compliance monitoring initiatives
Data center migrations
Server build automation
Security operations enablement
Infrastructure modernization
Enterprise vulnerability management

Limitations
-----------
Requires PowerShell Remoting.
Requires administrative access.
Processes servers sequentially.
Target servers must be reachable.
Depends on SMB and WinRM availability.
Installation success depends on MSI package integrity.
Does not currently support parallel processing.

Future Enhancements
-------------------
Parallel deployment support
Email reporting
HTML deployment dashboard
Automatic retry logic
Credential management integration
Deployment scheduling
Agent version validation
Agent upgrade automation
Centralized deployment history
Integration with configuration management platforms

Author
--------
Sundaram Gaur
Senior Systems Engineer | Windows Server | PowerShell Automation | Infrastructure Operations

Disclaimer
----------
This script is intended for authorized administrative use only. The tool deploys software remotely across Windows servers and should be executed only by users with appropriate permissions. Always validate deployment packages, test in non-production environments where appropriate, and follow organizational change management procedures before deploying to production systems.
