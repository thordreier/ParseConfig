class NetworkInterface : NetworkGeneric
{
    [string]   $Hostname  # Comes from NetworkGeneric, listed here so order of properties are logical
    [string]   $Type      # ditto
    [string]   $Name      # ditto
    [string]   $MemberOf
    [string[]] $Members
    [string]   $Member
    [string]   $Description
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
}
