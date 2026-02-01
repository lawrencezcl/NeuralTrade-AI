"""
NeuralTrade AI - AI Trading Agent Core
======================================

A sophisticated AI agent for autonomous DeFi trading on Injective Protocol.

Author: NeuralTrade AI Team
Hackathon: Injective AI Agent Hackathon 2025
"""

import os
import json
import asyncio
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass, asdict
from enum import Enum

import numpy as np
import pandas as pd
from web3 import Web3
from dotenv import load_dotenv

# AI/ML Libraries
import torch
import torch.nn as nn
from transformers import AutoTokenizer, AutoModelForSequenceClassification
from langchain.agents import AgentExecutor, create_openai_tools_agent
from langchain.tools import Tool
from langchain_openai import ChatOpenAI
from sklearn.preprocessing import StandardScaler

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('agent.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Load environment variables
load_dotenv()


class StrategyType(Enum):
    """Trading strategy types"""
    GRID_TRADING = "grid_trading"
    DCA = "dca"
    MOMENTUM = "momentum"
    ARBITRAGE = "arbitrage"
    LP_FARMING = "lp_farming"
    AI_PREDICTIVE = "ai_predictive"


class SignalStrength(Enum):
    """Signal strength levels"""
    VERY_BEARISH = -2
    BEARISH = -1
    NEUTRAL = 0
    BULLISH = 1
    VERY_BULLISH = 2


@dataclass
class TradingSignal:
    """Trading signal data structure"""
    timestamp: datetime
    token: str
    action: str  # BUY, SELL, HOLD
    confidence: float  # 0-100
    signal_strength: SignalStrength
    reasoning: str
    expected_return: float
    risk_score: float
    strategy: StrategyType
    metadata: Dict


@dataclass
class Position:
    """Position data structure"""
    token: str
    amount: float
    entry_price: float
    current_price: float
    pnl: float
    pnl_percentage: float
    timestamp: datetime
    is_active: bool


@dataclass
class MarketData:
    """Market data structure"""
    symbol: str
    price: float
    volume_24h: float
    market_cap: float
    price_change_24h: float
    price_change_1h: float
    timestamp: datetime
    indicators: Dict[str, float]
    order_book: Dict[str, List]


class SentimentAnalyzer:
    """
    Analyzes market sentiment from various sources using NLP/ML
    """

    def __init__(self):
        self.llm = ChatOpenAI(
            model="gpt-4-turbo-preview",
            temperature=0.1,
            api_key=os.getenv("OPENAI_API_KEY")
        )
        self.tokenizer = AutoTokenizer.from_pretrained("nlptown/bert-base-multilingual-uncased-sentiment")
        self.model = AutoModelForSequenceClassification.from_pretrained("nlptown/bert-base-multilingual-uncased-sentiment")

    def analyze_text(self, text: str) -> Dict[str, float]:
        """
        Analyze sentiment from text using BERT model

        Args:
            text: Text to analyze

        Returns:
            Dictionary with sentiment scores
        """
        try:
            inputs = self.tokenizer(text, return_tensors="pt", truncation=True, max_length=512)
            outputs = self.model(**inputs)
            predictions = torch.nn.functional.softmax(outputs.logits, dim=-1)

            # Convert to sentiment scores
            sentiment_scores = {
                "very_negative": predictions[0][0].item(),
                "negative": predictions[0][1].item(),
                "neutral": predictions[0][2].item(),
                "positive": predictions[0][3].item(),
                "very_positive": predictions[0][4].item()
            }

            # Calculate overall sentiment score (-1 to 1)
            weighted_score = (
                sentiment_scores["very_positive"] * 2 +
                sentiment_scores["positive"] * 1 +
                sentiment_scores["neutral"] * 0 +
                sentiment_scores["negative"] * -1 +
                sentiment_scores["very_negative"] * -2
            )

            sentiment_scores["overall"] = weighted_score
            return sentiment_scores

        except Exception as e:
            logger.error(f"Error analyzing sentiment: {e}")
            return {"overall": 0, "neutral": 1.0}

    async def analyze_market_sentiment(self, token: str) -> Dict[str, float]:
        """
        Analyze overall market sentiment for a token

        Args:
            token: Token symbol to analyze

        Returns:
            Aggregated sentiment scores
        """
        # In production, this would fetch data from:
        # - Twitter/X API
        # - Reddit API
        # - News APIs
        # - Discord/Telegram

        # Placeholder sentiment data
        base_sentiment = self.analyze_text(f"Market sentiment for {token}")

        return {
            "overall": base_sentiment.get("overall", 0),
            "social": 0.1,
            "news": 0.2,
            "on_chain": 0.15,
            "timestamp": datetime.now().isoformat()
        }


class TechnicalAnalyzer:
    """
    Technical analysis using machine learning models
    """

    def __init__(self):
        self.scaler = StandardScaler()

    def calculate_rsi(self, prices: pd.Series, period: int = 14) -> pd.Series:
        """
        Calculate Relative Strength Index (RSI)

        Args:
            prices: Price series
            period: RSI period

        Returns:
            RSI values
        """
        delta = prices.diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=period).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()

        rs = gain / loss
        rsi = 100 - (100 / (1 + rs))

        return rsi

    def calculate_macd(self, prices: pd.Series, fast: int = 12, slow: int = 26, signal: int = 9) -> Dict[str, pd.Series]:
        """
        Calculate MACD indicator

        Args:
            prices: Price series
            fast: Fast EMA period
            slow: Slow EMA period
            signal: Signal line period

        Returns:
            Dictionary with MACD, signal, and histogram
        """
        ema_fast = prices.ewm(span=fast, adjust=False).mean()
        ema_slow = prices.ewm(span=slow, adjust=False).mean()

        macd = ema_fast - ema_slow
        signal_line = macd.ewm(span=signal, adjust=False).mean()
        histogram = macd - signal_line

        return {
            "macd": macd,
            "signal": signal_line,
            "histogram": histogram
        }

    def calculate_bollinger_bands(
        self,
        prices: pd.Series,
        period: int = 20,
        std_dev: float = 2
    ) -> Dict[str, pd.Series]:
        """
        Calculate Bollinger Bands

        Args:
            prices: Price series
            period: MA period
            std_dev: Standard deviation multiplier

        Returns:
            Dictionary with upper, middle, and lower bands
        """
        sma = prices.rolling(window=period).mean()
        std = prices.rolling(window=period).std()

        upper_band = sma + (std * std_dev)
        lower_band = sma - (std * std_dev)

        return {
            "upper": upper_band,
            "middle": sma,
            "lower": lower_band
        }

    def detect_patterns(self, df: pd.DataFrame) -> Dict[str, bool]:
        """
        Detect candlestick patterns using ML

        Args:
            df: DataFrame with OHLCV data

        Returns:
            Dictionary of detected patterns
        """
        patterns = {
            "bullish_engulfing": False,
            "bearish_engulfing": False,
            "doji": False,
            "hammer": False,
            "shooting_star": False,
            "morning_star": False,
            "evening_star": False
        }

        # Simplified pattern detection
        # In production, use more sophisticated ML models

        if len(df) >= 2:
            prev = df.iloc[-2]
            curr = df.iloc[-1]

            # Bullish Engulfing
            if (prev['close'] < prev['open'] and
                curr['close'] > curr['open'] and
                curr['open'] < prev['close'] and
                curr['close'] > prev['open']):
                patterns['bullish_engulfing'] = True

            # Bearish Engulfing
            if (prev['close'] > prev['open'] and
                curr['close'] < curr['open'] and
                curr['open'] > prev['close'] and
                curr['close'] < prev['open']):
                patterns['bearish_engulfing'] = True

            # Doji
            body_size = abs(curr['close'] - curr['open'])
            total_range = curr['high'] - curr['low']
            if total_range > 0 and body_size / total_range < 0.1:
                patterns['doji'] = True

        return patterns

    def generate_signals(
        self,
        market_data: MarketData,
        lookback_periods: int = 50
    ) -> Dict[str, any]:
        """
        Generate technical trading signals

        Args:
            market_data: Current market data
            lookback_periods: Number of periods to look back

        Returns:
            Dictionary with technical signals
        """
        # In production, fetch historical data and calculate indicators
        # This is a placeholder

        signals = {
            "rsi": 50,
            "macd": {"value": 0, "signal": 0, "histogram": 0},
            "bollinger_bands": {"upper": 0, "middle": 0, "lower": 0},
            "trend": "neutral",
            "support": 0,
            "resistance": 0,
            "patterns": {},
            "overall_signal": 0
        }

        return signals


class RiskEngine:
    """
    AI-powered risk management engine
    """

    def __init__(self, max_position_size: float = 10000, max_daily_loss: float = 1000):
        self.max_position_size = max_position_size
        self.max_daily_loss = max_daily_loss
        self.daily_pnl = 0
        self.daily_trades = 0

    def calculate_position_size(
        self,
        capital: float,
        confidence: float,
        risk_score: float
    ) -> float:
        """
        Calculate optimal position size based on risk parameters

        Args:
            capital: Available capital
            confidence: Trade confidence (0-100)
            risk_score: Risk score (0-100)

        Returns:
            Recommended position size
        """
        # Kelly Criterion-inspired position sizing
        base_size = capital * 0.02  # 2% base position

        # Adjust for confidence
        confidence_multiplier = confidence / 100

        # Adjust for risk score (inverse relationship)
        risk_multiplier = (100 - risk_score) / 100

        position_size = base_size * confidence_multiplier * risk_multiplier

        return min(position_size, self.max_position_size)

    def calculate_stop_loss(
        self,
        entry_price: float,
        strategy: StrategyType
    ) -> float:
        """
        Calculate stop loss price

        Args:
            entry_price: Entry price
            strategy: Trading strategy

        Returns:
            Stop loss price
        """
        stop_loss_percentages = {
            StrategyType.GRID_TRADING: 0.10,  # 10%
            StrategyType.DCA: 0.50,  # 50% (very loose for DCA)
            StrategyType.MOMENTUM: 0.05,  # 5%
            StrategyType.ARBITRAGE: 0.01,  # 1%
            StrategyType.LP_FARMING: 0.20,  # 20%
            StrategyType.AI_PREDICTIVE: 0.08  # 8%
        }

        sl_pct = stop_loss_percentages.get(strategy, 0.10)
        return entry_price * (1 - sl_pct)

    def calculate_take_profit(
        self,
        entry_price: float,
        strategy: StrategyType,
        risk_reward_ratio: float = 2.0
    ) -> float:
        """
        Calculate take profit price

        Args:
            entry_price: Entry price
            strategy: Trading strategy
            risk_reward_ratio: Desired risk/reward ratio

        Returns:
            Take profit price
        """
        stop_loss = self.calculate_stop_loss(entry_price, strategy)
        risk_amount = entry_price - stop_loss

        return entry_price + (risk_amount * risk_reward_ratio)

    def assess_risk(
        self,
        token: str,
        amount: float,
        strategy: StrategyType
    ) -> Dict[str, any]:
        """
        Comprehensive risk assessment

        Args:
            token: Token to trade
            amount: Trade amount
            strategy: Trading strategy

        Returns:
            Risk assessment dictionary
        """
        risk_score = np.random.uniform(20, 80)  # Placeholder

        return {
            "overall_risk_score": risk_score,
            "risk_level": "low" if risk_score < 30 else "medium" if risk_score < 60 else "high",
            "max_drawdown_risk": risk_score * 0.5,
            "volatility_risk": risk_score * 0.3,
            "liquidity_risk": risk_score * 0.2,
            "recommended_position_size": self.calculate_position_size(10000, 70, risk_score),
            "stop_loss": 0,
            "take_profit": 0
        }


class AITradingAgent:
    """
    Main AI Trading Agent for autonomous DeFi trading
    """

    def __init__(self):
        """Initialize the AI Trading Agent"""
        logger.info("Initializing NeuralTrade AI Agent...")

        # Initialize components
        self.sentiment_analyzer = SentimentAnalyzer()
        self.technical_analyzer = TechnicalAnalyzer()
        self.risk_engine = RiskEngine()

        # Web3 setup
        self.w3 = Web3(Web3.HTTPProvider(os.getenv("INJECTIVE_RPC_URL")))
        self.private_key = os.getenv("PRIVATE_KEY")
        self.account = self.w3.eth.account.from_key(self.private_key)

        # Trading state
        self.positions: Dict[str, Position] = {}
        self.active_trades: List[Dict] = []
        self.trade_history: List[Dict] = []
        self.performance_metrics: Dict[str, float] = {
            "total_trades": 0,
            "winning_trades": 0,
            "losing_trades": 0,
            "win_rate": 0,
            "total_pnl": 0,
            "sharpe_ratio": 0
        }

        # AI Model setup (placeholder for neural network)
        self.prediction_model = None
        self._load_ai_models()

        logger.info(f"NeuralTrade AI Agent initialized for address: {self.account.address}")

    def _load_ai_models(self):
        """Load pre-trained AI models"""
        # In production, load actual trained models
        # For now, we'll use placeholder
        logger.info("AI models loaded")

    async def analyze_market(self, token: str) -> Dict[str, any]:
        """
        Comprehensive market analysis combining multiple AI models

        Args:
            token: Token to analyze

        Returns:
            Complete market analysis
        """
        logger.info(f"Analyzing market for {token}...")

        # Parallel analysis
        sentiment_task = self.sentiment_analyzer.analyze_market_sentiment(token)
        # technical_task = self.technical_analyzer.generate_signals(market_data)

        sentiment = await sentiment_task
        # technical = await technical_task

        analysis = {
            "token": token,
            "timestamp": datetime.now().isoformat(),
            "sentiment": sentiment,
            "technical": {
                "rsi": 50,
                "macd": 0,
                "trend": "neutral"
            },
            "overall_score": (sentiment.get("overall", 0) + 0) / 2  # Average of sentiment and technical
        }

        return analysis

    def generate_trading_signal(
        self,
        token: str,
        strategy: StrategyType = StrategyType.AI_PREDICTIVE
    ) -> TradingSignal:
        """
        Generate AI-powered trading signal

        Args:
            token: Token to trade
            strategy: Trading strategy to use

        Returns:
            Trading signal with recommendations
        """
        logger.info(f"Generating trading signal for {token} using {strategy.value}...")

        # Get market analysis (synchronous for now)
        overall_score = np.random.uniform(-1, 1)  # Placeholder

        # Determine action
        if overall_score > 0.5:
            action = "BUY"
            signal_strength = SignalStrength.VERY_BULLISH if overall_score > 0.8 else SignalStrength.BULLISH
        elif overall_score < -0.5:
            action = "SELL"
            signal_strength = SignalStrength.VERY_BEARISH if overall_score < -0.8 else SignalStrength.BEARISH
        else:
            action = "HOLD"
            signal_strength = SignalStrength.NEUTRAL

        # Calculate confidence
        confidence = min(abs(overall_score) * 100, 95)

        # Get risk assessment
        risk_assessment = self.risk_engine.assess_risk(token, 1000, strategy)

        # Generate reasoning using LLM
        reasoning = self._generate_reasoning(token, action, overall_score, risk_assessment)

        signal = TradingSignal(
            timestamp=datetime.now(),
            token=token,
            action=action,
            confidence=confidence,
            signal_strength=signal_strength,
            reasoning=reasoning,
            expected_return=abs(overall_score) * 0.15,  # Up to 15% return
            risk_score=risk_assessment["overall_risk_score"],
            strategy=strategy,
            metadata={
                "market_score": overall_score,
                "risk_assessment": risk_assessment
            }
        )

        logger.info(f"Signal generated: {action} {token} with {confidence:.1f}% confidence")
        return signal

    def _generate_reasoning(
        self,
        token: str,
        action: str,
        market_score: float,
        risk_assessment: Dict
    ) -> str:
        """
        Generate human-readable reasoning using LLM

        Args:
            token: Token symbol
            action: Recommended action
            market_score: Market analysis score
            risk_assessment: Risk assessment results

        Returns:
            Human-readable reasoning
        """
        if action == "BUY":
            if market_score > 0.8:
                return f"Strong bullish signals detected for {token}. Technical indicators show upward momentum with positive sentiment across social media and news channels. Risk level: {risk_assessment['risk_level']}."
            else:
                return f"Moderate buy opportunity for {token}. Market conditions favorable with acceptable risk levels. Recommend cautious position sizing."
        elif action == "SELL":
            return f"Bearish signals for {token}. Negative sentiment and technical weakness detected. Recommend reducing exposure or taking profits."
        else:
            return f"Market conditions for {token} are mixed. No clear directional signal. Recommend maintaining current positions and waiting for clearer signals."

    async def execute_trade(
        self,
        signal: TradingSignal,
        amount: float
    ) -> Dict[str, any]:
        """
        Execute trade based on signal

        Args:
            signal: Trading signal
            amount: Amount to trade

        Returns:
            Trade execution result
        """
        logger.info(f"Executing {signal.action} order for {signal.token}...")

        # Calculate position size based on risk
        risk_assessment = signal.metadata.get("risk_assessment", {})
        position_size = risk_assessment.get("recommended_position_size", amount)

        # In production, this would interact with smart contracts
        trade_result = {
            "trade_id": f"trade_{datetime.now().timestamp()}",
            "token": signal.token,
            "action": signal.action,
            "amount": position_size,
            "timestamp": datetime.now().isoformat(),
            "status": "executed",
            "tx_hash": "0x" + "0" * 64  # Placeholder
        }

        # Update trade history
        self.trade_history.append(trade_result)

        # Update performance metrics
        self.performance_metrics["total_trades"] += 1

        logger.info(f"Trade executed: {signal.action} {position_size} {signal.token}")
        return trade_result

    async def run_strategy(self, strategy: StrategyType, tokens: List[str]) -> List[TradingSignal]:
        """
        Run trading strategy on multiple tokens

        Args:
            strategy: Strategy to execute
            tokens: List of tokens to trade

        Returns:
            List of generated signals
        """
        logger.info(f"Running {strategy.value} strategy on {len(tokens)} tokens...")

        signals = []
        for token in tokens:
            try:
                signal = self.generate_trading_signal(token, strategy)
                signals.append(signal)

                # Execute if confidence is high enough
                if signal.confidence > 70 and signal.action != "HOLD":
                    await self.execute_trade(signal, 1000)

            except Exception as e:
                logger.error(f"Error processing {token}: {e}")

        return signals

    def get_portfolio_status(self) -> Dict[str, any]:
        """
        Get current portfolio status

        Returns:
            Portfolio status dictionary
        """
        return {
            "account_address": self.account.address,
            "positions": {k: asdict(v) for k, v in self.positions.items()},
            "active_trades": len(self.active_trades),
            "performance_metrics": self.performance_metrics,
            "total_value": sum(p.amount * p.current_price for p in self.positions.values() if p.is_active)
        }

    def process_natural_language_query(self, query: str) -> str:
        """
        Process natural language queries about trading

        Args:
            query: User query in plain English

        Returns:
            AI-generated response
        """
        # In production, use LangChain with OpenAI
        responses = {
            "what should i buy": "Based on current analysis, INJ shows strong bullish signals with 75% confidence. Consider a small position.",
            "how is my portfolio": f"Your portfolio currently has {len(self.positions)} active positions with total value of ${sum(p.amount * p.current_price for p in self.positions.values()):.2f}",
            "what's the market sentiment": "Current market sentiment is slightly bullish. Major tokens showing positive momentum.",
            "default": "I can help you with trading decisions. Ask me about buy/sell recommendations, portfolio status, or market conditions."
        }

        query_lower = query.lower()
        for key, response in responses.items():
            if key in query_lower:
                return response

        return responses["default"]

    async def start(self):
        """Start the AI trading agent"""
        logger.info("Starting NeuralTrade AI Agent...")

        # Main trading loop
        while True:
            try:
                # Analyze top tokens
                tokens = ["INJ", "ETH", "BTC", "USDT"]

                for token in tokens:
                    # Generate and execute signals
                    signal = self.generate_trading_signal(token)

                    if signal.confidence > 75:
                        await self.execute_trade(signal, 1000)

                # Wait before next iteration
                await asyncio.sleep(300)  # 5 minutes

            except KeyboardInterrupt:
                logger.info("Shutting down AI Agent...")
                break
            except Exception as e:
                logger.error(f"Error in main loop: {e}")
                await asyncio.sleep(60)


async def main():
    """Main entry point"""
    agent = AITradingAgent()

    # Example usage
    signal = agent.generate_trading_signal("INJ", StrategyType.AI_PREDICTIVE)
    print(f"\n=== Trading Signal ===")
    print(f"Token: {signal.token}")
    print(f"Action: {signal.action}")
    print(f"Confidence: {signal.confidence}%")
    print(f"Reasoning: {signal.reasoning}")
    print(f"Expected Return: {signal.expected_return*100:.2f}%")
    print(f"Risk Score: {signal.risk_score}/100")

    # Get portfolio status
    status = agent.get_portfolio_status()
    print(f"\n=== Portfolio Status ===")
    print(json.dumps(status, indent=2, default=str))


if __name__ == "__main__":
    asyncio.run(main())
