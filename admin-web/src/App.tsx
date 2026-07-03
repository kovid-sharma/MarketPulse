import { useState, useEffect } from 'react';
import { BrowserRouter, Routes, Route, Navigate, useNavigate, useLocation } from 'react-router-dom';
import axios from 'axios';
import { 
  RefreshCw, TrendingUp, AlertTriangle, CheckCircle2, 
  PlusCircle, DollarSign, LogOut, Check, X, ShieldAlert, 
  ArrowRight, FileText, Globe, KeyRound
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
  const token = localStorage.getItem('admin_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// ── TYPES ────────────────────────────────────────────────────────────────────

interface SystemHealth {
  status: string;
  queue_size: number;
  last_ingestion_time: string | null;
  error_count: number;
  total_articles: number;
}

interface Article {
  id: string;
  headline: string;
  content?: string;
  summary?: string;
  source?: string;
  url?: string;
  published_at?: string;
  classification_confidence?: number;
  credibility?: string;
  geography?: string;
}

// ── APP WRAPPER ──────────────────────────────────────────────────────────────

export default function App() {
  const [isAuthenticated, setIsAuthenticated] = useState<boolean>(() => {
    return !!localStorage.getItem('admin_token') && localStorage.getItem('user_role') === 'admin';
  });

  return (
    <BrowserRouter>
      <Routes>
        <Route 
          path="/" 
          element={
            isAuthenticated ? <Navigate to="/dashboard" replace /> : <LoginScreen onLoginSuccess={() => setIsAuthenticated(true)} />
          } 
        />
        <Route 
          path="/login" 
          element={
            isAuthenticated ? <Navigate to="/dashboard" replace /> : <LoginScreen onLoginSuccess={() => setIsAuthenticated(true)} />
          } 
        />
        <Route 
          path="/*" 
          element={
            isAuthenticated ? (
              <Layout onLogout={() => setIsAuthenticated(false)}>
                <Routes>
                  <Route path="/dashboard" element={<DashboardScreen />} />
                  <Route path="/review" element={<ReviewScreen />} />
                  <Route path="/manual-entry" element={<ManualEntryScreen />} />
                  <Route path="/payments" element={<PaymentsScreen />} />
                  <Route path="*" element={<Navigate to="/dashboard" replace />} />
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
      const { access_token, role } = response.data;

      if (role !== 'admin') {
        setError('This account does not have admin access.');
        setIsLoading(false);
        return;
      }

      localStorage.setItem('admin_token', access_token);
      localStorage.setItem('user_role', role);
      onLoginSuccess();
      navigate('/dashboard');
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
          <div className="brand-icon">
            <TrendingUp size={20} />
          </div>
          <span className="brand-title">MarketPulse Admin</span>
        </div>
        <h2 className="login-title">Welcome back</h2>
        <p className="login-subtitle">Sign in to access system operations</p>
        
        {error && <div className="auth-error-banner">{error}</div>}

        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label className="form-label">Email address</label>
            <input 
              type="email" 
              className="form-input" 
              placeholder="admin@marketpulse.com"
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
              <>Sign In <ArrowRight size={16} /></>
            )}
          </button>
        </form>
      </div>
    </div>
  );
}

// ── NAVIGATION & LAYOUT ───────────────────────────────────────────────────────

function Layout({ children, onLogout }: { children: React.ReactNode; onLogout: () => void }) {
  const navigate = useNavigate();
  const location = useLocation();

  const handleLogout = () => {
    localStorage.removeItem('admin_token');
    localStorage.removeItem('user_role');
    onLogout();
    navigate('/login');
  };

  const isActive = (path: string) => location.pathname === path;

  return (
    <div className="admin-container">
      <header className="admin-header">
        <div className="brand-section">
          <div className="brand-icon">
            <TrendingUp size={18} />
          </div>
          <span className="brand-title">MarketPulse Admin</span>
        </div>
        <nav className="header-nav">
          <button 
            className={`btn-nav ${isActive('/dashboard') ? 'active' : ''}`}
            onClick={() => navigate('/dashboard')}
          >
            Dashboard
          </button>
          <button 
            className={`btn-nav ${isActive('/review') ? 'active' : ''}`}
            onClick={() => navigate('/review')}
          >
            Review Queue
          </button>
          <button 
            className={`btn-nav ${isActive('/manual-entry') ? 'active' : ''}`}
            onClick={() => navigate('/manual-entry')}
          >
            Manual Entry
          </button>
          <button 
            className={`btn-nav ${isActive('/payments') ? 'active' : ''}`}
            onClick={() => navigate('/payments')}
          >
            Payments
          </button>
          <button className="btn-logout" onClick={handleLogout}>
            <LogOut size={14} /> Log Out
          </button>
        </nav>
      </header>
      <main className="admin-content">
        {children}
      </main>
    </div>
  );
}

// ── DASHBOARD SCREEN ──────────────────────────────────────────────────────────

function DashboardScreen() {
  const [health, setHealth] = useState<SystemHealth | null>(null);
  const [status, setStatus] = useState<'healthy' | 'error' | 'loading'>('loading');
  const navigate = useNavigate();

  const fetchHealth = async () => {
    setStatus('loading');
    try {
      const response = await api.get('/admin/health');
      setHealth(response.data);
      setStatus(response.data.status === 'healthy' ? 'healthy' : 'error');
    } catch (err) {
      console.error(err);
      setStatus('error');
    }
  };

  useEffect(() => {
    fetchHealth();
    const interval = setInterval(fetchHealth, 15000);
    return () => clearInterval(interval);
  }, []);

  const formatTimeAgo = (isoString: string | null) => {
    if (!isoString) return 'Never';
    try {
      const date = new Date(isoString);
      const diffMs = Date.now() - date.getTime();
      const diffMins = Math.floor(diffMs / 60000);
      if (diffMins < 1) return 'Just now';
      if (diffMins < 60) return `${diffMins}m ago`;
      const diffHours = Math.floor(diffMins / 60);
      return `${diffHours}h ago`;
    } catch (_) {
      return 'Unknown';
    }
  };

  return (
    <div>
      {status === 'healthy' && (
        <div className="status-banner healthy">
          <CheckCircle2 size={16} /> System operational
        </div>
      )}
      {status === 'error' && (
        <div className="status-banner error">
          <AlertTriangle size={16} /> Cannot reach backend API
        </div>
      )}
      {status === 'loading' && !health && (
        <div className="status-banner loading">
          <RefreshCw size={16} className="spinner" style={{ animation: 'spin 1.5s linear infinite' }} /> Fetching system status...
        </div>
      )}

      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
        <h2 className="section-title" style={{ marginBottom: 0 }}>System Health</h2>
        <button 
          onClick={fetchHealth} 
          style={{ color: 'var(--text-secondary)', display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px' }}
        >
          <RefreshCw size={14} /> Refresh
        </button>
      </div>

      <div className="stats-grid">
        <div className="stat-card">
          <div className="stat-icon" style={{ backgroundColor: 'rgba(99, 102, 241, 0.1)', color: 'var(--primary-color)' }}>
            <Globe size={20} />
          </div>
          <div className="stat-details">
            <span className="stat-label">Queue Size</span>
            <span className="stat-value">{health?.queue_size ?? 0}</span>
          </div>
        </div>
        
        <div className="stat-card">
          <div className="stat-icon" style={{ backgroundColor: 'rgba(16, 185, 129, 0.1)', color: 'var(--success-color)' }}>
            <FileText size={20} />
          </div>
          <div className="stat-details">
            <span className="stat-label">Total Articles</span>
            <span className="stat-value">{health?.total_articles ?? 0}</span>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-icon" style={{ backgroundColor: 'rgba(239, 68, 68, 0.1)', color: 'var(--danger-color)' }}>
            <AlertTriangle size={20} />
          </div>
          <div className="stat-details">
            <span className="stat-label">Errors</span>
            <span className="stat-value">{health?.error_count ?? 0}</span>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-icon" style={{ backgroundColor: 'rgba(245, 158, 11, 0.1)', color: 'var(--warning-color)' }}>
            <KeyRound size={20} />
          </div>
          <div className="stat-details">
            <span className="stat-label">Last Ingestion</span>
            <span className="stat-value" style={{ fontSize: '16px', fontWeight: 600, marginTop: '8px' }}>
              {formatTimeAgo(health?.last_ingestion_time || null)}
            </span>
          </div>
        </div>
      </div>

      <h2 className="section-title">Quick Actions</h2>
      <div className="actions-list">
        <button className="action-tile" onClick={() => navigate('/review')}>
          <div className="action-icon" style={{ backgroundColor: 'var(--primary-color)' }}>
            <CheckCircle2 size={18} />
          </div>
          <div className="action-info">
            <div className="action-title">Review Queue</div>
            <div className="action-subtitle">Approve or reject low-confidence articles</div>
          </div>
          <ArrowRight size={16} style={{ color: 'var(--text-muted)' }} />
        </button>

        <button className="action-tile" onClick={() => navigate('/manual-entry')}>
          <div className="action-icon" style={{ backgroundColor: 'var(--success-color)' }}>
            <PlusCircle size={18} />
          </div>
          <div className="action-info">
            <div className="action-title">Manual Article Entry</div>
            <div className="action-subtitle">Submit an article directly to the pipeline</div>
          </div>
          <ArrowRight size={16} style={{ color: 'var(--text-muted)' }} />
        </button>

        <button className="action-tile" onClick={() => navigate('/payments')}>
          <div className="action-icon" style={{ backgroundColor: 'var(--warning-color)' }}>
            <DollarSign size={18} />
          </div>
          <div className="action-info">
            <div className="action-title">Payments Overview</div>
            <div className="action-subtitle">View subscription and revenue summary</div>
          </div>
          <ArrowRight size={16} style={{ color: 'var(--text-muted)' }} />
        </button>
      </div>
    </div>
  );
}

// ── REVIEW QUEUE SCREEN ───────────────────────────────────────────────────────

function ReviewScreen() {
  const [articles, setArticles] = useState<Article[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchQueue = async () => {
    setIsLoading(true);
    setError(null);
    try {
      const response = await api.get('/admin/articles/review');
      setArticles(response.data);
    } catch (err: any) {
      console.error(err);
      setError('Failed to fetch review queue');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchQueue();
  }, []);

  const handleAction = async (id: string, action: 'approve' | 'reject') => {
    try {
      await api.patch(`/admin/articles/${id}/review`, null, {
        params: { action }
      });
      // Remove from list
      setArticles((prev) => prev.filter((a) => a.id !== id));
    } catch (err) {
      console.error(err);
      alert(`Failed to ${action} article`);
    }
  };

  const getConfidenceClass = (conf?: number) => {
    if (!conf) return 'low';
    if (conf >= 0.7) return 'high';
    if (conf >= 0.5) return 'medium';
    return 'low';
  };

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
        <h2 className="section-title" style={{ marginBottom: 0 }}>Review Queue</h2>
        <button 
          onClick={fetchQueue} 
          style={{ color: 'var(--text-secondary)', display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px' }}
        >
          <RefreshCw size={14} /> Refresh
        </button>
      </div>

      {isLoading ? (
        <div className="loader-container">
          <div className="spinner" />
        </div>
      ) : error ? (
        <div className="status-banner error">{error}</div>
      ) : articles.length === 0 ? (
        <div className="empty-state">
          <CheckCircle2 className="empty-icon" />
          <h3 className="empty-title">All caught up!</h3>
          <p className="empty-subtitle">No articles currently require moderation review.</p>
        </div>
      ) : (
        <>
          <div className="review-header-info">
            <ShieldAlert size={14} />
            <span>{articles.length} articles need review · Moderation required for low-confidence models</span>
          </div>

          <div className="review-list">
            {articles.map((article) => (
              <div key={article.id} className="review-tile">
                <div className="tile-top">
                  {article.classification_confidence !== undefined && (
                    <span className={`confidence-badge ${getConfidenceClass(article.classification_confidence)}`}>
                      {Math.round(article.classification_confidence * 100)}% confidence
                    </span>
                  )}
                  {article.source && <span className="tile-source">{article.source}</span>}
                </div>

                <div className="tile-headline">{article.headline}</div>
                
                {article.summary && (
                  <div className="tile-summary">{article.summary}</div>
                )}

                <div className="tile-footer">
                  <div className="badge-row">
                    <span className="badge credibility">{article.credibility || 'Opinion'}</span>
                    <span className="badge geography">{article.geography || 'Global'}</span>
                  </div>

                  <div className="tile-actions">
                    <button className="btn-action approve" onClick={() => handleAction(article.id, 'approve')}>
                      <Check size={14} /> Approve
                    </button>
                    <button className="btn-action reject" onClick={() => handleAction(article.id, 'reject')}>
                      <X size={14} /> Reject
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  );
}

// ── MANUAL ARTICLE ENTRY SCREEN ───────────────────────────────────────────────

function ManualEntryScreen() {
  const [headline, setHeadline] = useState('');
  const [content, setContent] = useState('');
  const [source, setSource] = useState('');
  const [url, setUrl] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [success, setSuccess] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!headline.trim()) return;

    setIsSubmitting(true);
    setSuccess(false);

    try {
      await api.post('/admin/articles/manual', {
        headline: headline.trim(),
        content: content.trim() || null,
        source: source.trim() || null,
        url: url.trim() || null,
      });

      setHeadline('');
      setContent('');
      setSource('');
      setUrl('');
      setSuccess(true);
      setTimeout(() => setSuccess(false), 5000);
    } catch (err) {
      console.error(err);
      alert('Failed to submit manual article');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div>
      <h2 className="section-title">Manual Article Entry</h2>
      
      <div className="manual-form-card">
        {success && (
          <div className="info-banner">
            <CheckCircle2 size={16} /> Article successfully queued for NLP pipeline classification
          </div>
        )}
        
        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label className="form-label">Headline *</label>
            <input 
              type="text" 
              className="form-input" 
              placeholder="Enter article headline..."
              value={headline}
              onChange={(e) => setHeadline(e.target.value)}
              required
            />
          </div>

          <div className="form-group">
            <label className="form-label">Content / Summary</label>
            <textarea 
              className="form-input" 
              rows={5}
              placeholder="Paste article body text or metadata context..."
              value={content}
              onChange={(e) => setContent(e.target.value)}
              style={{ resize: 'vertical' }}
            />
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
            <div className="form-group">
              <label className="form-label">Source</label>
              <input 
                type="text" 
                className="form-input" 
                placeholder="e.g. Mint, Bloomberg"
                value={source}
                onChange={(e) => setSource(e.target.value)}
              />
            </div>
            
            <div className="form-group">
              <label className="form-label">Article URL</label>
              <input 
                type="url" 
                className="form-input" 
                placeholder="https://..."
                value={url}
                onChange={(e) => setUrl(e.target.value)}
              />
            </div>
          </div>

          <button type="submit" className="btn-primary" style={{ marginTop: '24px', backgroundColor: 'var(--success-color)' }} disabled={isSubmitting}>
            {isSubmitting ? (
              <span className="spinner" style={{ width: '16px', height: '16px' }} />
            ) : (
              <>Submit to Pipeline <PlusCircle size={16} /></>
            )}
          </button>
        </form>
      </div>
    </div>
  );
}

// ── PAYMENTS OVERVIEW SCREEN ──────────────────────────────────────────────────

function PaymentsScreen() {
  return (
    <div>
      <h2 className="section-title">Payments Overview</h2>
      
      <div className="payments-banner">
        <AlertTriangle size={20} />
        <div>
          <h4>Under Construction</h4>
          <p>The payments ingestion connector is active. Live transactions tracking dashboard is coming soon.</p>
        </div>
      </div>

      <div className="stats-grid">
        <div className="stat-card" style={{ opacity: 0.8 }}>
          <div className="stat-icon" style={{ backgroundColor: 'rgba(245, 158, 11, 0.1)', color: 'var(--warning-color)' }}>
            <DollarSign size={20} />
          </div>
          <div className="stat-details">
            <span className="stat-label">Monthly Recurring Revenue (MRR)</span>
            <span className="stat-value">₹2,48,000</span>
          </div>
        </div>

        <div className="stat-card" style={{ opacity: 0.8 }}>
          <div className="stat-icon" style={{ backgroundColor: 'rgba(16, 185, 129, 0.1)', color: 'var(--success-color)' }}>
            <CheckCircle2 size={20} />
          </div>
          <div className="stat-details">
            <span className="stat-label">Active Subscribers</span>
            <span className="stat-value">114</span>
          </div>
        </div>
      </div>
    </div>
  );
}
