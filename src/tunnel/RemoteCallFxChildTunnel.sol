pragma solidity ^0.8.20;

import { FxBaseChildTunnel } from "fx-portal/tunnel/FxBaseChildTunnel.sol";
import { ERC721 } from "solmate/tokens/ERC721.sol";
import { Address } from "openzeppelin-contracts/contracts/utils/Address.sol";
import { ITunnel } from "../interfaces/ITunnel.sol";

contract RemoteCallFxChildTunnel is FxBaseChildTunnel, ITunnel {
    using Address for address;

    constructor(address _fxChild) FxBaseChildTunnel(_fxChild) { }

    function initialize(address _fxChild, address _rootTunnel) external {
        require(fxRootTunnel == address(0), "fxRootTunnel already initialized");
        require(fxChild == address(0), "fxChild already initialized");
        fxRootTunnel = _rootTunnel;
        fxChild = _fxChild;
    }

    function executeRemoteCall(bytes memory data) external {
        bytes memory message = abi.encode(msg.sender, data);
        _sendMessageToRoot(message);
    }

    function _processMessageFromRoot(uint256, address sender, bytes memory message)
        internal
        override
        validateSender(sender)
    {
        (address target, bytes memory data) = abi.decode(message, (address, bytes));
        target.functionCall(data);
    }
}
