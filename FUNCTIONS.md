# ParseConfig

Text in this document is automatically created - don't change it manually

## Index

[Invoke-ParseNetworkDeviceConfig](#Invoke-ParseNetworkDeviceConfig)<br>

## Functions

<a name="Invoke-ParseNetworkDeviceConfig"></a>
### Invoke-ParseNetworkDeviceConfig

```

NAME
    Invoke-ParseNetworkDeviceConfig
    
SYNOPSIS
    Parse config switch/router config file
    
    
SYNTAX
    Invoke-ParseNetworkDeviceConfig [-Path] <String[]> [-Type <String>] [-Interface] [-CustomType <String[]>] [-CustomProperty <Array>] [<CommonParameters>]
    
    Invoke-ParseNetworkDeviceConfig -Config <String[]> [-Type <String>] [-Interface] [-CustomType <String[]>] [-CustomProperty <Array>] [<CommonParameters>]
    
    
DESCRIPTION
    Parse config switch/router config file
    

PARAMETERS
    -Path <String[]>
        Path to switch config
        
    -Config <String[]>
        String with switch config
        
    -Type <String>
        Not used at the moment
        Config file format
        
    -Interface [<SwitchParameter>]
        Return interfaces as objects
        
    -CustomType <String[]>
        Return a custom type from config file as object
        
    -CustomProperty <Array>
        Add custom property eg.
        -CustomProperty @{Name = 'Speed'; RegEx = '^mode Eth (\d+)g'; ScriptBlock = {$Matches[1]}}
        
    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see 
        about_CommonParameters (https:/go.microsoft.com/fwlink/?LinkID=113216). 
    
    -------------------------- EXAMPLE 1 --------------------------
    
    PS C:\>Parse-Config -Path switch01.config -Interface
    
    
    
    
    
    
REMARKS
    To see the examples, type: "get-help Invoke-ParseNetworkDeviceConfig -examples".
    For more information, type: "get-help Invoke-ParseNetworkDeviceConfig -detailed".
    For technical information, type: "get-help Invoke-ParseNetworkDeviceConfig -full".

```



