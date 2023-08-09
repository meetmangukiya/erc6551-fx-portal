pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { DeployScript } from "script/deploy.s.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";

abstract contract BaseTest is DeployScript {
    function setUp() public virtual {
        run(false);
    }
}
