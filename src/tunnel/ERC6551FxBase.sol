pragma solidity ^0.8.20;

import { ERC6551_REGISTRY } from "../constants.sol";
import { IERC6551Account } from "../interfaces/IERC6551Account.sol";
import { LibERC6551 } from "../LibERC6551.sol";
import { ERC721 } from "solmate/tokens/ERC721.sol";

abstract contract ERC6551FxBase {
    error IncorrectParams();
    error OnlyRemoteChain();
    error OnlyNativeChain();
    error OnlyAccountOwner();

    function _executeRemoteCall(bytes memory _message) internal {
        (address account, address to, uint256 value, bytes memory data, bytes memory encodedParams) =
            abi.decode(_message, (address, address, uint256, bytes, bytes));

        // if account does not exist, deploy it, assumes same implementation address on
        // all networks
        if (account.code.length == 0) {
            (address implementation, uint256 chainId, address tokenContract, uint256 tokenId, uint256 salt) =
                _decodeAccountParams(encodedParams);
            address createdAccount =
                ERC6551_REGISTRY.createAccount(implementation, chainId, tokenContract, tokenId, salt, hex"");
            if (createdAccount != account) {
                revert IncorrectParams();
            }
        }

        _onlyRemoteChain(account);

        // execute the call
        IERC6551Account(payable(account)).executeCall(to, value, data);
    }

    function _encodeAccountParams(address _account) internal view returns (bytes memory _ret) {
        uint256 chainId = LibERC6551.chainId(_account);
        address tokenContract = LibERC6551.tokenContract(_account);
        uint256 tokenId = LibERC6551.tokenId(_account);
        uint256 salt = LibERC6551.salt(_account);
        address implementation = LibERC6551.implementation(_account);
        _ret = abi.encode(implementation, chainId, tokenContract, tokenId, salt);
    }

    function _decodeAccountParams(bytes memory _data)
        internal
        pure
        returns (address _implementation, uint256 _chainId, address _tokenContract, uint256 _tokenId, uint256 _salt)
    {
        (_implementation, _chainId, _tokenContract, _tokenId, _salt) =
            abi.decode(_data, (address, uint256, address, uint256, uint256));
    }

    modifier onlyAccountOwner(address _account, address _sender) {
        _onlyNativeChain(_account);
        ERC721 token = ERC721(LibERC6551.tokenContract(_account));
        uint256 tokenId = LibERC6551.tokenId(_account);
        uint256 networkId = LibERC6551.chainId(_account);
        address owner = token.ownerOf(tokenId);
        if (owner != _sender) revert OnlyAccountOwner();
        _;
    }

    function _onlyRemoteChain(address _account) internal view {
        uint256 networkId = LibERC6551.chainId(_account);
        if (networkId == block.chainid) revert OnlyRemoteChain();
    }

    function _onlyNativeChain(address _account) internal view {
        uint256 networkId = LibERC6551.chainId(_account);
        if (networkId != block.chainid) revert OnlyNativeChain();
    }
}
