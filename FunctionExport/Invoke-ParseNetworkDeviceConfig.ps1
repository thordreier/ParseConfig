function Invoke-ParseNetworkDeviceConfig
{
    <#
        .SYNOPSIS
            Parse config switch/router config file

        .DESCRIPTION
            Parse config switch/router config file

        .PARAMETER Path
            Path to switch config

        .PARAMETER Config
            String with switch config

        .PARAMETER Type
            Not used at the moment
            Config file format

        .PARAMETER Interface
            Return interfaces as objects

        .PARAMETER CustomType
            Return a custom type from config file as object

        .PARAMETER CustomProperty
            Add custom property eg.
            -CustomProperty @{Name = 'Speed'; RegEx = '^mode Eth (\d+)g'; ScriptBlock = {$_[1]}}

        .EXAMPLE
            Parse-Config -Path switch01.config -Interface
    #>

    [CmdletBinding()]
    param
    (
        [Parameter(ParameterSetName='Path',   Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position=0)]
        [System.String[]]
        $Path,

        [Parameter(ParameterSetName='Config', Mandatory = $true, ValueFromPipeline = $true)]
        [System.String[]]
        $Config,

        [Parameter()]
        [ValidateSet('Generic')]
        [System.String]
        $Type = 'Generic',

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $Interface,

        [Parameter()]
        [System.String[]]
        $CustomType = @(),

        [Parameter()]
        [array]
        $CustomProperty = @()
    )

    Write-Verbose -Message "Begin (ErrorActionPreference: $ErrorActionPreference)"
    $origErrorActionPreference = $ErrorActionPreference

    # We do this instead of begin/process/end
    if ($Input -and $Path)
    {
        $Path = $Input | Select-Object -ExpandProperty Path
    }
    elseif ($Input -and $Config)
    {
        $Config = $Input
    }

    try
    {
        # Make sure that we don't continue on error, and that we catches the error
        $ErrorActionPreference = 'Stop'

        if ($Path)
        {
            foreach ($p in $Path)
            {
                "Reading file $Path" | Write-Verbose
                $null = $PSBoundParameters.Remove('Path')
                Get-Content -Raw -Path $Path | Invoke-ParseNetworkDeviceConfig @PSBoundParameters
            }
        }
        elseif ($Config)
        {
            $conf = $Config -join "`n"

            if (
                ($conf -match '(^|\n)[ \t]*hostname[ \t]+(\S+)[ \t]*(\r?\n|$)') -or
                ($conf -match '(^|\n)[ \t]*hostname[ \t]+"([^"]+)"[ \t]*(\r?\n|$)')
            )
            {
                $hostname = $Matches[2]
            }
            else
            {
                Write-Warning "Hostname not found"
                $hostname = ''
            }

            switch ($Type)
            {
                'Generic'
                {
                    $regexObject = '(?<=^|\n)({0}[ \t]+(.+?))[ \t]*(\r?\n[ \t]*(.*?)[ \t]*)*?(?=((\r?\n)?$|\r?\n[ \t]*((!|exit|end|{0})([ \t][^\r\n]+)?)?[ \t]*(\r?\n|$)))'
                    $regexObjectGroupObjectLine = 1
                    $regexObjectGroupName       = 2
                    $regexObjectGroupConfLines  = 4
                }
                default {throw 'Unknown error'}
            }

            if ($Interface -and -not $CustomType.Contains('interface')) {$CustomType += 'interface'}

            $objects = @()
            $objectsHash = @{}
            foreach ($t in $CustomType)
            {
                $objectsHash[$t] = @{}
                # FIXXXME - should we test that $t don't contain any weird characters?
                $re = $regexObject -f $t
                "Parsing type $t with $re" | Write-Verbose
                $objectClass = 'NetworkGeneric'
                if ($Interface -and $t -eq 'interface') {$objectClass = 'NetworkInterface'}
                foreach ($m in [regex]::Matches($conf, $re))
                {
                    $name = $m.Groups[$regexObjectGroupName].Value
                    $object = New-Object -TypeName $objectClass -Property @{
                        Hostname  = $hostname
                        Name      = $name
                        Type      = $t
                        ConfLines = @($m.Groups[$regexObjectGroupObjectLine].Value) + $m.Groups[$regexObjectGroupConfLines].Captures.Value
                        Conf      = $m.Value
                    }
                    $objects += $object
                    $objectsHash[$t][$name] = $object
                }
            }
            
            if ($Interface)
            {
                $interfaceObjectsHash = $objectsHash['interface']
                $interfaceObjects = $objects.Where({$_ -is [NetworkInterface]})

                foreach ($interfaceObject in $interfaceObjects)
                {
                    foreach ($line in $interfaceObject.ConfLines)
                    {
                        if ($line -match 'description (.*)')
                        {
                            $interfaceObject.description = $Matches[1]
                        }
                        elseif ($line -match 'speed (.*)')
                        {
                            $interfaceObject.speed = $Matches[1]
                        }
                        elseif ($line -match 'ip(v4)? address (([0-9\.]+)[ /]([0-9\.]+))')
                        {
                            $ip = $Matches[2]
                            $interfaceObject.IPv4Address    = Get-IPv4Address -Ip $ip -IpOnly
                            $interfaceObject.IPv4Mask       = Get-IPv4Address -Ip $ip -MaskQuadDotOnly
                            $interfaceObject.IPv4MaskLength = Get-IPv4Address -Ip $ip -MaskLengthOnly
                            $interfaceObject.IPv4Cidr       = Get-IPv4Address -Ip $ip
                            $interfaceObject.IPv4Subnet     = Get-IPv4Address -Ip $ip -Subnet -IpOnly
                            $interfaceObject.IPv4SubnetCidr = Get-IPv4Address -Ip $ip -Subnet
                        }
                        elseif ($line -match 'ipv6 address ((\S+)/(\S+))')
                        {
                            $ip = $Matches[1]
                            $interfaceObject.IPv6Address    = Get-IPv6Address -Ip $ip -IPOnly
                            $interfaceObject.IPv6Prefix     = Get-IPv6Address -Ip $ip -WithPrefix
                            $interfaceObject.IPv6Cidr       = Get-IPv6Address -Ip $ip -PrefixOnly
                            $interfaceObject.IPv6Subnet     = Get-IPv6Address -Ip $ip -Subnet -IpOnly
                            $interfaceObject.IPv6SubnetCidr = Get-IPv6Address -Ip $ip -Subnet

                        }
                        elseif ($line -match 'bundle id (\d+) ')
                        {
                            $g = $interfaceObject.MemberOf = "Bundle-Ether$($Matches[1])"
                            if ($interfaceObjectsHash.ContainsKey($g)) { $interfaceObjectsHash[$g].Members += $interfaceObject.Name }
                        }
                        elseif ($line -match 'channel-group (\d+) ')
                        {
                            $g = $interfaceObject.MemberOf = "port-channel$($Matches[1])"
                            if ($interfaceObjectsHash.ContainsKey($g)) { $interfaceObjectsHash[$interfaceObject.MemberOf].Members += $interfaceObject.Name }
                        }
                    }
                }

                foreach ($interfaceObject in $interfaceObjects)
                {
                    $interfaceObject.Member = $interfaceObject.Members -join ','
                }
            }

            if ($CustomProperty)
            {
                foreach ($object in $objects)
                {
                    foreach ($cp in $CustomProperty)
                    {
                        foreach ($line in $object.ConfLines)
                        {
                            if ($line -match $cp.RegEx)
                            {
                                $object | Add-Member -NotePropertyName $cp.Name -NotePropertyValue (ForEach-Object -InputObject $Matches -Process $cp.ScriptBlock)
                                break
                            }
                        }
                    }
                }
            }


            #Return
            $objects
        }
    }
    catch
    {
        # If error was encountered inside this function then stop doing more
        # But still respect the ErrorAction that comes when calling this function
        # And also return the line number where the original error occured
        $msg = $_.ToString() + "`r`n" + $_.InvocationInfo.PositionMessage.ToString()
        Write-Verbose -Message "Encountered an error: $msg"
        Write-Error -ErrorAction $origErrorActionPreference -Exception $_.Exception -Message $msg
    }
    finally
    {
        $ErrorActionPreference = $origErrorActionPreference
    }

    Write-Verbose -Message 'End'
}
