/**
 * NeuralTrade AI - Frontend Dashboard
 * Main dashboard page for the AI trading agent
 */

'use client';

import React, { useState, useEffect } from 'react';
import { LineChart, Line, AreaChart, Area, BarChart, Bar, PieChart, Pie, Cell, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';

// Types
interface TradingSignal {
  timestamp: string;
  token: string;
  action: 'BUY' | 'SELL' | 'HOLD';
  confidence: number;
  reasoning: string;
  expectedReturn: number;
  riskScore: number;
}

interface Position {
  token: string;
  amount: number;
  entryPrice: number;
  currentPrice: number;
  pnl: number;
  pnlPercentage: number;
  isActive: boolean;
}

interface PortfolioMetrics {
  totalValue: number;
  totalPnl: number;
  totalPnlPercentage: number;
  winRate: number;
  totalTrades: number;
  sharpeRatio: number;
}

// Mock data
const MOCK_POSITIONS: Position[] = [
  { token: 'INJ', amount: 100, entryPrice: 35.50, currentPrice: 38.20, pnl: 270, pnlPercentage: 7.6, isActive: true },
  { token: 'ETH', amount: 2.5, entryPrice: 2800, currentPrice: 2950, pnl: 375, pnlPercentage: 5.4, isActive: true },
  { token: 'BTC', amount: 0.15, entryPrice: 52000, currentPrice: 53500, pnl: 225, pnlPercentage: 2.9, isActive: true },
];

const MOCK_SIGNALS: TradingSignal[] = [
  { timestamp: '2025-02-01T10:30:00Z', token: 'INJ', action: 'BUY', confidence: 85, reasoning: 'Strong bullish momentum detected', expectedReturn: 0.12, riskScore: 35 },
  { timestamp: '2025-02-01T09:15:00Z', token: 'ETH', action: 'HOLD', confidence: 60, reasoning: 'Mixed signals, wait for confirmation', expectedReturn: 0.02, riskScore: 50 },
];

const PERFORMANCE_DATA = [
  { day: 'Mon', value: 10200, pnl: 200 },
  { day: 'Tue', value: 10450, pnl: 250 },
  { day: 'Wed', value: 10380, pnl: -70 },
  { day: 'Thu', value: 10650, pnl: 270 },
  { day: 'Fri', value: 10820, pnl: 170 },
  { day: 'Sat', value: 10750, pnl: -70 },
  { day: 'Sun', value: 10950, pnl: 200 },
];

const STRATEGY_DATA = [
  { name: 'Grid Trading', value: 25, color: '#3b82f6' },
  { name: 'DCA', value: 30, color: '#10b981' },
  { name: 'Momentum', value: 20, color: '#f59e0b' },
  { name: 'Arbitrage', value: 15, color: '#ef4444' },
  { name: 'LP Farming', value: 10, color: '#8b5cf6' },
];

export default function DashboardPage() {
  const [positions, setPositions] = useState<Position[]>(MOCK_POSITIONS);
  const [signals, setSignals] = useState<TradingSignal[]>(MOCK_SIGNALS);
  const [isLoading, setIsLoading] = useState(false);
  const [chatInput, setChatInput] = useState('');
  const [chatMessages, setChatMessages] = useState<Array<{ role: 'user' | 'assistant', content: string }>>([
    { role: 'assistant', content: 'Hello! I\'m your AI trading assistant. Ask me anything about your portfolio, trading strategies, or market conditions.' }
  ]);

  // Calculate portfolio metrics
  const portfolioMetrics: PortfolioMetrics = {
    totalValue: positions.reduce((sum, p) => sum + (p.amount * p.currentPrice), 0),
    totalPnl: positions.reduce((sum, p) => sum + p.pnl, 0),
    totalPnlPercentage: positions.reduce((sum, p) => sum + p.pnlPercentage, 0) / positions.length,
    winRate: 68.5,
    totalTrades: 156,
    sharpeRatio: 1.85,
  };

  const handleSendMessage = async () => {
    if (!chatInput.trim()) return;

    const userMessage = chatInput;
    setChatMessages(prev => [...prev, { role: 'user', content: userMessage }]);
    setChatInput('');

    // Simulate AI response
    setTimeout(() => {
      let response = 'I\'m processing your request...';

      if (userMessage.toLowerCase().includes('buy') || userMessage.toLowerCase().includes('recommend')) {
        response = 'Based on my analysis, INJ shows strong bullish signals with 78% confidence. The technical indicators suggest upward momentum, and social sentiment is positive. I recommend a small position with proper stop-loss at $35.50.';
      } else if (userMessage.toLowerCase().includes('portfolio') || userMessage.toLowerCase().includes('how')) {
        response = `Your portfolio is currently worth $${portfolioMetrics.totalValue.toLocaleString()}. Total PnL: +$${portfolioMetrics.totalPnl} (+${portfolioMetrics.totalPnlPercentage.toFixed(1)}%). You have ${positions.length} active positions with a win rate of ${portfolioMetrics.winRate}%.`;
      } else if (userMessage.toLowerCase().includes('market') || userMessage.toLowerCase().includes('sentiment')) {
        response = 'Current market sentiment is moderately bullish. Major cryptocurrencies showing positive momentum. INJ leading gains with 12% weekly increase. No major risk events detected in the last 24 hours.';
      } else {
        response = 'I can help you with:\n• Buy/sell recommendations\n• Portfolio analysis\n• Market sentiment\n• Risk assessment\n• Trading strategies\n\nWhat would you like to know?';
      }

      setChatMessages(prev => [...prev, { role: 'assistant', content: response }]);
    }, 1000);
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-blue-900 to-gray-900 text-white">
      {/* Header */}
      <header className="border-b border-gray-800 bg-black/20 backdrop-blur-lg">
        <div className="container mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 bg-gradient-to-r from-blue-500 to-purple-600 rounded-lg flex items-center justify-center">
                <span className="text-xl">🧠</span>
              </div>
              <div>
                <h1 className="text-2xl font-bold bg-gradient-to-r from-blue-400 to-purple-400 bg-clip-text text-transparent">
                  NeuralTrade AI
                </h1>
                <p className="text-xs text-gray-400">Injective AI Agent Hackathon 2025</p>
              </div>
            </div>
            <div className="flex items-center gap-4">
              <div className="flex items-center gap-2 px-4 py-2 bg-green-500/20 border border-green-500/30 rounded-full">
                <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
                <span className="text-sm text-green-400">AI Agent Active</span>
              </div>
              <button className="px-4 py-2 bg-blue-600 hover:bg-blue-700 rounded-lg font-medium transition-colors">
                Connect Wallet
              </button>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="container mx-auto px-6 py-8">
        {/* Portfolio Overview Cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <MetricCard
            title="Portfolio Value"
            value={`$${portfolioMetrics.totalValue.toLocaleString()}`}
            change={`+$${portfolioMetrics.totalPnl} (${portfolioMetrics.totalPnlPercentage.toFixed(1)}%)`}
            positive={portfolioMetrics.totalPnl >= 0}
            icon="💰"
          />
          <MetricCard
            title="Win Rate"
            value={`${portfolioMetrics.winRate}%`}
            change="156 total trades"
            positive={true}
            icon="🎯"
          />
          <MetricCard
            title="Sharpe Ratio"
            value={portfolioMetrics.sharpeRatio.toFixed(2)}
            change="Risk-adjusted returns"
            positive={portfolioMetrics.sharpeRatio > 1}
            icon="📊"
          />
          <MetricCard
            title="Active Positions"
            value={positions.length.toString()}
            change="All performing well"
            positive={true}
            icon="📈"
          />
        </div>

        {/* Charts Row */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
          {/* Performance Chart */}
          <div className="lg:col-span-2 bg-gray-800/50 backdrop-blur rounded-xl p-6 border border-gray-700">
            <h2 className="text-xl font-semibold mb-4">Portfolio Performance</h2>
            <ResponsiveContainer width="100%" height={300}>
              <AreaChart data={PERFORMANCE_DATA}>
                <defs>
                  <linearGradient id="colorValue" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.8}/>
                    <stop offset="95%" stopColor="#3b82f6" stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
                <XAxis dataKey="day" stroke="#9ca3af" />
                <YAxis stroke="#9ca3af" />
                <Tooltip contentStyle={{ backgroundColor: '#1f2937', border: 'none', borderRadius: '8px' }} />
                <Legend />
                <Area type="monotone" dataKey="value" stroke="#3b82f6" fillOpacity={1} fill="url(#colorValue)" name="Portfolio Value ($)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>

          {/* Strategy Distribution */}
          <div className="bg-gray-800/50 backdrop-blur rounded-xl p-6 border border-gray-700">
            <h2 className="text-xl font-semibold mb-4">Strategy Distribution</h2>
            <ResponsiveContainer width="100%" height={250}>
              <PieChart>
                <Pie
                  data={STRATEGY_DATA}
                  cx="50%"
                  cy="50%"
                  innerRadius={50}
                  outerRadius={80}
                  paddingAngle={5}
                  dataKey="value"
                >
                  {STRATEGY_DATA.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={entry.color} />
                  ))}
                </Pie>
                <Tooltip contentStyle={{ backgroundColor: '#1f2937', border: 'none', borderRadius: '8px' }} />
              </PieChart>
            </ResponsiveContainer>
            <div className="mt-4 space-y-2">
              {STRATEGY_DATA.map(s => (
                <div key={s.name} className="flex items-center justify-between text-sm">
                  <div className="flex items-center gap-2">
                    <div className="w-3 h-3 rounded-full" style={{ backgroundColor: s.color }}></div>
                    <span className="text-gray-300">{s.name}</span>
                  </div>
                  <span className="text-gray-400">{s.value}%</span>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Positions and Signals */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
          {/* Active Positions */}
          <div className="bg-gray-800/50 backdrop-blur rounded-xl p-6 border border-gray-700">
            <h2 className="text-xl font-semibold mb-4">Active Positions</h2>
            <div className="space-y-3">
              {positions.map((pos, idx) => (
                <div key={idx} className="bg-gray-900/50 rounded-lg p-4 border border-gray-700">
                  <div className="flex items-center justify-between mb-2">
                    <div className="flex items-center gap-3">
                      <div className="w-10 h-10 bg-blue-500/20 rounded-lg flex items-center justify-center">
                        <span className="text-lg">🪙</span>
                      </div>
                      <div>
                        <p className="font-semibold">{pos.token}</p>
                        <p className="text-sm text-gray-400">{pos.amount} tokens</p>
                      </div>
                    </div>
                    <div className="text-right">
                      <p className="font-semibold">${pos.currentPrice.toFixed(2)}</p>
                      <p className={`text-sm ${pos.pnl >= 0 ? 'text-green-400' : 'text-red-400'}`}>
                        {pos.pnl >= 0 ? '+' : ''}${pos.pnl} ({pos.pnlPercentage >= 0 ? '+' : ''}{pos.pnlPercentage}%)
                      </p>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* AI Signals */}
          <div className="bg-gray-800/50 backdrop-blur rounded-xl p-6 border border-gray-700">
            <h2 className="text-xl font-semibold mb-4">Latest AI Signals</h2>
            <div className="space-y-3">
              {signals.map((signal, idx) => (
                <div key={idx} className="bg-gray-900/50 rounded-lg p-4 border border-gray-700">
                  <div className="flex items-center justify-between mb-2">
                    <div className="flex items-center gap-3">
                      <div className={`w-10 h-10 rounded-lg flex items-center justify-center ${
                        signal.action === 'BUY' ? 'bg-green-500/20' : signal.action === 'SELL' ? 'bg-red-500/20' : 'bg-gray-500/20'
                      }`}>
                        <span className="text-lg">
                          {signal.action === 'BUY' ? '📈' : signal.action === 'SELL' ? '📉' : '➡️'}
                        </span>
                      </div>
                      <div>
                        <p className="font-semibold">{signal.token} - {signal.action}</p>
                        <p className="text-sm text-gray-400">Confidence: {signal.confidence}%</p>
                      </div>
                    </div>
                    <div className={`px-3 py-1 rounded-full text-xs font-medium ${
                      signal.confidence >= 75 ? 'bg-green-500/20 text-green-400' : 'bg-yellow-500/20 text-yellow-400'
                    }`}>
                      {signal.confidence >= 75 ? 'High' : 'Medium'} Confidence
                    </div>
                  </div>
                  <p className="text-sm text-gray-300 mt-2">{signal.reasoning}</p>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* AI Chat Interface */}
        <div className="bg-gray-800/50 backdrop-blur rounded-xl border border-gray-700 overflow-hidden">
          <div className="bg-gradient-to-r from-blue-600/20 to-purple-600/20 px-6 py-4 border-b border-gray-700">
            <h2 className="text-xl font-semibold">💬 Chat with AI Trading Agent</h2>
            <p className="text-sm text-gray-400">Ask questions in plain English - get intelligent trading insights</p>
          </div>
          <div className="p-6">
            <div className="h-64 overflow-y-auto mb-4 space-y-4">
              {chatMessages.map((msg, idx) => (
                <div key={idx} className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}>
                  <div className={`max-w-[80%] rounded-lg px-4 py-2 ${
                    msg.role === 'user' ? 'bg-blue-600' : 'bg-gray-700'
                  }`}>
                    <p className="text-sm whitespace-pre-line">{msg.content}</p>
                  </div>
                </div>
              ))}
            </div>
            <div className="flex gap-3">
              <input
                type="text"
                value={chatInput}
                onChange={(e) => setChatInput(e.target.value)}
                onKeyPress={(e) => e.key === 'Enter' && handleSendMessage()}
                placeholder="Ask anything about your portfolio, trading strategies, or market conditions..."
                className="flex-1 bg-gray-900 border border-gray-700 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-blue-500"
              />
              <button
                onClick={handleSendMessage}
                className="px-6 py-3 bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-700 hover:to-purple-700 rounded-lg font-medium transition-all"
              >
                Send
              </button>
            </div>
          </div>
        </div>
      </main>

      {/* Footer */}
      <footer className="border-t border-gray-800 mt-12">
        <div className="container mx-auto px-6 py-6">
          <div className="flex items-center justify-between text-sm text-gray-400">
            <p>© 2025 NeuralTrade AI - Built for Injective AI Agent Hackathon</p>
            <div className="flex items-center gap-4">
              <span>🔒 Non-custodial</span>
              <span>🧠 AI-Powered</span>
              <span>⚡ Lightning Fast</span>
            </div>
          </div>
        </div>
      </footer>
    </div>
  );
}

function MetricCard({ title, value, change, positive, icon }: {
  title: string;
  value: string;
  change: string;
  positive: boolean;
  icon: string;
}) {
  return (
    <div className="bg-gray-800/50 backdrop-blur rounded-xl p-6 border border-gray-700">
      <div className="flex items-center justify-between mb-2">
        <span className="text-2xl">{icon}</span>
        <span className={`text-sm px-2 py-1 rounded ${positive ? 'bg-green-500/20 text-green-400' : 'bg-red-500/20 text-red-400'}`}>
          {positive ? '↑' : '↓'}
        </span>
      </div>
      <p className="text-gray-400 text-sm mb-1">{title}</p>
      <p className="text-2xl font-bold mb-1">{value}</p>
      <p className={`text-sm ${positive ? 'text-green-400' : 'text-red-400'}`}>{change}</p>
    </div>
  );
}
