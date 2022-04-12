# Variables
[string] $vnetName0 = "VnetHub";
[string] $vnetName1 = "VnetSpoke1";
[string] $vnetName2 = "VnetSpoke2";

[string] $subnetName0 = "AzureFirewallSubnet";
[string] $subnetName1 = "Subnet11";
[string] $subnetName2 = "Subnet21";

[string] $addressPrefix0 = "10.1.0.0/16";
[string] $addressPrefix1 = "10.2.0.0/16";
[string] $addressPrefix2 = "10.3.0.0/16";

[string] $addressPrefixSubnet0 = "10.1.1.0/24";
[string] $addressPrefixSubnet1 = "10.2.1.0/24";
[string] $addressPrefixSubnet2 = "10.3.1.0/24";

[string] $publicIpAdNameFirewall = "FW1-ip";
[string] $firewallName = "FW1";

[string] $networkRuleCollectionName1 = "Spoke-to-spoke";
[string] $networkRuleName1 = "Spoke1-2";
[string] $networkRuleName2 = "Spoke2-1";
[string] $networkRuleDesc1 = "Allow all traffic from Spoke1 to Spoke2";
[string] $networkRuleDesc2 = "Allow all traffic from Spoke2 to Spoke1";

[string] $echoRequestRemoteAddress = "'10.1.0.0/255.255.0.0', '10.2.0.0/255.255.0.0', '10.3.0.0/255.255.0.0'";

[string] $nsgName1 = "NSG1";
[string] $nsgName2 = "NSG2";

[string] $routeName11 = "RT1_ToSpoke2";
[string] $routeName21 = "RT2_ToSpoke1";

[string] $routeTableName1 = "RT1";
[string] $routeTableName2 = "RT2";

[string] $nicName1 = "VM1-nic";
[string] $nicName2 = "VM2-nic";

[string] $userName = "AdminXyz";
[string] $password = "sfr9jttzrjjeoem7hrf#";

[string] $vmName1 = "VM1";
[string] $vmName2 = "VM2";

[string] $publicIpAdName1 = "VM1-ip";
[string] $publicIpAdName2 = "VM2-ip";

[string] $size = "Standard_D2s_v3";
[string] $imagePublisherName = "MicrosoftWindowsServer";
[string] $imageOffer = "WindowsServer";
[string] $imageSku = "2019-Datacenter";
[string] $imageVersion = "latest";


# Get resource group
# The subscription should contain just one empty resource group
$resourceGroup = (Get-AzResourceGroup)[0];
#$resourceGroup = Get-AzResourceGroup -Name $devResourceGroupName;


# Create VNet0 (Hub)
$subnet0 = New-AzVirtualNetworkSubnetConfig -Name $subnetName0 -AddressPrefix $addressPrefixSubnet0;

$vnet0 = New-AzVirtualNetwork `
    -Name $vnetName0 `
    -ResourceGroupName $resourceGroup.ResourceGroupName `
    -Location $resourceGroup.Location `
    -AddressPrefix $addressPrefix0 `
    -Subnet $subnet0;

# Create VNet1 (Spoke1)
$subnet1 = New-AzVirtualNetworkSubnetConfig -Name $subnetName1 -AddressPrefix $addressPrefixSubnet1;

$vnet1 = New-AzVirtualNetwork `
    -Name $vnetName1 `
    -ResourceGroupName $resourceGroup.ResourceGroupName `
    -Location $resourceGroup.Location `
    -AddressPrefix $addressPrefix1 `
    -Subnet $subnet1;

# Create VNet2 (Spoke2)
$subnet2 = New-AzVirtualNetworkSubnetConfig -Name $subnetName2 -AddressPrefix $addressPrefixSubnet2;

$vnet2 = New-AzVirtualNetwork `
    -Name $vnetName2 `
    -ResourceGroupName $resourceGroup.ResourceGroupName `
    -Location $resourceGroup.Location `
    -AddressPrefix $addressPrefix2 `
    -Subnet $subnet2;


# Peer the vnets
Add-AzVirtualNetworkPeering `
    -Name Spoke1-Hub `
    -VirtualNetwork $vnet1 `
    -RemoteVirtualNetworkId $vnet0.Id `
    -AllowForwardedTraffic;

Add-AzVirtualNetworkPeering `
    -Name Hub-Spoke1 `
    -VirtualNetwork $vnet0 `
    -RemoteVirtualNetworkId $vnet1.Id `
    -AllowForwardedTraffic;

Add-AzVirtualNetworkPeering `
    -Name Spoke2-Hub `
    -VirtualNetwork $vnet2 `
    -RemoteVirtualNetworkId $vnet0.Id;

Add-AzVirtualNetworkPeering `
    -Name Hub-Spoke2 `
    -VirtualNetwork $vnet0 `
    -RemoteVirtualNetworkId $vnet2.Id;


# Azure Firewall
$pipFW = New-AzPublicIpAddress `
    -Name $publicIpAdNameFirewall `
    -Location $resourceGroup.Location `
    -ResourceGroupName $resourceGroup.ResourceGroupName `
    -AllocationMethod Static `
    -Sku Standard;

$firewall = New-AzFirewall `
    -Name $firewallName `
    -Location $resourceGroup.Location `
    -ResourceGroupName $resourceGroup.ResourceGroupName `
    -VirtualNetwork $vnet0 `
    -PublicIpAddress $pipFW;

$privateIpFirewall = $firewall.IpConfigurations.PrivateIpAddress;


# Firewall rules
$networkRule1 = New-AzFirewallNetworkRule `
    -Name $networkRuleName1 `
    -Description $networkRuleDesc1 `
    -Protocol Any `
    -SourceAddress $addressPrefix1 `
    -DestinationAddress $addressPrefix2 `
    -DestinationPort "*";

$networkRule2 = New-AzFirewallNetworkRule `
    -Name $networkRuleName2 `
    -Description $networkRuleDesc2 `
    -Protocol Any `
    -SourceAddress $addressPrefix2 `
    -DestinationAddress $addressPrefix1 `
    -DestinationPort "*";

$networkRuleCollection1 = New-AzFirewallNetworkRuleCollection `
    -Name $networkRuleCollectionName1 `
    -Priority 200 `
    -Rule $networkRule1, $networkRule2 `
    -ActionType Allow;

$firewall.NetworkRuleCollections.Add($networkRuleCollection1);

Set-AzFirewall -AzureFirewall $firewall;


# Create network security groups
$rule1 = New-AzNetworkSecurityRuleConfig `
    -Name Allow-RDP `
    -Access Allow `
    -Protocol Tcp `
    -Direction Inbound `
    -Priority 100 `
    -SourceAddressPrefix Internet `
    -SourcePortRange * `
    -DestinationAddressPrefix * `
    -DestinationPortRange 3389;

# NSG1
$nsg1 = New-AzNetworkSecurityGroup `
    -Name $nsgName1 `
    -ResourceGroupName $resourceGroup.ResourceGroupName `
    -Location $resourceGroup.Location `
    -SecurityRules $rule1;    

# NSG2
$nsg2 = New-AzNetworkSecurityGroup `
    -Name $nsgName2 `
    -ResourceGroupName $resourceGroup.ResourceGroupName `
    -Location $resourceGroup.Location `
    -SecurityRules $rule1;    


# Create routing tables
# RT1
$route11 = New-AzRouteConfig `
    -Name $routeName11 `
    -AddressPrefix $addressPrefix2 `
    -NextHopType "VirtualAppliance" `
    -NextHopIpAddress $privateIpFirewall;

$routeTable1 = New-AzRouteTable `
    -Name $routeTableName1 `
    -Location $resourceGroup.Location `
    -ResourceGroupName $resourceGroup.ResourceGroupName `
    -DisableBgpRoutePropagation `
    -Route $route11;

# RT2
$route21 = New-AzRouteConfig `
    -Name $routeName21 `
    -AddressPrefix $addressPrefix1 `
    -NextHopType "VirtualAppliance" `
    -NextHopIpAddress $privateIpFirewall;

$routeTable2 = New-AzRouteTable `
    -Name $routeTableName2 `
    -Location $resourceGroup.Location `
    -ResourceGroupName $resourceGroup.ResourceGroupName `
    -DisableBgpRoutePropagation `
    -Route $route21;


# Configure subnets
Set-AzVirtualNetworkSubnetConfig `
    -Name $subnetName1 `
    -VirtualNetwork $vnet1 `
    -AddressPrefix $addressPrefixSubnet1 `
    -NetworkSecurityGroup $nsg1 `
    -RouteTable $routeTable1;

$vnet1 | Set-AzVirtualNetwork;

Set-AzVirtualNetworkSubnetConfig `
    -Name $subnetName2 `
    -VirtualNetwork $vnet2 `
    -AddressPrefix $addressPrefixSubnet2 `
    -NetworkSecurityGroup $nsg2 `
    -RouteTable $routeTable2;

$vnet2 | Set-AzVirtualNetwork;


# Create public IP addresses
$pip1 = New-AzPublicIpAddress `
    -Name $publicIpAdName1 `
    -Location $resourceGroup.Location `
    -ResourceGroupName $resourceGroup.ResourceGroupName `
    -AllocationMethod Dynamic `
    -IdleTimeoutInMinutes 4;

$pip2 = New-AzPublicIpAddress `
    -Name $publicIpAdName2 `
    -Location $resourceGroup.Location `
    -ResourceGroupName $resourceGroup.ResourceGroupName `
    -AllocationMethod Dynamic `
    -IdleTimeoutInMinutes 4;


# Create virtual network cards
# VM1-nic
$subnetCfg1 = Get-AzVirtualNetworkSubnetConfig `
    -Name $subnetName1 `
    -VirtualNetwork $vnet1;

$nic1 = New-AzNetworkInterface `
    -Name $nicName1 `
    -Location $resourceGroup.Location `
    -ResourceGroupName $resourceGroup.ResourceGroupName `
    -SubnetId $subnetCfg1.Id `
    -PublicIpAddressId $pip1.Id;

# VM2-nic
$subnetCfg2 = Get-AzVirtualNetworkSubnetConfig `
    -Name $subnetName2 `
    -VirtualNetwork $vnet2;

$nic2 = New-AzNetworkInterface `
    -Name $nicName2 `
    -Location $resourceGroup.Location `
    -ResourceGroupName $resourceGroup.ResourceGroupName `
    -SubnetId $subnetCfg2.Id `
    -PublicIpAddressId $pip2.Id;


# Create virtual machines
# Credential
$pw = $password | ConvertTo-SecureString -Force -AsPlainText;
$credential = New-Object PSCredential($userName, $pw);

# VM1
$vmConfig1 = New-AzVMConfig `
    -VMName $vmName1 `
    -VMSize $size `
    | `
    Set-AzVMOperatingSystem `
        -Windows `
        -ComputerName $vmName1 `
        -Credential $credential `
    | `
    Set-AzVMSourceImage `
          -PublisherName $imagePublisherName `
          -Offer $imageOffer `
          -Sku $imageSku `
          -Version $imageVersion `
    | `
    Set-AzVMBootDiagnostic `
        -Enable `
        -ResourceGroupName $resourceGroup.ResourceGroupName `
    | `
    Add-AzVMNetworkInterface -Id $nic1.Id;

New-AzVM `
    -VM $vmConfig1 `
    -Location $resourceGroup.Location `
    -ResourceGroupName $resourceGroup.ResourceGroupName;

# VM2
$vmConfig2 = New-AzVMConfig `
    -VMName $vmName2 `
    -VMSize $size `
    | `
    Set-AzVMOperatingSystem `
        -Windows `
        -ComputerName $vmName2 `
        -Credential $credential `
    | `
    Set-AzVMSourceImage `
          -PublisherName $imagePublisherName `
          -Offer $imageOffer `
          -Sku $imageSku `
          -Version $imageVersion `
    | `
    Set-AzVMBootDiagnostic `
        -Enable `
        -ResourceGroupName $resourceGroup.ResourceGroupName `
    | `
    Add-AzVMNetworkInterface -Id $nic2.Id;

New-AzVM `
    -VM $vmConfig2 `
    -Location $resourceGroup.Location `
    -ResourceGroupName $resourceGroup.ResourceGroupName;


# Allow ICMPv4 Echo Requests
$settingString = '{"commandToExecute":"powershell Set-NetFirewallRule -Name FPS-ICMP4-ERQ-In -Enabled True -RemoteAddress @(' + $echoRequestRemoteAddress + ');"}';

Set-AzVMExtension `
    -VMName $vmName1 `
    -Location $resourceGroup.Location `
    -ResourceGroupName $resourceGroup.ResourceGroupName `
    -ExtensionName "AllowEchoRequest" `
    -Publisher Microsoft.Compute `
    -ExtensionType CustomScriptExtension `
    -TypeHandlerVersion 1.8 `
    -SettingString $settingString;

Set-AzVMExtension `
    -VMName $vmName2 `
    -Location $resourceGroup.Location `
    -ResourceGroupName $resourceGroup.ResourceGroupName `
    -ExtensionName "AllowEchoRequest" `
    -Publisher Microsoft.Compute `
    -ExtensionType CustomScriptExtension `
    -TypeHandlerVersion 1.8 `
    -SettingString $settingString;
