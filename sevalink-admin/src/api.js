const BASE = import.meta.env.VITE_API_BASE || 'http://localhost:8080';

function authHeaders() {
  const token = localStorage.getItem('accessToken');
  return token ? { 'Authorization': `Bearer ${token}` } : {};
}

export async function login(identifier, password) {
  const res = await fetch(`${BASE}/api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ identifier, password })
  });
  if (!res.ok) {
    const body = await res.json().catch(()=>({}));
    throw new Error(body?.message || 'Login failed');
  }
  const wrapper = await res.json();
  const auth = wrapper.data;
  localStorage.setItem('accessToken', auth.accessToken);
  localStorage.setItem('refreshToken', auth.refreshToken);
  return auth.user;
}

export async function register(payload) {
  const res = await fetch(`${BASE}/api/auth/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });
  const body = await res.json().catch(()=>({}));
  if (!res.ok) {
    throw new Error(body?.message || 'Registration failed');
  }
  const auth = body.data;
  localStorage.setItem('accessToken', auth.accessToken);
  localStorage.setItem('refreshToken', auth.refreshToken);
  return auth.user;
}

export async function forgotPassword(email) {
  const res = await fetch(`${BASE}/api/auth/forgot-password`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email })
  });
  const body = await res.json().catch(()=>({}));
  if (!res.ok) {
    throw new Error(body?.message || 'Forgot password request failed');
  }
  return body.message || 'If your email exists, a reset link was sent.';
}

export async function resetPassword(token, newPassword) {
  const res = await fetch(`${BASE}/api/auth/reset-password`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ token, newPassword })
  });
  const body = await res.json().catch(()=>({}));
  if (!res.ok) {
    throw new Error(body?.message || 'Reset password failed');
  }
  return body.message || 'Password reset successful';
}

export async function getCurrentUser() {
  const res = await fetch(`${BASE}/api/auth/me`, {
    headers: { ...authHeaders() }
  });
  if (!res.ok) throw new Error('Unauthorized');
  const wrapper = await res.json();
  return wrapper.data;
}

export async function updateProfile(payload) {
  const res = await fetch(`${BASE}/api/auth/me`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json', ...authHeaders() },
    body: JSON.stringify(payload)
  });
  if (!res.ok) {
    const body = await res.json().catch(()=>({}));
    throw new Error(body?.message || 'Update failed');
  }
  const wrapper = await res.json();
  return wrapper.data;
}

export function logout() {
  localStorage.removeItem('accessToken');
  localStorage.removeItem('refreshToken');
}

export default { login, forgotPassword, resetPassword, getCurrentUser, updateProfile, logout };
