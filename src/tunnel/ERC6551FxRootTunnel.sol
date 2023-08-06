pragma solidity ^0.8.20;

import { FxBaseRootTunnel, ICheckpointManager, IFxStateSender } from "fx-portal/tunnel/FxBaseRootTunnel.sol";
import { ERC6551FxBase } from "./ERC6551FxBase.sol";

contract ERC6551FxRootTunnel is FxBaseRootTunnel, ERC6551FxBase {
    constructor(address _checkpointManager, address _fxRoot) FxBaseRootTunnel(_checkpointManager, _fxRoot) { }

    function initialize(address _checkpointManager, address _fxRoot, address _fxChildTunnel) external {
        require(address(checkpointManager) == address(0), "checkpointManager already initialized");
        require(address(fxRoot) == address(0), "fxRoot already initialized");
        require(fxChildTunnel == address(0), "fxChildTunnel already initialized");
        fxRoot = IFxStateSender(_fxRoot);
        checkpointManager = ICheckpointManager(_checkpointManager);
        fxChildTunnel = _fxChildTunnel;
    }

    function executeRemoteCall(address account, address to, uint256 value, bytes memory data)
        external
        onlyAccountOwner(account, msg.sender)
    {
        bytes memory encodedParams = _encodeAccountParams(account);
        bytes memory encodedRemoteCalldata = abi.encode(account, to, value, data, encodedParams);
        _sendMessageToChild(encodedRemoteCalldata);
    }

    function _processMessageFromChild(bytes memory data) internal override {
        _executeRemoteCall(data);
    }
}
