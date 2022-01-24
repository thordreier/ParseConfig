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

        .PARAMETER Output
            Not used at the moment

        .EXAMPLE
            Parse-Config -Path switch01.config
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
        $Type,

        [Parameter()]
        [ValidateSet('Interfaces')]
        [System.String]
        $Output
    )

    Write-Verbose -Message "Process begin (ErrorActionPreference: $ErrorActionPreference)"

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
                Get-Content -Raw -Path $Path | Invoke-ParseNetworkDeviceConfig
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
            
            $interfacesHash = @{}
            $interfaces = @()
            $regexInterface = '(?<=^|\n)interface[ \t]+(.+?)[ \t]*(\r?\n[ \t]*(.*?)[ \t]*)*?(?=((\r?\n)?$|\r?\n[ \t]*((!|exit|end|interface|cli)([ \t][^\r\n]+)?)?[ \t]*(\r?\n|$)))'
            foreach ($r1 in [regex]::Matches($conf, $regexInterface))
            {
                $name = $r1.Groups[1].Value
                $interface = [NetworkInterface] @{
                    Hostname  = $hostname
                    Name      = $name
                    ConfLines = $r1.Groups[3].Captures.Value
                    Conf      = $r1.Value
                }
                $interfaces += $interface
                $interfacesHash[$name] = $interface
            }

            foreach ($interface in $interfaces)
            {
                foreach ($line in $interface.ConfLines)
                {
                    if ($line -match 'description (.*)')
                    {
                        $interface.description = $Matches[1]
                    }
                    elseif ($line -match 'ip(v4)? address (([0-9\.]+)[ /]([0-9\.]+))')
                    {
                        $ip = $Matches[2]
                        $interface.IPv4Address    = Get-IPv4Address -Ip $ip -IpOnly
                        $interface.IPv4Mask       = Get-IPv4Address -Ip $ip -MaskQuadDotOnly
                        $interface.IPv4MaskLength = Get-IPv4Address -Ip $ip -MaskLengthOnly
                        $interface.IPv4Cidr       = Get-IPv4Address -Ip $ip
                        $interface.IPv4Subnet     = Get-IPv4Address -Ip $ip -Subnet -IpOnly
                        $interface.IPv4SubnetCidr = Get-IPv4Address -Ip $ip -Subnet
                    }
                    elseif ($line -match 'ipv6 address ((\S+)/(\S+))')
                    {
                        $ip = $Matches[1]
                        $interface.IPv6Address    = Get-IPv6Address -Ip $ip -IPOnly
                        $interface.IPv6Prefix     = Get-IPv6Address -Ip $ip -WithPrefix
                        $interface.IPv6Cidr       = Get-IPv6Address -Ip $ip -PrefixOnly
                        $interface.IPv6Subnet     = Get-IPv6Address -Ip $ip -Subnet -IpOnly
                        $interface.IPv6SubnetCidr = Get-IPv6Address -Ip $ip -Subnet

                    }
                    elseif ($line -match 'bundle id (\d+) ')
                    {
                        $g = $interface.MemberOf = "Bundle-Ether$($Matches[1])"
                        if ($interfacesHash.ContainsKey($g)) { $interfacesHash[$g].Members += $interface.Name }
                    }
                    elseif ($line -match 'channel-group (\d+) ')
                    {
                        $g = $interface.MemberOf = "port-channel$($Matches[1])"
                        if ($interfacesHash.ContainsKey($g)) { $interfacesHash[$interface.MemberOf].Members += $interface.Name }
                    }
                }
            }

            foreach ($interface in $interfaces)
            {
                $interface.Member = $interface.Members -join ','
            }

            #Return
            $interfaces
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

    Write-Verbose -Message 'Process end'
}
