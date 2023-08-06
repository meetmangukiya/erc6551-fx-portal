pragma solidity ^0.8.20;

import { ERC6551_REGISTRY, FX_CHILD_POLYGON_POS } from "src/constants.sol";
import { Test } from "forge-std/test.sol";
import { console } from "forge-std/console.sol";
import { ERC6551Account } from "src/ERC6551Account.sol";
import { BaseTest } from "./BaseTest.sol";
import { ERC721 } from "solmate/tokens/ERC721.sol";
import { BaseTest } from "./BaseTest.sol";
import { ERC6551FxBase } from "src/tunnel/ERC6551FxBase.sol";
import { Vm } from "forge-std/Vm.sol";
import { LibERC6551 } from "src/LibERC6551.sol";

function addr(string memory inp) pure returns (address) {
    return address(uint160(uint256(keccak256(abi.encodePacked(inp)))));
}

contract MockERC721 is ERC721("MockERC721", "MockERC721") {
    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function tokenURI(uint256) public pure override returns (string memory) {
        return "https://example.com";
    }
}

uint256 constant POLYGON_CHAIN_ID = 137;

contract ERC6551AccountTest is BaseTest {
    MockERC721 token;
    MockERC721 tokenL2;

    function setUp() public override {
        super.setUp();
        vm.selectFork(mainnetForkId);
        token = new MockERC721();
        vm.selectFork(l2ForkId);
        tokenL2 = new MockERC721();
    }

    function _assertParams(
        ERC6551Account account,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        uint256 salt,
        address accountImpl
    ) internal {
        assertEq(account.chainId(), chainId);
        assertEq(account.tokenContract(), tokenContract);
        assertEq(account.tokenId(), tokenId);
        assertEq(account.salt(), salt);
        assertEq(account.implementation(), accountImpl);
    }

    function testGetParams(uint256 _chainId, address _tokenContract, uint256 _tokenId, uint256 _salt) external {
        {
            vm.selectFork(mainnetForkId);
            address account_address = ERC6551_REGISTRY.createAccount(
                addresses.accountBeaconProxyMainnet, _chainId, _tokenContract, _tokenId, _salt, hex""
            );
            ERC6551Account account = ERC6551Account(payable(account_address));
            _assertParams(account, _chainId, _tokenContract, _tokenId, _salt, addresses.accountBeaconProxyMainnet);
        }
        {
            vm.selectFork(l2ForkId);
            address account_address2 = ERC6551_REGISTRY.createAccount(
                addresses.accountBeaconProxyL2, _chainId, _tokenContract, _tokenId, _salt, hex""
            );
            ERC6551Account account2 = ERC6551Account(payable(account_address2));
            _assertParams(account2, _chainId, _tokenContract, _tokenId, _salt, addresses.accountBeaconProxyL2);
        }
    }

    function testExecuteCallNativeToken() external {
        vm.selectFork(mainnetForkId);
        address fxTunnel = address(0xb41d6e);
        ERC6551Account accountImpl = new ERC6551Account(fxTunnel);
        uint256 chainId = block.chainid;
        uint256 tokenId = 1;
        uint256 salt = 1;
        address account_address =
            ERC6551_REGISTRY.createAccount(address(accountImpl), chainId, address(token), tokenId, salt, hex"");
        ERC6551Account account = ERC6551Account(payable(account_address));

        // mint account bound token
        token.mint(address(this), 1);

        address target = addr("target");
        uint256 value = 0;
        bytes memory data = hex"1234";

        // called as expected
        vm.expectCall(target, value, data);
        account.executeCall(target, value, data);

        // owner shouldn't be able to call
        address other = addr("other");
        vm.prank(other);
        vm.expectRevert(ERC6551Account.OnlyOwner.selector);
        account.executeCall(target, value, data);

        // transfer the nft to other
        token.safeTransferFrom(address(this), other, tokenId);
        // calls should fail from previous owner now
        vm.expectRevert(ERC6551Account.OnlyOwner.selector);
        account.executeCall(target, value, data);

        // call should succeed from new owner
        vm.prank(other);
        vm.expectCall(target, value, data);
        account.executeCall(target, value, data);
    }

    function testExecuteCallRemoteToken() external {
        vm.selectFork(mainnetForkId);
        address fxTunnel = address(0xb41d6e);
        ERC6551Account accountImpl = new ERC6551Account(fxTunnel);
        uint256 chainId = POLYGON_CHAIN_ID;
        uint256 tokenId = 1;
        uint256 salt = 1;
        address account_address =
            ERC6551_REGISTRY.createAccount(address(accountImpl), chainId, address(token), tokenId, salt, hex"");
        ERC6551Account account = ERC6551Account(payable(account_address));

        // mint account bound token
        token.mint(address(this), 1);

        address owner = account.owner();
        assertEq(owner, fxTunnel, "owner should be the tunnel for remote nft accounts");

        vm.expectRevert(ERC6551Account.OnlyOwner.selector);
        account.executeCall(addr("target"), 0, hex"");
    }

    function testExecuteRemoteCallL1NativeToken() external {
        vm.selectFork(mainnetForkId);
        uint256 chainId = 1;
        uint256 tokenId = 1;
        uint256 salt = 1;
        address account_address = ERC6551_REGISTRY.createAccount(
            addresses.accountBeaconProxyMainnet, chainId, address(token), tokenId, salt, hex""
        );
        ERC6551Account account = ERC6551Account(payable(account_address));

        // mint account bound token
        token.mint(address(this), 1);

        address target = addr("target");
        uint256 value = 0;
        bytes memory data = hex"1234";
        vm.expectCall(target, value, data);
        account.executeCall(target, value, data);

        address other = addr("other");
        vm.prank(other);
        vm.expectRevert(ERC6551FxBase.OnlyAccountOwner.selector);
        contracts.rootTunnelProxy.executeRemoteCall(account_address, target, value, data);

        vm.recordLogs();
        contracts.rootTunnelProxy.executeRemoteCall(account_address, target, value, data);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1, "should emit 1 log");
        bytes memory logData = logs[0].data;
        bytes memory rawBytes = abi.decode(logData, (bytes));
        (,, bytes memory messageData) = abi.decode(rawBytes, (address, address, bytes));

        // switch to L2
        vm.selectFork(l2ForkId);

        assertEq(address(account).code.length, 0, "account shouldnt exist on L2 yet");
        vm.expectCall(target, value, hex"1234");
        vm.prank(FX_CHILD_POLYGON_POS);
        contracts.childTunnelProxy.processMessageFromRoot(0, addresses.rootTunnelProxy, messageData);
        assertGt(address(account).code.length, 0, "account should be created if didnt exist");

        assertEq(account.owner(), addresses.childTunnelProxy, "account owner should be the tunnel on L2");
    }

    function testExecuteRemoteCallL2NativeToken() external {
        vm.selectFork(l2ForkId);
        uint256 chainId = block.chainid;
        uint256 tokenId = 1;
        uint256 salt = 1;
        address account_address = ERC6551_REGISTRY.createAccount(
            addresses.accountBeaconProxyL2, chainId, address(tokenL2), tokenId, salt, hex""
        );

        // mint account bound token
        tokenL2.mint(address(this), 1);

        ERC6551Account account = ERC6551Account(payable(account_address));

        address target = addr("target");
        uint256 value = 0;
        bytes memory data = hex"1234";
        vm.expectCall(target, value, data);
        account.executeCall(target, value, data);

        address other = addr("other");
        vm.prank(other);
        vm.expectRevert(ERC6551Account.OnlyOwner.selector);
        account.executeCall(target, value, data);

        // cant test receiveMessage on root tunnel easily because it requires proof
    }
}
