pragma solidity ^0.8.20;

import { CommonBase } from "forge-std/Base.sol";

contract BaseScript is CommonBase {
    bool broadcast;
    address sender;

    function _broadcast() internal {
        if (broadcast) {
            vm.broadcast();
        } else {
            vm.prank(sender);
        }
    }

    modifier withBroadcast(bool __broadcast, address _sender) {
        broadcast = __broadcast;
        sender = _sender;
        _;
    }
}
