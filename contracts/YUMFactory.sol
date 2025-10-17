// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./YUMToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title YUMFactory
 * @dev Factory contract for creating and managing YUM tokens
 * Handles fee collection and token creation logic
 */
contract YUMFactory is Ownable, ReentrancyGuard, Pausable {
    // Fee structure constants
    uint256 public constant FIRST_BUY_FEE = 0.002 ether; // 0.002 ETH for first buy
    uint256 public constant TRADING_FEE_BASIS_POINTS = 30; // 0.3% (30 basis points)
    uint256 public constant PROTOCOL_FEE_BASIS_POINTS = 5; // 0.05% to protocol
    uint256 public constant CREATOR_FEE_BASIS_POINTS = 5; // 0.05% to creator
    uint256 public constant LIQUIDITY_FEE_BASIS_POINTS = 20; // 0.20% to liquidity
    
    // Minimum amounts
    uint256 public constant MIN_FIRST_BUY_AMOUNT = 0.004 ether; // Minimum ETH needed for first buy
    uint256 public constant MIN_TRADE_AMOUNT = 0.001 ether; // Minimum trade amount
    
    // State variables
    mapping(address => bool) public isToken;
    mapping(address => address) public tokenToCreator;
    mapping(address => bool) public hasFirstBuy;
    address[] public allTokens;
    
    // Fee recipients
    address public protocolFeeRecipient;
    address public treasury;
    address public aerodromeIntegration;
    
    // Statistics
    uint256 public totalTokensCreated = 0;
    uint256 public totalVolume = 0;
    uint256 public totalFeesCollected = 0;
    
    // Events
    event TokenCreated(
        address indexed token,
        address indexed creator,
        string name,
        string symbol,
        uint256 timestamp
    );
    
    event FirstBuy(
        address indexed token,
        address indexed buyer,
        uint256 ethAmount,
        uint256 tokenAmount
    );
    
    event Trade(
        address indexed token,
        address indexed trader,
        bool isBuy,
        uint256 ethAmount,
        uint256 tokenAmount,
        uint256 protocolFee,
        uint256 creatorFee
    );
    
    event FeesCollected(
        address indexed token,
        uint256 protocolFee,
        uint256 creatorFee,
        uint256 totalFees
    );
    
    constructor(address _protocolFeeRecipient, address _treasury) Ownable(msg.sender) {
        protocolFeeRecipient = _protocolFeeRecipient;
        treasury = _treasury;
    }
    
    /**
     * @dev Create a new YUM token
     * @param name Token name
     * @param symbol Token symbol
     * @param description Token description
     * @param imageUri Token image URI
     * @param twitter Twitter handle
     * @param telegram Telegram link
     * @param website Website URL
     * @param makeFirstBuy Whether to make the first buy immediately
     * @param firstBuyAmount Amount of ETH for first buy (if makeFirstBuy is true)
     */
    function createToken(
        string memory name,
        string memory symbol,
        string memory description,
        string memory imageUri,
        string memory twitter,
        string memory telegram,
        string memory website,
        bool makeFirstBuy,
        uint256 firstBuyAmount
    ) external payable nonReentrant whenNotPaused {
        // Validate inputs
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(symbol).length > 0, "Symbol cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");
        
        // If making first buy, validate amount and payment
        if (makeFirstBuy) {
            require(msg.value >= firstBuyAmount + FIRST_BUY_FEE, "Insufficient payment for first buy");
            require(firstBuyAmount >= MIN_FIRST_BUY_AMOUNT, "First buy amount too low");
        } else {
            require(msg.value == 0, "No payment needed for token creation without first buy");
        }
        
        // Create new token
        YUMToken newToken = new YUMToken(
            name,
            symbol,
            description,
            imageUri,
            twitter,
            telegram,
            website,
            msg.sender
        );
        
        // Set Aerodrome integration (if available)
        if (aerodromeIntegration != address(0)) {
            newToken.setAerodromeIntegration(aerodromeIntegration);
        }
        
        address tokenAddress = address(newToken);
        
        // Register token
        isToken[tokenAddress] = true;
        tokenToCreator[tokenAddress] = msg.sender;
        allTokens.push(tokenAddress);
        totalTokensCreated++;
        
        emit TokenCreated(tokenAddress, msg.sender, name, symbol, block.timestamp);
        
        // Make first buy if requested
        if (makeFirstBuy) {
            _makeFirstBuy(tokenAddress, firstBuyAmount);
        }
    }
    
    /**
     * @dev Make the first buy for a token
     * @param tokenAddress Address of the token
     * @param amount Amount of ETH to spend on tokens
     */
    function makeFirstBuyForToken(address tokenAddress, uint256 amount) external payable nonReentrant {
        require(isToken[tokenAddress], "Token does not exist");
        require(!hasFirstBuy[tokenAddress], "First buy already made");
        require(msg.value >= amount + FIRST_BUY_FEE, "Insufficient payment");
        require(amount >= MIN_FIRST_BUY_AMOUNT, "Amount too low");
        
        _makeFirstBuy(tokenAddress, amount);
    }
    
    /**
     * @dev Internal function to make first buy
     */
    function _makeFirstBuy(address tokenAddress, uint256 amount) internal {
        YUMToken token = YUMToken(payable(tokenAddress));
        
        // Calculate token amount before fees
        uint256 tokenAmount = token.calculateTokenAmount(amount);
        require(tokenAmount > 0, "Invalid token amount");
        
        // Make the buy by calling the token contract directly
        token.buyTokensFor{value: amount}(msg.sender, amount);
        
        // Mark first buy as completed
        hasFirstBuy[tokenAddress] = true;
        
        // Collect first buy fee
        if (msg.value > amount) {
            uint256 feeAmount = msg.value - amount;
            payable(protocolFeeRecipient).transfer(feeAmount);
            totalFeesCollected += feeAmount;
        }
        
        emit FirstBuy(tokenAddress, msg.sender, amount, tokenAmount);
    }
    
    /**
     * @dev Buy tokens with fee calculation
     * @param tokenAddress Address of the token to buy
     */
    function buyTokens(address tokenAddress) external payable nonReentrant {
        require(isToken[tokenAddress], "Token does not exist");
        require(hasFirstBuy[tokenAddress], "First buy not made yet");
        require(msg.value >= MIN_TRADE_AMOUNT, "Amount too low");
        
        YUMToken token = YUMToken(payable(tokenAddress));
        
        // Calculate fees
        uint256 protocolFee = (msg.value * PROTOCOL_FEE_BASIS_POINTS) / 10000;
        uint256 creatorFee = (msg.value * CREATOR_FEE_BASIS_POINTS) / 10000;
        uint256 netAmount = msg.value - protocolFee - creatorFee;
        
        // Calculate token amount with net amount
        uint256 tokenAmount = token.calculateTokenAmount(netAmount);
        
        // Buy tokens with net amount for the actual buyer
        token.buyTokensFor{value: netAmount}(msg.sender, netAmount);
        
        // Transfer fees after the buy (so graduation can happen with full amount)
        if (protocolFee > 0) {
            payable(protocolFeeRecipient).transfer(protocolFee);
        }
        if (creatorFee > 0) {
            payable(tokenToCreator[tokenAddress]).transfer(creatorFee);
        }
        
        // Update statistics
        totalVolume += msg.value;
        totalFeesCollected += protocolFee + creatorFee;
        
        emit Trade(tokenAddress, msg.sender, true, msg.value, tokenAmount, protocolFee, creatorFee);
        emit FeesCollected(tokenAddress, protocolFee, creatorFee, protocolFee + creatorFee);
    }
    
    /**
     * @dev Sell tokens with fee calculation
     * @param tokenAddress Address of the token to sell
     * @param tokenAmount Amount of tokens to sell
     */
    function sellTokens(address tokenAddress, uint256 tokenAmount) external nonReentrant {
        require(isToken[tokenAddress], "Token does not exist");
        require(hasFirstBuy[tokenAddress], "First buy not made yet");
        require(tokenAmount > 0, "Amount must be greater than 0");
        
        YUMToken token = YUMToken(payable(tokenAddress));
        
        // Execute sell on token contract and get ETH amount
        uint256 ethAmount = token.sellTokensForFactory(msg.sender, tokenAmount);
        require(ethAmount >= MIN_TRADE_AMOUNT, "ETH amount too low");
        
        // Calculate fees
        uint256 protocolFee = (ethAmount * PROTOCOL_FEE_BASIS_POINTS) / 10000;
        uint256 creatorFee = (ethAmount * CREATOR_FEE_BASIS_POINTS) / 10000;
        uint256 netAmount = ethAmount - protocolFee - creatorFee;
        
        // Transfer fees
        if (protocolFee > 0) {
            payable(protocolFeeRecipient).transfer(protocolFee);
        }
        if (creatorFee > 0) {
            payable(tokenToCreator[tokenAddress]).transfer(creatorFee);
        }
        
        // Transfer net amount to seller
        payable(msg.sender).transfer(netAmount);
        
        // Update statistics
        totalVolume += ethAmount;
        totalFeesCollected += protocolFee + creatorFee;
        
        emit Trade(tokenAddress, msg.sender, false, ethAmount, tokenAmount, protocolFee, creatorFee);
        emit FeesCollected(tokenAddress, protocolFee, creatorFee, protocolFee + creatorFee);
    }
    
    /**
     * @dev Get all created tokens
     */
    function getAllTokens() external view returns (address[] memory) {
        return allTokens;
    }
    
    /**
     * @dev Get token count
     */
    function getTokenCount() external view returns (uint256) {
        return allTokens.length;
    }
    
    /**
     * @dev Get token info
     */
    function getTokenInfo(address tokenAddress) external view returns (
        address creator,
        bool exists,
        bool firstBuyMade,
        uint256 totalRaised,
        bool isGraduated
    ) {
        require(isToken[tokenAddress], "Token does not exist");
        
        return (
            tokenToCreator[tokenAddress],
            true,
            hasFirstBuy[tokenAddress],
            0, // We'll implement this later
            false // We'll implement this later
        );
    }
    
    /**
     * @dev Update fee recipients (only owner)
     */
    function updateFeeRecipients(address _protocolFeeRecipient, address _treasury) external onlyOwner {
        protocolFeeRecipient = _protocolFeeRecipient;
        treasury = _treasury;
    }
    
    /**
     * @dev Set Aerodrome integration address (only owner)
     */
    function setAerodromeIntegration(address _aerodromeIntegration) external onlyOwner {
        aerodromeIntegration = _aerodromeIntegration;
    }
    
    /**
     * @dev Pause contract (only owner)
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause contract (only owner)
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Emergency withdraw (only owner)
     */
    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
    
    // Receive ETH
    receive() external payable {
        // Allow direct ETH transfers
    }
}
