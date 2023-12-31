pragma solidity ^0.8.20;

import { IERC6551Registry } from "./interfaces/IERC6551Registry.sol";

IERC6551Registry constant ERC6551_REGISTRY = IERC6551Registry(0x02101dfB77FDE026414827Fdc604ddAF224F0921);

address constant FX_ROOT_GOERLI = 0x3d1d3E34f7fB6D26245E6640E1c50710eFFf15bA;
address constant FX_CHILD_MUMBAI = 0xCf73231F28B7331BBe3124B907840A94851f9f11;
address constant FX_ROOT_MAINNET = 0xfe5e5D361b2ad62c541bAb87C45a0B9B018389a2;
address constant FX_CHILD_POLYGON_POS = 0x8397259c983751DAf40400790063935a11afa28a;
address constant CHECKPOINT_MANAGER = 0x86E4Dc95c7FBdBf52e33D563BbDB00823894C287;
address constant ACCOUNT_ABSTRACTION_ENTRYPOINT = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
