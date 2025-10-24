# Security Hardening Specification

## ADDED Requirements

### Requirement: Command Injection Prevention
All scripts that execute PowerShell commands SHALL properly escape or quote user-controlled input to prevent command injection attacks.

#### Scenario: Safe PowerShell execution with user input
- **GIVEN** a script needs to execute a PowerShell command with user-provided arguments
- **WHEN** the command is constructed
- **THEN** all user input MUST be properly escaped or passed as separate parameters
- **AND** special PowerShell characters SHALL NOT be interpreted in user data

#### Scenario: Rejection of malicious input
- **GIVEN** a user provides input containing PowerShell command separators (`;`, `|`, `&`)
- **WHEN** the input is processed for PowerShell execution
- **THEN** the characters SHALL be treated as literal data, not command syntax

### Requirement: Environment Variable Expansion Restrictions
Scripts SHALL restrict `envsubst` to only expand explicitly allowed environment variables to prevent command injection through crafted variables.

#### Scenario: Safe environment variable substitution
- **GIVEN** a configuration file contains variable references like `${WIN_WINDIR}`
- **WHEN** envsubst is used for expansion
- **THEN** only variables in an allowlist (WIN_WINDIR, WIN_PROGRAMFILES, WIN_USERPROFILE, etc.) SHALL be expanded
- **AND** arbitrary variable references SHALL NOT be expanded

#### Scenario: Prevention of command injection via environment variables
- **GIVEN** a malicious environment variable containing `$(rm -rf /)`
- **WHEN** envsubst processes configuration with restricted variable list
- **THEN** the malicious variable SHALL NOT be expanded or executed

### Requirement: Cache File Integrity Validation
Scripts SHALL validate cache files before sourcing them to prevent arbitrary code execution.

#### Scenario: Valid cache file sourcing
- **GIVEN** a cache file exists with proper WIN_ENV variable declarations
- **WHEN** the cache file is validated
- **THEN** the file SHALL be sourced successfully

#### Scenario: Rejection of malicious cache file
- **GIVEN** a cache file contains arbitrary commands or malicious code
- **WHEN** the cache file is validated
- **THEN** the validation SHALL fail and the file SHALL NOT be sourced
- **AND** an error message SHALL be displayed to the user

#### Scenario: Detection of suspicious content
- **GIVEN** a cache file contains commands other than variable assignments
- **WHEN** validation checks for allowed patterns
- **THEN** content not matching `WIN_ENV[...]` pattern SHALL trigger rejection

### Requirement: Race Condition Prevention in File Operations
Scripts SHALL perform atomic file operations while holding locks to prevent TOCTOU (Time-of-Check-Time-of-Use) vulnerabilities.

#### Scenario: Atomic cache file creation
- **GIVEN** multiple processes attempt to build cache files simultaneously
- **WHEN** a process acquires the file lock
- **THEN** all file operations SHALL complete before releasing the lock
- **AND** no file moves SHALL occur after lock release

#### Scenario: Concurrent cache building safety
- **GIVEN** two processes simultaneously attempt to build WIN_ENV cache
- **WHEN** both processes try to acquire the lock
- **THEN** only one SHALL proceed while the other waits
- **AND** the final cache file SHALL be consistent and uncorrupted

### Requirement: Path Traversal Protection
Scripts SHALL validate user-provided file paths to prevent access to files outside allowed directories.

#### Scenario: Valid path within allowed boundaries
- **GIVEN** a user provides a path within their home directory or current working directory
- **WHEN** the path is validated
- **THEN** the path SHALL be resolved and accepted

#### Scenario: Rejection of directory traversal attempts
- **GIVEN** a user provides a path like `../../../../etc/passwd`
- **WHEN** the path is validated
- **THEN** the validation SHALL fail
- **AND** an error message SHALL inform the user the path is outside allowed boundaries

#### Scenario: Protection of sensitive Windows files
- **GIVEN** a user attempts to access `C:\Windows\System32\config\SAM`
- **WHEN** path validation is performed
- **THEN** access SHALL be restricted based on security policies

### Requirement: Log Injection Prevention
Scripts SHALL sanitize all user input before writing to log files to prevent log injection attacks.

#### Scenario: Safe logging of user commands
- **GIVEN** a user executes a command with normal arguments
- **WHEN** the command is logged
- **THEN** the log entry SHALL contain sanitized output with timestamps

#### Scenario: Prevention of fake log entries
- **GIVEN** a user provides input containing newline characters and fake log entries
- **WHEN** the input is logged
- **THEN** newlines SHALL be escaped or replaced
- **AND** control characters SHALL be removed
- **AND** fake log entries SHALL NOT be created

### Requirement: Secure Log File Permissions
Scripts SHALL create log files with restricted permissions (600) to prevent unauthorized access to sensitive information.

#### Scenario: Log directory creation with secure permissions
- **GIVEN** a script needs to create a log directory
- **WHEN** the directory is created
- **THEN** it SHALL have permissions 700 (drwx------)
- **AND** only the owner SHALL have read, write, and execute access

#### Scenario: Log file creation with restricted access
- **GIVEN** a script creates a new log file
- **WHEN** the file is created
- **THEN** it SHALL have permissions 600 (-rw-------)
- **AND** only the owner SHALL have read and write access

### Requirement: PowerShell Variable Quoting
All PowerShell command constructions SHALL properly quote variables to prevent unintended word splitting and command interpretation.

#### Scenario: Quoted variable in PowerShell command
- **GIVEN** a PowerShell command needs to reference a file path with spaces
- **WHEN** the command string is constructed
- **THEN** the variable SHALL be quoted within the PowerShell context
- **AND** spaces in the path SHALL NOT cause word splitting

#### Scenario: Safe execution with special characters
- **GIVEN** a variable contains PowerShell special characters
- **WHEN** the variable is used in a PowerShell command
- **THEN** proper quoting SHALL prevent interpretation of special characters
