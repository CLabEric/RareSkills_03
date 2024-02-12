// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {MiniSwap} from "./MiniSwapPair.sol";

/// @title MiniSwapFactory
/// @author Eric Abt
/// @notice Creates a MiniSwap pair
/// @dev Inspired by Uniswap V2
contract MiniSwapFactory {
    mapping(address tokenA => mapping(address tokenB => address pair)) pairs;

    event PairCreated(address indexed token0, address indexed token1, address pair);

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param tokenA address of one half of the pair to create
    /// @param tokenB address of other half of the pair to create. Order does not matter
    /// @return pair address of newly created pair contract
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, "must have two different tokens");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "Pair can't include zero address");
        require(pairs[token0][token1] == address(0), "pair already exists");
        bytes memory contractCode = type(MiniSwap).creationCode;

        bytes memory byteCode = abi.encode(contractCode, tokenA, tokenB);
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(byteCode, 32), mload(byteCode), salt)
        }
        pairs[token0][token1] = pair;
        pairs[token1][token0] = pair;
        emit PairCreated(token0, token1, pair);
    }
}
