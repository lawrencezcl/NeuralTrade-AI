# NeuralTrade AI - API Reference

## Smart Contract APIs

### TradingAgent Contract

#### executeTrade

Execute a trade based on AI signal.

```solidity
function executeTrade(
    address inputToken,
    address outputToken,
    uint256 inputAmount,
    uint256 minOutputAmount,
    Strategy strategy,
    string calldata aiReasoning
) external onlyAuthorizedAI notPaused nonReentrant returns (uint256 tradeId)
```

**Parameters:**
- `inputToken`: Token to sell
- `outputToken`: Token to buy
- `inputAmount`: Amount of input token (in wei)
- `minOutputAmount`: Minimum output amount (slippage protection)
- `strategy`: Trading strategy enum
- `aiReasoning`: AI's explanation for the trade

**Returns:**
- `tradeId`: ID of the executed trade

**Example:**
```javascript
const tx = await tradingAgent.executeTrade(
  injTokenAddress,
  usdtTokenAddress,
  ethers.parseEther("100"),
  ethers.parseEther("2800"),
  0, // MOMENTUM strategy
  "Strong bullish signals detected"
);
```

---

#### executeGridTrade

Execute grid trading strategy.

```solidity
function executeGridTrade(
    address baseToken,
    address quoteToken,
    uint256 gridCount,
    uint256 gridSpacing,
    uint256 lowerBound,
    uint256 upperBound
) external onlyAuthorizedAI notPaused
```

**Parameters:**
- `baseToken`: Base asset for grid
- `quoteToken`: Quote asset for grid
- `gridCount`: Number of grid levels (1-50)
- `gridSpacing`: Spacing between grids in basis points
- `lowerBound`: Lower price bound (in wei)
- `upperBound`: Upper price bound (in wei)

---

#### closePosition

Close an active position.

```solidity
function closePosition(
    address token,
    uint256 amount
) external onlyAuthorizedAI notPaused
```

---

## REST API Endpoints

### Base URL
```
https://api.neuraltrade-ai.com/v1
```

### Authentication
Include API key in header:
```
Authorization: Bearer YOUR_API_KEY
```

---

### POST /api/v1/signals

Generate a trading signal.

**Request:**
```json
{
  "token": "INJ",
  "strategy": "momentum",
  "timeframe": "1h"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "token": "INJ",
    "action": "BUY",
    "confidence": 85.5,
    "signal_strength": "BULLISH",
    "reasoning": "Strong bullish momentum detected...",
    "expected_return": 0.12,
    "risk_score": 35,
    "timestamp": "2025-02-01T10:30:00Z"
  }
}
```

---

### GET /api/v1/portfolio

Get portfolio status.

**Response:**
```json
{
  "success": true,
  "data": {
    "total_value": 10950.00,
    "total_pnl": 950.00,
    "total_pnl_percentage": 9.5,
    "win_rate": 68.5,
    "total_trades": 156,
    "sharpe_ratio": 1.85,
    "positions": [
      {
        "token": "INJ",
        "amount": 100,
        "entry_price": 35.50,
        "current_price": 38.20,
        "pnl": 270.00,
        "pnl_percentage": 7.6,
        "is_active": true
      }
    ]
  }
}
```

---

### POST /api/v1/chat

Send chat message to AI agent.

**Request:**
```json
{
  "message": "What should I buy right now?"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "response": "Based on my analysis, INJ shows strong bullish signals with 78% confidence...",
    "suggestions": [
      {"token": "INJ", "action": "BUY", "confidence": 78}
    ]
  }
}
```

---

## Python API

### AITradingAgent Class

```python
from agent.main import AITradingAgent, StrategyType

# Initialize agent
agent = AITradingAgent()

# Generate trading signal
signal = agent.generate_trading_signal(
    token="INJ",
    strategy=StrategyType.MOMENTUM
)

# Access signal properties
print(signal.action)        # "BUY"
print(signal.confidence)    # 85.5
print(signal.reasoning)     # "Strong bullish signals..."

# Execute trade
result = await agent.execute_trade(signal, amount=1000)

# Get portfolio status
status = agent.get_portfolio_status()
```

---

## JavaScript/Web3 API

### Frontend Integration

```javascript
import { TradingAgent } from '@neuraltrade/contracts';

// Connect to Injective
const provider = new ethers.JsonRpcProvider(INJECTIVE_RPC_URL);
const signer = new ethers.Wallet(PRIVATE_KEY, provider);

// Get contract instance
const tradingAgent = new ethers.Contract(
  TRADING_AGENT_ADDRESS,
  TradingAgentABI,
  signer
);

// Execute trade
const tx = await tradingAgent.executeTrade(
  INJ_TOKEN_ADDRESS,
  USDT_TOKEN_ADDRESS,
  ethers.parseEther("100"),
  ethers.parseEther("2800"),
  0, // Strategy.MOMENTUM
  "AI reasoning here..."
);

await tx.wait();
```

---

## WebSocket API

### Connect to Real-time Updates

```javascript
const ws = new WebSocket('wss://api.neuraltrade-ai.com/ws');

ws.onopen = () => {
  // Subscribe to signals
  ws.send(JSON.stringify({
    action: 'subscribe',
    channel: 'signals',
    tokens: ['INJ', 'ETH', 'BTC']
  }));
};

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log('New signal:', data);
};
```

---

## Rate Limits

| Endpoint | Rate Limit |
|----------|------------|
| POST /signals | 10/minute |
| GET /portfolio | 60/minute |
| POST /chat | 20/minute |
| WebSocket | 100 connections/hour |

---

## Error Codes

| Code | Description |
|------|-------------|
| 400 | Bad Request |
| 401 | Unauthorized |
| 429 | Rate Limit Exceeded |
| 500 | Internal Server Error |
| 503 | Service Unavailable |

---

## Webhooks

### Configure Webhook

Receive notifications for important events:

```bash
POST /api/v1/webhooks
{
  "url": "https://your-server.com/webhook",
  "events": ["trade_executed", "signal_generated", "risk_alert"]
}
```

**Webhook Payload:**
```json
{
  "event": "trade_executed",
  "timestamp": "2025-02-01T10:30:00Z",
  "data": {
    "trade_id": "12345",
    "token": "INJ",
    "action": "BUY",
    "amount": 100
  }
}
```

---

For more information, visit:
- Documentation: https://docs.neuraltrade-ai.com
- GitHub: https://github.com/neuraltrade-ai
- Discord: https://discord.gg/neuraltrade-ai
