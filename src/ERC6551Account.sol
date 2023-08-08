pragma solidity ^0.8.20;

import { IERC6551Account } from "./interfaces/IERC6551Account.sol";
import { IERC721 } from "./interfaces/IERC721.sol";
import { LibERC6551 } from "./LibERC6551.sol";
import { ITunnel } from "./interfaces/ITunnel.sol";

contract ERC6551Account is IERC6551Account {
    error NotInited();
    error OnlyOwner();
    error OnlyBridge();
    error OnlyDelegateCall();

    address immutable self;
    address immutable tunnel;
    uint256 internal _nonce;

    constructor(address _tunnel) {
        self = address(this);
        tunnel = _tunnel;
    }

    /// @inheritdoc IERC6551Account
    receive() external payable onlyDelegateCall { }

    /// @inheritdoc IERC6551Account
    function executeCall(address to, uint256 value, bytes calldata data)
        external
        payable
        onlyOwner
        onlyDelegateCall
        returns (bytes memory ret)
    {
        bool success;
        (success, ret) = to.call{ value: value }(data);
        if (!success) {
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }
        _nonce++;
    }

    function executeRemoteCall(address to, uint256 value, bytes calldata data) external onlyOwner onlyDelegateCall {
        bytes memory cd = abi.encodeCall(this.executeCall, (to, value, data));
        ITunnel(tunnel).executeRemoteCall(cd);
    }

    /**
     * @notice Handles ERC1155 Token batch callback.
     * return Standardized onERC1155BatchReceived return value.
     */
    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return 0xbc197c81;
    }

    /**
     * @notice Handles ERC721 Token callback.
     *  return Standardized onERC721Received return value.
     */
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return 0x150b7a02;
    }

    /// @inheritdoc IERC6551Account
    function token() external view onlyDelegateCall returns (uint256, address, uint256) {
        return (chainId(), tokenContract(), tokenId());
    }

    /// @inheritdoc IERC6551Account
    function nonce() external view onlyDelegateCall returns (uint256) {
        return _nonce;
    }

    /// @inheritdoc IERC6551Account
    function owner() public view onlyDelegateCall returns (address) {
        if (chainId() == block.chainid) {
            return IERC721(tokenContract()).ownerOf(tokenId());
        } else {
            return tunnel;
        }
    }

    // -----------------------------------------------------------------------
    //                 Views for data stored into contract code
    // -----------------------------------------------------------------------
    function salt() public view onlyDelegateCall returns (uint256 _salt) {
        _salt = LibERC6551.salt(address(this));
    }

    function chainId() public view onlyDelegateCall returns (uint256 _chainId) {
        _chainId = LibERC6551.chainId(address(this));
    }

    function tokenContract() public view onlyDelegateCall returns (address _tokenContract) {
        _tokenContract = LibERC6551.tokenContract(address(this));
    }

    function tokenId() public view onlyDelegateCall returns (uint256 _tokenId) {
        _tokenId = LibERC6551.tokenId(address(this));
    }

    function implementation() public view onlyDelegateCall returns (address _implementation) {
        _implementation = LibERC6551.implementation(address(this));
    }

    modifier onlyDelegateCall() {
        if (self == address(this)) revert OnlyDelegateCall();
        _;
    }

    modifier onlyOwner() {
        if (owner() != msg.sender) revert OnlyOwner();
        _;
    }
}
