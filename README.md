# erc6551-fx-portal

[`fx-portal`](https://github.com/0xPolygon/fx-portal/) tunnel implementation
that allows users to call functions on their own addresses on the remote
chains.

Also a system of scripts that deploys:

1. [tokenbound's ERC6551 account implementation](https://github.com/tokenbound/contracts/blob/main/src/Account.sol) at a determinstic UpgradeableBeacon proxy.
2. A beacon proxy pointing to the above proxy.
3. A guardian on a determinstic address that sets tunnels as trusted executors.
4. Fx root and child tunnels for remote calling.

![Execution flow chart](./execution-flow.png)
