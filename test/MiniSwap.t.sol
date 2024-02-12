// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MiniSwap} from "../src/MiniSwapPair.sol";
import {MiniSwapFactory} from "../src/MiniSwapFactory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "lib/solady/src/utils/FixedPointMathLib.sol";
import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";

contract MiniSwapTest is Test, IERC3156FlashBorrower {
    MiniSwapFactory public miniSwapFactory;

    address wethAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
    address shibAddress = 0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE; // SHIB
    address wethHolder = 0xB05ED5d7b4F7f26a73561732D5bd64C38f9076Bd;
    address shibHolder = 0x46533f26Eb4080e2050e3f8a3014aedf7B5FDb12;
    address internal user1;
    address internal user2;

    uint256 immutable WETH_AMOUNT = 5;
    uint256 immutable SHIB_AMOUNT = 5000000;

    MiniSwap pair;

    function setUp() public {
        user1 = address(3);
        user2 = address(4);

        miniSwapFactory = new MiniSwapFactory();

        pair = new MiniSwap(wethAddress, shibAddress);

        vm.label(user1, "User1");
        vm.label(user2, "User2");
    }

    function getSomeTokens() internal {
        vm.prank(wethHolder);
        IERC20(wethAddress).transfer(user1, WETH_AMOUNT);
        vm.prank(shibHolder);
        IERC20(shibAddress).transfer(user1, SHIB_AMOUNT);
    }

    function provideLiquidity() internal {
        getSomeTokens();
        vm.prank(user1);
        IERC20(wethAddress).approve(address(pair), WETH_AMOUNT);
        vm.prank(user1);
        IERC20(shibAddress).approve(address(pair), SHIB_AMOUNT);
        pair.mint(user1, WETH_AMOUNT, SHIB_AMOUNT);
    }

    function testCreatePair() public {}

    function testMint() public {
        getSomeTokens();

        uint256 balanceWeth = IERC20(wethAddress).balanceOf(user1);
        uint256 balanceShib = IERC20(shibAddress).balanceOf(user1);

        assertEq(balanceWeth, WETH_AMOUNT);
        assertEq(balanceShib, SHIB_AMOUNT);

        vm.prank(user1);
        IERC20(wethAddress).approve(address(pair), WETH_AMOUNT);
        vm.prank(user1);
        IERC20(shibAddress).approve(address(pair), SHIB_AMOUNT);

        uint256 liquidity = pair.mint(user1, WETH_AMOUNT, SHIB_AMOUNT);
        assertEq(liquidity, FixedPointMathLib.sqrt(WETH_AMOUNT * SHIB_AMOUNT));
    }

    function testBurn() public {
        provideLiquidity();

        assertGt(pair.balanceOf(user1), 0);
        vm.prank(user1);
        pair.burn();
        assertEq(pair.balanceOf(user1), 0);
    }

    function testSwap() public {
        provideLiquidity();

        // User2 gets some weth and performs a swap
        vm.prank(wethHolder);
        IERC20(wethAddress).transfer(user2, WETH_AMOUNT);
        assertEq(IERC20(wethAddress).balanceOf(user2), WETH_AMOUNT);
        assertEq(IERC20(shibAddress).balanceOf(user2), 0);
        vm.prank(user2);
        IERC20(wethAddress).approve(address(pair), WETH_AMOUNT);

        pair.swap(user2, wethAddress, WETH_AMOUNT, 0);

        // User2's balances are now swapped
        uint256 u2ShibBal = IERC20(shibAddress).balanceOf(user2);
        assertEq(IERC20(wethAddress).balanceOf(user2), 0);
        assertGt(u2ShibBal, 0);
    }

    function testFlashLoan() public {
        provideLiquidity();

        bool flSuccess = pair.flashLoan(this, shibAddress, 1000000, "");
        assertEq(flSuccess, true);
    }

    function onFlashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes calldata data)
        external
        returns (bytes32)
    {
        initiator;
        token;
        fee;
        data;
        // Do stuff with loaned SHIB and allow pair to take it back
        IERC20(shibAddress).approve(address(pair), amount);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}
