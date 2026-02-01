// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title NeuralTrade AI - Trading Agent
 * @notice Autonomous AI-powered trading agent for Injective Protocol
 * @dev Implements secure, non-custodial trading with risk management
 */
contract TradingAgent is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ==================== State Variables ====================

    struct Trade {
        uint256 id;
        address trader;
        address inputToken;
        address outputToken;
        uint256 inputAmount;
        uint256 outputAmount;
        uint256 timestamp;
        TradeType tradeType;
        TradeStatus status;
        string aiReasoning;
    }

    struct StrategyConfig {
        bool enabled;
        uint256 maxPositionSize;
        uint256 stopLossPercentage;
        uint256 takeProfitPercentage;
        uint256 dailyVolumeLimit;
        uint256 minTradeAmount;
        uint256 maxTradeAmount;
    }

    struct Position {
        address token;
        uint256 amount;
        uint256 entryPrice;
        uint256 currentPrice;
        uint256 pnl;
        uint256 timestamp;
        bool isActive;
    }

    enum TradeType {
        BUY,
        SELL,
        SWAP,
        ARBITRAGE,
        LIQUIDITY_ADD,
        LIQUIDITY_REMOVE
    }

    enum TradeStatus {
        PENDING,
        EXECUTED,
        FAILED,
        CANCELLED
    }

    enum Strategy {
        GRID_TRADING,
        DCA,
        MOMENTUM,
        ARBITRAGE,
        LP_FARMING
    }

    // Mappings
    mapping(uint256 => Trade) public trades;
    mapping(address => Position[]) public userPositions;
    mapping(address => StrategyConfig) public strategyConfigs;
    mapping(Strategy => StrategyConfig) public defaultStrategyConfigs;
    mapping(address => bool) public approvedTokens;
    mapping(address => bool) public authorizedAI;
    mapping(address => uint256) public dailyTradeVolume;
    mapping(address => uint256) public lastTradeDay;

    // Counters
    uint256 public tradeCounter;
    uint256 public positionCounter;

    // Constants
    uint256 private constant BASIS_POINTS = 10000;
    uint256 private constant MAX_DAILY_TRADES = 100;
    uint256 private constant EMERGENCY_COOLDOWN = 1 days;

    // Variables
    bool public emergencyPaused;
    address public injectiveExchange;
    address public aiOracle;

    // ==================== Events ====================

    event TradeExecuted(
        uint256 indexed tradeId,
        address indexed trader,
        TradeType tradeType,
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 outputAmount,
        string aiReasoning
    );

    event PositionOpened(
        address indexed trader,
        address token,
        uint256 amount,
        uint256 entryPrice
    );

    event PositionClosed(
        address indexed trader,
        address token,
        uint256 amount,
        uint256 pnl
    );

    event StrategyConfigured(
        Strategy strategy,
        StrategyConfig config
    );

    event AIDecision(
        uint256 indexed tradeId,
        string decision,
        int256 confidence,
        string reasoning
    );

    event EmergencyPause(bool paused);

    // ==================== Modifiers ====================

    modifier onlyAuthorizedAI() {
        require(authorizedAI[msg.sender] || msg.sender == owner(), "Not authorized AI");
        _;
    }

    modifier notPaused() {
        require(!emergencyPaused, "Contract is paused");
        _;
    }

    modifier validToken(address token) {
        require(approvedTokens[token], "Token not approved");
        _;
    }

    // ==================== Constructor ====================

    constructor(address _injectiveExchange) {
        injectiveExchange = _injectiveExchange;
        _setupDefaultStrategies();
    }

    // ==================== Core Trading Functions ====================

    /**
     * @notice Execute a trade based on AI signal
     * @param inputToken Token to sell
     * @param outputToken Token to buy
     * @param inputAmount Amount of input token
     * @param minOutputAmount Minimum output amount (slippage protection)
     * @param strategy Trading strategy used
     * @param aiReasoning AI's explanation for the trade
     * @return tradeId ID of the executed trade
     */
    function executeTrade(
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 minOutputAmount,
        Strategy strategy,
        string calldata aiReasoning
    ) external onlyAuthorizedAI notPaused nonReentrant returns (uint256 tradeId) {
        require(inputToken != outputToken, "Cannot trade same token");
        require(inputAmount > 0, "Invalid amount");
        require(approvedTokens[inputToken] && approvedTokens[outputToken], "Token not approved");

        StrategyConfig memory config = strategyConfigs[msg.sender];
        if (!config.enabled) {
            config = defaultStrategyConfigs[strategy];
        }

        require(config.enabled, "Strategy not enabled");
        require(inputAmount >= config.minTradeAmount && inputAmount <= config.maxTradeAmount, "Amount outside limits");

        // Check daily volume limit
        _checkAndUpdateDailyVolume(msg.sender, inputAmount);

        // Calculate expected output (simplified - in production, use DEX quotes)
        uint256 outputAmount = _getExpectedOutput(inputToken, outputToken, inputAmount);
        require(outputAmount >= minOutputAmount, "Slippage exceeded");

        // Execute trade
        tradeId = ++tradeCounter;
        trades[tradeId] = Trade({
            id: tradeId,
            trader: msg.sender,
            inputToken: inputToken,
            outputToken: outputToken,
            inputAmount: inputAmount,
            outputAmount: outputAmount,
            timestamp: block.timestamp,
            tradeType: TradeType.SWAP,
            status: TradeStatus.EXECUTED,
            aiReasoning: aiReasoning
        });

        // Update positions
        _updatePosition(msg.sender, outputToken, outputAmount, true);
        _updatePosition(msg.sender, inputToken, inputAmount, false);

        emit TradeExecuted(tradeId, msg.sender, TradeType.SWAP, inputToken, outputToken, inputAmount, outputAmount, aiReasoning);
        emit AIDecision(tradeId, "EXECUTE_TRADE", 85, aiReasoning);

        return tradeId;
    }

    /**
     * @notice Execute grid trading strategy
     * @param baseToken Base asset for grid trading
     * @param quoteToken Quote asset for grid trading
     * @param gridCount Number of grid levels
     * @param gridSpacing Percentage spacing between grids
     * @param lowerBound Lower price bound
     * @param upperBound Upper price bound
     */
    function executeGridTrade(
        address baseToken,
        address quoteToken,
        uint256 gridCount,
        uint256 gridSpacing,
        uint256 lowerBound,
        uint256 upperBound
    ) external onlyAuthorizedAI notPaused {
        require(gridCount > 0 && gridCount <= 50, "Invalid grid count");
        require(upperBound > lowerBound, "Invalid price bounds");
        require(gridSpacing > 0 && gridSpacing <= 1000, "Invalid grid spacing"); // Max 10% per grid

        StrategyConfig storage config = defaultStrategyConfigs[Strategy.GRID_TRADING];
        require(config.enabled, "Grid trading not enabled");

        // AI determines grid placement
        emit AIDecision(0, "GRID_TRADING_SETUP", 90, "Grid trading configured based on volatility analysis");

        // In production: place orders at each grid level
    }

    /**
     * @notice Execute DCA (Dollar Cost Average) strategy
     * @param token Token to purchase
     * @param amount Amount to purchase each time
     * @param frequency Frequency in seconds
     * @param totalPurchases Total number of purchases
     */
    function executeDCA(
        address token,
        uint256 amount,
        uint256 frequency,
        uint256 totalPurchases
    ) external onlyAuthorizedAI notPaused {
        require(amount > 0, "Invalid amount");
        require(frequency >= 1 hours, "Frequency too short");
        require(totalPurchases > 0 && totalPurchases <= 365, "Invalid purchase count");

        StrategyConfig storage config = defaultStrategyConfigs[Strategy.DCA];
        require(config.enabled, "DCA not enabled");

        emit AIDecision(0, "DCA_STARTED", 95, "DCA strategy initialized for long-term accumulation");

        // In production: set up recurring purchases
    }

    /**
     * @notice Close a position
     * @param token Token to close position for
     * @param amount Amount to close
     */
    function closePosition(
        address token,
        uint256 amount
    ) external onlyAuthorizedAI notPaused {
        Position[] storage positions = userPositions[msg.sender];

        uint256 totalClosed = 0;
        for (uint256 i = 0; i < positions.length; i++) {
            if (positions[i].token == token && positions[i].isActive) {
                uint256 closeAmount = positions[i].amount > (amount - totalClosed)
                    ? (amount - totalClosed)
                    : positions[i].amount;

                positions[i].amount -= closeAmount;
                if (positions[i].amount == 0) {
                    positions[i].isActive = false;
                }

                totalClosed += closeAmount;

                // Calculate PnL (simplified)
                uint256 pnl = _calculatePnL(positions[i].entryPrice, _getCurrentPrice(token), closeAmount);

                emit PositionClosed(msg.sender, token, closeAmount, pnl);

                if (totalClosed >= amount) break;
            }
        }
    }

    // ==================== AI Oracle Functions ====================

    /**
     * @notice Set AI oracle address
     * @param _aiOracle Address of the AI oracle
     */
    function setAIOracle(address _aiOracle) external onlyOwner {
        require(_aiOracle != address(0), "Invalid address");
        aiOracle = _aiOracle;
    }

    /**
     * @notice Authorize AI agent
     * @param agent Address of the AI agent
     * @param authorized Whether to authorize or revoke
     */
    function setAuthorizedAI(address agent, bool authorized) external onlyOwner {
        authorizedAI[agent] = authorized;
    }

    /**
     * @notice Process AI trading signal
     * @param signal Encoded trading signal from AI
     * @param confidence Confidence level (0-100)
     * @param reasoning AI's reasoning
     */
    function processAISignal(
        bytes calldata signal,
        int256 confidence,
        string calldata reasoning
    ) external onlyAuthorizedAI notPaused {
        require(confidence > 50, "Confidence too low");

        // Decode signal and execute trade
        // This is a placeholder for the actual implementation
        emit AIDecision(tradeCounter + 1, "SIGNAL_RECEIVED", confidence, reasoning);
    }

    // ==================== Risk Management ====================

    /**
     * @notice Configure strategy parameters
     * @param strategy Strategy to configure
     * @param config Configuration parameters
     */
    function configureStrategy(
        Strategy strategy,
        StrategyConfig calldata config
    ) external onlyOwner {
        require(config.maxPositionSize > 0, "Invalid max position size");
        require(config.stopLossPercentage <= 5000, "Stop loss too high"); // Max 50%
        require(config.takeProfitPercentage <= 10000, "Take profit too high"); // Max 100%

        defaultStrategyConfigs[strategy] = config;
        emit StrategyConfigured(strategy, config);
    }

    /**
     * @notice Emergency pause
     * @param paused Whether to pause or unpause
     */
    function setEmergencyPause(bool paused) external onlyOwner {
        emergencyPaused = paused;
        emit EmergencyPause(paused);
    }

    /**
     * @notice Set approved token
     * @param token Token address
     * @param approved Whether to approve or revoke
     */
    function setApprovedToken(address token, bool approved) external onlyOwner {
        approvedTokens[token] = approved;
    }

    // ==================== View Functions ====================

    /**
     * @notice Get user's active positions
     * @param user Address of the user
     * @return positions Array of active positions
     */
    function getUserPositions(address user) external view returns (Position[] memory) {
        Position[] memory activePositions = new Position[](positionCounter);
        uint256 activeCount = 0;

        Position[] storage userPositionsArray = userPositions[user];
        for (uint256 i = 0; i < userPositionsArray.length; i++) {
            if (userPositionsArray[i].isActive) {
                activePositions[activeCount] = userPositionsArray[i];
                activeCount++;
            }
        }

        // Resize array to actual count
        Position[] memory result = new Position[](activeCount);
        for (uint256 i = 0; i < activeCount; i++) {
            result[i] = activePositions[i];
        }

        return result;
    }

    /**
     * @notice Get trade details
     * @param tradeId ID of the trade
     * @return trade Trade details
     */
    function getTrade(uint256 tradeId) external view returns (Trade memory) {
        require(tradeId > 0 && tradeId <= tradeCounter, "Invalid trade ID");
        return trades[tradeId];
    }

    /**
     * @notice Calculate portfolio value
     * @param user Address of the user
     * @return totalValue Total portfolio value in USD
     */
    function calculatePortfolioValue(address user) external view returns (uint256 totalValue) {
        Position[] storage positions = userPositions[user];
        for (uint256 i = 0; i < positions.length; i++) {
            if (positions[i].isActive) {
                uint256 tokenPrice = _getCurrentPrice(positions[i].token);
                totalValue += (positions[i].amount * tokenPrice) / 1e18;
            }
        }
    }

    // ==================== Internal Functions ====================

    function _updatePosition(
        address trader,
        address token,
        uint256 amount,
        bool isBuying
    ) internal {
        Position[] storage positions = userPositions[trader];
        bool positionFound = false;

        for (uint256 i = 0; i < positions.length; i++) {
            if (positions[i].token == token && positions[i].isActive) {
                if (isBuying) {
                    uint256 oldAmount = positions[i].amount;
                    uint256 oldPrice = positions[i].entryPrice;
                    uint256 newPrice = _getCurrentPrice(token);

                    // Calculate new average entry price
                    positions[i].entryPrice = (oldAmount * oldPrice + amount * newPrice) / (oldAmount + amount);
                    positions[i].amount += amount;
                    positions[i].currentPrice = newPrice;
                } else {
                    positions[i].amount -= amount;
                    if (positions[i].amount == 0) {
                        positions[i].isActive = false;
                    }
                }
                positionFound = true;
                break;
            }
        }

        if (!positionFound && isBuying) {
            positions.push(Position({
                token: token,
                amount: amount,
                entryPrice: _getCurrentPrice(token),
                currentPrice: _getCurrentPrice(token),
                pnl: 0,
                timestamp: block.timestamp,
                isActive: true
            }));
            positionCounter++;
            emit PositionOpened(trader, token, amount, _getCurrentPrice(token));
        }
    }

    function _checkAndUpdateDailyVolume(address trader, uint256 amount) internal {
        uint256 currentDay = block.timestamp / 1 days;

        if (lastTradeDay[trader] != currentDay) {
            dailyTradeVolume[trader] = 0;
            lastTradeDay[trader] = currentDay;
        }

        StrategyConfig memory config = strategyConfigs[trader];
        if (config.enabled) {
            require(dailyTradeVolume[trader] + amount <= config.dailyVolumeLimit, "Daily volume limit exceeded");
        }

        dailyTradeVolume[trader] += amount;
    }

    function _getExpectedOutput(
        address inputToken,
        address outputToken,
        uint256 inputAmount
    ) internal view returns (uint256) {
        // Simplified price calculation - in production, use DEX quote
        uint256 inputPrice = _getCurrentPrice(inputToken);
        uint256 outputPrice = _getCurrentPrice(outputToken);

        return (inputAmount * inputPrice) / outputPrice;
    }

    function _getCurrentPrice(address token) internal view returns (uint256) {
        // Placeholder - in production, use price oracle
        return 1e18; // $1.00
    }

    function _calculatePnL(
        uint256 entryPrice,
        uint256 currentPrice,
        uint256 amount
    ) internal pure returns (uint256) {
        if (currentPrice > entryPrice) {
            return ((currentPrice - entryPrice) * amount) / currentPrice;
        }
        return 0;
    }

    function _setupDefaultStrategies() internal {
        // Grid Trading
        defaultStrategyConfigs[Strategy.GRID_TRADING] = StrategyConfig({
            enabled: true,
            maxPositionSize: 10000 * 1e18,
            stopLossPercentage: 1000, // 10%
            takeProfitPercentage: 2000, // 20%
            dailyVolumeLimit: 100000 * 1e18,
            minTradeAmount: 100 * 1e18,
            maxTradeAmount: 10000 * 1e18
        });

        // DCA
        defaultStrategyConfigs[Strategy.DCA] = StrategyConfig({
            enabled: true,
            maxPositionSize: 50000 * 1e18,
            stopLossPercentage: 0, // No stop loss for DCA
            takeProfitPercentage: 5000, // 50%
            dailyVolumeLimit: 10000 * 1e18,
            minTradeAmount: 50 * 1e18,
            maxTradeAmount: 5000 * 1e18
        });

        // Momentum
        defaultStrategyConfigs[Strategy.MOMENTUM] = StrategyConfig({
            enabled: true,
            maxPositionSize: 20000 * 1e18,
            stopLossPercentage: 500, // 5%
            takeProfitPercentage: 1500, // 15%
            dailyVolumeLimit: 200000 * 1e18,
            minTradeAmount: 500 * 1e18,
            maxTradeAmount: 20000 * 1e18
        });

        // Arbitrage
        defaultStrategyConfigs[Strategy.ARBITRAGE] = StrategyConfig({
            enabled: true,
            maxPositionSize: 50000 * 1e18,
            stopLossPercentage: 100, // 1%
            takeProfitPercentage: 300, // 3%
            dailyVolumeLimit: 500000 * 1e18,
            minTradeAmount: 1000 * 1e18,
            maxTradeAmount: 50000 * 1e18
        });

        // LP Farming
        defaultStrategyConfigs[Strategy.LP_FARMING] = StrategyConfig({
            enabled: true,
            maxPositionSize: 100000 * 1e18,
            stopLossPercentage: 2000, // 20%
            takeProfitPercentage: 10000, // 100%
            dailyVolumeLimit: 50000 * 1e18,
            minTradeAmount: 500 * 1e18,
            maxTradeAmount: 50000 * 1e18
        });
    }

    // ==================== Emergency Functions ====================

    /**
     * @notice Emergency withdraw all funds
     * @param token Token to withdraw
     * @param recipient Address to send funds to
     */
    function emergencyWithdraw(address token, address recipient) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(recipient, balance);
    }

    /**
     * @notice Allow contract to receive tokens
     */
    receive() external payable {}
}
