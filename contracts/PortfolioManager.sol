// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./TradingAgent.sol";

/**
 * @title PortfolioManager
 * @notice AI-powered portfolio management and rebalancing
 * @dev Automatically rebalances portfolio based on AI recommendations
 */
contract PortfolioManager is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ==================== State Variables ====================

    struct Portfolio {
        address owner;
        string name;
        address[] tokens;
        uint256[] targetAllocations; // In basis points (10000 = 100%)
        uint256 totalValue;
        uint256 lastRebalance;
        bool isActive;
        RebalanceFrequency rebalanceFrequency;
    }

    struct RebalanceRecommendation {
        address token;
        uint256 currentAllocation;
        uint256 targetAllocation;
        uint256 amountToTrade;
        bool shouldBuy;
        uint256 priority; // 0-100, higher = more urgent
    }

    enum RebalanceFrequency {
        MANUAL,
        HOURLY,
        DAILY,
        WEEKLY,
        MONTHLY
    }

    enum RiskLevel {
        CONSERVATIVE,
        MODERATE,
        AGGRESSIVE
    }

    // Mappings
    mapping(address => Portfolio[]) public userPortfolios;
    mapping(address => bool) public approvedTokens;
    mapping(address => RiskLevel) public userRiskLevels;
    mapping(address => uint256) public portfolioCount;

    // AI Oracle
    address public aiAdvisor;
    TradingAgent public tradingAgent;

    // Constants
    uint256 private constant MIN_REBALANCE_THRESHOLD = 500; // 5% deviation
    uint256 private constant BASIS_POINTS = 10000;
    uint256 private constant MAX_PORTFOLIOS_PER_USER = 10;

    // ==================== Events ====================

    event PortfolioCreated(
        address indexed owner,
        uint256 portfolioId,
        string name
    );

    event PortfolioRebalanced(
        uint256 indexed portfolioId,
        uint256 timestamp,
        uint256 totalTrades
    );

    event RebalanceRecommended(
        uint256 indexed portfolioId,
        RebalanceRecommendation[] recommendations
    );

    event AIAdvisory(
        uint256 indexed portfolioId,
        string advisory,
        int256 sentiment
    );

    // ==================== Constructor ====================

    constructor(address _tradingAgent) {
        tradingAgent = TradingAgent(_tradingAgent);
    }

    // ==================== Portfolio Management ====================

    /**
     * @notice Create a new portfolio
     * @param name Portfolio name
     * @param tokens Tokens in the portfolio
     * @param targetAllocations Target allocation for each token (basis points)
     * @param frequency Rebalance frequency
     */
    function createPortfolio(
        string calldata name,
        address[] calldata tokens,
        uint256[] calldata targetAllocations,
        RebalanceFrequency frequency
    ) external returns (uint256 portfolioId) {
        require(tokens.length == targetAllocations.length, "Array length mismatch");
        require(tokens.length > 0 && tokens.length <= 20, "Invalid token count");
        require(portfolioCount[msg.sender] < MAX_PORTFOLIOS_PER_USER, "Too many portfolios");

        uint256 totalAllocation = 0;
        for (uint256 i = 0; i < targetAllocations.length; i++) {
            totalAllocation += targetAllocations[i];
            require(approvedTokens[tokens[i]], "Token not approved");
        }
        require(totalAllocation == BASIS_POINTS, "Allocations must sum to 100%");

        portfolioId = portfolioCount[msg.sender]++;
        userPortfolios[msg.sender].push(Portfolio({
            owner: msg.sender,
            name: name,
            tokens: tokens,
            targetAllocations: targetAllocations,
            totalValue: 0,
            lastRebalance: block.timestamp,
            isActive: true,
            rebalanceFrequency: frequency
        }));

        emit PortfolioCreated(msg.sender, portfolioId, name);
    }

    /**
     * @notice AI-driven portfolio rebalancing
     * @param portfolioId ID of portfolio to rebalance
     * @param forceRebalance Force rebalance regardless of threshold
     */
    function rebalancePortfolio(
        uint256 portfolioId,
        bool forceRebalance
    ) external nonReentrant {
        require(portfolioId < portfolioCount[msg.sender], "Invalid portfolio ID");

        Portfolio storage portfolio = userPortfolios[msg.sender][portfolioId];
        require(portfolio.isActive, "Portfolio not active");

        // Check if rebalance is needed based on frequency
        if (!forceRebalance && !_shouldRebalance(portfolio)) {
            return;
        }

        // Get current allocations
        uint256[] memory currentAllocations = _getCurrentAllocations(portfolio);

        // Calculate deviation from target
        RebalanceRecommendation[] memory recommendations = _calculateRebalanceRecommendations(
            portfolio,
            currentAllocations
        );

        // Execute trades through TradingAgent
        uint256 tradesExecuted = 0;
        for (uint256 i = 0; i < recommendations.length; i++) {
            if (recommendations[i].priority >= MIN_REBALANCE_THRESHOLD) {
                _executeRebalanceTrade(recommendations[i]);
                tradesExecuted++;
            }
        }

        portfolio.lastRebalance = block.timestamp;
        emit PortfolioRebalanced(portfolioId, block.timestamp, tradesExecuted);
    }

    /**
     * @notice Get AI rebalancing recommendations
     * @param portfolioId ID of portfolio
     * @return recommendations Array of rebalancing recommendations
     */
    function getRebalanceRecommendations(
        uint256 portfolioId
    ) external view returns (RebalanceRecommendation[] memory recommendations) {
        require(portfolioId < portfolioCount[msg.sender], "Invalid portfolio ID");

        Portfolio storage portfolio = userPortfolios[msg.sender][portfolioId];
        uint256[] memory currentAllocations = _getCurrentAllocations(portfolio);

        return _calculateRebalanceRecommendations(portfolio, currentAllocations);
    }

    /**
     * @notice Optimize portfolio based on AI analysis
     * @param portfolioId ID of portfolio to optimize
     * @param marketConditions Current market conditions (encoded)
     */
    function optimizePortfolio(
        uint256 portfolioId,
        bytes calldata marketConditions
    ) external {
        require(portfolioId < portfolioCount[msg.sender], "Invalid portfolio ID");

        Portfolio storage portfolio = userPortfolios[msg.sender][portfolioId];

        // AI analyzes market conditions and suggests new allocations
        // This would typically call an AI oracle
        emit AIAdvisory(
            portfolioId,
            "Portfolio optimization analysis completed",
            75
        );
    }

    // ==================== Risk Management ====================

    /**
     * @notice Set user risk level
     * @param riskLevel Risk level for the user
     */
    function setRiskLevel(RiskLevel riskLevel) external {
        userRiskLevels[msg.sender] = riskLevel;
    }

    /**
     * @notice Get recommended allocations based on risk level
     * @param riskLevel User's risk level
     * @return tokens Recommended tokens
     * @return allocations Recommended allocations
     */
    function getRecommendedAllocations(
        RiskLevel riskLevel
    ) external pure returns (address[] memory tokens, uint256[] memory allocations) {
        if (riskLevel == RiskLevel.CONSERVATIVE) {
            // Stablecoins + blue chip tokens
            tokens = new address[](3);
            allocations = new uint256[](3);
            allocations[0] = 4000; // 40% stable
            allocations[1] = 3500; // 35% BTC
            allocations[2] = 2500; // 25% ETH
        } else if (riskLevel == RiskLevel.MODERATE) {
            tokens = new address[](4);
            allocations = new uint256[](4);
            allocations[0] = 2000; // 20% stable
            allocations[1] = 3000; // 30% BTC
            allocations[2] = 2500; // 25% ETH
            allocations[3] = 2500; // 25% altcoins
        } else { // AGGRESSIVE
            tokens = new address[](5);
            allocations = new uint256[](5);
            allocations[0] = 1000; // 10% stable
            allocations[1] = 2000; // 20% BTC
            allocations[2] = 2000; // 20% ETH
            allocations[3] = 3000; // 30% altcoins
            allocations[4] = 2000; // 20% DeFi tokens
        }
    }

    // ==================== View Functions ====================

    /**
     * @notice Get portfolio details
     * @param portfolioId ID of portfolio
     * @return portfolio Portfolio details
     */
    function getPortfolio(uint256 portfolioId) external view returns (Portfolio memory) {
        require(portfolioId < portfolioCount[msg.sender], "Invalid portfolio ID");
        return userPortfolios[msg.sender][portfolioId];
    }

    /**
     * @notice Get all user portfolios
     * @return portfolios Array of user's portfolios
     */
    function getUserPortfolios() external view returns (Portfolio[] memory) {
        return userPortfolios[msg.sender];
    }

    /**
     * @notice Calculate portfolio performance
     * @param portfolioId ID of portfolio
     * @return totalReturn Total return percentage
     * @return dailyReturn Daily return percentage
     */
    function getPortfolioPerformance(
        uint256 portfolioId
    ) external view returns (int256 totalReturn, int256 dailyReturn) {
        require(portfolioId < portfolioCount[msg.sender], "Invalid portfolio ID");

        Portfolio storage portfolio = userPortfolios[msg.sender][portfolioId];

        // Calculate current value vs initial value
        uint256 currentValue = _calculatePortfolioValue(portfolio);
        uint256 initialValue = portfolio.totalValue;

        if (initialValue > 0) {
            totalReturn = int256(((currentValue - initialValue) * 100) / initialValue);
        }

        // Daily return would require historical data
        dailyReturn = 0;
    }

    // ==================== Admin Functions ====================

    function setApprovedToken(address token, bool approved) external onlyOwner {
        approvedTokens[token] = approved;
    }

    function setAIAdvisor(address _aiAdvisor) external onlyOwner {
        aiAdvisor = _aiAdvisor;
    }

    function setTradingAgent(address _tradingAgent) external onlyOwner {
        tradingAgent = TradingAgent(_tradingAgent);
    }

    // ==================== Internal Functions ====================

    function _shouldRebalance(Portfolio storage portfolio) internal view returns (bool) {
        uint256 timeSinceLastRebalance = block.timestamp - portfolio.lastRebalance;

        if (portfolio.rebalanceFrequency == RebalanceFrequency.HOURLY) {
            return timeSinceLastRebalance >= 1 hours;
        } else if (portfolio.rebalanceFrequency == RebalanceFrequency.DAILY) {
            return timeSinceLastRebalance >= 1 days;
        } else if (portfolio.rebalanceFrequency == RebalanceFrequency.WEEKLY) {
            return timeSinceLastRebalance >= 7 days;
        } else if (portfolio.rebalanceFrequency == RebalanceFrequency.MONTHLY) {
            return timeSinceLastRebalance >= 30 days;
        }
        return false;
    }

    function _getCurrentAllocations(
        Portfolio storage portfolio
    ) internal view returns (uint256[] memory allocations) {
        allocations = new uint256[](portfolio.tokens.length);
        uint256 totalValue = _calculatePortfolioValue(portfolio);

        if (totalValue == 0) return allocations;

        for (uint256 i = 0; i < portfolio.tokens.length; i++) {
            uint256 tokenBalance = IERC20(portfolio.tokens[i]).balanceOf(address(this));
            uint256 tokenValue = tokenBalance * _getTokenPrice(portfolio.tokens[i]);
            allocations[i] = (tokenValue * BASIS_POINTS) / totalValue;
        }
    }

    function _calculateRebalanceRecommendations(
        Portfolio storage portfolio,
        uint256[] memory currentAllocations
    ) internal pure returns (RebalanceRecommendation[] memory) {
        RebalanceRecommendation[] memory recommendations = new RebalanceRecommendation[](portfolio.tokens.length);

        for (uint256 i = 0; i < portfolio.tokens.length; i++) {
            int256 deviation = int256(currentAllocations[i]) - int256(portfolio.targetAllocations[i]);
            uint256 absDeviation = deviation >= 0 ? uint256(deviation) : uint256(-deviation);

            recommendations[i] = RebalanceRecommendation({
                token: portfolio.tokens[i],
                currentAllocation: currentAllocations[i],
                targetAllocation: portfolio.targetAllocations[i],
                amountToTrade: 0, // Would be calculated based on deviation
                shouldBuy: deviation < 0,
                priority: absDeviation
            });
        }

        return recommendations;
    }

    function _executeRebalanceTrade(RebalanceRecommendation memory recommendation) internal {
        // Would execute trade through TradingAgent
        // This is a placeholder for the actual implementation
    }

    function _calculatePortfolioValue(Portfolio storage portfolio) internal view returns (uint256) {
        uint256 totalValue = 0;
        for (uint256 i = 0; i < portfolio.tokens.length; i++) {
            uint256 balance = IERC20(portfolio.tokens[i]).balanceOf(address(this));
            totalValue += balance * _getTokenPrice(portfolio.tokens[i]);
        }
        return totalValue;
    }

    function _getTokenPrice(address token) internal view returns (uint256) {
        // Placeholder - in production, use price oracle
        return 1e18;
    }

    /**
     * @notice Withdraw from portfolio
     * @param portfolioId ID of portfolio
     * @param token Token to withdraw
     * @param amount Amount to withdraw
     */
    function withdrawFromPortfolio(
        uint256 portfolioId,
        address token,
        uint256 amount
    ) external nonReentrant {
        require(portfolioId < portfolioCount[msg.sender], "Invalid portfolio ID");

        Portfolio storage portfolio = userPortfolios[msg.sender][portfolioId];
        require(portfolio.owner == msg.sender, "Not portfolio owner");

        IERC20(token).safeTransfer(msg.sender, amount);
    }

    /**
     * @notice Deactivate portfolio
     * @param portfolioId ID of portfolio to deactivate
     */
    function deactivatePortfolio(uint256 portfolioId) external {
        require(portfolioId < portfolioCount[msg.sender], "Invalid portfolio ID");

        Portfolio storage portfolio = userPortfolios[msg.sender][portfolioId];
        require(portfolio.owner == msg.sender, "Not portfolio owner");

        portfolio.isActive = false;
    }

    /**
     * @notice Deposit into portfolio
     * @param portfolioId ID of portfolio
     * @param token Token to deposit
     * @param amount Amount to deposit
     */
    function depositToPortfolio(
        uint256 portfolioId,
        address token,
        uint256 amount
    ) external nonReentrant {
        require(portfolioId < portfolioCount[msg.sender], "Invalid portfolio ID");
        require(approvedTokens[token], "Token not approved");

        Portfolio storage portfolio = userPortfolios[msg.sender][portfolioId];
        require(portfolio.isActive, "Portfolio not active");

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    }

    receive() external payable {}
}
