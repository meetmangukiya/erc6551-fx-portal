import { BaseTest } from "./BaseTest.sol";
import { FX_ROOT_MAINNET, FX_CHILD_POLYGON_POS } from "src/constants.sol";

interface IFxRoot {
    function stateSender() external view returns (address);
}

interface IStateSender {
    function counter() external view returns (uint256);
}

contract TunnelTest is BaseTest {
    event StateSynced(uint256 indexed, address indexed, bytes);
    event MessageSent(bytes);

    function testExecuteRemoteCallRootTunnel() external {
        vm.selectFork(mainnetForkId);
        bytes memory remoteCalldata = hex"0123456789";
        bytes memory remoteMessage = abi.encode(address(this), remoteCalldata);

        address emitter = IFxRoot(FX_ROOT_MAINNET).stateSender();
        uint256 nextId = IStateSender(emitter).counter() + 1;
        address receiver = addresses.childTunnelProxy;
        address sender = addresses.rootTunnelProxy;
        bytes memory message = abi.encode(sender, receiver, remoteMessage);

        vm.expectEmit(emitter);
        emit StateSynced(nextId, FX_CHILD_POLYGON_POS, message);
        contracts.rootTunnelProxy.executeRemoteCall(remoteCalldata);
    }

    function testExecuteRemoteCallChildTunnel() external {
        vm.selectFork(l2ForkId);
        bytes memory remoteCalldata = hex"0123456789";
        bytes memory remoteMessage = abi.encode(address(this), remoteCalldata);

        vm.expectEmit(addresses.childTunnelProxy);
        emit MessageSent(remoteMessage);
        contracts.childTunnelProxy.executeRemoteCall(remoteCalldata);
    }
}
