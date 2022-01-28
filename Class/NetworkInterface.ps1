class NetworkInterface : NetworkGeneric
{
    [string]   $Hostname  # Comes from NetworkGeneric, listed here so order of properties are logical
    [string]   $Type      # ditto
    [string]   $Name      # ditto
    [string]   $Description
    [string]   $Shutdown
    [string]   $Speed
    [string]   $Mtu
    [string]   $VlanUntagged
    [string]   $VlanTagged
    [string[]] $VlanTaggedList = @()
    [string]   $PortUntagged
    [string[]] $PortUntaggedList = @()
    [string]   $PortTagged
    [string[]] $PortTaggedList = @()
    [string]   $IPv4Address
    [string]   $IPv4Mask
    [string]   $IPv4MaskLength
    [string]   $IPv4Cidr
    [string]   $IPv4Subnet
    [string]   $IPv4SubnetCidr
    [string]   $IPv6Address
    [string]   $IPv6Prefix
    [string]   $IPv6Cidr
    [string]   $IPv6Subnet
    [string]   $IPv6SubnetCidr
    [string]   $MemberOf
    [string]   $Members
    [string[]] $MembersList = @()
}
