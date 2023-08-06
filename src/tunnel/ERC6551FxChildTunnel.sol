pragma solidity ^0.8.20;

import { FxBaseChildTunnel } from "fx-portal/tunnel/FxBaseChildTunnel.sol";
import { ERC721 } from "solmate/tokens/ERC721.sol";
import { LibERC6551 } from "../LibERC6551.sol";
import { ERC6551FxBase } from "./ERC6551FxBase.sol";

contract ERC6551FxChildTunnel is FxBaseChildTunnel, ERC6551FxBase {
    constructor(address _fxChild) FxBaseChildTunnel(_fxChild) { }

    function initialize(address _fxChild, address _rootTunnel) external {
        require(fxRootTunnel == address(0), "fxRootTunnel already initialized");
        require(fxChild == address(0), "fxChild already initialized");
        fxRootTunnel = _rootTunnel;
        fxChild = _fxChild;
    }

    function executeRemoteCall(address account, address to, uint256 value, bytes memory data)
        external
        onlyAccountOwner(account, msg.sender)
    {
        bytes memory encodedParams = _encodeAccountParams(account);
        bytes memory encodedRemoteCalldata = abi.encode(account, to, value, data, encodedParams);
        _sendMessageToRoot(encodedRemoteCalldata);
    }

    function _processMessageFromRoot(uint256, address sender, bytes memory data)
        internal
        override
        validateSender(sender)
    {
        _executeRemoteCall(data);
    }
}
