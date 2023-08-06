pragma solidity ^0.8.20;

/**
 *  @dev ERC6551 accounts are proxies with the following code layout:
 *  ERC-1167 Header               (10 bytes)
 *  <implementation (address)>    (20 bytes)
 *  ERC-1167 Footer               (15 bytes)
 *  <salt (uint256)>              (32 bytes)
 *  <chainId (uint256)>           (32 bytes)
 *  <tokenContract (address)>     (32 bytes)
 *  <tokenId (uint256)>           (32 bytes)
 *  This library provides helpers to read the same.
 */
library LibERC6551 {
    error InvalidAccount();
    error EmptyAccount();

    uint256 internal constant _IMPLEMENTATION_OFFSET = 10;
    uint256 internal constant _SALT_OFFSET = 45;
    uint256 internal constant _CHAIN_ID_OFFSET = 77; // _SALT_OFFSET + 32
    uint256 internal constant _TOKEN_CONTRACT_OFFSET = 109; // _CHAIN_ID_OFFSET + 32
    uint256 internal constant _TOKEN_ID_OFFSET = 141; // _TOKEN_CONTRACT_OFFSET + 32
    uint256 internal constant _ACCOUNT_SIZE = 173;

    modifier validateAccountSize(address _account) {
        if (_account.code.length != _ACCOUNT_SIZE) {
            revert EmptyAccount();
        }
        _;
    }

    function salt(address _account) internal view validateAccountSize(_account) returns (uint256 _salt) {
        assembly ("memory-safe") {
            extcodecopy(_account, 0x00, _SALT_OFFSET, 32)
            _salt := mload(0x00)
        }
    }

    function chainId(address _account) internal view validateAccountSize(_account) returns (uint256 _chainId) {
        assembly ("memory-safe") {
            extcodecopy(_account, 0x00, _CHAIN_ID_OFFSET, 32)
            _chainId := mload(0x00)
        }
    }

    function tokenContract(address _account)
        internal
        view
        validateAccountSize(_account)
        returns (address _tokenContract)
    {
        assembly ("memory-safe") {
            extcodecopy(_account, 0x00, _TOKEN_CONTRACT_OFFSET, 32)
            _tokenContract := mload(0x00)
        }
    }

    function tokenId(address _account) internal view validateAccountSize(_account) returns (uint256 _tokenId) {
        assembly ("memory-safe") {
            extcodecopy(_account, 0x00, _TOKEN_ID_OFFSET, 32)
            _tokenId := mload(0x00)
        }
    }

    function implementation(address _account)
        internal
        view
        validateAccountSize(_account)
        returns (address _implementation)
    {
        assembly ("memory-safe") {
            extcodecopy(_account, 12, _IMPLEMENTATION_OFFSET, 20)
            _implementation := mload(0x00)
        }
    }
}
