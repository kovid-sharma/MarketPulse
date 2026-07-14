import { useState, useEffect, useCallback } from 'react';
import { BrowserRouter, Routes, Route, Navigate, useNavigate, useLocation } from 'react-router-dom';
import axios from 'axios';
import {
  RefreshCw, TrendingUp, AlertTriangle, CheckCircle2,
  PlusCircle, DollarSign, LogOut, Check, X, ShieldAlert,
  ArrowRight, FileText, Globe, KeyRound, Database, Cpu,
  Zap, ChevronRight, Edit3, Save, BarChart2, Link2,
  Search, Tag, Brain, Activity, Clock, ToggleLeft, ToggleRight,
  AlertCircle, BookOpen, Layers
} from 'lucide-react';
import './App.css';

// ── API CLIENT ───────────────────────────────────────────────────────────────

const api = axios.create({
  baseURL: 'https://marketpulse-mu5o.onrender.com',
  headers: { 'Content-Type': 'application/json' },
});

api.interceptors.request.use((config) => {
  const token = localStorage.getItem('admin_token');
  if (token) config.headers.Authorization = `Bearer ${token}`;
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
  sentiment?: string;
  impacts?: StockImpact[];
  vector_synced?: boolean;
  vector_synced_at?: string;
  ai_status?: string;
}

interface StockImpact {
  symbol: string;
  name?: string;
  sector?: string;
  direction: string;
  effect: string;
  reason?: string;
}

interface VectorStats {
  available: boolean;
  news_count: number;
  stock_count: number;
  pending_sync_count: number;
  stock_profiles_count: number;
  error?: string;
}

interface StockNewsItem {
  article_id: string;
  headline: string;
  content_snippet?: string;
  sector?: string;
  direction: string;
  sentiment: string;
  published_at?: string;
  admin_verified: boolean;
  effect?: string;
  reason?: string;
}

// ── APP WRAPPER ──────────────────────────────────────────────────────────────

export default function App() {
  const [isAuthenticated, setIsAuthenticated] = useState<boolean>(() =>
    !!localStorage.getItem('admin_token') && localStorage.getItem('user_role') === 'admin'
  );

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={isAuthenticated ? <Navigate to="/dashboard" replace /> : <LoginScreen onLoginSuccess={() => setIsAuthenticated(true)} />} />
        <Route path="/login" element={isAuthenticated ? <Navigate to="/dashboard" replace /> : <LoginScreen onLoginSuccess={() => setIsAuthenticated(true)} />} />
        <Route
          path="/*"
          element={
            isAuthenticated ? (
              <Layout onLogout={() => setIsAuthenticated(false)}>
                <Routes>
                  <Route path="/dashboard" element={<DashboardScreen />} />
                  <Route path="/review" element={<ReviewScreen />} />
                  <Route path="/manual-entry" element={<ManualEntryScreen />} />
                  <Route path="/vector-training" element={<VectorTrainingScreen />} />
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
      if (role !== 'admin') { setError('This account does not have admin access.'); setIsLoading(false); return; }
      localStorage.setItem('admin_token', access_token);
      localStorage.setItem('user_role', role);
      onLoginSuccess();
      navigate('/dashboard');
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Login failed. Check credentials.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="login-container">
      <div className="login-card">
        <div className="brand-section" style={{ justifyContent: 'center', marginBottom: '24px' }}>
          <div className="brand-icon"><TrendingUp size={20} /></div>
          <span className="brand-title">MarketPulse Admin</span>
        </div>
        <h2 className="login-title">Welcome back</h2>
        <p className="login-subtitle">Sign in to access system operations</p>
        {error && <div className="auth-error-banner">{error}</div>}
        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label className="form-label">Email address</label>
            <input type="email" className="form-input" placeholder="admin@marketpulse.com" value={email} onChange={(e) => setEmail(e.target.value)} required />
          </div>
          <div className="form-group">
            <label className="form-label">Password</label>
            <input type="password" className="form-input" placeholder="••••••••" value={password} onChange={(e) => setPassword(e.target.value)} required />
          </div>
          <button type="submit" className="btn-primary" disabled={isLoading}>
            {isLoading ? <span className="spinner" style={{ width: '16px', height: '16px' }} /> : <><span>Sign In</span><ArrowRight size={16} /></>}
          </button>
        </form>
      </div>
    </div>
  );
}

// ── LAYOUT ─────────────────────────────────────────────────────────────────────

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

  const navItems = [
    { path: '/dashboard', label: 'Dashboard' },
    { path: '/review', label: 'Review Queue' },
    { path: '/manual-entry', label: 'Manual Entry' },
    { path: '/vector-training', label: 'Vector Training', badge: true },
    { path: '/payments', label: 'Payments' },
  ];

  return (
    <div className="admin-container">
      <header className="admin-header">
        <div className="brand-section">
          <div className="brand-icon"><TrendingUp size={18} /></div>
          <span className="brand-title">MarketPulse Admin</span>
        </div>
        <nav className="header-nav">
          {navItems.map(item => (
            <button
              key={item.path}
              className={`btn-nav ${isActive(item.path) ? 'active' : ''}`}
              onClick={() => navigate(item.path)}
            >
              {item.path === '/vector-training' && <Brain size={13} style={{ marginRight: 4 }} />}
              {item.label}
              {item.badge && <span className="nav-badge">AWS</span>}
            </button>
          ))}
          <button className="btn-logout" onClick={handleLogout}>
            <LogOut size={14} /> Log Out
          </button>
        </nav>
      </header>
      <main className="admin-content">{children}</main>
    </div>
  );
}

// ── DASHBOARD ─────────────────────────────────────────────────────────────────

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
    } catch { setStatus('error'); }
  };

  useEffect(() => {
    fetchHealth();
    const interval = setInterval(fetchHealth, 15000);
    return () => clearInterval(interval);
  }, []);

  const formatTimeAgo = (isoString: string | null) => {
    if (!isoString) return 'Never';
    const diffMins = Math.floor((Date.now() - new Date(isoString).getTime()) / 60000);
    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins}m ago`;
    return `${Math.floor(diffMins / 60)}h ago`;
  };

  return (
    <div>
      {status === 'healthy' && <div className="status-banner healthy"><CheckCircle2 size={16} /> System operational</div>}
      {status === 'error' && <div className="status-banner error"><AlertTriangle size={16} /> Cannot reach backend API</div>}
      {status === 'loading' && !health && <div className="status-banner loading"><RefreshCw size={16} className="spinner" style={{ animation: 'spin 1.5s linear infinite' }} /> Fetching system status...</div>}

      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
        <h2 className="section-title" style={{ marginBottom: 0 }}>System Health</h2>
        <button onClick={fetchHealth} style={{ color: 'var(--text-secondary)', display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px' }}>
          <RefreshCw size={14} /> Refresh
        </button>
      </div>

      <div className="stats-grid">
        {[
          { icon: <Globe size={20} />, label: 'Queue Size', value: health?.queue_size ?? 0, color: 'var(--primary-color)', bg: 'rgba(99,102,241,0.1)' },
          { icon: <FileText size={20} />, label: 'Total Articles', value: health?.total_articles ?? 0, color: 'var(--success-color)', bg: 'rgba(16,185,129,0.1)' },
          { icon: <AlertTriangle size={20} />, label: 'Errors', value: health?.error_count ?? 0, color: 'var(--danger-color)', bg: 'rgba(239,68,68,0.1)' },
          { icon: <KeyRound size={20} />, label: 'Last Ingestion', value: formatTimeAgo(health?.last_ingestion_time || null), color: 'var(--warning-color)', bg: 'rgba(245,158,11,0.1)' },
        ].map((stat, i) => (
          <div key={i} className="stat-card">
            <div className="stat-icon" style={{ backgroundColor: stat.bg, color: stat.color }}>{stat.icon}</div>
            <div className="stat-details">
              <span className="stat-label">{stat.label}</span>
              <span className="stat-value" style={{ fontSize: typeof stat.value === 'string' ? '16px' : undefined }}>{stat.value}</span>
            </div>
          </div>
        ))}
      </div>

      <h2 className="section-title">Quick Actions</h2>
      <div className="actions-list">
        {[
          { icon: <CheckCircle2 size={18} />, color: 'var(--primary-color)', title: 'Review Queue', sub: 'Approve or reject low-confidence articles', path: '/review' },
          { icon: <PlusCircle size={18} />, color: 'var(--success-color)', title: 'Manual Article Entry', sub: 'Submit an article directly to the pipeline', path: '/manual-entry' },
          { icon: <Brain size={18} />, color: '#8B5CF6', title: 'Vector Training', sub: 'Train AI on news↔stock relationships (AWS)', path: '/vector-training' },
          { icon: <DollarSign size={18} />, color: 'var(--warning-color)', title: 'Payments Overview', sub: 'View subscription and revenue summary', path: '/payments' },
        ].map((action, i) => (
          <button key={i} className="action-tile" onClick={() => navigate(action.path)}>
            <div className="action-icon" style={{ backgroundColor: action.color }}>{action.icon}</div>
            <div className="action-info">
              <div className="action-title">{action.title}</div>
              <div className="action-subtitle">{action.sub}</div>
            </div>
            <ArrowRight size={16} style={{ color: 'var(--text-muted)' }} />
          </button>
        ))}
      </div>
    </div>
  );
}

// ── REVIEW QUEUE ──────────────────────────────────────────────────────────────

function ReviewScreen() {
  const [articles, setArticles] = useState<Article[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchQueue = async () => {
    setIsLoading(true); setError(null);
    try {
      const response = await api.get('/admin/articles/review');
      setArticles(response.data);
    } catch { setError('Failed to fetch review queue'); }
    finally { setIsLoading(false); }
  };

  useEffect(() => { fetchQueue(); }, []);

  const handleAction = async (id: string, action: 'approve' | 'reject') => {
    try {
      await api.patch(`/admin/articles/${id}/review`, null, { params: { action } });
      setArticles((prev) => prev.filter((a) => a.id !== id));
    } catch { alert(`Failed to ${action} article`); }
  };

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
        <h2 className="section-title" style={{ marginBottom: 0 }}>Review Queue</h2>
        <button onClick={fetchQueue} style={{ color: 'var(--text-secondary)', display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px' }}>
          <RefreshCw size={14} /> Refresh
        </button>
      </div>
      {isLoading ? (
        <div className="loader-container"><div className="spinner" /></div>
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
          <div className="review-header-info"><ShieldAlert size={14} /><span>{articles.length} articles need review</span></div>
          <div className="review-list">
            {articles.map((article) => (
              <div key={article.id} className="review-tile">
                <div className="tile-top">
                  {article.classification_confidence !== undefined && (
                    <span className={`confidence-badge ${article.classification_confidence >= 0.7 ? 'high' : article.classification_confidence >= 0.5 ? 'medium' : 'low'}`}>
                      {Math.round(article.classification_confidence * 100)}% confidence
                    </span>
                  )}
                  {article.source && <span className="tile-source">{article.source}</span>}
                </div>
                <div className="tile-headline">{article.headline}</div>
                {article.summary && <div className="tile-summary">{article.summary}</div>}
                <div className="tile-footer">
                  <div className="badge-row">
                    <span className="badge credibility">{article.credibility || 'Opinion'}</span>
                    <span className="badge geography">{article.geography || 'Global'}</span>
                  </div>
                  <div className="tile-actions">
                    <button className="btn-action approve" onClick={() => handleAction(article.id, 'approve')}><Check size={14} /> Approve</button>
                    <button className="btn-action reject" onClick={() => handleAction(article.id, 'reject')}><X size={14} /> Reject</button>
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

// ── MANUAL ENTRY ──────────────────────────────────────────────────────────────

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
    setIsSubmitting(true); setSuccess(false);
    try {
      await api.post('/admin/articles/manual', {
        headline: headline.trim(), content: content.trim() || null,
        source: source.trim() || null, url: url.trim() || null,
      });
      setHeadline(''); setContent(''); setSource(''); setUrl('');
      setSuccess(true);
      setTimeout(() => setSuccess(false), 5000);
    } catch { alert('Failed to submit manual article'); }
    finally { setIsSubmitting(false); }
  };

  return (
    <div>
      <h2 className="section-title">Manual Article Entry</h2>
      <div className="manual-form-card">
        {success && <div className="info-banner"><CheckCircle2 size={16} /> Article successfully queued for NLP pipeline classification</div>}
        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label className="form-label">Headline *</label>
            <input type="text" className="form-input" placeholder="Enter article headline..." value={headline} onChange={(e) => setHeadline(e.target.value)} required />
          </div>
          <div className="form-group">
            <label className="form-label">Content / Summary</label>
            <textarea className="form-input" rows={5} placeholder="Paste article body text or metadata context..." value={content} onChange={(e) => setContent(e.target.value)} style={{ resize: 'vertical' }} />
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
            <div className="form-group">
              <label className="form-label">Source</label>
              <input type="text" className="form-input" placeholder="e.g. Mint, Bloomberg" value={source} onChange={(e) => setSource(e.target.value)} />
            </div>
            <div className="form-group">
              <label className="form-label">Article URL</label>
              <input type="url" className="form-input" placeholder="https://..." value={url} onChange={(e) => setUrl(e.target.value)} />
            </div>
          </div>
          <button type="submit" className="btn-primary" style={{ marginTop: '24px', backgroundColor: 'var(--success-color)' }} disabled={isSubmitting}>
            {isSubmitting ? <span className="spinner" style={{ width: '16px', height: '16px' }} /> : <><span>Submit to Pipeline</span><PlusCircle size={16} /></>}
          </button>
        </form>
      </div>
    </div>
  );
}

// ── VECTOR TRAINING SCREEN ─────────────────────────────────────────────────────

function VectorTrainingScreen() {
  const [activeTab, setActiveTab] = useState<'pending' | 'synced' | 'stocks'>('pending');
  const [vectorStats, setVectorStats] = useState<VectorStats | null>(null);
  const [statsLoading, setStatsLoading] = useState(true);

  const fetchStats = useCallback(async () => {
    setStatsLoading(true);
    try {
      const res = await api.get('/admin/vector/stats');
      setVectorStats(res.data);
    } catch { setVectorStats(null); }
    finally { setStatsLoading(false); }
  }, []);

  useEffect(() => { fetchStats(); }, [fetchStats]);

  return (
    <div>
      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '20px' }}>
        <div>
          <h2 className="section-title" style={{ marginBottom: 4 }}>
            <Brain size={20} style={{ display: 'inline', marginRight: 8, color: '#8B5CF6' }} />
            Vector Training — AWS
          </h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '13px', margin: 0 }}>
            Train the AI on news↔stock relationships using Amazon Bedrock + OpenSearch Serverless
          </p>
        </div>
        <button onClick={fetchStats} style={{ color: 'var(--text-secondary)', display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px' }}>
          <RefreshCw size={14} /> Refresh
        </button>
      </div>

      {/* AWS Status Cards */}
      <div className="vector-stats-row">
        <VectorStatCard
          icon={<Cpu size={18} />}
          label="AWS Bedrock"
          value={vectorStats?.available ? 'Connected' : 'Not Configured'}
          color={vectorStats?.available ? 'var(--success-color)' : 'var(--text-muted)'}
          sub="Titan Embeddings V2"
        />
        <VectorStatCard
          icon={<Database size={18} />}
          label="News Vectors"
          value={statsLoading ? '...' : String(vectorStats?.news_count ?? 0)}
          color="var(--primary-color)"
          sub="In OpenSearch index"
        />
        <VectorStatCard
          icon={<BarChart2 size={18} />}
          label="Stock Profiles"
          value={statsLoading ? '...' : String(vectorStats?.stock_count ?? 0)}
          color="#F59E0B"
          sub="Vice-versa profiles"
        />
        <VectorStatCard
          icon={<Clock size={18} />}
          label="Pending Sync"
          value={statsLoading ? '...' : String(vectorStats?.pending_sync_count ?? 0)}
          color={vectorStats && vectorStats.pending_sync_count > 0 ? 'var(--danger-color)' : 'var(--success-color)'}
          sub="Articles awaiting sync"
        />
      </div>

      {/* Tabs */}
      <div className="vector-tabs">
        {[
          { id: 'pending', label: 'Pending Training', icon: <Zap size={14} /> },
          { id: 'synced', label: 'Trained Articles', icon: <CheckCircle2 size={14} /> },
          { id: 'stocks', label: 'Stock Profiles (Vice-Versa)', icon: <Link2 size={14} /> },
        ].map((tab) => (
          <button
            key={tab.id}
            className={`vector-tab ${activeTab === tab.id ? 'active' : ''}`}
            onClick={() => setActiveTab(tab.id as typeof activeTab)}
          >
            {tab.icon} {tab.label}
          </button>
        ))}
      </div>

      {/* Tab content */}
      <div style={{ marginTop: '16px' }}>
        {activeTab === 'pending' && <PendingTrainingPanel onSyncComplete={fetchStats} />}
        {activeTab === 'synced' && <SyncedArticlesPanel />}
        {activeTab === 'stocks' && <StockProfilesPanel />}
      </div>
    </div>
  );
}

function VectorStatCard({ icon, label, value, color, sub }: { icon: React.ReactNode; label: string; value: string; color: string; sub: string }) {
  return (
    <div className="vector-stat-card">
      <div className="vector-stat-icon" style={{ color }}>{icon}</div>
      <div>
        <div className="vector-stat-label">{label}</div>
        <div className="vector-stat-value" style={{ color }}>{value}</div>
        <div className="vector-stat-sub">{sub}</div>
      </div>
    </div>
  );
}

// ── PENDING TRAINING PANEL ─────────────────────────────────────────────────────

function PendingTrainingPanel({ onSyncComplete }: { onSyncComplete: () => void }) {
  const [articles, setArticles] = useState<Article[]>([]);
  const [loading, setLoading] = useState(true);
  const [bulkLoading, setBulkLoading] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);

  const fetchPending = async () => {
    setLoading(true);
    try {
      const res = await api.get('/admin/vector/pending?limit=100');
      setArticles(res.data);
    } catch { /* empty */ }
    finally { setLoading(false); }
  };

  useEffect(() => { fetchPending(); }, []);

  const syncOne = async (id: string) => {
    try {
      await api.post(`/admin/vector/train/${id}`);
      setArticles(prev => prev.filter(a => a.id !== id));
      onSyncComplete();
    } catch { alert('Sync failed'); }
  };

  const syncAll = async () => {
    setBulkLoading(true);
    try {
      const res = await api.post('/admin/vector/train-all');
      alert(`Bulk sync complete: ${res.data.synced} synced, ${res.data.failed} failed`);
      fetchPending();
      onSyncComplete();
    } catch { alert('Bulk sync failed'); }
    finally { setBulkLoading(false); }
  };

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
        <p style={{ color: 'var(--text-secondary)', fontSize: '13px', margin: 0 }}>
          These articles were AI-processed but not yet embedded into the AWS vector store.
          Sync them to improve future predictions via RAG context injection.
        </p>
        {articles.length > 0 && (
          <button className="btn-primary" style={{ whiteSpace: 'nowrap', padding: '8px 16px', fontSize: '13px' }} onClick={syncAll} disabled={bulkLoading}>
            {bulkLoading ? <span className="spinner" style={{ width: '14px', height: '14px' }} /> : <><Zap size={13} /> Sync All ({articles.length})</>}
          </button>
        )}
      </div>

      {loading ? (
        <div className="loader-container"><div className="spinner" /></div>
      ) : articles.length === 0 ? (
        <div className="empty-state">
          <CheckCircle2 className="empty-icon" />
          <h3 className="empty-title">All synced!</h3>
          <p className="empty-subtitle">No articles pending vector store sync.</p>
        </div>
      ) : (
        <div className="training-list">
          {articles.map((article) => (
            <TrainingArticleRow
              key={article.id}
              article={article}
              onSync={() => syncOne(article.id)}
              isEditing={editingId === article.id}
              onEdit={() => setEditingId(article.id)}
              onEditClose={() => { setEditingId(null); fetchPending(); onSyncComplete(); }}
            />
          ))}
        </div>
      )}
    </div>
  );
}

function TrainingArticleRow({
  article, onSync, isEditing, onEdit, onEditClose,
}: {
  article: Article;
  onSync: () => void;
  isEditing: boolean;
  onEdit: () => void;
  onEditClose: () => void;
}) {
  const [syncing, setSyncing] = useState(false);
  const [symbols, setSymbols] = useState(
    article.impacts?.map(i => i.symbol).join(', ') || ''
  );
  const [sector, setSector] = useState(article.impacts?.[0]?.sector || 'broad market');
  const [direction, setDirection] = useState(article.impacts?.[0]?.direction || 'neutral');
  const [saving, setSaving] = useState(false);

  const handleSync = async () => {
    setSyncing(true);
    await onSync();
    setSyncing(false);
  };

  const handleSave = async () => {
    const symList = symbols.split(',').map(s => s.trim().toUpperCase()).filter(Boolean);
    if (!symList.length) { alert('Enter at least one stock symbol'); return; }
    setSaving(true);
    try {
      await api.patch(`/admin/articles/${article.id}/train-stocks`, {
        stock_symbols: symList,
        sector,
        direction,
      });
      onEditClose();
    } catch { alert('Failed to save changes'); }
    finally { setSaving(false); }
  };

  const sentimentColor = { bullish: '#10B981', bearish: '#EF4444', neutral: '#8B8FA8' }[article.sentiment || 'neutral'] || '#8B8FA8';

  return (
    <div className={`training-row ${isEditing ? 'editing' : ''}`}>
      <div className="training-row-main">
        <div className="training-row-left">
          <div className="training-row-headline">{article.headline}</div>
          <div className="training-row-meta">
            {article.source && <span className="meta-chip">{article.source}</span>}
            {article.sentiment && <span className="meta-chip" style={{ color: sentimentColor, borderColor: sentimentColor + '44' }}>{article.sentiment}</span>}
            {article.impacts && article.impacts.length > 0 && (
              <span className="meta-chip" style={{ color: 'var(--primary-color)' }}>
                {article.impacts.slice(0, 3).map(i => i.symbol).join(', ')}
                {article.impacts.length > 3 && ` +${article.impacts.length - 3}`}
              </span>
            )}
          </div>
        </div>
        <div className="training-row-actions">
          <button className="btn-train-edit" onClick={onEdit} title="Edit stock associations">
            <Edit3 size={13} />
          </button>
          <button className="btn-train-sync" onClick={handleSync} disabled={syncing}>
            {syncing ? <span className="spinner" style={{ width: '12px', height: '12px' }} /> : <><Zap size={13} /> Sync</>}
          </button>
        </div>
      </div>

      {isEditing && (
        <div className="training-edit-panel">
          <div className="edit-panel-title"><Edit3 size={13} /> Edit Stock Associations</div>
          <div className="edit-fields">
            <div className="form-group" style={{ margin: 0 }}>
              <label className="form-label">Stock Symbols (comma separated)</label>
              <input
                className="form-input"
                placeholder="e.g. HDFCBANK, ICICIBANK, SBIN"
                value={symbols}
                onChange={e => setSymbols(e.target.value)}
              />
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
              <div className="form-group" style={{ margin: 0 }}>
                <label className="form-label">Sector</label>
                <select className="form-input" value={sector} onChange={e => setSector(e.target.value)}>
                  {['banking', 'it', 'pharma', 'fmcg', 'auto', 'realty', 'oil & gas', 'broad market', 'aviation', 'telecom', 'metals', 'infra'].map(s => (
                    <option key={s} value={s}>{s}</option>
                  ))}
                </select>
              </div>
              <div className="form-group" style={{ margin: 0 }}>
                <label className="form-label">Direction</label>
                <select className="form-input" value={direction} onChange={e => setDirection(e.target.value)}>
                  <option value="positive">Positive ▲</option>
                  <option value="negative">Negative ▼</option>
                  <option value="neutral">Neutral ━</option>
                </select>
              </div>
            </div>
          </div>
          <div style={{ display: 'flex', gap: '8px', marginTop: '12px' }}>
            <button className="btn-primary" style={{ padding: '8px 16px', fontSize: '12px', backgroundColor: '#8B5CF6' }} onClick={handleSave} disabled={saving}>
              {saving ? <span className="spinner" style={{ width: '12px', height: '12px' }} /> : <><Save size={12} /> Save & Re-sync (Admin Verified)</>}
            </button>
            <button style={{ color: 'var(--text-muted)', fontSize: '12px', padding: '8px 12px' }} onClick={onEditClose}>
              Cancel
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

// ── SYNCED ARTICLES PANEL ─────────────────────────────────────────────────────

function SyncedArticlesPanel() {
  const [articles, setArticles] = useState<Article[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    (async () => {
      setLoading(true);
      try {
        const res = await api.get('/admin/vector/synced?limit=50');
        setArticles(res.data);
      } catch { /**/ }
      finally { setLoading(false); }
    })();
  }, []);

  if (loading) return <div className="loader-container"><div className="spinner" /></div>;

  return (
    <div>
      <p style={{ color: 'var(--text-secondary)', fontSize: '13px', marginBottom: '16px' }}>
        {articles.length} articles are embedded in the AWS OpenSearch vector store and used as RAG context for future AI predictions.
      </p>
      {articles.length === 0 ? (
        <div className="empty-state">
          <Database className="empty-icon" />
          <h3 className="empty-title">No synced articles yet</h3>
          <p className="empty-subtitle">Sync articles from the Pending Training tab to get started.</p>
        </div>
      ) : (
        <div className="synced-list">
          {articles.map(art => (
            <div key={art.id} className="synced-row">
              <div className="synced-row-left">
                <span className="sync-badge"><CheckCircle2 size={11} /> Synced</span>
                <span className="synced-headline">{art.headline}</span>
              </div>
              <div className="synced-stocks">
                {art.impacts?.slice(0, 4).map(i => (
                  <span key={i.symbol} className={`stock-chip direction-${i.direction}`}>{i.symbol}</span>
                ))}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

// ── STOCK PROFILES PANEL (VICE-VERSA) ─────────────────────────────────────────

function StockProfilesPanel() {
  const [searchSymbol, setSearchSymbol] = useState('');
  const [newsResults, setNewsResults] = useState<StockNewsItem[] | null>(null);
  const [searching, setSearching] = useState(false);
  const [searchedSymbol, setSearchedSymbol] = useState('');

  const searchStock = async () => {
    const sym = searchSymbol.trim().toUpperCase();
    if (!sym) return;
    setSearching(true);
    setSearchedSymbol(sym);
    try {
      const res = await api.get(`/admin/stocks/${sym}/news`);
      setNewsResults(res.data.news || []);
    } catch { setNewsResults([]); }
    finally { setSearching(false); }
  };

  return (
    <div>
      {/* Header */}
      <div className="vice-versa-header">
        <div className="vice-versa-icon"><Link2 size={20} /></div>
        <div>
          <div className="vice-versa-title">Vice-Versa: Stock → News</div>
          <div className="vice-versa-sub">
            Enter a stock symbol to see all news articles that affect it and their directional impact.
            Admin-verified associations feed directly into user app intelligence.
          </div>
        </div>
      </div>

      {/* Search */}
      <div className="stock-search-bar">
        <div className="stock-search-input-wrap">
          <Search size={15} />
          <input
            className="stock-search-input"
            placeholder="e.g. HDFCBANK, RELIANCE, TCS..."
            value={searchSymbol}
            onChange={e => setSearchSymbol(e.target.value.toUpperCase())}
            onKeyDown={e => e.key === 'Enter' && searchStock()}
          />
        </div>
        <button className="btn-primary" style={{ padding: '10px 20px', fontSize: '13px' }} onClick={searchStock} disabled={searching || !searchSymbol.trim()}>
          {searching ? <span className="spinner" style={{ width: '14px', height: '14px' }} /> : <><Search size={13} /> Find News</>}
        </button>
      </div>

      {/* Quick symbol chips */}
      <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', marginBottom: '20px' }}>
        {['HDFCBANK', 'RELIANCE', 'TCS', 'INFY', 'SBIN', 'TATAMOTORS', 'ICICIBANK', 'WIPRO'].map(sym => (
          <button
            key={sym}
            className="quick-sym-chip"
            onClick={() => { setSearchSymbol(sym); }}
          >
            {sym}
          </button>
        ))}
      </div>

      {/* Results */}
      {newsResults !== null && (
        <div>
          <div className="search-results-header">
            <span className="search-results-symbol">{searchedSymbol}</span>
            <span style={{ color: 'var(--text-secondary)', fontSize: '13px' }}>
              {newsResults.length} news article{newsResults.length !== 1 ? 's' : ''} found
            </span>
          </div>

          {newsResults.length === 0 ? (
            <div className="empty-state" style={{ padding: '32px' }}>
              <AlertCircle className="empty-icon" />
              <h3 className="empty-title">No articles found</h3>
              <p className="empty-subtitle">No news articles for {searchedSymbol} yet. They'll appear as the AI pipeline processes more articles.</p>
            </div>
          ) : (
            <div className="news-results-list">
              {newsResults.map((item, i) => (
                <StockNewsRow key={item.article_id || i} item={item} />
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

function StockNewsRow({ item }: { item: StockNewsItem }) {
  const dirColor = { positive: '#10B981', negative: '#EF4444', neutral: '#8B8FA8' }[item.direction] || '#8B8FA8';
  const dirIcon = { positive: '▲', negative: '▼', neutral: '━' }[item.direction] || '━';
  const senColor = { bullish: '#10B981', bearish: '#EF4444', neutral: '#8B8FA8' }[item.sentiment] || '#8B8FA8';

  return (
    <div className="stock-news-row">
      <div className="stock-news-row-left">
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '6px' }}>
          <span className="dir-badge" style={{ color: dirColor, borderColor: dirColor + '44', backgroundColor: dirColor + '15' }}>
            {dirIcon} {item.direction.toUpperCase()}
          </span>
          <span className="sent-badge" style={{ color: senColor }}>{item.sentiment}</span>
          {item.admin_verified && <span className="verified-badge"><CheckCircle2 size={10} /> Admin Verified</span>}
          {item.sector && <span style={{ color: 'var(--text-muted)', fontSize: '11px' }}>{item.sector}</span>}
        </div>
        <div className="stock-news-headline">{item.headline}</div>
        {item.reason && <div className="stock-news-reason">{item.reason}</div>}
      </div>
      <div className="stock-news-date">{item.published_at ? new Date(item.published_at).toLocaleDateString() : '–'}</div>
    </div>
  );
}

// ── PAYMENTS ──────────────────────────────────────────────────────────────────

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
          <div className="stat-icon" style={{ backgroundColor: 'rgba(245,158,11,0.1)', color: 'var(--warning-color)' }}><DollarSign size={20} /></div>
          <div className="stat-details">
            <span className="stat-label">Monthly Recurring Revenue (MRR)</span>
            <span className="stat-value">₹2,48,000</span>
          </div>
        </div>
        <div className="stat-card" style={{ opacity: 0.8 }}>
          <div className="stat-icon" style={{ backgroundColor: 'rgba(16,185,129,0.1)', color: 'var(--success-color)' }}><CheckCircle2 size={20} /></div>
          <div className="stat-details">
            <span className="stat-label">Active Subscribers</span>
            <span className="stat-value">114</span>
          </div>
        </div>
      </div>
    </div>
  );
}
