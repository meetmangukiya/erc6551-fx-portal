pragma solidity ^0.8.20;

interface ITunnel {
    function executeRemoteCall(bytes memory data) external;
}
