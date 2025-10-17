// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @dev Interface for YUMAerodromeAdapter
 */
interface IYUMAerodromeAdapter {
    function graduateToken(
        address yumToken,
        address creator,
        uint256 ethAmount,
        uint256 tokenAmount
    ) external payable returns (address pool, address locker);
}

/**
 * @title YUMToken
 * @dev ERC20 token contract for YUM.fun platform
 * Each token has a fixed supply of 1 billion tokens
 */
contract YUMToken is ERC20, Ownable, ReentrancyGuard {
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 10**18; // 1 billion tokens
    uint256 public constant GRADUATION_THRESHOLD = 4 ether; // 4 ETH graduation threshold (net amount after fees)
    
    // Token metadata
    string private _name;
    string private _symbol;
    string private _description;
    string private _imageUri;
    string private _twitter;
    string private _telegram;
    string private _website;
    
    // Bonding curve parameters
    uint256 public constant VIRTUAL_ETH_RESERVES = 30 ether; // Virtual ETH reserves
    uint256 public constant VIRTUAL_TOKEN_RESERVES = 1_000_000_000 * 10**18; // Virtual token reserves
    
    // State variables
    bool public isGraduated = false;
    uint256 public totalEthRaised = 0;
    uint256 public graduationTime;
    address public factory;
    address public aerodromeIntegration;
    
    // Events
    event TokenCreated(
        address indexed token,
        address indexed creator,
        string name,
        string symbol,
        string description
    );
    
    event TokenBought(
        address indexed buyer,
        uint256 ethAmount,
        uint256 tokenAmount,
        uint256 newTotalRaised
    );
    
    event TokenSold(
        address indexed seller,
        uint256 tokenAmount,
        uint256 ethAmount,
        uint256 newTotalRaised
    );
    
    event TokenGraduated(
        address indexed token,
        uint256 totalRaised,
        uint256 graduationTime
    );
    
    modifier onlyFactory() {
        require(msg.sender == factory, "Only factory can call this function");
        _;
    }
    
    modifier notGraduated() {
        require(!isGraduated, "Token has already graduated");
        _;
    }
    
    constructor(
        string memory name_,
        string memory symbol_,
        string memory description_,
        string memory imageUri_,
        string memory twitter_,
        string memory telegram_,
        string memory website_,
        address creator_
    ) ERC20(name_, symbol_) Ownable(creator_) {
        _name = name_;
        _symbol = symbol_;
        _description = description_;
        _imageUri = imageUri_;
        _twitter = twitter_;
        _telegram = telegram_;
        _website = website_;
        factory = msg.sender;
        
        // Mint all tokens to this contract initially
        _mint(address(this), TOTAL_SUPPLY);
        
        emit TokenCreated(address(this), creator_, name_, symbol_, description_);
    }
    
    /**
     * @dev Calculate token amount for given ETH amount using bonding curve
     * Uses constant product formula: x * y = k
     */
    function calculateTokenAmount(uint256 ethAmount) public view returns (uint256) {
        if (ethAmount == 0) return 0;
        
        uint256 currentEthReserves = VIRTUAL_ETH_RESERVES + totalEthRaised;
        uint256 currentTokenReserves = VIRTUAL_TOKEN_RESERVES - (TOTAL_SUPPLY - balanceOf(address(this)));
        
        // Calculate tokens to receive using constant product formula
        uint256 tokensOut = (ethAmount * currentTokenReserves) / (currentEthReserves + ethAmount);
        
        return tokensOut;
    }
    
    /**
     * @dev Calculate ETH amount for given token amount using bonding curve
     */
    function calculateEthAmount(uint256 tokenAmount) public view returns (uint256) {
        if (tokenAmount == 0) return 0;
        
        uint256 currentEthReserves = VIRTUAL_ETH_RESERVES + totalEthRaised;
        uint256 currentTokenReserves = VIRTUAL_TOKEN_RESERVES - (TOTAL_SUPPLY - balanceOf(address(this)));
        
        // Calculate ETH to receive using constant product formula
        uint256 ethOut = (tokenAmount * currentEthReserves) / (currentTokenReserves + tokenAmount);
        
        return ethOut;
    }
    
    /**
     * @dev Buy tokens with ETH
     */
    function buyTokens() external payable nonReentrant notGraduated {
        _buyTokensFor(msg.sender, msg.value);
    }
    
    /**
     * @dev Buy tokens for a specific address (called by factory)
     */
    function buyTokensFor(address buyer, uint256 ethAmount) external payable nonReentrant notGraduated {
        require(msg.sender == factory, "Only factory can call this function");
        require(ethAmount > 0, "ETH amount must be greater than 0");
        require(ethAmount >= 0.001 ether, "Minimum buy amount is 0.001 ETH");
        
        _buyTokensFor(buyer, ethAmount);
    }
    
    /**
     * @dev Internal function to buy tokens
     */
    function _buyTokensFor(address buyer, uint256 ethAmount) internal {
        uint256 tokenAmount = calculateTokenAmount(ethAmount);
        require(tokenAmount > 0, "Invalid token amount");
        require(balanceOf(address(this)) >= tokenAmount, "Insufficient token balance");
        
        // Update total raised
        totalEthRaised += ethAmount;
        
        // Transfer tokens to buyer
        _transfer(address(this), buyer, tokenAmount);
        
        emit TokenBought(buyer, ethAmount, tokenAmount, totalEthRaised);
        
        // Check for graduation
        if (totalEthRaised >= GRADUATION_THRESHOLD && !isGraduated) {
            _graduate();
        }
    }
    
    /**
     * @dev Sell tokens for ETH
     */
    function sellTokens(uint256 tokenAmount) external nonReentrant notGraduated {
        _sellTokensFor(msg.sender, tokenAmount);
    }
    
    /**
     * @dev Sell tokens for a specific address (called by factory)
     */
    function sellTokensFor(address seller, uint256 tokenAmount) external nonReentrant notGraduated {
        require(msg.sender == factory, "Only factory can call this function");
        require(tokenAmount > 0, "Token amount must be greater than 0");
        
        _sellTokensFor(seller, tokenAmount);
    }
    
    /**
     * @dev Sell tokens and send ETH to factory for fee distribution
     */
    function sellTokensForFactory(address seller, uint256 tokenAmount) external nonReentrant notGraduated returns (uint256) {
        require(msg.sender == factory, "Only factory can call this function");
        require(tokenAmount > 0, "Token amount must be greater than 0");
        require(balanceOf(seller) >= tokenAmount, "Insufficient token balance");
        
        uint256 ethAmount = calculateEthAmount(tokenAmount);
        require(ethAmount > 0, "Invalid ETH amount");
        require(address(this).balance >= ethAmount, "Insufficient ETH balance");
        
        // Update total raised
        totalEthRaised -= ethAmount;
        
        // Transfer tokens from seller to contract
        _transfer(seller, address(this), tokenAmount);
        
        // Transfer ETH to factory for fee distribution
        payable(factory).transfer(ethAmount);
        
        emit TokenSold(seller, tokenAmount, ethAmount, totalEthRaised);
        
        return ethAmount;
    }
    
    /**
     * @dev Internal function to sell tokens
     */
    function _sellTokensFor(address seller, uint256 tokenAmount) internal {
        require(balanceOf(seller) >= tokenAmount, "Insufficient token balance");
        
        uint256 ethAmount = calculateEthAmount(tokenAmount);
        require(ethAmount > 0, "Invalid ETH amount");
        require(address(this).balance >= ethAmount, "Insufficient ETH balance");
        
        // Update total raised
        totalEthRaised -= ethAmount;
        
        // Transfer tokens from seller to contract
        _transfer(seller, address(this), tokenAmount);
        
        // Transfer ETH to seller
        payable(seller).transfer(ethAmount);
        
        emit TokenSold(seller, tokenAmount, ethAmount, totalEthRaised);
    }
    
    /**
     * @dev Graduate the token (called when threshold is reached)
     */
    function _graduate() internal {
        isGraduated = true;
        graduationTime = block.timestamp;
        
        emit TokenGraduated(address(this), totalEthRaised, graduationTime);
        
        // Integrate with Aerodrome DEX for LP creation
        if (aerodromeIntegration != address(0)) {
            // Calculate amounts for LP creation
            uint256 ethForLP = totalEthRaised;
            uint256 tokensForLP = (TOTAL_SUPPLY * 207) / 1000; // 20.7% of total supply
            
            // Approve Aerodrome adapter to spend tokens
            _approve(address(this), aerodromeIntegration, tokensForLP);
            
            // Call Aerodrome adapter to graduate token
            // Note: The adapter will handle pool creation and liquidity locking
            try IYUMAerodromeAdapter(aerodromeIntegration).graduateToken{value: ethForLP}(
                address(this),
                owner(),
                ethForLP,
                tokensForLP
            ) returns (address /*pool*/, address /*locker*/) {
                // Successfully graduated - event already emitted above
            } catch {
                // If graduation fails, revert to allow retry
                revert("Graduation to Aerodrome failed");
            }
        }
    }
    
    /**
     * @dev Set Aerodrome integration address (only factory)
     */
    function setAerodromeIntegration(address _aerodromeIntegration) external onlyFactory {
        aerodromeIntegration = _aerodromeIntegration;
    }
    
    /**
     * @dev Get current market cap in ETH
     */
    function getMarketCap() public view returns (uint256) {
        uint256 currentEthReserves = VIRTUAL_ETH_RESERVES + totalEthRaised;
        uint256 currentTokenReserves = VIRTUAL_TOKEN_RESERVES - (TOTAL_SUPPLY - balanceOf(address(this)));
        
        if (currentTokenReserves == 0) return 0;
        
        return (currentEthReserves * TOTAL_SUPPLY) / currentTokenReserves;
    }
    
    /**
     * @dev Get token metadata
     */
    function getMetadata() external view returns (
        string memory name,
        string memory symbol,
        string memory description,
        string memory imageUri,
        string memory twitter,
        string memory telegram,
        string memory website
    ) {
        return (_name, _symbol, _description, _imageUri, _twitter, _telegram, _website);
    }
    
    /**
     * @dev Get bonding curve progress (0-100)
     */
    function getProgress() external view returns (uint256) {
        return (totalEthRaised * 100) / GRADUATION_THRESHOLD;
    }
    
    // Receive ETH
    receive() external payable {
        // Allow direct ETH transfers for buying tokens
    }
    
    // Fallback function
    fallback() external payable {
        // Allow direct ETH transfers
    }
}
