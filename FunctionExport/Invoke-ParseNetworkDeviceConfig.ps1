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

    function SplitAndExpand ([string] $List)
    {
        $r = '^(.*[^\d])?(\d+)$'
        $pre = ''
        if ($List -match '^(\S+\s+)(.+)$')
        {
            $pre  = $Matches[1]
            $List = $Matches[2]
        }
        foreach ($a in ($List -split ','))
        {
            $b,$c = $a -split '-'
            if ($c)
            {
                # We assume something like 1/1-1/20 - 1/1-2/20 will not work
                if (($d = $b -replace $r,'$1') -eq ($c -replace $r,'$1'))
                {
                    foreach ($e in ($b -replace $r,'$2')..($c -replace $r,'$2'))
                    {
                        "$pre$d$e"
                    }
                }
            }
            else
            {
                "$pre$b"
            }
        }
    }

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

                foreach ($io in $interfaceObjects)
                {
                    foreach ($line in $io.ConfLines)
                    {
                        if     ($line -match '^description ("(.+)"|(.+))$')         { $io.Description = $Matches.Values | Select-Object -First 1 }
                        elseif ($line -match '^shutdown$')                          { $io.Shutdown = 'yes' }
                        elseif ($line -match '^no shutdown$')                       { $io.Shutdown = 'no' }
                        elseif ($line -match '^speed (.+)')                         { $io.Speed = $Matches[1] }
                        elseif ($line -match '^mtu (.+)')                           { $io.Mtu = $Matches[1] }
                        elseif ($line -match '^switchport mode trunk$')             { if (-not $io.VlanTagged) {$io.VlanTagged = 'all'} }
                        elseif ($line -match '^switchport access vlan (.+)')
                        {
                            $v = $io.VlanUntagged = $Matches[1]
                            if (($o = $interfaceObjectsHash["vlan$v"]) -or ($o = $interfaceObjectsHash["vlan $v"]))
                            {
                                $o.PortUntaggedList += $io.Name
                            }
                        }
                        elseif ($line -match '^switchport trunk allowed vlan (.+)')
                        {
                            $io.VlanTagged = if ($io.VlanTagged -and $io.VlanTagged -ne 'all') { $io.VlanTagged, $Matches[1] -join ',' } else { $Matches[1] }
                            $io.VlanTaggedList += $vtl = SplitAndExpand -List $io.VlanTagged
                            foreach ($v in $vtl)
                            {
                                if (($o = $interfaceObjectsHash["vlan$v"]) -or ($o = $interfaceObjectsHash["vlan $v"]))
                                {
                                    $o.PortTaggedList += $io.Name
                                }
                            }
                        }
                        elseif ($line -match '^untagged (.+)')
                        {
                            $io.PortUntagged = if ($io.PortUntagged) { $io.PortUntagged, $Matches[1] -join ',' } else { $Matches[1] }
                            $io.PortUntaggedList += $pl = SplitAndExpand -List $Matches[1]
                            foreach ($p in $pl)
                            {
                                if ($o = $interfaceObjectsHash[$p])
                                {
                                    $o.VlanUntagged = $io.Name -replace '^vlan\s?'
                                }
                            }
                        }
                        elseif ($line -match '^tagged (.+)')
                        {
                            $io.PortTagged = if ($io.PortTagged) { $io.PortTagged, $Matches[1] -join ',' } else { $Matches[1] }
                            $io.PortTaggedList += $pl = SplitAndExpand -List $Matches[1]
                            foreach ($p in $pl)
                            {
                                if ($o = $interfaceObjectsHash[$p])
                                {
                                    $o.VlanTaggedList += $io.Name -replace '^vlan\s?'
                                }
                            }
                        }
                        elseif ($line -match '^ip(v4)? address (([0-9\.]+)[ /]([0-9\.]+))')
                        {
                            $ip = $Matches[2]
                            $io.IPv4Address    = Get-IPv4Address -Ip $ip -IpOnly
                            $io.IPv4Mask       = Get-IPv4Address -Ip $ip -MaskQuadDotOnly
                            $io.IPv4MaskLength = Get-IPv4Address -Ip $ip -MaskLengthOnly
                            $io.IPv4Cidr       = Get-IPv4Address -Ip $ip
                            $io.IPv4Subnet     = Get-IPv4Address -Ip $ip -Subnet -IpOnly
                            $io.IPv4SubnetCidr = Get-IPv4Address -Ip $ip -Subnet
                        }
                        elseif ($line -match '^ipv6 address ((\S+)/(\S+))')
                        {
                            $ip = $Matches[1]
                            $io.IPv6Address    = Get-IPv6Address -Ip $ip -IPOnly
                            $io.IPv6Prefix     = Get-IPv6Address -Ip $ip -WithPrefix
                            $io.IPv6Cidr       = Get-IPv6Address -Ip $ip -PrefixOnly
                            $io.IPv6Subnet     = Get-IPv6Address -Ip $ip -Subnet -IpOnly
                            $io.IPv6SubnetCidr = Get-IPv6Address -Ip $ip -Subnet

                        }
                        elseif ($line -match '^bundle id (\d+) ')
                        {
                            $g = $io.MemberOf = "Bundle-Ether$($Matches[1])"
                            if ($o = $interfaceObjectsHash[$g]) { $o.MembersList += $io.Name }
                        }
                        elseif ($line -match '^channel-group (\d+) ')
                        {
                            $g = $io.MemberOf = "port-channel$($Matches[1])"
                            if ($o = $interfaceObjectsHash[$g]) { $o.MembersList += $io.Name }
                        }
                        elseif ($line -match '^channel-member (.+)')
                        {
                            $io.Members = if ($io.Members) { $io.Members, $Matches[1] -join ',' } else { $Matches[1] }
                            $io.MembersList += $ml = SplitAndExpand -List $io.Members
                            foreach ($m in $ml)
                            {
                                if ($o = $interfaceObjectsHash[$m])
                                {
                                    $o.MemberOf += $io.Name
                                }
                            }
                        }
                    }
                }

                foreach ($io in $interfaceObjects)
                {
                    if ($io.VlanTagged -eq 'all')
                    {
                        foreach ($vio in $interfaceObjects)
                        {
                            if ($vio.Name -match '^vlan\s?(\d+)$')
                            {
                                $io.VlanTaggedList  += $Matches[1]
                                $vio.PortTaggedList += $io.Name
                            }
                        }
                    }
                }

                foreach ($io in $interfaceObjects)
                {
                    if (-not $io.VlanTagged)   { $io.VlanTagged   = $io.VlanTaggedList   -join ',' }
                    if (-not $io.PortUntagged) { $io.PortUntagged = $io.PortUntaggedList -join ',' }
                    if (-not $io.PortTagged)   { $io.PortTagged   = $io.PortTaggedList   -join ',' }
                    if (-not $io.Members)      { $io.Members      = $io.MembersList      -join ',' }
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
