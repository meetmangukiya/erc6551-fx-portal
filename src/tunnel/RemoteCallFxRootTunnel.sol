pragma solidity ^0.8.20;

import { FxBaseRootTunnel, ICheckpointManager, IFxStateSender } from "fx-portal/tunnel/FxBaseRootTunnel.sol";
import { Address } from "openzeppelin-contracts/contracts/utils/Address.sol";
import { ITunnel } from "../interfaces/ITunnel.sol";

contract RemoteCallFxRootTunnel is FxBaseRootTunnel {
    using Address for address;

    constructor(address _checkpointManager, address _fxRoot) FxBaseRootTunnel(_checkpointManager, _fxRoot) { }

    function initialize(address _checkpointManager, address _fxRoot, address _fxChildTunnel) external {
        require(address(checkpointManager) == address(0), "checkpointManager already initialized");
        require(address(fxRoot) == address(0), "fxRoot already initialized");
        require(fxChildTunnel == address(0), "fxChildTunnel already initialized");
        fxRoot = IFxStateSender(_fxRoot);
        checkpointManager = ICheckpointManager(_checkpointManager);
        fxChildTunnel = _fxChildTunnel;
    }

    function executeRemoteCall(bytes memory data) external {
        bytes memory message = abi.encode(msg.sender, data);
        _sendMessageToChild(message);
    }

    function _processMessageFromChild(bytes memory message) internal override {
        (address target, bytes memory data) = abi.decode(message, (address, bytes));
        target.functionCall(data);
    }
}
