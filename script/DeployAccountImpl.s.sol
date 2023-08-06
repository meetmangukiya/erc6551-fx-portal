pragma solidity ^0.8.20;
import { BaseScript } from "./BaseScript.sol";
import { ERC6551Account } from "src/ERC6551Account.sol";
import { BeaconProxy } from "openzeppelin-contracts/contracts/proxy/beacon/BeaconProxy.sol";
import { UpgradeableBeacon } from "openzeppelin-contracts/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { ERC1967FactoryConstants } from "solady/utils/ERC1967FactoryConstants.sol";

contract DeployAccountImplScript is BaseScript {
    bytes32 constant ACCOUNT_BEACON_SALT = keccak256("account-beacon");
    bytes32 constant ACCOUNT_BEACON_PROXY_SALT = keccak256("account-beacon-proxy");

    constructor(bool _broadcast, address _sender) withBroadcast(_broadcast, _sender) { }

    function deploy(address _tunnel)
        external
        returns (address _implementationAddress, address _beaconAddress, address _proxyAddress)
    {
        // create2 will create different address since tunnel is immutable and part of initcode
        _broadcast();
        ERC6551Account accountImpl = new ERC6551Account(_tunnel);
        // doesn't matter what address implementation is in the constructor
        // as long as it is a contract and same address
        _broadcast();
        UpgradeableBeacon beacon =
            new UpgradeableBeacon{salt: ACCOUNT_BEACON_SALT}(ERC1967FactoryConstants.ADDRESS, sender);
        _broadcast();
        beacon.upgradeTo(address(accountImpl));
        _broadcast();
        BeaconProxy proxy = new BeaconProxy{salt: ACCOUNT_BEACON_PROXY_SALT}(address(beacon), hex"");

        _implementationAddress = address(accountImpl);
        _beaconAddress = address(beacon);
        _proxyAddress = address(proxy);
    }
}
