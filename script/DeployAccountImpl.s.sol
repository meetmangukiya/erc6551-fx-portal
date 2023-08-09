pragma solidity ^0.8.20;

import { BaseScript } from "./BaseScript.sol";
import { Account } from "tokenbound-contracts/src/Account.sol";
import { AccountProxy } from "tokenbound-contracts/src/AccountProxy.sol";
import { AccountGuardian } from "tokenbound-contracts/src/AccountGuardian.sol";
import { BeaconProxy } from "openzeppelin-contracts/contracts/proxy/beacon/BeaconProxy.sol";
import { UpgradeableBeacon } from "openzeppelin-contracts/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { ERC1967FactoryConstants } from "solady/utils/ERC1967FactoryConstants.sol";
import { ACCOUNT_ABSTRACTION_ENTRYPOINT } from "src/constants.sol";

contract DeployAccountImplScript is BaseScript {
    bytes32 constant ACCOUNT_BEACON_SALT = keccak256("account-beacon");
    bytes32 constant ACCOUNT_BEACON_PROXY_SALT = keccak256("account-beacon-proxy");
    bytes32 constant ACCOUNT_GUARDIAN_SALT = keccak256("account-guardian");

    constructor(bool _broadcast, address _sender) withBroadcast(_broadcast, _sender) { }

    function deploy(address _tunnel)
        external
        returns (
            address _guardianAddress,
            address _implementationAddress,
            address _beaconAddress,
            address _proxyAddress
        )
    {
        // deploy the guardian
        _broadcast();
        AccountGuardian guardian = new AccountGuardian{salt: ACCOUNT_GUARDIAN_SALT}();

        // set the tunnel as trusted executor
        _broadcast();
        guardian.setTrustedExecutor(_tunnel, true);

        // create2 will create different address since tunnel is immutable and part of initcode
        _broadcast();
        Account accountImpl = new Account(address(guardian), ACCOUNT_ABSTRACTION_ENTRYPOINT);
        // doesn't matter what address implementation is in the constructor
        // as long as it is a contract and same address
        _broadcast();
        UpgradeableBeacon beacon =
            new UpgradeableBeacon{salt: ACCOUNT_BEACON_SALT}(ERC1967FactoryConstants.ADDRESS, sender);
        _broadcast();
        beacon.upgradeTo(address(accountImpl));
        _broadcast();
        BeaconProxy proxy = new BeaconProxy{salt: ACCOUNT_BEACON_PROXY_SALT}(address(beacon), hex"");

        _guardianAddress = address(guardian);
        _implementationAddress = address(accountImpl);
        _beaconAddress = address(beacon);
        _proxyAddress = address(proxy);
    }
}
