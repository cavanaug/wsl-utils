# Code Quality Specification

## ADDED Requirements

### Requirement: Safe Command Substitution in Loops
Scripts SHALL use array-based approaches instead of unsafe command substitution that relies on word splitting.

#### Scenario: Safe iteration over command output
- **GIVEN** a script needs to iterate over a list of items from command output
- **WHEN** the list is generated using command substitution
- **THEN** the output SHALL be read into an array using `readarray` or similar
- **AND** array elements SHALL be quoted during iteration

#### Scenario: Handling special characters in output
- **GIVEN** command output contains items with spaces or special characters
- **WHEN** the output is processed for iteration
- **THEN** spaces and special characters SHALL NOT cause word splitting
- **AND** each item SHALL be treated as a single element

### Requirement: Proper Array Expansion
Scripts SHALL properly quote array expansions to prevent word splitting and globbing.

#### Scenario: Array expansion with spaces
- **GIVEN** an array contains elements with spaces
- **WHEN** the array is expanded using `"${array[@]}"`
- **THEN** each element SHALL be preserved as a separate word
- **AND** spaces within elements SHALL NOT cause splitting

#### Scenario: String to array conversion
- **GIVEN** a variable is used to store multiple arguments as a string
- **WHEN** the variable needs to be expanded with proper word boundaries
- **THEN** the variable SHALL be converted to an array
- **AND** the array SHALL be used for expansion

### Requirement: Portable Shebang Lines
All executable scripts SHALL use portable shebang lines for maximum compatibility.

#### Scenario: Bash script portability
- **GIVEN** a bash script needs to run on different systems
- **WHEN** the shebang line is defined
- **THEN** it SHALL use `#!/usr/bin/env bash`
- **AND** the script SHALL work on systems where bash is not at `/bin/bash`

#### Scenario: Consistent shebang across codebase
- **GIVEN** all scripts in the wsl-utils project
- **WHEN** reviewing shebang lines
- **THEN** all scripts SHALL use the same portable format

### Requirement: Named Constants for Magic Numbers
Scripts SHALL replace magic numbers with named constants that document their purpose.

#### Scenario: Chunk size constant definition
- **GIVEN** a script uses a buffer size for data processing
- **WHEN** the buffer size is defined
- **THEN** it SHALL be defined as a readonly constant with a descriptive name
- **AND** a comment SHALL explain the rationale for the value

#### Scenario: Magic number elimination
- **GIVEN** a script contains hardcoded numeric values
- **WHEN** the values represent meaningful limits or sizes
- **THEN** they SHALL be replaced with named constants
- **AND** the constants SHALL be defined at the top of the script

### Requirement: Code Cleanup and Maintenance
Scripts SHALL not contain commented-out code blocks that reduce readability.

#### Scenario: Removal of commented code
- **GIVEN** a script contains large blocks of commented-out code
- **WHEN** the code is reviewed for cleanup
- **THEN** the commented code SHALL be removed
- **AND** git history SHALL preserve the removed code for reference

#### Scenario: Explanatory comments retention
- **GIVEN** a script contains comments explaining why features were removed
- **WHEN** code cleanup is performed
- **THEN** explanatory comments SHALL be retained
- **AND** commented-out code SHALL be removed

### Requirement: GNU Tools Compatibility
Scripts SHALL detect and adapt to differences between GNU and BSD versions of common tools.

#### Scenario: GNU stat detection
- **GIVEN** a script needs to use the stat command
- **WHEN** the script checks the stat version
- **THEN** it SHALL detect whether GNU or BSD stat is available
- **AND** it SHALL use the appropriate flags for the detected version

#### Scenario: Fallback for BSD tools
- **GIVEN** a system has BSD versions of coreutils
- **WHEN** scripts attempt to use GNU-specific flags
- **THEN** they SHALL fall back to BSD-compatible alternatives
- **AND** functionality SHALL remain consistent across platforms

### Requirement: Dependency Version Verification
Scripts SHALL verify that external dependencies meet minimum version requirements.

#### Scenario: yq version check
- **GIVEN** a script requires yq version 4.0 or higher
- **WHEN** the script checks dependencies
- **THEN** it SHALL verify the installed yq version
- **AND** it SHALL display an error if version is too old

#### Scenario: Graceful dependency failure
- **GIVEN** a required tool is not installed
- **WHEN** the script attempts to use the tool
- **THEN** a clear error message SHALL inform the user
- **AND** the error message SHALL suggest how to install the tool

### Requirement: File Permission Validation
Installation scripts SHALL validate file permissions and ownership to ensure proper setup.

#### Scenario: Executable verification
- **GIVEN** an installation script creates executables
- **WHEN** installation is complete
- **THEN** the script SHALL verify files have executable permissions
- **AND** it SHALL display an error if permissions are incorrect

#### Scenario: Ownership verification
- **GIVEN** files are installed in user space
- **WHEN** installation validation is performed
- **THEN** the script SHALL check file ownership matches current user
- **AND** it SHALL display a warning if ownership is unexpected

### Requirement: Pipeline Optimization
Scripts SHALL use efficient command pipelines, preferring single tools like awk over multiple grep/sed pipes where appropriate.

#### Scenario: Combined text processing
- **GIVEN** a pipeline uses grep followed by sed for text transformation
- **WHEN** the operations can be combined into a single awk command
- **THEN** the pipeline SHALL be refactored to use awk
- **AND** functionality SHALL remain equivalent

#### Scenario: Performance improvement verification
- **GIVEN** a pipeline is optimized
- **WHEN** performance is measured
- **THEN** the optimized version SHALL show measurable improvement
- **AND** output SHALL remain identical to the original
