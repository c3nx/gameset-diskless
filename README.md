# GameSet Advanced v3.0 - Diskless Gaming Cafe Management System

## Overview

GameSet Advanced is a comprehensive management system for diskless gaming cafes, featuring pattern-based game detection and centralized game management from the server's E: drive.

## Key Features

- **Claude AI Integration (v3.0)**: Intelligent filtering of unnecessary files
- **Registry Snapshot System**: Captures only changed registry keys
- **Pattern-Based Detection**: Fast, offline detection
- **Client-Based Detection**: Solves server GPU limitation
- **Portable GameSet Packages**: Each game in its own Set folder
- **Deploy-Once Mechanism**: Server C: deployment for UpdateSync
- **PowerShell Bypass**: ExecutionPolicy issues auto-resolved with BAT wrappers
- **Environment Variable Support**: User-independent paths (%APPDATA%, %LOCALAPPDATA%)

## Quick Start

### 1. Installation
```batch
REM Clone or download to C:\GameSet
git clone https://github.com/c3nx/gameset-diskless.git C:\GameSet

REM Edit config if needed (default E: drive)
notepad C:\GameSet\GameSet_Config.ini
```

### 2. Add New Game (on Client)
```batch
GS_Client_DetectNewGame.bat
```

### 3. Deploy to Server
```batch
GS_Server_DeployToC.bat GameNameSet
```

### 4. Client Setup
Add to Gizmo startup script:
```batch
E:\GameSet\GS_Client_AutoLoader.bat
```

## Documentation

- **[CLAUDE.md](CLAUDE.md)** - Detailed Turkish documentation
- **[TEST_SCENARIOS.md](TEST_SCENARIOS.md)** - Test scenarios and validation

## File Structure

```
gameset-diskless/
├── GS_Client_DetectNewGame.bat # Client game detection
├── GS_Server_DeployToC.bat     # Server deployment
├── GS_Client_AutoLoader.bat    # Client auto-loader
├── GS_Server_UpdateSync.bat    # Update synchronization
├── GS_RunPowerShell.bat        # PowerShell helper
├── GS_LoadConfig.bat           # Config loader
├── GameSet_Config.ini          # Main configuration
├── Scripts/                     # PowerShell scripts
│   ├── GS_Client_DetectChanges.ps1  # Main detection script
│   ├── GS_Server_DeployToC.ps1      # Server deployment
│   ├── GS_Client_AutoLoader.ps1     # Client auto-loader
│   ├── GS_Server_UpdateSync.ps1     # Update sync
│   ├── GS_Core_Config.ps1           # Config module
│   ├── GS_Core_SmartDetector.ps1    # Pattern detection
│   ├── GS_Core_SymlinkManager.ps1   # Symlink management
│   └── GS_Core_ClaudeAnalyzer.ps1   # Claude AI module
└── Data/                        # Configuration files
    ├── GamePatterns.json        # Pattern database
    └── config.json              # System configuration
```

## Requirements

- Windows 10/11
- PowerShell 5.1+
- Administrator privileges
- E: drive (network mapped or local)
- Diskless gaming cafe setup

## Workflow

1. **Detection**: Install game on client, detect changes
2. **Package**: Create portable GameSet package
3. **Deploy**: Deploy package to server C:
4. **Load**: Clients auto-load packages on startup

## Troubleshooting

### Common Issues

1. **PowerShell Execution Policy**: BAT wrappers automatically bypass this
2. **Network Drive Not Found**: Ensure E: drive is mapped
3. **Registry Changes Not Captured**: Run as Administrator
4. **Symlinks Not Created**: Requires admin privileges

## Version History

- **v3.0** (2025-01-18): Claude AI integration, registry snapshot system, English translation
- **v2.0** (2025-01-16): Pattern-based system, client detection, portable packages
- **v1.0** (2025-01-14): Initial release

## License

Developed for diskless gaming cafes. Commercial use requires permission.

## Support

Check log files for detailed information:
- `E:\GameSet\Logs\detection.log`
- `E:\GameSet\Logs\deployment.log`
- `E:\GameSet\Logs\client_loader.log`

For issues and feedback:
- GitHub: https://github.com/c3nx/gameset-diskless/issues