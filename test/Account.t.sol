pragma solidity ^0.8.20;

import { ERC6551_REGISTRY, FX_CHILD_POLYGON_POS } from "src/constants.sol";
import { console } from "forge-std/console.sol";
import { Account, NotAuthorized } from "tokenbound-contracts/src/Account.sol";
import { BaseTest } from "./BaseTest.sol";
import { ERC721 } from "solmate/tokens/ERC721.sol";
import { BaseTest } from "./BaseTest.sol";
import { Vm } from "forge-std/Vm.sol";
import { RemoteCallFxChildTunnel } from "src/tunnel/RemoteCallFxChildTunnel.sol";

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

contract AccountTest is BaseTest {
    MockERC721 token;
    MockERC721 tokenL2;
    Account accountMainnetNative;
    Account accountL2Remote;

    Account accountMainnetRemote;
    Account accountL2Native;
    uint256 tokenId = 1;
    uint256 salt = 1;

    function setUp() public override {
        super.setUp();
        vm.selectFork(mainnetForkId);
        token = new MockERC721();
        accountMainnetNative = Account(
            payable(
                ERC6551_REGISTRY.createAccount(
                    addresses.accountBeaconProxyMainnet, 1, address(token), tokenId, salt, hex""
                )
            )
        );
        vm.selectFork(l2ForkId);
        accountL2Remote = Account(
            payable(
                ERC6551_REGISTRY.createAccount(addresses.accountBeaconProxyL2, 1, address(token), tokenId, salt, hex"")
            )
        );
        assertEq(address(accountMainnetNative), address(accountL2Remote), "account addresses should be same");

        vm.selectFork(l2ForkId);
        tokenL2 = new MockERC721();
        accountL2Native = Account(
            payable(
                ERC6551_REGISTRY.createAccount(
                    addresses.accountBeaconProxyL2, block.chainid, address(tokenL2), 1, 1, hex""
                )
            )
        );
        vm.selectFork(mainnetForkId);
        accountMainnetRemote = Account(
            payable(
                ERC6551_REGISTRY.createAccount(
                    addresses.accountBeaconProxyMainnet, POLYGON_CHAIN_ID, address(tokenL2), 1, 1, hex""
                )
            )
        );
        assertEq(address(accountL2Native), address(accountMainnetRemote), "account addresses should be same");
    }

    function testExecuteCallNativeToken() external {
        vm.selectFork(mainnetForkId);
        // mint account bound token
        token.mint(address(this), 1);

        address target = addr("target");
        uint256 value = 0;
        bytes memory data = hex"1234";

        // called as expected
        vm.expectCall(target, value, data);
        accountMainnetNative.execute(target, value, data, 0);

        // other shouldn't be able to call
        address other = addr("other");
        vm.prank(other);
        vm.expectRevert(NotAuthorized.selector);
        accountMainnetNative.execute(target, value, data, 0);

        // transfer the nft to other
        token.safeTransferFrom(address(this), other, tokenId);
        // calls should fail from previous owner now
        vm.expectRevert(NotAuthorized.selector);
        accountMainnetNative.execute(target, value, data, 0);

        // call should succeed from new owner
        vm.prank(other);
        vm.expectCall(target, value, data);
        accountMainnetNative.execute(target, value, data, 0);
    }

    function testExecuteCallRemoteToken() external {
        vm.selectFork(mainnetForkId);

        address owner = accountMainnetRemote.owner();
        assertEq(owner, address(0), "owner should be the tunnel for remote nft accounts");

        vm.expectRevert(NotAuthorized.selector);
        accountMainnetRemote.execute(addr("target"), 0, hex"", 0);

        // call should pass from tunnel
        vm.prank(addresses.rootTunnelProxy);
        vm.expectCall(addr("target"), 0, hex"");
        accountMainnetRemote.execute(addr("target"), 0, hex"", 0);
    }

    function testExecuteRemoteCallL1NativeToken() external {
        vm.selectFork(mainnetForkId);
        // mint account bound token
        token.mint(address(this), 1);

        address target = addr("target");
        uint256 value = 0;
        bytes memory data = hex"1234";
        vm.expectCall(target, value, data);
        accountMainnetNative.execute(target, value, data, 0);

        address other = addr("other");
        vm.prank(other);
        vm.expectRevert(NotAuthorized.selector);
        accountMainnetNative.execute(target, value, data, 0);

        vm.recordLogs();
        accountMainnetNative.execute(addresses.rootTunnelProxy, 0, _getTunnelCalldata(target, value, data), 0);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1, "should emit 1 log");
        bytes memory logData = logs[0].data;
        bytes memory rawBytes = abi.decode(logData, (bytes));
        (,, bytes memory messageData) = abi.decode(rawBytes, (address, address, bytes));

        // switch to L2
        vm.selectFork(l2ForkId);

        vm.expectCall(address(accountL2Remote), abi.encodeCall(Account.execute, (target, value, data, 0)));
        vm.expectCall(target, value, data);
        vm.prank(FX_CHILD_POLYGON_POS);
        contracts.childTunnelProxy.processMessageFromRoot(0, addresses.rootTunnelProxy, messageData);

        assertEq(accountL2Remote.owner(), address(0), "account owner should be the tunnel on L2");
    }

    function testExecuteRemoteCallL2NativeToken() external {
        vm.selectFork(l2ForkId);
        // mint account bound token
        tokenL2.mint(address(this), 1);

        address target = addr("target");
        uint256 value = 0;
        bytes memory data = hex"1234";
        vm.expectCall(target, value, data);
        accountL2Native.execute(target, value, data, 0);

        address other = addr("other");
        vm.prank(other);
        vm.expectRevert(NotAuthorized.selector);
        accountL2Native.execute(target, value, data, 0);

        // cant test receiveMessage on root tunnel easily because it requires proof
    }

    function _getExecuteCalldata(address target, uint256 value, bytes memory data)
        internal
        pure
        returns (bytes memory _cd)
    {
        _cd = abi.encodeCall(Account.execute, (target, value, data, 0));
    }

    function _getTunnelCalldata(address target, uint256 value, bytes memory data)
        internal
        pure
        returns (bytes memory _cd)
    {
        bytes memory remoteCd = _getExecuteCalldata(target, value, data);
        _cd = abi.encodeCall(RemoteCallFxChildTunnel.executeRemoteCall, (remoteCd));
    }
}
