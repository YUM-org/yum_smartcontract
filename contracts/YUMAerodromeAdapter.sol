// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./aerodrome/extensions/v2/V2PoolLauncher.sol";
import "./aerodrome/extensions/v2/V2LockerFactory.sol";
import "./aerodrome/interfaces/extensions/v2/IV2PoolLauncher.sol";

/**
 * @title YUMAerodromeAdapter
 * @author YUM.fun
 * @notice Adapter contract to integrate YUM.fun token graduation with Aerodrome DEX
 * @dev This contract handles the graduation process by creating pools and locking liquidity on Aerodrome
 */
contract YUMAerodromeAdapter is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Aerodrome contracts
    V2PoolLauncher public immutable poolLauncher;
    V2LockerFactory public immutable lockerFactory;
    address public immutable pairedToken; // WETH or other base token

    // YUM.fun factory
    address public yumFactory;

    // Constants for graduation
    uint256 public constant LOCK_DURATION = 365 days; // 1 year lock
    uint16 public constant BRIBEABLE_SHARE = 500; // 5% bribeable

    // Events
    event TokenGraduated(
        address indexed yumToken,
        address indexed creator,
        address pool,
        address locker,
        uint256 ethAmount,
        uint256 tokenAmount
    );

    event PoolLauncherUpdated(address indexed oldLauncher, address indexed newLauncher);
    event YUMFactoryUpdated(address indexed oldFactory, address indexed newFactory);

    // Errors
    error OnlyYUMFactory();
    error InvalidPoolLauncher();
    error InvalidLockerFactory();
    error InvalidPairedToken();
    error InvalidYUMFactory();
    error GraduationFailed();

    modifier onlyYUMFactory() {
        if (msg.sender != yumFactory) revert OnlyYUMFactory();
        _;
    }

    /**
     * @notice Constructor to initialize the adapter
     * @param _poolLauncher Address of the V2PoolLauncher contract
     * @param _lockerFactory Address of the V2LockerFactory contract
     * @param _pairedToken Address of the token to pair with (e.g., WETH)
     * @param _yumFactory Address of the YUM.fun factory
     * @param _owner Owner of this adapter contract
     */
    constructor(
        address _poolLauncher,
        address _lockerFactory,
        address _pairedToken,
        address _yumFactory,
        address _owner
    ) Ownable(_owner) {
        if (_poolLauncher == address(0)) revert InvalidPoolLauncher();
        if (_lockerFactory == address(0)) revert InvalidLockerFactory();
        if (_pairedToken == address(0)) revert InvalidPairedToken();
        if (_yumFactory == address(0)) revert InvalidYUMFactory();

        poolLauncher = V2PoolLauncher(_poolLauncher);
        lockerFactory = V2LockerFactory(_lockerFactory);
        pairedToken = _pairedToken;
        yumFactory = _yumFactory;
    }

    /**
     * @notice Graduate a YUM token to Aerodrome
     * @dev Called by YUMFactory when a token reaches graduation threshold
     * @param yumToken Address of the YUM token to graduate
     * @param creator Address of the token creator
     * @param ethAmount Amount of ETH for liquidity
     * @param tokenAmount Amount of tokens for liquidity
     * @return pool Address of the created pool
     * @return locker Address of the created locker
     */
    function graduateToken(
        address yumToken,
        address creator,
        uint256 ethAmount,
        uint256 tokenAmount
    ) external payable onlyYUMFactory nonReentrant returns (address pool, address locker) {
        require(msg.value >= ethAmount, "Insufficient ETH sent");
        require(tokenAmount > 0, "Invalid token amount");

        // Transfer YUM tokens from YUM token contract to this adapter
        IERC20(yumToken).safeTransferFrom(msg.sender, address(this), tokenAmount);

        // Transfer paired token (WETH or other) from sender
        // Note: Sender must have approved this contract to spend pairedToken
        IERC20(pairedToken).safeTransferFrom(msg.sender, address(this), ethAmount);

        // Approve tokens for pool launcher
        IERC20(yumToken).forceApprove(address(poolLauncher), tokenAmount);
        IERC20(pairedToken).forceApprove(address(poolLauncher), ethAmount);

        // Create launch parameters
        IV2PoolLauncher.LaunchParams memory params = IV2PoolLauncher.LaunchParams({
            poolLauncherToken: yumToken,
            tokenToPair: pairedToken,
            stable: false, // Volatile pool for YUM tokens
            liquidity: IV2PoolLauncher.LiquidityParams({
                amountPoolLauncherToken: tokenAmount,
                amountTokenToPair: ethAmount,
                amountPoolLauncherTokenMin: (tokenAmount * 95) / 100, // 5% slippage
                amountTokenToPairMin: (ethAmount * 95) / 100, // 5% slippage
                lockDuration: uint32(LOCK_DURATION)
            })
        });

        // Launch pool and create locker
        (IPoolLauncher.PoolLauncherPool memory poolInfo, address newLocker) = 
            poolLauncher.launch(params, creator, creator);

        pool = poolInfo.pool;
        locker = newLocker;

        emit TokenGraduated(yumToken, creator, pool, locker, ethAmount, tokenAmount);

        // Refund any excess ETH
        if (address(this).balance > 0) {
            payable(creator).transfer(address(this).balance);
        }
    }

    /**
     * @notice Update YUM factory address
     * @param _yumFactory New YUM factory address
     */
    function setYUMFactory(address _yumFactory) external onlyOwner {
        if (_yumFactory == address(0)) revert InvalidYUMFactory();
        address oldFactory = yumFactory;
        yumFactory = _yumFactory;
        emit YUMFactoryUpdated(oldFactory, _yumFactory);
    }

    /**
     * @notice Emergency withdraw function
     * @param token Token to withdraw (address(0) for ETH)
     */
    function emergencyWithdraw(address token) external onlyOwner {
        if (token == address(0)) {
            payable(owner()).transfer(address(this).balance);
        } else {
            uint256 balance = IERC20(token).balanceOf(address(this));
            if (balance > 0) {
                IERC20(token).safeTransfer(owner(), balance);
            }
        }
    }

    // Receive ETH
    receive() external payable {}
}

