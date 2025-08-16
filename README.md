# GameSet Advanced v2.0 - Diskless Gaming Cafe Management System

## Overview

GameSet Advanced is a comprehensive management system for diskless gaming cafes, featuring pattern-based game detection and centralized game management from the server's E: drive.

## Key Features

- **Pattern-Based Detection**: Fast, offline detection without AI
- **Client-Based Detection**: Solves server GPU limitation
- **Portable GameSet Packages**: Each game in its own Set folder
- **Deploy-Once Mechanism**: Server C: deployment for UpdateSync
- **Game Doctor**: Automatic problem detection and resolution
- **PowerShell Bypass**: ExecutionPolicy issues auto-resolved with BAT wrappers

## Quick Start

### 1. Installation
```batch
REM Run as Administrator
GS_INSTALL.bat
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
├── GS_INSTALL.bat              # One-click installer
├── GS_Client_DetectNewGame.bat # Client game detection
├── GS_Server_DeployToC.bat     # Server deployment
├── GS_Client_AutoLoader.bat    # Client auto-loader
├── GS_Server_UpdateSync.bat    # Update synchronization
├── GS_Tools_GameDoctor.bat     # Diagnostic tool
├── GS_RunPowerShell.bat        # PowerShell helper
├── Scripts/                     # PowerShell scripts
│   ├── GS_Client_DetectNewGame.ps1
│   ├── GS_Server_DeployToC.ps1
│   ├── GS_Client_AutoLoader.ps1
│   ├── GS_Server_UpdateSync.ps1
│   ├── GS_Tools_GameDoctor.ps1
│   ├── GS_Core_SmartDetector.ps1
│   └── GS_Core_SymlinkManager.ps1
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

Use Game Doctor for automatic diagnosis:
```batch
GS_Tools_GameDoctor.bat GameName -AutoFix
```

## Version History

- **v2.0** (2025-01-16): Pattern-based system, client detection, portable packages
- **v1.0** (2025-01-14): Initial release

## License

Developed for diskless gaming cafes. Commercial use requires permission.

## Support

Check log files for detailed information:
- `E:\GameSet\Logs\detection.log`
- `E:\GameSet\Logs\deployment.log`
- `E:\GameSet\Logs\game_doctor.log`