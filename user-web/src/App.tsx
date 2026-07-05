import { useState, useEffect } from 'react';
import { BrowserRouter, Routes, Route, Navigate, useNavigate, useParams, useLocation } from 'react-router-dom';
import axios from 'axios';
import { 
  TrendingUp, RefreshCw, SlidersHorizontal, User, 
  ArrowLeft, ExternalLink, Lightbulb, Bell, FileText, 
  AlertTriangle, HelpCircle, 
  LogOut, Save, Landmark, Cpu, Pill, ShoppingCart, 
  Car, Building, Flame, LineChart, X
} from 'lucide-react';
import './App.css';

// ── API CLIENT ───────────────────────────────────────────────────────────────

const api = axios.create({
  baseURL: 'https://marketpulse-mu5o.onrender.com',
  headers: {
    'Content-Type': 'application/json',
  },
});

api.interceptors.request.use((config) => {
  const token = localStorage.getItem('user_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// ── TYPES ────────────────────────────────────────────────────────────────────

interface StockImpact {
  symbol: string;
  name?: string;
  sector?: string;
  direction: 'positive' | 'negative' | 'neutral';
  effect: 'high' | 'medium' | 'low';
  reason?: string;
}

interface Article {
  id: string;
  headline: string;
  content?: string;
  summary?: string;
  context?: string;
  impact_explanation?: string;
  key_takeaway?: string;
  sentiment?: 'bullish' | 'bearish' | 'neutral';
  source?: string;
  url?: string;
  published_at?: string;
  credibility?: string;
  geography?: 'india' | 'global';
  markets_affected?: string[];
  trade_logic?: string;
  impacts?: StockImpact[];
}

// ── APP WRAPPER ──────────────────────────────────────────────────────────────

export default function App() {
  const [isAuthenticated, setIsAuthenticated] = useState<boolean>(() => {
    return !!localStorage.getItem('user_token');
  });

  return (
    <BrowserRouter>
      <Routes>
        <Route 
          path="/" 
          element={
            isAuthenticated ? <Navigate to="/feed" replace /> : <LoginScreen onLoginSuccess={() => setIsAuthenticated(true)} />
          } 
        />
        <Route 
          path="/login" 
          element={
            isAuthenticated ? <Navigate to="/feed" replace /> : <LoginScreen onLoginSuccess={() => setIsAuthenticated(true)} />
          } 
        />
        <Route 
          path="/*" 
          element={
            isAuthenticated ? (
              <Layout>
                <Routes>
                  <Route path="/feed" element={<FeedScreen />} />
                  <Route path="/article/:id" element={<ArticleDetailScreen />} />
                  <Route path="/settings" element={<SettingsScreen onLogout={() => setIsAuthenticated(false)} />} />
                  <Route path="/notifications" element={<NotificationsScreen />} />
                  <Route path="*" element={<Navigate to="/feed" replace />} />
                </Routes>
              </Layout>
            ) : (
              <Navigate to="/" replace />
            )
          } 
        />
      </Routes>
    </BrowserRouter>
  );
}

// ── LOGIN SCREEN ──────────────────────────────────────────────────────────────

function LoginScreen({ onLoginSuccess }: { onLoginSuccess: () => void }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const navigate = useNavigate();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email.trim() || !password) return;

    setIsLoading(true);
    setError(null);

    try {
      const response = await api.post('/auth/login', { email: email.trim(), password });
      const { access_token, user_id } = response.data;

      localStorage.setItem('user_token', access_token);
      localStorage.setItem('user_email', email.trim());
      localStorage.setItem('user_id', user_id);
      
      onLoginSuccess();
      navigate('/feed');
    } catch (err: any) {
      console.error(err);
      setError(err.response?.data?.detail || 'Login failed. Check credentials.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="login-container">
      <div className="login-card">
        <div className="brand-section" style={{ justifyContent: 'center', marginBottom: '24px' }}>
          <div className="brand-logo">
            <LineChart size={18} />
          </div>
          <span className="brand-title">MarketPulse</span>
        </div>
        <h2 className="login-title">Invest Smarter</h2>
        <p className="login-subtitle">Sign in to track real-time stock impacts</p>
        
        {error && <div className="auth-error-banner">{error}</div>}

        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label className="form-label">Email address</label>
            <input 
              type="email" 
              className="form-input" 
              placeholder="you@example.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
          </div>

          <div className="form-group">
            <label className="form-label">Password</label>
            <input 
              type="password" 
              className="form-input" 
              placeholder="••••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />
          </div>

          <button type="submit" className="btn-primary" disabled={isLoading}>
            {isLoading ? (
              <span className="spinner" style={{ width: '16px', height: '16px' }} />
            ) : (
              'Sign In'
            )}
          </button>
        </form>
      </div>
    </div>
  );
}

// ── LAYOUT & BOTTOM NAVIGATION ───────────────────────────────────────────────

function Layout({ children }: { children: React.ReactNode }) {
  const navigate = useNavigate();
  const location = useLocation();

  const isActive = (path: string) => location.pathname === path;
  
  // Show header and bottom nav only for top-level pages
  const isDetailPage = location.pathname.startsWith('/article/');

  return (
    <div className="app-container">
      {!isDetailPage && (
        <header className="app-header">
          <div className="brand-section">
            <div className="brand-logo">
              <LineChart size={18} />
            </div>
            <span className="brand-title">MarketPulse</span>
          </div>
          <div className="header-actions">
            <button className="icon-btn" onClick={() => navigate('/notifications')}>
              <Bell size={20} />
            </button>
            <button className="icon-btn" onClick={() => navigate('/settings')}>
              <User size={20} />
            </button>
          </div>
        </header>
      )}

      <main className="app-content">
        {children}
      </main>

      {!isDetailPage && (
        <nav className="bottom-nav">
          <button 
            className={`bottom-nav-item ${isActive('/feed') ? 'active' : ''}`}
            onClick={() => navigate('/feed')}
          >
            <FileText size={20} />
            <span>Feed</span>
          </button>
          <button 
            className={`bottom-nav-item ${isActive('/notifications') ? 'active' : ''}`}
            onClick={() => navigate('/notifications')}
          >
            <Bell size={20} />
            <span>Alerts</span>
          </button>
          <button 
            className={`bottom-nav-item ${isActive('/settings') ? 'active' : ''}`}
            onClick={() => navigate('/settings')}
          >
            <User size={20} />
            <span>Settings</span>
          </button>
        </nav>
      )}
    </div>
  );
}

// ── FEED SCREEN ──────────────────────────────────────────────────────────────

function FeedScreen() {
  const [articles, setArticles] = useState<Article[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  
  // Filters State
  const [geography, setGeography] = useState<string | null>(null);
  const [sentiment, setSentiment] = useState<string | null>(null);
  const [sector, setSector] = useState<string | null>(null);
  const [showFilterSheet, setShowFilterSheet] = useState(false);

  const navigate = useNavigate();

  const fetchFeed = async () => {
    setIsLoading(true);
    setError(null);
    try {
      const params: any = {};
      if (geography) params.geography = geography;
      if (sentiment) params.sentiment = sentiment;
      if (sector) params.sector = sector;

      const response = await api.get('/users/feed', { params });
      setArticles(response.data);
    } catch (err) {
      console.error(err);
      setError('Failed to fetch articles. Retry?');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchFeed();
  }, [geography, sentiment, sector]);

  const removeFilter = (type: 'geography' | 'sentiment' | 'sector') => {
    if (type === 'geography') setGeography(null);
    if (type === 'sentiment') setSentiment(null);
    if (type === 'sector') setSector(null);
  };

  const getSectors = (article: Article) => {
    if (article.markets_affected && article.markets_affected.length > 0) {
      return article.markets_affected;
    }
    if (!article.impacts) return [];
    return Array.from(new Set(article.impacts.map(i => (i as any).sector).filter(Boolean)));
  };

  // Get the highest effect level for a given stock across all impacts
  const getTopStockEffect = (article: Article, symbol: string): 'high' | 'medium' | 'low' => {
    if (!article.impacts) return 'low';
    for (const imp of article.impacts as StockImpact[]) {
      if (imp.symbol === symbol) return imp.effect || 'low';
    }
    return 'low';
  };

  const getUniqueStocksFromImpacts = (article: Article): StockImpact[] => {
    if (!article.impacts) return [];
    const seen = new Set<string>();
    const result: StockImpact[] = [];
    for (const imp of article.impacts as StockImpact[]) {
      if (imp.symbol && !seen.has(imp.symbol)) {
        seen.add(imp.symbol);
        result.push(imp);
      }
    }
    return result;
  };

  // Effect color helpers
  const effectBg = (effect: 'high' | 'medium' | 'low'): string => {
    if (effect === 'high') return 'rgba(239,68,68,0.18)';
    if (effect === 'medium') return 'rgba(245,158,11,0.18)';
    return 'rgba(16,185,129,0.18)';
  };
  const effectBorder = (effect: 'high' | 'medium' | 'low'): string => {
    if (effect === 'high') return 'rgba(239,68,68,0.5)';
    if (effect === 'medium') return 'rgba(245,158,11,0.5)';
    return 'rgba(16,185,129,0.5)';
  };
  const effectColor = (effect: 'high' | 'medium' | 'low'): string => {
    if (effect === 'high') return '#EF4444';
    if (effect === 'medium') return '#F59E0B';
    return '#10B981';
  };

  return (
    <div>
      {/* Search/Filter Bar */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px', padding: '0 4px' }}>
        <h2 className="section-title" style={{ marginBottom: 0 }}>Markets Today</h2>
        <div style={{ display: 'flex', gap: '8px' }}>
          <button className="icon-btn" onClick={() => setShowFilterSheet(true)}>
            <SlidersHorizontal size={18} />
          </button>
          <button className="icon-btn" onClick={fetchFeed}>
            <RefreshCw size={18} />
          </button>
        </div>
      </div>

      {/* Active Filter Chips */}
      {(geography || sentiment || sector) && (
        <div className="filter-chips-row">
          {geography && (
            <span className="filter-chip">
              {geography}
              <span className="btn-remove-chip" onClick={() => removeFilter('geography')}><X size={12} /></span>
            </span>
          )}
          {sentiment && (
            <span className="filter-chip">
              {sentiment}
              <span className="btn-remove-chip" onClick={() => removeFilter('sentiment')}><X size={12} /></span>
            </span>
          )}
          {sector && (
            <span className="filter-chip">
              {sector}
              <span className="btn-remove-chip" onClick={() => removeFilter('sector')}><X size={12} /></span>
            </span>
          )}
        </div>
      )}

      {isLoading ? (
        <div className="loader-container">
          <div className="spinner" />
        </div>
      ) : error ? (
        <div className="empty-state">
          <AlertTriangle className="empty-icon" style={{ color: 'var(--danger-color)' }} />
          <p className="empty-subtitle">{error}</p>
          <button className="btn-primary" style={{ marginTop: '16px', maxWidth: '200px' }} onClick={fetchFeed}>Retry</button>
        </div>
      ) : articles.length === 0 ? (
        <div className="empty-state">
          <HelpCircle className="empty-icon" style={{ color: 'var(--text-muted)' }} />
          <h3 className="empty-title">No articles found</h3>
          <p className="empty-subtitle">Try adjusting your active filters.</p>
        </div>
      ) : (
        <div className="feed-list">
          {articles.map((article) => {
            const topStocks = getUniqueStocksFromImpacts(article).slice(0, 4);
            return (
            <div key={article.id} className="article-card" onClick={() => navigate(`/article/${article.id}`)}>
              <div className="card-top">
                {article.source && <span className="source-badge">{article.source}</span>}
                {article.sentiment && (
                  <span className={`sentiment-chip ${article.sentiment}`}>
                    {article.sentiment}
                  </span>
                )}
              </div>

              <div className="headline-text">{article.headline}</div>

              {article.key_takeaway && (
                <div className="takeaway-box">
                  <Lightbulb size={14} className="takeaway-icon" />
                  <div className="takeaway-text">{article.key_takeaway}</div>
                </div>
              )}

              {/* Affected stocks with effect-coloured backgrounds */}
              {topStocks.length > 0 && (
                <div style={{ display: 'flex', gap: '6px', flexWrap: 'wrap', marginTop: '10px' }}>
                  {topStocks.map((s) => (
                    <span
                      key={s.symbol}
                      style={{
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: '4px',
                        padding: '3px 8px',
                        borderRadius: '6px',
                        fontSize: '11px',
                        fontWeight: 700,
                        background: effectBg(s.effect),
                        color: effectColor(s.effect),
                        border: `1px solid ${effectBorder(s.effect)}`,
                        letterSpacing: '0.5px',
                      }}
                    >
                      {s.direction === 'positive' ? '▲' : s.direction === 'negative' ? '▼' : '■'} {s.symbol}
                    </span>
                  ))}
                </div>
              )}

              <div className="tags-row">
                {article.geography && <span className="tag geography">{article.geography}</span>}
                {getSectors(article).map((s) => (
                  <span key={s} className="tag sector">{s}</span>
                ))}
              </div>
            </div>
            );
          })}
        </div>
      )}

      {/* Filters Overlay Dialog */}
      {showFilterSheet && (
        <div className="filter-overlay" onClick={() => setShowFilterSheet(false)}>
          <div className="filter-sheet" onClick={(e) => e.stopPropagation()}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
              <h3 style={{ fontSize: '18px', fontWeight: 700 }}>Filter Articles</h3>
              <button onClick={() => setShowFilterSheet(false)} style={{ color: 'var(--text-secondary)' }}>
                <X size={20} />
              </button>
            </div>

            <div className="filter-section">
              <div className="filter-section-title">Geography</div>
              <div className="filter-options">
                <button 
                  className={`filter-option-pill ${geography === 'india' ? 'selected' : ''}`}
                  onClick={() => setGeography(geography === 'india' ? null : 'india')}
                >
                  india
                </button>
                <button 
                  className={`filter-option-pill ${geography === 'global' ? 'selected' : ''}`}
                  onClick={() => setGeography(geography === 'global' ? null : 'global')}
                >
                  global
                </button>
              </div>
            </div>

            <div className="filter-section">
              <div className="filter-section-title">Sentiment</div>
              <div className="filter-options">
                <button 
                  className={`filter-option-pill ${sentiment === 'bullish' ? 'selected' : ''}`}
                  onClick={() => setSentiment(sentiment === 'bullish' ? null : 'bullish')}
                >
                  bullish
                </button>
                <button 
                  className={`filter-option-pill ${sentiment === 'bearish' ? 'selected' : ''}`}
                  onClick={() => setSentiment(sentiment === 'bearish' ? null : 'bearish')}
                >
                  bearish
                </button>
                <button 
                  className={`filter-option-pill ${sentiment === 'neutral' ? 'selected' : ''}`}
                  onClick={() => setSentiment(sentiment === 'neutral' ? null : 'neutral')}
                >
                  neutral
                </button>
              </div>
            </div>

            <div className="filter-section">
              <div className="filter-section-title">Sector</div>
              <div className="filter-options">
                {['banking', 'it', 'pharma', 'fmcg', 'auto', 'realty', 'oil & gas'].map((sec) => (
                  <button 
                    key={sec}
                    className={`filter-option-pill ${sector === sec ? 'selected' : ''}`}
                    onClick={() => setSector(sector === sec ? null : sec)}
                  >
                    {sec}
                  </button>
                ))}
              </div>
            </div>

            <button className="btn-primary" style={{ marginTop: '12px' }} onClick={() => setShowFilterSheet(false)}>
              Apply Filters
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

// ── ARTICLE DETAIL SCREEN ─────────────────────────────────────────────────────

function ArticleDetailScreen() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [article, setArticle] = useState<Article | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchDetail = async () => {
      setIsLoading(true);
      setError(null);
      try {
        const response = await api.get(`/articles/${id}`);
        setArticle(response.data);
      } catch (err) {
        console.error(err);
        setError('Failed to load article detail');
      } finally {
        setIsLoading(false);
      }
    };
    if (id) fetchDetail();
  }, [id]);

  // ── helpers ──────────────────────────────────────────────────────────────
  const getStockImpacts = (): StockImpact[] => {
    if (!article?.impacts) return [];
    const seen = new Set<string>();
    const result: StockImpact[] = [];
    for (const imp of article.impacts as StockImpact[]) {
      if (imp.symbol && !seen.has(imp.symbol)) {
        seen.add(imp.symbol);
        result.push(imp);
      }
    }
    return result;
  };

  const effectColor = (effect: 'high' | 'medium' | 'low') => {
    if (effect === 'high') return '#EF4444';
    if (effect === 'medium') return '#F59E0B';
    return '#10B981';
  };
  const effectBg = (effect: 'high' | 'medium' | 'low') => {
    if (effect === 'high') return 'rgba(239,68,68,0.12)';
    if (effect === 'medium') return 'rgba(245,158,11,0.12)';
    return 'rgba(16,185,129,0.12)';
  };
  const effectBorder = (effect: 'high' | 'medium' | 'low') => {
    if (effect === 'high') return 'rgba(239,68,68,0.35)';
    if (effect === 'medium') return 'rgba(245,158,11,0.35)';
    return 'rgba(16,185,129,0.35)';
  };

  // Blocks: high → 4-5 filled, medium → 2-3 filled, low → 1 filled
  const effectBlocks = (effect: 'high' | 'medium' | 'low'): number => {
    if (effect === 'high') return 5;
    if (effect === 'medium') return 3;
    return 1;
  };

  return (
    <div className="detail-container">
      <button className="btn-back" onClick={() => navigate('/feed')}>
        <ArrowLeft size={16} /> Back
      </button>

      {isLoading ? (
        <div className="loader-container">
          <div className="spinner" />
        </div>
      ) : error || !article ? (
        <div className="status-banner error">{error || 'Article not found'}</div>
      ) : (
        <>
          <div className="detail-meta-row">
            <div className="detail-meta-left">
              {article.source && <span className="meta-badge source">{article.source}</span>}
              {article.geography && <span className="meta-badge geo">{article.geography}</span>}
            </div>
            {article.sentiment && (
              <span className={`sentiment-chip ${article.sentiment}`}>
                {article.sentiment}
              </span>
            )}
          </div>

          <h2 className="detail-title">{article.headline}</h2>
          
          {article.published_at && (
            <div className="detail-date">
              Published on {new Date(article.published_at).toLocaleDateString()} at {new Date(article.published_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
            </div>
          )}

          {article.summary && (
            <div className="info-card">
              <div className="info-header" style={{ color: 'var(--primary-color)' }}>
                <FileText size={16} />
                <span>AI Summary</span>
              </div>
              <div className="info-body">{article.summary}</div>
            </div>
          )}

          {article.context && (
            <div className="info-card">
              <div className="info-header" style={{ color: '#0EA5E9' }}>
                <HelpCircle size={16} />
                <span>Why It Matters</span>
              </div>
              <div className="info-body">{article.context}</div>
            </div>
          )}

          {article.impact_explanation && (
            <div className="info-card">
              <div className="info-header" style={{ color: 'var(--success-color)' }}>
                <TrendingUp size={16} />
                <span>Market Impact</span>
              </div>
              <div className="info-body">{article.impact_explanation}</div>
            </div>
          )}

          {article.key_takeaway && (
            <div className="takeaway-gradient-card">
              <div className="takeaway-gradient-header">
                <Lightbulb size={18} style={{ color: '#FFD700' }} />
                <span>Key Takeaway</span>
              </div>
              <div className="takeaway-gradient-body">{article.key_takeaway}</div>
            </div>
          )}

          {/* ── Markets Affected ───────────────────────────────────────── */}
          {article.markets_affected && article.markets_affected.length > 0 && (
            <div className="info-card" style={{ marginTop: '16px' }}>
              <div className="info-header" style={{ color: '#A78BFA' }}>
                <Landmark size={16} />
                <span>Markets Affected</span>
              </div>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px', marginTop: '10px' }}>
                {article.markets_affected.map((m) => (
                  <span key={m} style={{
                    padding: '4px 12px',
                    borderRadius: '20px',
                    fontSize: '12px',
                    fontWeight: 600,
                    background: 'rgba(167,139,250,0.12)',
                    color: '#A78BFA',
                    border: '1px solid rgba(167,139,250,0.3)',
                    letterSpacing: '0.3px',
                  }}>
                    {m}
                  </span>
                ))}
              </div>
            </div>
          )}

          {/* ── Stocks Affected ────────────────────────────────────────── */}
          {getStockImpacts().length > 0 && (
            <div style={{ marginTop: '20px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '12px' }}>
                <TrendingUp size={16} style={{ color: 'var(--text-secondary)' }} />
                <h4 className="stocks-section-title" style={{ marginBottom: 0 }}>Stocks Affected</h4>
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(160px, 1fr))', gap: '10px' }}>
                {getStockImpacts().map((stock) => {
                  const col = effectColor(stock.effect);
                  const bg = effectBg(stock.effect);
                  const border = effectBorder(stock.effect);
                  const filled = effectBlocks(stock.effect);
                  return (
                    <div key={stock.symbol} style={{
                      background: bg,
                      border: `1px solid ${border}`,
                      borderRadius: '12px',
                      padding: '12px 14px',
                      display: 'flex',
                      flexDirection: 'column',
                      gap: '8px',
                    }}>
                      {/* Stock name + direction */}
                      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                        <span style={{ color: col, fontWeight: 700, fontSize: '14px', letterSpacing: '0.5px' }}>
                          {stock.symbol}
                        </span>
                        <span style={{ fontSize: '11px', color: col, opacity: 0.9 }}>
                          {stock.direction === 'positive' ? '▲' : stock.direction === 'negative' ? '▼' : '━'}
                        </span>
                      </div>

                      {/* Company name */}
                      {stock.name && stock.name !== stock.symbol && (
                        <span style={{ fontSize: '11px', color: 'var(--text-muted)', lineHeight: 1.3 }}>
                          {stock.name}
                        </span>
                      )}

                      {/* Block-bar indicator */}
                      <div style={{ display: 'flex', gap: '3px' }}>
                        {[1,2,3,4,5].map((n) => (
                          <div key={n} style={{
                            flex: 1,
                            height: '5px',
                            borderRadius: '3px',
                            background: n <= filled ? col : 'rgba(255,255,255,0.1)',
                            transition: 'background 0.2s',
                          }} />
                        ))}
                      </div>

                      {/* Effect label */}
                      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                        <span style={{
                          fontSize: '10px',
                          fontWeight: 700,
                          color: col,
                          textTransform: 'uppercase',
                          letterSpacing: '0.8px',
                        }}>
                          {stock.effect} impact
                        </span>
                        {stock.sector && (
                          <span style={{ fontSize: '10px', color: 'var(--text-muted)', fontStyle: 'italic' }}>
                            {stock.sector}
                          </span>
                        )}
                      </div>

                      {/* Reason */}
                      {stock.reason && (
                        <p style={{ fontSize: '11px', color: 'var(--text-secondary)', margin: 0, lineHeight: 1.5 }}>
                          {stock.reason}
                        </p>
                      )}
                    </div>
                  );
                })}
              </div>
            </div>
          )}

          {/* ── Trade Logic ────────────────────────────────────────────── */}
          {article.trade_logic && article.trade_logic.trim() && (
            <div className="info-card" style={{ marginTop: '16px', background: 'linear-gradient(135deg, rgba(99,102,241,0.08) 0%, rgba(139,92,246,0.06) 100%)', borderColor: 'rgba(99,102,241,0.25)' }}>
              <div className="info-header" style={{ color: '#818CF8' }}>
                <Lightbulb size={16} />
                <span>Logic Behind the Trade</span>
              </div>
              <div className="info-body" style={{ color: 'var(--text-secondary)', lineHeight: 1.7 }}>
                {article.trade_logic}
              </div>
            </div>
          )}

          {article.url && (
            <a href={article.url} target="_blank" rel="noopener noreferrer" className="btn-read-more">
              Read Full Article <ExternalLink size={14} />
            </a>
          )}
        </>
      )}
    </div>
  );
}

// ── SETTINGS SCREEN ──────────────────────────────────────────────────────────

function SettingsScreen({ onLogout }: { onLogout: () => void }) {
  const [sectors, setSectors] = useState<string[]>([]);
  const [geography, setGeography] = useState<string>('both');
  const [isSaving, setIsSaving] = useState(false);

  const allSectors = [
    'banking', 'it', 'pharma', 'fmcg', 'auto', 'realty',
    'oil & gas', 'broad market'
  ];

  // Map sectors icons
  const getSectorIcon = (sec: string) => {
    switch(sec) {
      case 'banking': return <Landmark size={14} />;
      case 'it': return <Cpu size={14} />;
      case 'pharma': return <Pill size={14} />;
      case 'fmcg': return <ShoppingCart size={14} />;
      case 'auto': return <Car size={14} />;
      case 'realty': return <Building size={14} />;
      case 'oil & gas': return <Flame size={14} />;
      default: return <LineChart size={14} />;
    }
  };

  const handleToggleSector = (sec: string) => {
    setSectors(prev => 
      prev.includes(sec) ? prev.filter(s => s !== sec) : [...prev, sec]
    );
  };

  const handleSave = async () => {
    setIsSaving(true);
    try {
      await api.post('/users/preferences', {
        sectors,
        geography: geography === 'both' ? null : geography,
        sentiments: [],
        alert_threshold: 'all'
      });
      alert('Preferences saved successfully!');
    } catch (err) {
      console.error(err);
      alert('Failed to save preferences');
    } finally {
      setIsSaving(false);
    }
  };

  const handleLogoutClick = () => {
    localStorage.removeItem('user_token');
    localStorage.removeItem('user_email');
    localStorage.removeItem('user_id');
    onLogout();
  };

  const email = localStorage.getItem('user_email') || 'user@marketpulse.com';

  return (
    <div style={{ textAlign: 'left' }}>
      <h2 className="section-title">Settings</h2>

      <div className="settings-section-header">Account</div>
      <div className="settings-card">
        <div className="settings-profile-tile">
          <div className="profile-avatar">
            <User size={18} />
          </div>
          <div className="profile-info">
            <span className="profile-email">{email}</span>
            <span className="profile-role">Subscriber</span>
          </div>
        </div>
        <hr style={{ borderColor: 'var(--border-color)', margin: '12px 0' }} />
        <button className="btn-logout-settings" onClick={handleLogoutClick}>
          <LogOut size={13} style={{ marginRight: '6px' }} /> Log Out
        </button>
      </div>

      <div className="settings-section-header">Sector Preferences</div>
      <div className="settings-card">
        <div className="pref-option-row">
          {allSectors.map((sec) => {
            const selected = sectors.includes(sec);
            return (
              <button 
                key={sec} 
                className={`pref-pill ${selected ? 'selected' : ''}`}
                onClick={() => handleToggleSector(sec)}
                style={{ display: 'flex', alignItems: 'center', gap: '6px', cursor: 'pointer' }}
              >
                {getSectorIcon(sec)}
                <span style={{ textTransform: 'capitalize' }}>{sec}</span>
              </button>
            );
          })}
        </div>
      </div>

      <div className="settings-section-header">Geography</div>
      <div className="settings-card">
        <div className="pref-option-row">
          {['india', 'global', 'both'].map((geo) => (
            <button 
              key={geo} 
              className={`pref-pill ${geography === geo ? 'selected' : ''}`}
              onClick={() => setGeography(geo)}
              style={{ textTransform: 'capitalize', cursor: 'pointer' }}
            >
              {geo}
            </button>
          ))}
        </div>
      </div>

      <button 
        className="btn-primary" 
        style={{ marginTop: '28px', backgroundColor: 'var(--primary-color)' }}
        disabled={isSaving}
        onClick={handleSave}
      >
        {isSaving ? (
          <span className="spinner" style={{ width: '16px', height: '16px' }} />
        ) : (
          <><Save size={16} /> Save Preferences</>
        )}
      </button>
    </div>
  );
}

// ── ALERTS / NOTIFICATIONS SCREEN ─────────────────────────────────────────────

function NotificationsScreen() {
  const [notifications] = useState([
    {
      id: 1,
      title: 'High Impact Alert: HDFC Bank',
      message: 'HDFC Bank announces strong quarterly profit growth beating consensus by 4.2%.',
      timestamp: '10 mins ago',
      unread: true
    },
    {
      id: 2,
      title: 'Global Sentiment Shift',
      message: 'Federal Reserve holds interest rates steady; signals potential cut in Q3.',
      timestamp: '1 hour ago',
      unread: false
    },
    {
      id: 3,
      title: 'IT Sector Momentum',
      message: 'Infosys secures $1.2B digital transformation deal with European energy major.',
      timestamp: '4 hours ago',
      unread: false
    }
  ]);

  return (
    <div style={{ textAlign: 'left' }}>
      <h2 className="section-title">Alerts History</h2>
      
      <div className="actions-list">
        {notifications.map((n) => (
          <div 
            key={n.id} 
            className="action-tile" 
            style={{ 
              backgroundColor: n.unread ? 'rgba(99, 102, 241, 0.05)' : 'var(--surface-color)',
              borderColor: n.unread ? 'rgba(99, 102, 241, 0.3)' : 'var(--border-color)'
            }}
          >
            <div className="action-icon" style={{ 
              backgroundColor: n.unread ? 'var(--primary-color)' : 'var(--border-color)',
              color: '#FFFFFF'
            }}>
              <Bell size={18} />
            </div>
            <div className="action-info">
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span className="action-title" style={{ color: n.unread ? '#FFFFFF' : 'var(--text-secondary)' }}>
                  {n.title}
                </span>
                <span style={{ fontSize: '10px', color: 'var(--text-muted)' }}>{n.timestamp}</span>
              </div>
              <div className="action-subtitle" style={{ fontSize: '13px', marginTop: '4px', color: 'var(--text-secondary)' }}>
                {n.message}
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
