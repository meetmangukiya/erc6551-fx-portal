pragma solidity ^0.8.20;

import { StdAssertions } from "forge-std/StdAssertions.sol";
import { Test } from "forge-std/Test.sol";
import { ERC1967Factory } from "solady/utils/ERC1967Factory.sol";
import { ERC1967FactoryConstants } from "solady/utils/ERC1967FactoryConstants.sol";
import { RemoteCallFxChildTunnel } from "src/tunnel/RemoteCallFxChildTunnel.sol";
import { RemoteCallFxRootTunnel } from "src/tunnel/RemoteCallFxRootTunnel.sol";
import { FX_ROOT_MAINNET, FX_CHILD_POLYGON_POS, CHECKPOINT_MANAGER } from "src/constants.sol";
import { BeaconProxy } from "openzeppelin-contracts/contracts/proxy/beacon/BeaconProxy.sol";
import { UpgradeableBeacon } from "openzeppelin-contracts/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { BaseScript } from "./BaseScript.sol";
import { DeployAccountImplScript } from "./DeployAccountImpl.s.sol";
import { console } from "forge-std/console.sol";
import { AccountGuardian } from "tokenbound-contracts/src/AccountGuardian.sol";
import { Account } from "tokenbound-contracts/src/Account.sol";
import { CommonBase } from "forge-std/Base.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";

ERC1967Factory constant FACTORY = ERC1967Factory(ERC1967FactoryConstants.ADDRESS);

contract DeployScript is BaseScript, StdAssertions {
    uint256 mainnetForkId;
    uint256 l2ForkId;

    struct Addresses {
        address accountBeaconProxyMainnet;
        address accountBeaconProxyL2;
        address accountProxyMainnet;
        address accountProxyL2;
        address rootTunnelProxy;
        address childTunnelProxy;
        address accountImplMainnet;
        address accountImplL2;
        address rootTunnelImpl;
        address childTunnelImpl;
        address guardianMainnet;
        address guardianL2;
    }

    struct Contracts {
        Account accountBeaconProxyMainnet;
        Account accountBeaconProxyL2;
        Account accountMainnetProxy;
        Account accountL2Proxy;
        RemoteCallFxRootTunnel rootTunnelProxy;
        RemoteCallFxChildTunnel childTunnelProxy;
        Account accountMainnetImpl;
        Account accountL2Impl;
        RemoteCallFxRootTunnel rootTunnelImpl;
        RemoteCallFxChildTunnel childTunnelImpl;
        AccountGuardian guardianMainnet;
        AccountGuardian guardianL2;
    }

    Addresses addresses;
    Contracts contracts;

    function run(bool broadcast_) public {
        broadcast = broadcast_;
        mainnetForkId = vm.createFork("mainnet");
        l2ForkId = vm.createFork("polygon");

        runWithForkIds(broadcast_, mainnetForkId, l2ForkId);
    }

    function runWithForkIds(bool broadcast_, uint256 mainnetForkId_, uint256 l2ForkId_) public {
        broadcast = broadcast_;
        mainnetForkId = mainnetForkId_;
        l2ForkId = l2ForkId_;

        address deployer = msg.sender;
        sender = deployer;
        bytes32 deployerBytes32 = bytes32(uint256(uint160(deployer))) << 96;

        bytes32 childTunnelSalt = bytes32("CHILD_TUNN") >> 160;
        bytes32 rootTunnelSalt = bytes32("ROOT_TUNN") >> 160;
        bytes32 childTunnelSoladySalt = deployerBytes32 | childTunnelSalt;
        bytes32 rootTunnelSoladySalt = deployerBytes32 | rootTunnelSalt;

        vm.selectFork(mainnetForkId);
        address childTunnelAddress = FACTORY.predictDeterministicAddress(childTunnelSoladySalt);
        vm.label(childTunnelAddress, "CHILD_TUNNEL_PROXY");
        address rootTunnelAddress = FACTORY.predictDeterministicAddress(rootTunnelSoladySalt);
        vm.label(rootTunnelAddress, "ROOT_TUNNEL_PROXY");

        // deploy root tunnel and account implementation on mainnet
        vm.selectFork(mainnetForkId);
        // deploy root tunnel
        _broadcast();
        RemoteCallFxRootTunnel rootTunnelImpl = new RemoteCallFxRootTunnel(address(0), address(0));
        addresses.rootTunnelImpl = address(rootTunnelImpl);
        vm.label(addresses.rootTunnelImpl, "ROOT_TUNNEL_IMPL");

        _broadcast();
        addresses.rootTunnelProxy = FACTORY.deployDeterministicAndCall(
            address(rootTunnelImpl),
            deployer,
            rootTunnelSoladySalt,
            abi.encodeCall(rootTunnelImpl.initialize, (CHECKPOINT_MANAGER, FX_ROOT_MAINNET, childTunnelAddress))
        );
        assertEq(addresses.rootTunnelProxy, rootTunnelAddress, "root tunnel address not as expected");

        (
            addresses.guardianMainnet,
            addresses.accountImplMainnet,
            addresses.accountProxyMainnet,
            addresses.accountBeaconProxyMainnet
        ) = new DeployAccountImplScript(broadcast, sender).deploy(addresses.rootTunnelProxy);

        // deploy child tunnel and account implementation on l2
        vm.selectFork(l2ForkId);
        // deploy child tunnel
        _broadcast();
        RemoteCallFxChildTunnel childTunnelImpl = new RemoteCallFxChildTunnel(address(0));
        addresses.childTunnelImpl = address(childTunnelImpl);
        vm.label(addresses.childTunnelImpl, "CHILD_TUNNEL_IMPL");

        address deployer_ = deployer;
        _broadcast();
        addresses.childTunnelProxy = FACTORY.deployDeterministicAndCall(
            address(childTunnelImpl),
            deployer_,
            childTunnelSoladySalt,
            abi.encodeCall(childTunnelImpl.initialize, (FX_CHILD_POLYGON_POS, rootTunnelAddress))
        );
        assertEq(addresses.childTunnelProxy, childTunnelAddress, "child tunnel address not as expected");

        // deploy account implementation
        (addresses.guardianL2, addresses.accountImplL2, addresses.accountProxyL2, addresses.accountBeaconProxyL2) =
            new DeployAccountImplScript(broadcast, sender).deploy(addresses.childTunnelProxy);
        assertEq(
            addresses.accountProxyL2,
            addresses.accountProxyMainnet,
            "L2 account proxy address not the same as mainnet proxy address"
        );
        assertEq(
            addresses.accountBeaconProxyL2,
            addresses.accountBeaconProxyMainnet,
            "L2 account beacon proxy address not the same as mainnet beacon proxy address"
        );

        _syncContracts();

        console.log("accountBeaconProxyMainnet", addresses.accountBeaconProxyMainnet);
        console.log("accountBeaconProxyL2", addresses.accountBeaconProxyL2);
        console.log("accountProxyMainnet", addresses.accountProxyMainnet);
        console.log("accountProxyL2", addresses.accountProxyL2);
        console.log("rootTunnelProxy", addresses.rootTunnelProxy);
        console.log("childTunnelProxy", addresses.childTunnelProxy);
        console.log("accountImplMainnet", addresses.accountImplMainnet);
        console.log("accountImplL2", addresses.accountImplL2);
        console.log("rootTunnelImpl", addresses.rootTunnelImpl);
        console.log("childTunnelImpl", addresses.childTunnelImpl);
    }

    function _syncContracts() internal {
        contracts.accountBeaconProxyMainnet = Account(payable(addresses.accountBeaconProxyMainnet));
        contracts.accountBeaconProxyL2 = Account(payable(addresses.accountBeaconProxyL2));
        contracts.accountMainnetProxy = Account(payable(addresses.accountProxyMainnet));
        contracts.accountL2Proxy = Account(payable(addresses.accountProxyL2));
        contracts.rootTunnelProxy = RemoteCallFxRootTunnel(addresses.rootTunnelProxy);
        contracts.childTunnelProxy = RemoteCallFxChildTunnel(addresses.childTunnelProxy);

        contracts.accountMainnetImpl = Account(payable(addresses.accountImplMainnet));
        contracts.accountL2Impl = Account(payable(addresses.accountImplL2));
        contracts.rootTunnelImpl = RemoteCallFxRootTunnel(addresses.rootTunnelImpl);
        contracts.childTunnelImpl = RemoteCallFxChildTunnel(addresses.childTunnelImpl);
        contracts.guardianMainnet = AccountGuardian(addresses.guardianMainnet);
        contracts.guardianL2 = AccountGuardian(addresses.guardianL2);
    }
}
