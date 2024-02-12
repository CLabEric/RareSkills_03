// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20} from "lib/solady/src/tokens/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC3156FlashLender} from "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "lib/solady/src/utils/FixedPointMathLib.sol";
import "forge-std/console.sol";

/// @title MiniSwap
/// @author Eric Abt
/// @notice Light version of Uniswap V2
/// @dev Inspired by Uniswap V2
contract MiniSwap is ERC20, IERC3156FlashLender {
    address token0;
    address token1;

    uint256 fee;
    uint public constant MINIMUM_LIQUIDITY = 10**3;

    string _name = "MiniSwap";
    string _symbol = "MS";

    bytes32 private constant FLASH_LOAN_CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }

    /// @notice Returns the name of the token.
    function name() public view override returns (string memory) {
        return _name;
    }

    /// @notice Returns the symbol of the token.
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /* ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ */
    /*                                        STANDARD PAIR FUNCTIONS                                             */
    /* ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ */

    /// @notice user decides how much of what token to put in and they get back what they get back
    /// @dev Enforces a liquidity ratio of x*y = k
    /// @param trader address of entity sending and receiving token
    /// @param _in address of token to be sent
    /// @param _amountIn how much of _in token the trader wishes to send
    /// @param _minAmountOut slippage protection. Trader must calculate offline what amount is acceptable
    function swap(address trader, address _in, uint256 _amountIn, uint256 _minAmountOut) external {
        require(trader != address(0) && trader != address(this), "not a valid trader");

        uint256 balanceIn = IERC20(_in).balanceOf(address(this));
        address outToken = token0 == _in ? token1 : token0;
        uint256 balanceOut = IERC20(outToken).balanceOf(address(this));
        uint256 k = balanceIn * balanceOut;
        uint256 amountOut = k / (balanceIn + _amountIn);

        require(amountOut < balanceOut, "not enough liquidity to cover this trade");
        IERC20(_in).transferFrom(trader, address(this), _amountIn);
        require(amountOut >= _minAmountOut);
        IERC20(outToken).transfer(trader, amountOut);
    }

    /// @notice Liquidity providers call this function to. They must first approve this pair for each token+sum
    /// @param depositor address of user depositing liquidity
    /// @param amount0 amount of token0 to deposit
    /// @param amount1 amount of token1 to deposit
    /// @return liquidity uint256 amount of liquidity tokens minted to depositor
    function mint(address depositor, uint256 amount0, uint256 amount1) external returns (uint256 liquidity) {
        require(depositor != address(0) && depositor != address(this), "not a valid depositor");

        uint256 reserve0 = IERC20(token0).balanceOf(address(this));
        uint256 reserve1 = IERC20(token1).balanceOf(address(this));

        if (reserve0 == 0 && reserve1 == 0) {
            IERC20(token0).transferFrom(depositor, address(this), amount0);
            IERC20(token1).transferFrom(depositor, address(this), amount1);
            liquidity = FixedPointMathLib.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            uint256 _totalSupply = totalSupply();
            liquidity = FixedPointMathLib.min((amount0 * _totalSupply) / reserve0, (amount1 * _totalSupply) / reserve1);
        }

        _mint(depositor, liquidity);
    }

    /// @notice Remove liquidity
    function burn() external {
        uint256 liquidity = balanceOf(msg.sender);
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        uint256 _totalSupply = totalSupply();
        uint256 amount0 = (liquidity * balance0) / _totalSupply;
        uint256 amount1 = (liquidity * balance1) / _totalSupply;

        _burn(msg.sender, liquidity);
        IERC20(token0).transfer(msg.sender, amount0);
        IERC20(token1).transfer(msg.sender, amount1);
    }

    /* ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ */
    /*                                   IERC3156 FLASH LOAN LENDER IMPLEMENTATION                                */
    /* ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ */

    /// @notice The amount of currency available to be lended.
    /// @param token The loan currency.
    /// @return The amount of `token` that can be borrowed.
    function maxFlashLoan(address token) public view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    /// @notice The fee to be charged for a given loan
    /// @param token The loan currency.
    /// @param amount The amount of tokens lent.
    /// @return The amount of `token` to be charged for the loan, on top of the returned principal.
    function flashFee(address token, uint256 amount) public view returns (uint256) {
        token;
        amount;
        return fee;
    }

    /// @notice Initiate a flash loan.
    /// @param receiver The receiver of the tokens in the loan, and the receiver of the callback.
    /// @param token The loan currency.
    /// @param amount The amount of tokens lent.
    /// @param data Arbitrary data structure, intended to contain user-defined parameters.
    function flashLoan(IERC3156FlashBorrower receiver, address token, uint256 amount, bytes calldata data)
        external
        returns (bool)
    {
        require(token == token0 || token == token1, "unsupported token");
        require(amount <= maxFlashLoan(token), "Not enough liquidity for that amount");

        IERC20(token).transfer(address(receiver), amount);

        bytes32 callbackResponse = receiver.onFlashLoan(msg.sender, token, amount, 0, data);
        require(callbackResponse == FLASH_LOAN_CALLBACK_SUCCESS, "onFlashLoan not implemented in receiver");

        require(IERC20(token).transferFrom(address(receiver), address(this), amount), "repayment unsuccessful");

        return true;
    }
}
