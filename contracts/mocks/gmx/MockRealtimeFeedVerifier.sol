// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;


interface IRealtimeFeedVerifier {
    function verify(bytes memory data) external returns (bytes memory);
}

contract MockRealtimeFeedVerifier is IRealtimeFeedVerifier {
    function verify(bytes memory data) external pure returns (bytes memory) {
        return data;
    }
}
