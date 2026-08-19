const STORAGE_KEY = 'outlook_mail_web_v1';
const FILTERS = ['success', 'all', 'failed'];
const FOLDERS = { inbox: '收件箱', junkemail: '垃圾邮件', deleteditems: '已删除' };

const demoAccounts = [
  { id: 'demo-1', email: 'miku@outlook.com', password: '', clientId: '', refreshToken: '', status: 'success', unreadCount: 2, isFavorite: true, demo: true },
  { id: 'demo-2', email: 'studio@outlook.com', password: '', clientId: '', refreshToken: '', status: 'success', unreadCount: 1, isFavorite: false, demo: true },
  { id: 'demo-3', email: 'archive@outlook.com', password: '', clientId: '', refreshToken: '', status: 'failed', unreadCount: 0, isFavorite: false, errorMessage: '演示账号未连接', demo: true },
];

const demoMessages = {
  'demo-1:inbox': [
    { id: 'miku-1', subject: '你的本周摘要已准备好', sender: 'Microsoft Outlook', recipients: 'miku@outlook.com', receivedAt: '2026-08-19T08:40:00+08:00', isRead: false, hasAttachments: false, preview: '查看最近的登录活动、收件箱整理建议和账户安全提醒。', body: '<h2>本周摘要</h2><p>你的收件箱运行良好。这里是最近一周的账户活动与整理建议。</p><p><a href="https://outlook.live.com">打开 Outlook</a></p>' },
    { id: 'miku-2', subject: '项目设计评审记录', sender: '林澈', recipients: 'miku@outlook.com', receivedAt: '2026-08-18T16:12:00+08:00', isRead: false, hasAttachments: true, preview: '谢谢今天的讨论，我把邮件渲染和缓存部分的结论整理在这里。', body: '<p>谢谢今天的讨论，我把邮件渲染和缓存部分的结论整理在这里。</p><ul><li>正文默认纯文本</li><li>HTML 通过白名单过滤</li></ul>' },
    { id: 'miku-3', subject: '欢迎使用本地邮箱', sender: '本地邮箱', recipients: 'miku@outlook.com', receivedAt: '2026-08-17T11:30:00+08:00', isRead: true, hasAttachments: false, preview: '这是一个演示邮件，用来查看详情页和左右切换。', body: '<p>这是一个演示邮件，用来查看详情页和左右切换。</p>' },
  ],
  'demo-2:inbox': [
    { id: 'studio-1', subject: '设计系统更新通知', sender: 'Studio Notes', recipients: 'studio@outlook.com', receivedAt: '2026-08-18T09:05:00+08:00', isRead: false, hasAttachments: false, preview: '新的颜色变量和边框规则已经同步。', body: '<h2>设计系统更新</h2><p>新的颜色变量和边框规则已经同步，请在下次评审前查看。</p>' },
    { id: 'studio-2', subject: '上月账单', sender: 'Billing', recipients: 'studio@outlook.com', receivedAt: '2026-08-12T18:20:00+08:00', isRead: true, hasAttachments: true, preview: '你的账单已生成，附件中包含明细。', body: '<p>你的账单已生成，附件中包含明细。</p>' },
  ],
};

const state = {
  accounts: [], messages: {}, activeAccountId: null, activeMessageId: null,
  filter: 'success', folder: 'inbox', accountQuery: '', mailQuery: '', bodyMode: 'plain', selectedIds: new Set(), loading: false, sessions: {},
};

const $ = (selector) => document.querySelector(selector);
const escapeHtml = (value = '') => String(value).replace(/[&<>'"]/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' })[char]);
const formatDate = (value) => value ? new Intl.DateTimeFormat('zh-CN', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }).format(new Date(value)) : '';
const initials = (value = '') => value.trim().slice(0, 1).toUpperCase() || '?';
const keyFor = (accountId, folder) => `${accountId}:${folder}`;

function persist() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify({ accounts: state.accounts, messages: state.messages }));
}

function loadState() {
  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || 'null');
    state.accounts = saved?.accounts?.length ? saved.accounts : structuredClone(demoAccounts);
    state.messages = saved?.messages || structuredClone(demoMessages);
  } catch (_) { state.accounts = structuredClone(demoAccounts); state.messages = structuredClone(demoMessages); }
  state.activeAccountId = filteredAccounts()[0]?.id || null;
}

function filteredAccounts() {
  const query = state.accountQuery.toLowerCase();
  return state.accounts.filter((account) => {
    const filterMatch = state.filter === 'all' || account.status === state.filter;
    return filterMatch && account.email.toLowerCase().includes(query);
  });
}

function currentAccount() { return state.accounts.find((account) => account.id === state.activeAccountId) || null; }
function currentMessages() {
  const account = currentAccount(); if (!account) return [];
  const query = state.mailQuery.toLowerCase();
  return (state.messages[keyFor(account.id, state.folder)] || []).filter((message) => `${message.subject} ${message.sender} ${message.preview}`.toLowerCase().includes(query));
}
function currentMessage() { return currentMessages().find((message) => message.id === state.activeMessageId) || null; }

function render() {
  renderCounts(); renderAccounts(); renderWorkspace(); renderMailList(); renderDetail();
}

function renderCounts() {
  $('#success-count').textContent = state.accounts.filter((a) => a.status === 'success').length;
  $('#all-count').textContent = state.accounts.length;
  $('#failed-count').textContent = state.accounts.filter((a) => a.status === 'failed').length;
  document.querySelectorAll('[data-filter]').forEach((button) => button.classList.toggle('active', button.dataset.filter === state.filter));
}

function renderAccounts() {
  const accounts = filteredAccounts();
  $('#account-list').innerHTML = accounts.length ? accounts.map((account) => `
    <button class="account-row ${account.id === state.activeAccountId ? 'active' : ''}" data-account-id="${escapeHtml(account.id)}">
      <span class="account-avatar">${escapeHtml(initials(account.email))}</span>
      <span class="account-copy"><span class="account-email">${escapeHtml(account.email || '未命名账号')}</span><span class="account-meta">${account.status === 'failed' ? escapeHtml(account.errorMessage || '验证失败') : `${account.unreadCount || 0} 封未读邮件`}</span></span>
      <span class="account-status ${account.status}">${account.isFavorite ? '★' : account.status === 'success' ? '●' : '×'}</span>
    </button>`).join('') : '<div class="empty-list">没有符合当前筛选的邮箱。<br />可以从右上角添加账号。</div>';
  document.querySelectorAll('[data-account-id]').forEach((button) => button.addEventListener('click', () => selectAccount(button.dataset.accountId)));
}

function renderWorkspace() {
  const account = currentAccount();
  const hasAccount = Boolean(account);
  $('#empty-state').classList.toggle('hidden', hasAccount);
  $('#mail-view').classList.toggle('hidden', !hasAccount);
  $('#workspace-eyebrow').textContent = state.filter === 'success' ? '成功账号' : state.filter === 'failed' ? '失败账号' : '全部账号';
  $('#workspace-title').textContent = account ? account.email : '选择一个邮箱';
  $('#sync-label').textContent = state.loading ? '同步中…' : account ? '已缓存' : '等待同步';
  $('#inbox-count').textContent = account ? (state.messages[keyFor(account.id, 'inbox')] || []).filter((message) => !message.isRead).length : 0;
  document.querySelectorAll('[data-folder]').forEach((button) => button.classList.toggle('active', button.dataset.folder === state.folder));
}

function renderMailList() {
  const messages = currentMessages();
  $('#mail-list').innerHTML = messages.length ? messages.map((message) => `
    <button class="mail-row ${message.id === state.activeMessageId ? 'active' : ''} ${message.isRead ? '' : 'unread'}" data-message-id="${escapeHtml(message.id)}">
      <span class="mail-unread-dot"></span><span><span class="mail-sender">${escapeHtml(message.sender)}</span><span class="mail-subject">${escapeHtml(message.subject)}</span><span class="mail-preview">${escapeHtml(message.preview)}</span></span><span class="mail-date">${formatDate(message.receivedAt)}</span>
    </button>`).join('') : '<div class="empty-list">当前文件夹没有邮件。<br />刷新或切换其他邮箱试试。</div>';
  document.querySelectorAll('[data-message-id]').forEach((button) => button.addEventListener('click', () => selectMessage(button.dataset.messageId)));
}

function renderDetail() {
  const message = currentMessage();
  if (!message) { $('#mail-detail').innerHTML = '<div class="detail-empty">选择一封邮件查看正文</div>'; return; }
  const body = state.bodyMode === 'plain' ? plainText(message.body || message.preview) : message.body || `<p>${escapeHtml(message.preview)}</p>`;
  $('#mail-detail').innerHTML = `<div class="detail-head">
    <div class="detail-kicker">${escapeHtml(FOLDERS[state.folder])}</div><h3 class="detail-subject">${escapeHtml(message.subject)}</h3>
    <div class="detail-meta"><span class="sender-avatar">${escapeHtml(initials(message.sender))}</span><span class="meta-copy"><strong>${escapeHtml(message.sender)}</strong><span>收件人：${escapeHtml(message.recipients || '当前账号')} · ${formatDate(message.receivedAt)}</span></span><div class="detail-actions"><button class="detail-action" data-detail="read" title="标记已读">✓</button><button class="detail-action" data-detail="favorite" title="收藏">★</button><button class="detail-action danger" data-detail="delete" title="删除">⌫</button></div></div>
    <div class="body-switcher"><button class="body-mode ${state.bodyMode === 'plain' ? 'active' : ''}" data-body-mode="plain">纯文本</button><button class="body-mode ${state.bodyMode === 'html' ? 'active' : ''}" data-body-mode="html">渲染邮件</button></div>
    <div class="body-content">${state.bodyMode === 'plain' ? `<pre>${escapeHtml(body)}</pre>` : `<iframe sandbox="allow-same-origin" title="邮件 HTML 预览" srcdoc="${escapeHtml(safeEmailDocument(body))}"></iframe>`}</div>
  </div>`;
  document.querySelectorAll('[data-body-mode]').forEach((button) => button.addEventListener('click', () => { state.bodyMode = button.dataset.bodyMode; renderDetail(); }));
  document.querySelectorAll('[data-detail]').forEach((button) => button.addEventListener('click', () => handleDetailAction(button.dataset.detail)));
}

function plainText(value) { return String(value).replace(/<(https?:\/\/[^>\s]+)>/gi, '$1').replace(/<[^>]+>/g, '').replace(/\s{3,}/g, '\n\n').trim(); }
function sanitizeHtml(source) {
  const allowedTags = new Set(['A', 'B', 'BLOCKQUOTE', 'BR', 'CENTER', 'CODE', 'DIV', 'EM', 'FONT', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6', 'HR', 'I', 'IMG', 'LI', 'OL', 'P', 'PRE', 'SMALL', 'SPAN', 'STRONG', 'SUB', 'SUP', 'TABLE', 'TBODY', 'TD', 'TH', 'THEAD', 'TR', 'U', 'UL']);
  const allowedAttrs = new Set(['align', 'alt', 'border', 'cellpadding', 'cellspacing', 'class', 'colspan', 'height', 'href', 'rowspan', 'src', 'style', 'title', 'width']);
  const documentNode = new DOMParser().parseFromString(String(source || ''), 'text/html');
  documentNode.querySelectorAll('*').forEach((element) => {
    if (!allowedTags.has(element.tagName)) { element.replaceWith(...element.childNodes); return; }
    [...element.attributes].forEach((attribute) => { if (!allowedAttrs.has(attribute.name.toLowerCase())) element.removeAttribute(attribute.name); });
    ['href', 'src'].forEach((name) => { const value = element.getAttribute(name)?.trim() || ''; const safe = /^(https?:|mailto:|cid:|data:image\/|#)/i.test(value); if (value && !safe) element.removeAttribute(name); });
    const style = element.getAttribute('style') || ''; if (/javascript:|expression\s*\(/i.test(style)) element.removeAttribute('style');
  });
  return documentNode.body.innerHTML;
}
function safeEmailDocument(body) { return `<!doctype html><html><head><meta charset="utf-8"><style>body{font:15px/1.7 system-ui,sans-serif;color:#34423d;padding:12px;overflow-wrap:anywhere}img{max-width:100%;height:auto}table{max-width:100%}a{color:#287364}</style></head><body>${sanitizeHtml(body)}</body></html>`; }

function selectAccount(id) { state.activeAccountId = id; state.activeMessageId = null; state.folder = 'inbox'; state.mailQuery = ''; $('#mail-search').value = ''; document.querySelector('.account-panel')?.classList.add('mobile-hidden'); document.querySelector('.workspace')?.classList.remove('mobile-hidden'); render(); }
function selectMessage(id) { const message = (state.messages[keyFor(state.activeAccountId, state.folder)] || []).find((item) => item.id === id); if (!message) return; state.activeMessageId = id; if (!message.isRead) { void markMessageRead(message); } document.querySelector('#mail-detail')?.classList.add('mobile-open'); render(); if (!message.body && !currentAccount()?.demo) void loadMessageDetail(message); }

async function handleDetailAction(action) {
  const message = currentMessage(); if (!message) return;
  if (action === 'read') { await markMessageRead(message); toast('已标记为已读'); }
  if (action === 'favorite') { message.favorite = !message.favorite; persist(); renderDetail(); toast(message.favorite ? '已收藏' : '已取消收藏'); }
  if (action === 'delete') { if (confirm('删除这封邮件？此操作会同步影响邮箱。')) { try { await deleteRemoteMessage(message); removeMessage(message.id); toast('邮件已删除'); } catch (error) { toast(`删除失败：${error.message}`); } } }
}
function removeMessage(id) { const key = keyFor(state.activeAccountId, state.folder); state.messages[key] = (state.messages[key] || []).filter((message) => message.id !== id); state.activeMessageId = null; persist(); render(); }

async function getAccessToken(account) {
  if (state.sessions[account.id]) return state.sessions[account.id];
  const response = await fetch('https://login.microsoftonline.com/common/oauth2/v2.0/token', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams({ client_id: account.clientId, grant_type: 'refresh_token', refresh_token: account.refreshToken, scope: 'https://graph.microsoft.com/Mail.Read https://graph.microsoft.com/Mail.ReadWrite offline_access' }) });
  const data = await response.json(); if (!response.ok || !data.access_token) throw new Error(data.error_description || '令牌请求失败'); state.sessions[account.id] = data.access_token; if (data.refresh_token) account.refreshToken = data.refresh_token; persist(); return data.access_token;
}
async function graphRequest(account, path, options = {}) { const token = await getAccessToken(account); let response = await fetch(`https://graph.microsoft.com/v1.0${path}`, { ...options, headers: { Authorization: `Bearer ${token}`, Prefer: "outlook.body-content-type='text'", ...(options.headers || {}) } }); if (response.status === 401) { delete state.sessions[account.id]; const retryToken = await getAccessToken(account); response = await fetch(`https://graph.microsoft.com/v1.0${path}`, { ...options, headers: { Authorization: `Bearer ${retryToken}`, Prefer: "outlook.body-content-type='text'", ...(options.headers || {}) } }); } return response; }
async function loadMessageDetail(message) { const account = currentAccount(); if (!account || account.demo) return; try { const response = await graphRequest(account, `/me/messages/${encodeURIComponent(message.id)}?$select=id,subject,from,toRecipients,receivedDateTime,isRead,hasAttachments,body,bodyPreview`, { headers: { Prefer: "outlook.body-content-type='html'" } }); const data = await response.json(); if (!response.ok) throw new Error(data.error?.message || '读取邮件详情失败'); message.body = data.body?.content || data.bodyPreview || ''; persist(); renderDetail(); } catch (error) { toast(`正文读取失败：${error.message}`); } }
async function markMessageRead(message) { if (message.isRead) return; const account = currentAccount(); try { if (account && !account.demo) { const response = await graphRequest(account, `/me/messages/${encodeURIComponent(message.id)}`, { method: 'PATCH', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ isRead: true }) }); if (!response.ok) { const data = await response.json().catch(() => ({})); throw new Error(data.error?.message || '标记已读失败'); } } message.isRead = true; if (account) account.unreadCount = Math.max(0, (account.unreadCount || 0) - 1); persist(); render(); } catch (error) { toast(`标记已读失败：${error.message}`); } }
async function deleteRemoteMessage(message) { const account = currentAccount(); if (!account || account.demo) return; const response = await graphRequest(account, `/me/messages/${encodeURIComponent(message.id)}`, { method: 'DELETE' }); if (!response.ok && response.status !== 204) { const data = await response.json().catch(() => ({})); throw new Error(data.error?.message || '删除请求失败'); } }

function openImport() {
  $('#modal-root').innerHTML = `<div class="modal-backdrop"><div class="modal" role="dialog" aria-modal="true" aria-labelledby="import-title"><div class="modal-heading"><h3 id="import-title">批量导入账号</h3><button class="icon-button" data-modal-close aria-label="关闭">×</button></div><div class="modal-body"><label for="account-input">每行一个账号</label><textarea id="account-input" placeholder="email----password----client_id----refresh_token"></textarea><p class="modal-note">浏览器版会把账号凭据保存在 localStorage。仅建议在你自己的设备上使用，演示账号不会发起网络请求。</p></div><div class="modal-actions"><button class="secondary-button" data-modal-close>取消</button><button class="primary-button" data-import-submit>导入并验证</button></div></div></div>`;
  document.querySelectorAll('[data-modal-close]').forEach((button) => button.addEventListener('click', closeModal)); document.querySelector('[data-import-submit]').addEventListener('click', importAccounts);
}
function closeModal() { $('#modal-root').innerHTML = ''; }
function parseAccounts(input) { return input.split(/\r?\n/).map((line) => line.trim()).filter(Boolean).map((line, index) => { const parts = line.split('----').map((part) => part.trim()); const [email = '', password = '', third = '', fourth = ''] = parts; const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i; const clientId = uuid.test(fourth) && !uuid.test(third) ? fourth : third; const refreshToken = clientId === fourth ? third : fourth; return { id: `account-${Date.now()}-${index}`, email, password, clientId, refreshToken, rawLine: line, status: email.includes('@') && clientId && refreshToken ? 'validating' : 'failed', unreadCount: 0, isFavorite: false, errorMessage: parts.length < 4 ? '格式错误，需要四段内容' : undefined }; }); }
async function importAccounts() { const input = $('#account-input')?.value || ''; const parsed = parseAccounts(input); if (!parsed.length) return toast('没有可导入的账号'); closeModal(); state.loading = true; state.accounts = [...parsed.map((account) => ({ ...account, status: account.status === 'validating' ? 'success' : 'failed' })), ...state.accounts.filter((old) => !parsed.some((next) => next.email && old.email.toLowerCase() === next.email.toLowerCase()))]; state.activeAccountId = state.accounts[0]?.id || null; persist(); render(); toast('账号已导入，成功账号可直接打开'); for (const account of parsed.filter((item) => item.status === 'validating')) await validateAccount(account); state.loading = false; persist(); render(); }
async function validateAccount(account) { if (account.demo || !account.clientId || !account.refreshToken) return; try { const tokenPayload = new URLSearchParams({ client_id: account.clientId, grant_type: 'refresh_token', refresh_token: account.refreshToken, scope: 'https://graph.microsoft.com/Mail.Read https://graph.microsoft.com/Mail.ReadWrite offline_access' }); const tokenResponse = await fetch('https://login.microsoftonline.com/common/oauth2/v2.0/token', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: tokenPayload }); const token = await tokenResponse.json(); if (!tokenResponse.ok || !token.access_token) throw new Error(token.error_description || '令牌请求失败'); const response = await fetch('https://graph.microsoft.com/v1.0/me/mailFolders/inbox/messages?$top=50&$select=id,subject,from,toRecipients,receivedDateTime,isRead,hasAttachments,bodyPreview&$orderby=receivedDateTime desc', { headers: { Authorization: `Bearer ${token.access_token}`, Prefer: "outlook.body-content-type='text'" } }); const data = await response.json(); if (!response.ok) throw new Error(data.error?.message || 'Graph 请求失败'); state.messages[keyFor(account.id, 'inbox')] = (data.value || []).map((item) => normalizeGraphMessage(item)); account.status = 'success'; account.unreadCount = state.messages[keyFor(account.id, 'inbox')].filter((message) => !message.isRead).length; account.refreshToken = token.refresh_token || account.refreshToken; } catch (error) { account.status = 'failed'; account.errorMessage = error.message; } persist(); render(); }
function normalizeGraphMessage(item) { const sender = item.from?.emailAddress || {}; return { id: item.id || '', subject: item.subject || '无主题', sender: sender.name || sender.address || '未知发件人', recipients: (item.toRecipients || []).map((entry) => entry.emailAddress?.address).filter(Boolean).join(', '), receivedAt: item.receivedDateTime, isRead: Boolean(item.isRead), hasAttachments: Boolean(item.hasAttachments), preview: item.bodyPreview || '', body: '' }; }

function exportAccounts(accounts = state.accounts) { if (!accounts.length) return toast('没有可导出的账号'); const content = accounts.map((account) => account.rawLine || [account.email, account.password, account.clientId, account.refreshToken].join('----')).join('\n'); const blob = new Blob([content], { type: 'text/plain;charset=utf-8' }); const link = document.createElement('a'); link.href = URL.createObjectURL(blob); link.download = 'outlook-accounts.txt'; link.click(); URL.revokeObjectURL(link.href); toast('账号已导出'); }
function toast(message) { const node = document.createElement('div'); node.className = 'toast'; node.textContent = message; $('#toast-root').appendChild(node); setTimeout(() => node.remove(), 2600); }
function selectAllMessages() { const messages = currentMessages(); if (!messages.length) return toast('当前没有邮件'); const allSelected = messages.every((message) => state.selectedIds.has(message.id)); messages.forEach((message) => allSelected ? state.selectedIds.delete(message.id) : state.selectedIds.add(message.id)); toast(allSelected ? '已取消全选' : `已选择 ${messages.length} 封邮件`); }
function clearData() { if (confirm('清空本地数据？这不会删除服务器邮件，但会删除浏览器缓存和账号记录。')) { localStorage.removeItem(STORAGE_KEY); state.accounts = structuredClone(demoAccounts); state.messages = structuredClone(demoMessages); state.activeAccountId = state.accounts[0].id; state.activeMessageId = null; render(); toast('本地数据已清空'); } }

document.addEventListener('click', (event) => { const action = event.target.closest('[data-action]')?.dataset.action; if (!action) return; if (action === 'import') openImport(); if (action === 'settings') toast('设置页暂时只保留本地模式说明'); if (action === 'refresh') { const account = currentAccount(); if (account && !account.demo) { state.loading = true; render(); void validateAccount(account).finally(() => { state.loading = false; render(); }); } else { state.loading = true; render(); setTimeout(() => { state.loading = false; render(); toast('已刷新本地缓存'); }, 500); } } if (action === 'export-all') exportAccounts(); if (action === 'select-all') selectAllMessages(); if (action === 'clear-data') clearData(); if (action === 'back') { $('#mail-detail')?.classList.remove('mobile-open'); document.querySelector('.account-panel')?.classList.remove('mobile-hidden'); document.querySelector('.workspace')?.classList.add('mobile-hidden'); } });
document.querySelectorAll('[data-filter]').forEach((button) => button.addEventListener('click', () => { state.filter = button.dataset.filter; state.activeAccountId = filteredAccounts()[0]?.id || null; state.activeMessageId = null; render(); }));
document.querySelectorAll('[data-folder]').forEach((button) => button.addEventListener('click', () => { state.folder = button.dataset.folder; state.activeMessageId = null; render(); }));
$('#account-search').addEventListener('input', (event) => { state.accountQuery = event.target.value; state.activeAccountId = filteredAccounts()[0]?.id || null; state.activeMessageId = null; render(); });
$('#mail-search').addEventListener('input', (event) => { state.mailQuery = event.target.value; state.activeMessageId = null; render(); });
loadState(); render();
