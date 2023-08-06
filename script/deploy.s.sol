pragma solidity ^0.8.20;
import { StdAssertions } from "forge-std/StdAssertions.sol";
import { Test } from "forge-std/Test.sol";
import { ERC1967Factory } from "solady/utils/ERC1967Factory.sol";
import { ERC1967FactoryConstants } from "solady/utils/ERC1967FactoryConstants.sol";
import { ERC6551FxChildTunnel } from "src/tunnel/ERC6551FxChildTunnel.sol";
import { ERC6551FxRootTunnel } from "src/tunnel/ERC6551FxRootTunnel.sol";
import { ERC6551Account } from "src/ERC6551Account.sol";
import { FX_ROOT_MAINNET, FX_CHILD_POLYGON_POS, CHECKPOINT_MANAGER } from "src/constants.sol";
import { BeaconProxy } from "openzeppelin-contracts/contracts/proxy/beacon/BeaconProxy.sol";
import { UpgradeableBeacon } from "openzeppelin-contracts/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { BaseScript } from "./BaseScript.sol";
import { DeployAccountImplScript } from "./DeployAccountImpl.s.sol";
import { console } from "forge-std/console.sol";

ERC1967Factory constant FACTORY = ERC1967Factory(ERC1967FactoryConstants.ADDRESS);

contract DeployScript is Test, BaseScript {
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
    }

    struct Contracts {
        ERC6551Account accountBeaconProxyMainnet;
        ERC6551Account accountBeaconProxyL2;
        ERC6551Account accountMainnetProxy;
        ERC6551Account accountL2Proxy;
        ERC6551FxRootTunnel rootTunnelProxy;
        ERC6551FxChildTunnel childTunnelProxy;
        ERC6551Account accountMainnetImpl;
        ERC6551Account accountL2Impl;
        ERC6551FxRootTunnel rootTunnelImpl;
        ERC6551FxChildTunnel childTunnelImpl;
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
        ERC6551FxRootTunnel rootTunnelImpl = new ERC6551FxRootTunnel(address(0), address(0));
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

        (addresses.accountImplMainnet, addresses.accountProxyMainnet, addresses.accountBeaconProxyMainnet) =
            new DeployAccountImplScript(broadcast, sender).deploy(addresses.rootTunnelProxy);

        // deploy child tunnel and account implementation on l2
        vm.selectFork(l2ForkId);
        // deploy child tunnel
        _broadcast();
        ERC6551FxChildTunnel childTunnelImpl = new ERC6551FxChildTunnel(address(0));
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
        (addresses.accountImplL2, addresses.accountProxyL2, addresses.accountBeaconProxyL2) =
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
        contracts.accountBeaconProxyMainnet = ERC6551Account(payable(addresses.accountBeaconProxyMainnet));
        contracts.accountBeaconProxyL2 = ERC6551Account(payable(addresses.accountBeaconProxyL2));
        contracts.accountMainnetProxy = ERC6551Account(payable(addresses.accountProxyMainnet));
        contracts.accountL2Proxy = ERC6551Account(payable(addresses.accountProxyL2));
        contracts.rootTunnelProxy = ERC6551FxRootTunnel(addresses.rootTunnelProxy);
        contracts.childTunnelProxy = ERC6551FxChildTunnel(addresses.childTunnelProxy);

        contracts.accountMainnetImpl = ERC6551Account(payable(addresses.accountImplMainnet));
        contracts.accountL2Impl = ERC6551Account(payable(addresses.accountImplL2));
        contracts.rootTunnelImpl = ERC6551FxRootTunnel(addresses.rootTunnelImpl);
        contracts.childTunnelImpl = ERC6551FxChildTunnel(addresses.childTunnelImpl);
    }
}
