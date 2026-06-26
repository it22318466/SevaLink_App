import React, { useState, useEffect } from "react";
import * as api from "./api";
import {
  PieChart,
  Pie,
  Cell,
  Tooltip,
  ResponsiveContainer,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  LineChart,
  Line,
  CartesianGrid,
  Legend,
} from "recharts";

function App({ onLogout }) {

  const [adminName, setAdminName] = useState("");
  const [adminEmail, setAdminEmail] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [profileImageUrl, setProfileImageUrl] = useState("");
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState(null);
  const [dashboardStats, setDashboardStats] = useState({
    totalUsers: 0,
    totalWorkers: 0,
    totalJobs: 0,
    onlineUsers: 0,
  });
  const [workers, setWorkers] = useState([]);
  const [workerSearch, setWorkerSearch] = useState("");
  const [filterStatus, setFilterStatus] = useState("All");
  const [workerLoading, setWorkerLoading] = useState(false);

  const loadAdminWorkers = async () => {
    setWorkerLoading(true);
    try {
      const data = await api.getAdminWorkers();
      setWorkers(data);
    } catch (error) {
      console.error("Failed to load admin workers", error);
      setWorkers([]);
    } finally {
      setWorkerLoading(false);
    }
  };

  useEffect(() => {
    // Fetch current user and dashboard stats when the admin loads the app
    api.getCurrentUser().then(user => {
      if (user) {
        setAdminName(user.fullName || "");
        setAdminEmail(user.email || "");
        setProfileImageUrl(user.profileImageUrl || "");
      }
    }).catch(() => {});

    api.getAdminDashboardStats()
      .then(stats => setDashboardStats(stats))
      .catch(() => {
        setDashboardStats({
          totalUsers: 0,
          totalWorkers: 0,
          totalJobs: 0,
          onlineUsers: 0,
        });
      });

    loadAdminWorkers();
  }, []);

  const handleWorkerStatusChange = async (workerId, status) => {
    try {
      await api.updateWorkerStatus(workerId, status);
      await loadAdminWorkers();
    } catch (error) {
      console.error("Unable to update worker status", error);
    }
  };

  const filteredWorkers = workers.filter(worker => {
    const matchesSearch = workerSearch.length === 0 ||
      worker.fullName?.toLowerCase().includes(workerSearch.toLowerCase()) ||
      worker.email?.toLowerCase().includes(workerSearch.toLowerCase()) ||
      worker.skills?.toLowerCase().includes(workerSearch.toLowerCase()) ||
      worker.category?.toLowerCase().includes(workerSearch.toLowerCase());

    const matchesStatus = filterStatus === "All" || worker.status === filterStatus;
    return matchesSearch && matchesStatus;
  });

  const workerCounts = {
    total: workers.length,
    pending: workers.filter(w => w.status === "PENDING" || w.status === "Pending").length,
    verified: workers.filter(w => w.status === "VERIFIED" || w.status === "Verified").length,
    rejected: workers.filter(w => w.status === "REJECTED" || w.status === "Rejected").length,
  };

  const [activePage, setActivePage] = useState("dashboard");
  const [showFilter, setShowFilter] = useState(false);
  const [selectedRole, setSelectedRole] = useState("All");
  const pieData = [
  { name: "Users", value: 8542 },
  { name: "Workers", value: 2145 },
  { name: "Jobs", value: 1245 },
];

const barData = [
  { month: "Jan", jobs: 400 },
  { month: "Feb", jobs: 700 },
  { month: "Mar", jobs: 500 },
  { month: "Apr", jobs: 900 },
  { month: "May", jobs: 1200 },
];

const lineData = [
  { day: "Mon", users: 200 },
  { day: "Tue", users: 450 },
  { day: "Wed", users: 300 },
  { day: "Thu", users: 600 },
  { day: "Fri", users: 750 },
];

  const [users, setUsers] = useState([]);
  const [usersLoading, setUsersLoading] = useState(false);
  const [userSearch, setUserSearch] = useState("");
  const [userFilter, setUserFilter] = useState("All");

  const loadUsers = async () => {
    setUsersLoading(true);
    try {
      const data = await api.getAllUsers();
      setUsers(data || []);
    } catch (e) {
      console.error('Failed to load users', e);
      setUsers([]);
    } finally {
      setUsersLoading(false);
    }
  };

  useEffect(() => {
    loadUsers();
  }, []);

  // Jobs state and actions
  const [jobs, setJobs] = useState([]);
  const [jobsLoading, setJobsLoading] = useState(false);
  const [jobSearch, setJobSearch] = useState("");
  const [jobFilter, setJobFilter] = useState("All");

  const loadJobs = async () => {
    setJobsLoading(true);
    try {
      const data = await api.getAllJobs();
      setJobs(data || []);
    } catch (e) {
      console.error('Failed to load jobs', e);
      setJobs([]);
    } finally {
      setJobsLoading(false);
    }
  };

  useEffect(() => {
    loadJobs();
  }, []);

  const handleViewJob = (job) => {
    alert(JSON.stringify(job, null, 2));
  };

  const handleEditJob = async (job) => {
    const newTitle = prompt('Job title', job.title || '');
    if (newTitle == null) return;
    try {
      await api.updateJob(job.id, { title: newTitle });
      await loadJobs();
    } catch (e) {
      console.error('Failed to update job', e);
      alert('Update failed');
    }
  };

  const handleDeleteJob = async (job) => {
    if (!confirm(`Delete job ${job.title}?`)) return;
    try {
      await api.deleteJob(job.id);
      await loadJobs();
    } catch (e) {
      console.error('Failed to delete job', e);
      alert('Delete failed');
    }
  };

  const handleUpdateJobStatus = async (job, status) => {
    try {
      await api.updateJob(job.id, { status });
      await loadJobs();
    } catch (e) {
      console.error('Failed to update job status', e);
      alert('Status update failed');
    }
  };

  const handleViewUser = (user) => {
    // quick view - can be replaced with modal
    alert(JSON.stringify(user, null, 2));
  };

  const handleEditUser = async (user) => {
    const newName = prompt('Full name', user.fullName || '');
    if (newName == null) return; // cancelled
    try {
      await api.updateUser(user.id, { fullName: newName });
      await loadUsers();
    } catch (e) {
      console.error('Failed to update user', e);
      alert('Update failed');
    }
  };

  const handleBlockUser = async (user) => {
    if (!confirm(`Block user ${user.email}?`)) return;
    try {
      await api.blockUser(user.id);
      await loadUsers();
    } catch (e) {
      console.error('Failed to block user', e);
      alert('Block failed');
    }
  };

  const handleLogout = () => {
    api.logout();
    if (typeof onLogout === 'function') {
      onLogout();
    }
  };
  // ================= DASHBOARD =================
  if (activePage === "dashboard") {
    return (
      <div className="flex min-h-screen bg-gray-100">

        {/* Sidebar */}
        <div className="w-64 bg-gray-900 text-white p-5">

          <h1 className="text-4xl font-bold text-orange-500 mb-12">
            SevaLink
          </h1>

          <div className="space-y-4">

            <button
              onClick={() => setActivePage("dashboard")}
              className="w-full text-left bg-orange-500 hover:bg-orange-600 py-2 px-4 rounded-xl text-sm"
            >
              Main Dashboard
            </button>

            <button
              onClick={() => setActivePage("workers")}
              className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
            >
              Worker Verification
            </button>

            <button
              onClick={() => setActivePage("users")}
              className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
            >
              User Management
            </button>

      
      
            <button
  onClick={() => setActivePage("jobs")}
  className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
>
  Job Management
</button>

            <button
  onClick={() => setActivePage("chat")}
  className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
>
  Chat Monitoring
</button>

            <button
  onClick={() => setActivePage("analytics")}
  className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
>
  Analytics

</button>

           <button
  onClick={() => setActivePage("disputes")}
  className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
>
  Reports and Complaints 
</button>

            <button
  onClick={() => setActivePage("settings")}
  className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
>
  Settings
</button>

            <button onClick={handleLogout} className="w-full text-left hover:bg-red-500 py-2 px-4 rounded-xl text-sm">
              Logout
            </button>

          </div>

        </div>

        {/* Main Dashboard */}
        <div className="flex-1 p-8">

          <h1 className="text-4xl font-bold text-gray-800 mb-8">
            Main Dashboard
          </h1>

          <div className="grid grid-cols-4 gap-6 mb-8">

  <div className="bg-white p-6 rounded-3xl shadow-md border-l-4 border-orange-500">
    <p className="text-gray-500 text-sm">
      Total Users
    </p>

    <h1 className="text-5xl font-bold mt-3 text-gray-800">
      {dashboardStats.totalUsers.toLocaleString()}
    </h1>

    <p className="text-green-500 mt-2 text-sm">
      {dashboardStats.totalUsers === 0 ? 'No users yet' : '+ Active platform users'}
    </p>
  </div>

  <div className="bg-white p-6 rounded-3xl shadow-md border-l-4 border-yellow-400">
    <p className="text-gray-500 text-sm">
      Total Workers
    </p>

    <h1 className="text-5xl font-bold mt-3 text-gray-800">
      {dashboardStats.totalWorkers.toLocaleString()}
    </h1>

    <p className="text-green-500 mt-2 text-sm">
      {dashboardStats.totalWorkers === 0 ? 'No workers yet' : 'Verified worker accounts'}
    </p>
  </div>

  <div className="bg-white p-6 rounded-3xl shadow-md border-l-4 border-green-500">
    <p className="text-gray-500 text-sm">
      Total Jobs
    </p>

    <h1 className="text-5xl font-bold mt-3 text-gray-800">
      {dashboardStats.totalJobs.toLocaleString()}
    </h1>

    <p className="text-orange-500 mt-2 text-sm">
      {dashboardStats.totalJobs === 0 ? 'No jobs posted yet' : 'Jobs currently in the system'}
    </p>
  </div>

  <div className="bg-white p-6 rounded-3xl shadow-md border-l-4 border-red-500">
    <p className="text-gray-500 text-sm">
      Online Users
    </p>

    <h1 className="text-5xl font-bold mt-3 text-gray-800">
      {dashboardStats.onlineUsers.toLocaleString()}
    </h1>

    <p className="text-green-500 mt-2 text-sm">
      {dashboardStats.onlineUsers === 0 ? 'No active users' : 'Active within last 10 min'}
    </p>
  </div>
  </div>
  </div>


</div>     
);
}
  // ================= WORKERS PAGE =================
  if (activePage === "workers") {
    return (
      <div className="flex min-h-screen bg-gray-100">

        {/* Sidebar */}
        <div className="w-64 bg-gray-900 text-white p-5">

          <h1 className="text-4xl font-bold text-orange-500 mb-12">
            SevaLink
          </h1>

          <div className="space-y-4">

            <button
              onClick={() => setActivePage("dashboard")}
              className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
            >
              Main Dashboard
            </button>

            <button
              onClick={() => setActivePage("workers")}
              className="w-full text-left bg-orange-500 hover:bg-orange-600 py-2 px-4 rounded-xl text-sm"
            >
              Worker Verification
            </button>

            <button
              onClick={() => setActivePage("users")}
              className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
            >
              User Management
            </button>

             <button
  onClick={() => setActivePage("jobs")}
  className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
>
  Job Management
</button>

            <button
  onClick={() => setActivePage("chat")}
  className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
>
  Chat Monitoring
</button>

           <button
  onClick={() => setActivePage("analytics")}
  className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
>
  Analytics
</button>
             <button
  onClick={() => setActivePage("disputes")}
  className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
>
  reports and complaints 
</button>
            <button
  onClick={() => setActivePage("settings")}
  className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
>
  Settings
</button>

            <button onClick={handleLogout} className="w-full text-left hover:bg-red-500 py-2 px-4 rounded-xl text-sm">
              Logout
            </button>

          </div>

        </div>

        {/* Worker Content */}
        <div className="flex-1 p-8">

          <h1 className="text-4xl font-bold text-orange-500 mb-8">
            Worker Verification
          </h1>

          <div className="grid grid-cols-4 gap-6 mb-8">

  <div className="bg-white p-6 rounded-3xl shadow-md border-l-4 border-orange-500">
    <p className="text-gray-500">Total Workers</p>
    <h1 className="text-4xl font-bold mt-2">{workerCounts.total}</h1>
  </div>

  <div className="bg-white p-6 rounded-3xl shadow-md border-l-4 border-yellow-400">
    <p className="text-gray-500">Pending Workers</p>
    <h1 className="text-4xl font-bold mt-2">{workerCounts.pending}</h1>
  </div>

  <div className="bg-white p-6 rounded-3xl shadow-md border-l-4 border-green-500">
    <p className="text-gray-500">Verified Workers</p>
    <h1 className="text-4xl font-bold mt-2">{workerCounts.verified}</h1>
  </div>

  <div className="bg-white p-6 rounded-3xl shadow-md border-l-4 border-red-500">
    <p className="text-gray-500">Rejected Workers</p>
    <h1 className="text-4xl font-bold mt-2">{workerCounts.rejected}</h1>
  </div>

</div>

          <div className="bg-white rounded-3xl shadow-md p-6">
            <div className="flex gap-4 mb-6">

  <input
    type="text"
    value={workerSearch}
    onChange={e => setWorkerSearch(e.target.value)}
    placeholder="Search workers..."
    className="flex-1 border border-gray-300 px-5 py-4 rounded-2xl"
  />

<div className="relative">

  <button
    onClick={() => setShowFilter(!showFilter)}
    className="border border-gray-300 px-6 py-4 rounded-2xl bg-white hover:bg-gray-50"
  >
    🔍 Filter
  </button>

  {showFilter && (
    <div className="absolute right-0 mt-2 w-64 bg-white shadow-lg rounded-2xl p-4 z-50">

      <h3 className="font-bold mb-3">
        Filter Workers
      </h3>

      <div className="mb-4">
        <p className="font-semibold mb-2">Status</p>

        <label className="block">
          <input type="checkbox" /> Verified
        </label>

        <label className="block">
          <input type="checkbox" /> Pending
        </label>

        <label className="block">
          <input type="checkbox" /> Rejected
        </label>
      </div>

      <div className="mb-4">
        <p className="font-semibold mb-2">Rating</p>

        <label className="block">
          <input type="checkbox" /> 4.5+
        </label>

        <label className="block">
          <input type="checkbox" /> 4.0+
        </label>
      </div>

      <div className="mb-4">
        <p className="font-semibold mb-2">Jobs</p>

        <label className="block">
          <input type="checkbox" /> 50+
        </label>

        <label className="block">
          <input type="checkbox" /> 100+
        </label>
      </div>

      <button className="w-full bg-orange-500 text-white py-2 rounded-xl">
        Apply Filters
      </button>

    </div>
  )}

</div>

</div>

<div className="flex gap-4 mb-6 flex-wrap">

<button
        onClick={() => setFilterStatus("All")}
        className={`px-5 py-3 rounded-2xl ${filterStatus === "All" ? "bg-orange-500 text-white" : "bg-gray-200"}`}>
        All Workers
      </button>

      <button
        onClick={() => setFilterStatus("VERIFIED")}
        className={`px-5 py-3 rounded-2xl ${filterStatus === "VERIFIED" ? "bg-yellow-400" : "bg-gray-200"}`}>
        Verified
      </button>

      <button
        onClick={() => setFilterStatus("PENDING")}
        className={`px-5 py-3 rounded-2xl ${filterStatus === "PENDING" ? "bg-gray-500 text-white" : "bg-gray-200"}`}>
        Pending
      </button>

      <button
        onClick={() => setFilterStatus("REJECTED")}
        className={`px-5 py-3 rounded-2xl ${filterStatus === "REJECTED" ? "bg-green-500 text-white" : "bg-gray-200"}`}>
        Rejected
      </button>

      <button className="bg-gray-300 px-5 py-3 rounded-2xl">
        More Categories
      </button>

  <select className="border border-gray-300 px-5 py-3 rounded-2xl bg-white">
    <option>More Categories</option>
    <option>Gardening</option>
    <option>AC Repair</option>
    <option>Masonry</option>
    <option>Roofing</option>
    <option>Appliance Repair</option>
  </select>

</div>

            <div className="grid grid-cols-7 bg-gray-100 py-2 px-4 rounded-xl text-sm font-bold mb-4">

              <p>Worker</p>
              <p>Category</p>
              <p>Rating</p>
              <p>Status</p>
              <p>Jobs</p>
              <p>Joined</p>
              <p>Actions</p>

            </div>

            {workerLoading ? (
            <div className="p-6 text-center text-gray-600">Loading workers...</div>
          ) : filteredWorkers.length === 0 ? (
            <div className="p-6 text-center text-gray-600">No workers found.</div>
          ) : (
            filteredWorkers.map(worker => (
              <div key={worker.id} className="grid grid-cols-7 items-center p-4 border-b">
                <div>
                  <p className="font-semibold">{worker.fullName || "Unnamed"}</p>
                  <p className="text-sm text-gray-500">{worker.email}</p>
                </div>
                <p>{worker.category || "Uncategorized"}</p>
                <p>⭐ {worker.rating?.toFixed(1) || "0.0"}</p>
                <span className={
                  `px-3 py-1 rounded-full text-sm ${worker.status === "VERIFIED" ? "bg-green-100 text-green-700" : worker.status === "REJECTED" ? "bg-red-100 text-red-700" : "bg-yellow-100 text-yellow-700"}`
                }>
                  {worker.status}
                </span>
                <p>{worker.totalJobs ?? 0}</p>
                <p>{worker.createdAt ? new Date(worker.createdAt).toLocaleDateString() : "-"}</p>
                <div className="flex gap-2">
                  <button
                    onClick={() => handleWorkerStatusChange(worker.id, "VERIFIED")}
                    className="bg-green-500 text-white px-3 py-1 rounded-lg"
                  >
                    Verify
                  </button>
                  <button
                    onClick={() => handleWorkerStatusChange(worker.id, "REJECTED")}
                    className="bg-red-500 text-white px-3 py-1 rounded-lg"
                  >
                    Reject
                  </button>
                </div>
              </div>
            ))
          )}

          </div>

        </div>

      </div>
    );
  }

  // ================= USERS PAGE =================
  if (activePage === "users") {
    return (
      <div className="flex min-h-screen bg-gray-100">

        {/* Sidebar */}
        <div className="w-64 bg-gray-900 text-white p-5">

          <h1 className="text-4xl font-bold text-orange-500 mb-12">
            SevaLink
          </h1>

          <div className="space-y-4">

            <button
  onClick={() => setActivePage("dashboard")}
  className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
>
              Main Dashboard
            </button>

            <button
              onClick={() => setActivePage("workers")}
              className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
            >
              Worker Verification
            </button>

            <button
              onClick={() => setActivePage("users")}
              className="w-full text-left bg-orange-500 hover:bg-orange-600 py-2 px-4 rounded-xl text-sm"
            >
              User Management
            </button>

            <button
  onClick={() => setActivePage("jobs")}
  className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
>
  Job Management
</button>

            <button
  onClick={() => setActivePage("chat")}
  className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
>
  Chat Monitoring
</button>

            <button
  onClick={() => setActivePage("analytics")}
  className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
>
  Analytics
</button>
              <button
  onClick={() => setActivePage("disputes")}
  className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
>
  Reports and Complaints 
</button>

            <button
  onClick={() => setActivePage("settings")}
  className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
>
  Settings
</button>

            <button onClick={handleLogout} className="w-full text-left hover:bg-red-500 py-2 px-4 rounded-xl text-sm">
              Logout
            </button>

          </div>

        </div>

        {/* Users Content */}
        <div className="flex-1 p-8">

          <h1 className="text-4xl font-bold text-orange-500 mb-8">
            User Management
          </h1>
<div className="grid grid-cols-4 gap-6 mb-8">

  <div className="bg-white p-6 rounded-3xl shadow-md">
    <p className="text-gray-500">Total Users</p>
    <h1 className="text-5xl font-bold mt-3">{users.length}</h1>
  </div>

  <div className="bg-white p-6 rounded-3xl shadow-md">
    <p className="text-gray-500">Clients</p>
    <h1 className="text-5xl font-bold text-orange-500 mt-3">{users.filter(u => u.role === 'CLIENT').length}</h1>
  </div>

  <div className="bg-white p-6 rounded-3xl shadow-md">
    <p className="text-gray-500">Workers</p>
    <h1 className="text-5xl font-bold text-green-500 mt-3">{users.filter(u => u.role === 'WORKER').length}</h1>
  </div>

  <div className="bg-white p-6 rounded-3xl shadow-md">
    <p className="text-gray-500">Blocked Users</p>
    <h1 className="text-5xl font-bold text-red-500 mt-3">{users.filter(u => u.isActive === false).length}</h1>
  </div>

</div>

  <div className="flex gap-4 mb-6">

  <input
    type="text"
    value={userSearch}
    onChange={e => setUserSearch(e.target.value)}
    placeholder="Search users..."
    className="flex-1 border border-gray-300 px-5 py-4 rounded-2xl"
  />


</div>

<div className="flex gap-4 mb-6 flex-wrap">

  <button onClick={() => setUserFilter('All')} className={`px-5 py-3 rounded-2xl ${userFilter==='All' ? 'bg-orange-500 text-white' : 'bg-gray-200'}`}>
    All Users
  </button>

  <button onClick={() => setUserFilter('CLIENT')} className={`px-5 py-3 rounded-2xl ${userFilter==='CLIENT' ? 'bg-yellow-400' : 'bg-gray-200'}`}>
    Clients
  </button>

  <button onClick={() => setUserFilter('WORKER')} className={`px-5 py-3 rounded-2xl ${userFilter==='WORKER' ? 'bg-green-500 text-white' : 'bg-gray-200'}`}>
    Workers
  </button>

  <button onClick={() => setUserFilter('ADMIN')} className={`px-5 py-3 rounded-2xl ${userFilter==='ADMIN' ? 'bg-gray-500 text-white' : 'bg-gray-200'}`}>
    Admins
  </button>

  <button onClick={() => setUserFilter('BLOCKED')} className={`px-5 py-3 rounded-2xl ${userFilter==='BLOCKED' ? 'bg-red-500 text-white' : 'bg-gray-200'}`}>
    Blocked

  </button>

</div>
          <div className="bg-white rounded-3xl shadow-md p-6">

            <div className="grid grid-cols-6 bg-gray-100 py-2 px-4 rounded-xl text-sm font-bold mb-4">

              <p>User</p>
              <p>Role</p>
              <p>Email</p>
              <p>Status</p>
              <p>Joined</p>
              <p>Actions</p>

            </div>

            {usersLoading ? (
              <div className="p-6 text-center text-gray-600">Loading users...</div>
            ) : users.length === 0 ? (
              <div className="p-6 text-center text-gray-600">No users found.</div>
            ) : (
              users
                .filter(u => {
                  if (userFilter === 'BLOCKED') return u.isActive === false;
                  if (userFilter === 'All') return true;
                  if (['CLIENT','WORKER','ADMIN'].includes(userFilter)) return u.role === userFilter;
                  return true;
                })
                .filter(u => {
                  if (!userSearch) return true;
                  const s = userSearch.toLowerCase();
                  return (u.fullName && u.fullName.toLowerCase().includes(s)) ||
                         (u.email && u.email.toLowerCase().includes(s));
                })
                .map(u => (
                  <div key={u.id} className="grid grid-cols-6 items-center p-4 border-b">
                    <div>
                      <p className="font-semibold">{u.fullName}</p>
                      <p className="text-sm text-gray-500">{u.email}</p>
                    </div>
                    <p>{u.role}</p>
                    <p>{u.email}</p>
                    <span className={u.isActive ? 'text-green-500' : 'text-red-500'}>
                      {u.isActive ? 'Active' : 'Blocked'}
                    </span>
                    <p>{u.createdAt ? new Date(u.createdAt).toLocaleDateString() : '-'}</p>
                    <div className="flex gap-2">
                      <button onClick={() => handleViewUser(u)} className="bg-blue-500 text-white px-3 py-1 rounded-lg">View</button>
                      <button onClick={() => handleEditUser(u)} className="bg-yellow-500 text-white px-3 py-1 rounded-lg">Edit</button>
                      <button onClick={() => handleBlockUser(u)} className="bg-red-500 text-white px-3 py-1 rounded-lg">Block</button>
                    </div>
                  </div>
                ))
            )}

          </div>

        </div>

      </div>
    );
  }

if (activePage === "jobs") {
  return (

    <div className="flex min-h-screen bg-gray-100">

    <div className="w-64 bg-gray-900 text-white p-5">

  <h1 className="text-4xl font-bold text-orange-500 mb-12">
    SevaLink
  </h1>

  <div className="space-y-4">

    <button
      onClick={() => setActivePage("dashboard")}
      className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
    >
      Main Dashboard
    </button>

    <button
      onClick={() => setActivePage("workers")}
      className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
    >
      Worker Verification
    </button>

    <button
      onClick={() => setActivePage("users")}
      className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
    >
      User Management
    </button>

    <button
      onClick={() => setActivePage("jobs")}
      className="w-full text-left bg-orange-500 py-2 px-4 rounded-xl text-sm"
    >
      Job Management
    </button>

    <button
  onClick={() => setActivePage("chat")}
  className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
>
  Chat Monitoring
</button>

    <button
  onClick={() => setActivePage("analytics")}
  className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
>
  Analytics
</button>
      <button
  onClick={() => setActivePage("disputes")}
  className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
>
  Reports and Complaints 
</button>
    <button
  onClick={() => setActivePage("settings")}
  className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
>
  Settings
</button>

    <button onClick={handleLogout} className="w-full text-left hover:bg-red-500 py-2 px-4 rounded-xl text-sm">
      Logout
    </button>

  </div>

</div>


      {/* Main Content */}
      <div className="flex-1 p-8">

        <h1 className="text-5xl font-bold text-orange-500 mb-8">
          Job Management
        </h1>

        {/* Statistics Cards */}
        <div className="grid grid-cols-4 gap-6 mb-8">
          <div className="bg-white p-6 rounded-3xl shadow-md">
            <p className="text-gray-500">Total Jobs</p>
            <h1 className="text-5xl font-bold mt-3">{jobs.length}</h1>
          </div>

          <div className="bg-white p-6 rounded-3xl shadow-md">
            <p className="text-gray-500">Pending</p>
            <h1 className="text-5xl font-bold text-yellow-500 mt-3">{jobs.filter(j=> ['OPEN','PENDING','Pending','ASSIGNED'].includes(j.status)).length}</h1>
          </div>

          <div className="bg-white p-6 rounded-3xl shadow-md">
            <p className="text-gray-500">Completed</p>
            <h1 className="text-5xl font-bold text-green-500 mt-3">{jobs.filter(j=> j.status === 'COMPLETED' || j.status === 'Completed').length}</h1>
          </div>

          <div className="bg-white p-6 rounded-3xl shadow-md">
            <p className="text-gray-500">Cancelled</p>
            <h1 className="text-5xl font-bold text-red-500 mt-3">{jobs.filter(j=> j.status === 'CANCELLED' || j.status === 'Cancelled').length}</h1>
          </div>

        </div>
   

        {/* Search */}
        <div className="flex gap-4 mb-6">

          <input
            type="text"
            value={jobSearch}
            onChange={e => setJobSearch(e.target.value)}
            placeholder="Search jobs..."
            className="flex-1 border border-gray-300 px-5 py-4 rounded-2xl"
          />

        </div>

        {/* Status Buttons */}
        <div className="flex gap-4 mb-6 flex-wrap">

          <button onClick={() => setJobFilter('All')} className={`px-5 py-3 rounded-2xl ${jobFilter==='All' ? 'bg-orange-500 text-white' : 'bg-gray-200'}`}>
            All Jobs
          </button>

          <button onClick={() => setJobFilter('PENDING')} className={`px-5 py-3 rounded-2xl ${jobFilter==='PENDING' ? 'bg-yellow-400' : 'bg-gray-200'}`}>
            Pending
          </button>

          <button onClick={() => setJobFilter('COMPLETED')} className={`px-5 py-3 rounded-2xl ${jobFilter==='COMPLETED' ? 'bg-green-500 text-white' : 'bg-gray-200'}`}>
            Completed
          </button>

          <button onClick={() => setJobFilter('CANCELLED')} className={`px-5 py-3 rounded-2xl ${jobFilter==='CANCELLED' ? 'bg-red-500 text-white' : 'bg-gray-200'}`}>
            Cancelled
          </button>

        </div>

        {/* Job Table */}
        <div className="bg-white rounded-3xl shadow-md p-6">

          <div className="grid grid-cols-6 bg-gray-100 py-2 px-4 rounded-xl text-sm font-bold mb-4">

            <p>Job</p>
            <p>Client</p>
            <p>Worker</p>
            <p>Status</p>
            <p>Date</p>
            <p>Actions</p>

          </div>

          {jobsLoading ? (
            <div className="p-6 text-center text-gray-600">Loading jobs...</div>
          ) : jobs.length === 0 ? (
            <div className="p-6 text-center text-gray-600">No jobs found.</div>
          ) : (
            jobs
              .filter(j => {
                if (jobFilter === 'All') return true;
                if (jobFilter === 'PENDING') return ['OPEN','PENDING','Pending','ASSIGNED'].includes(j.status);
                if (jobFilter === 'COMPLETED') return j.status === 'COMPLETED' || j.status === 'Completed';
                if (jobFilter === 'CANCELLED') return j.status === 'CANCELLED' || j.status === 'Cancelled';
                return true;
              })
              .filter(j => {
                if (!jobSearch) return true;
                const s = jobSearch.toLowerCase();
                return (j.title && j.title.toLowerCase().includes(s)) ||
                       (j.clientName && j.clientName.toLowerCase().includes(s)) ||
                       (j.workerName && j.workerName.toLowerCase().includes(s));
              })
              .map(j => (
                <div key={j.id} className="grid grid-cols-6 items-center p-4 border-b">
                  <div>
                    <p className="font-semibold">{j.title}</p>
                    <p className="text-sm text-gray-500">{j.description}</p>
                  </div>
                  <p>{j.clientName || j.client?.fullName || '-'}</p>
                  <p>{j.workerName || j.worker?.fullName || '-'}</p>
                  <span className={j.status && (j.status === 'COMPLETED' || j.status === 'Completed') ? 'text-green-500' : j.status && (['OPEN','PENDING','Pending','ASSIGNED'].includes(j.status)) ? 'text-yellow-500' : 'text-red-500'}>
                    {j.status}
                  </span>
                  <p>{j.createdAt ? new Date(j.createdAt).toLocaleDateString() : '-'}</p>
                  <div className="flex gap-2">
                    <button onClick={()=>handleViewJob(j)} className="bg-blue-500 text-white px-3 py-1 rounded-lg">View</button>
                    <button onClick={()=>handleEditJob(j)} className="bg-yellow-500 text-white px-3 py-1 rounded-lg">Edit</button>
                    <button onClick={()=>handleDeleteJob(j)} className="bg-red-500 text-white px-3 py-1 rounded-lg">Delete</button>
                  </div>
                </div>
              ))
          )}

        </div>

      </div>

      </div>

    

  );
}

// ================= CHAT PAGE =================
if (activePage === "chat") {
  return (

    <div className="flex min-h-screen bg-gray-100">

      {/* Sidebar */}
      <div className="w-64 bg-gray-900 text-white p-5">

        <h1 className="text-4xl font-bold text-orange-500 mb-12">
          SevaLink
        </h1>

        <div className="space-y-4">

          <button
            onClick={() => setActivePage("dashboard")}
            className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
          >
            Main Dashboard
          </button>

          <button
            onClick={() => setActivePage("workers")}
            className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
          >
            Worker Verification
          </button>

          <button
            onClick={() => setActivePage("users")}
            className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
          >
            User Management
          </button>

          <button
            onClick={() => setActivePage("jobs")}
            className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
          >
            Job Management
          </button>

          <button
            onClick={() => setActivePage("chat")}
            className="w-full text-left bg-orange-500 py-2 px-4 rounded-xl text-sm"
          >
            Chat Monitoring
          </button>

         <button
  onClick={() => setActivePage("analytics")}
  className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
>
  Analytics
</button>

           <button
  onClick={() => setActivePage("disputes")}
  className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
>
  Reports and Complaints 
</button>
          <button
  onClick={() => setActivePage("settings")}
  className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
>
  Settings
</button>

          <button onClick={handleLogout} className="w-full text-left hover:bg-red-500 py-2 px-4 rounded-xl text-sm">
            Logout
          </button>

        </div>

      </div>

      {/* Chat Layout */}
      <div className="flex flex-1">

        {/* LEFT SIDE */}
        <div className="w-1/4 bg-white border-r p-5">

          <h1 className="text-2xl font-bold mb-5">
            Conversations
          </h1>

          <input
            type="text"
            placeholder="Search chats..."
            className="w-full border px-4 py-3 rounded-2xl mb-6"
          />

          <div className="space-y-4">

            <div className="bg-gray-100 p-4 rounded-2xl cursor-pointer hover:bg-orange-100">

              <h2 className="font-bold">
                Job #5678
              </h2>

              <p className="text-sm text-gray-500">
                Nimal & Sunil
              </p>

            </div>

            <div className="bg-gray-100 p-4 rounded-2xl cursor-pointer hover:bg-orange-100">

              <h2 className="font-bold">
                Job #4582
              </h2>

              <p className="text-sm text-gray-500">
                Kasun & Amal
              </p>

            </div>

          </div>

        </div>

        {/* CENTER CHAT */}
        <div className="flex-1 flex flex-col">

          {/* Top */}
          <div className="bg-white p-5 border-b">

            <h1 className="text-2xl font-bold">
              Job #5678
            </h1>

            <p className="text-gray-500">
              Nimal Fernando & Sunil Perera
            </p>

          </div>

          {/* Messages */}
          <div className="flex-1 p-6 space-y-5 overflow-y-auto">

            <div className="flex justify-start">

              <div className="bg-gray-300 px-5 py-3 rounded-2xl max-w-sm">
<div>
  <p>When can you come?</p>

  <span className="text-xs text-gray-500">
    2:45 PM
  </span>
</div>              </div>

            </div>

            <div className="flex justify-end">

              <div className="bg-orange-500 text-white px-5 py-3 rounded-2xl max-w-sm">
                I can come by 3 PM today.
              </div>

            </div>

            <div className="flex justify-start">

              <div className="bg-gray-300 px-5 py-3 rounded-2xl max-w-sm">
                Please bring materials.

                <div className="flex justify-start">

  <div className="bg-red-500 text-white px-5 py-3 rounded-2xl max-w-sm">
    ⚠ Abusive Message Detected
  </div>

</div>
              </div>

            </div>

          </div>

          {/* Bottom Input */}
          <div className="bg-white p-4 border-t flex gap-4">

            <input
              type="text"
              placeholder="Type message..."
              className="flex-1 border px-4 py-3 rounded-2xl"
            />

            <button className="bg-orange-500 text-white px-6 rounded-2xl">
              Send
            </button>

          </div>

        </div>

        {/* RIGHT SIDE */}
        <div className="w-1/4 bg-white border-l p-5">

          <h1 className="text-2xl font-bold mb-6">
            Chat Details
          </h1>

          <div className="space-y-4">

            <p>
              <span className="font-bold">
                Job ID:
              </span> #5678
            </p>

            <p>
              <span className="font-bold">
                Client:
              </span> Nimal Fernando
            </p>

            <p>
              <span className="font-bold">
                Worker:
              </span> Sunil Perera
            </p>

            <p>
              <span className="font-bold">
                Status:
              </span>

              <span className="text-green-500 ml-2">
                Active
              </span>
            </p>

            <p>
  <span className="font-bold">
    Risk Level:
  </span>

  <span className="text-red-500 ml-2">
    Medium Risk
  </span>
</p>

            <p>
              <span className="font-bold">
                Accepted:
              </span> 28 May 2024
            </p>

          </div>

          <button className="w-full bg-orange-500 text-white py-3 rounded-2xl mt-8">
            View Job Details
          </button>
          <button className="w-full bg-red-500 text-white py-3 rounded-2xl mt-4">
  Report Conversation
</button>

<div className="bg-red-100 border border-red-300 p-4 rounded-2xl mt-6">

  <h2 className="text-red-600 font-bold text-lg">
    Scam Alert
  </h2>

  <p className="text-sm text-gray-700 mt-2">
    Worker requested external payment outside SevaLink.
  </p>

</div>

<div className="bg-yellow-100 border border-yellow-300 p-4 rounded-2xl mt-4">

  <h2 className="text-yellow-700 font-bold text-lg">
    Complaint Status
  </h2>

  <p className="text-sm text-gray-700 mt-2">
    Complaint currently under admin review.
  </p>

</div>
        </div>

      </div>

    </div>

  );
}
// ================= ANALYTICS PAGE =================
if (activePage === "analytics") {
  return (

    <div className="flex min-h-screen bg-gray-100">

      {/* Sidebar */}
      <div className="w-64 bg-gray-900 text-white p-5">

        <h1 className="text-4xl font-bold text-orange-500 mb-12">
          SevaLink
        </h1>

        <div className="space-y-4">

          <button
            onClick={() => setActivePage("dashboard")}
            className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
          >
            Main Dashboard
          </button>

          <button
            onClick={() => setActivePage("workers")}
            className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
          >
            Worker Verification
          </button>

          <button
            onClick={() => setActivePage("users")}
            className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
          >
            User Management
          </button>

          <button
            onClick={() => setActivePage("jobs")}
            className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
          >
            Job Management
          </button>

          <button
            onClick={() => setActivePage("chat")}
            className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
          >
            Chat Monitoring
          </button>

          <button
            onClick={() => setActivePage("analytics")}
            className="w-full text-left bg-orange-500 py-2 px-4 rounded-xl text-sm"
          >
            Analytics
          </button>

            <button
  onClick={() => setActivePage("disputes")}
  className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
>
  Reports and Complaints 
</button>

          <button
  onClick={() => setActivePage("settings")}
  className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
>
  Settings
</button>

          <button onClick={handleLogout} className="w-full text-left hover:bg-red-500 py-2 px-4 rounded-xl text-sm">
            Logout
          </button>

        </div>

      </div>

      {/* Main Content */}
      <div className="flex-1 p-8 overflow-y-auto">

        <h1 className="text-4xl font-bold mb-8">
          Analytics Dashboard
        </h1>

        {/* Analytics Cards */}
        <div className="grid grid-cols-4 gap-6 mb-8">

          <div className="bg-white p-6 rounded-3xl shadow-md border-l-4 border-orange-500">
            <p className="text-gray-500">
              Total Users
            </p>

            <h1 className="text-5xl font-bold mt-3">
              8,542
            </h1>

            <p className="text-green-500 mt-2">
              +12% Growth
            </p>
          </div>

          <div className="bg-white p-6 rounded-3xl shadow-md border-l-4 border-yellow-400">
            <p className="text-gray-500">
              Total Jobs
            </p>

            <h1 className="text-5xl font-bold mt-3">
              1,245
            </h1>

            <p className="text-green-500 mt-2">
              +8% Growth
            </p>
          </div>

          <div className="bg-white p-6 rounded-3xl shadow-md border-l-4 border-green-500">
            <p className="text-gray-500">
              Revenue
            </p>

            <h1 className="text-5xl font-bold mt-3">
              LKR 1.2M
            </h1>

            <p className="text-green-500 mt-2">
              Monthly Revenue
            </p>
          </div>

          <div className="bg-white p-6 rounded-3xl shadow-md border-l-4 border-red-500">
            <p className="text-gray-500">
              Complaints
            </p>

            <h1 className="text-5xl font-bold mt-3">
              84
            </h1>

            <p className="text-red-500 mt-2">
              Needs Review
            </p>
          </div>

        </div>

        {/* Charts */}
        <div className="grid grid-cols-2 gap-6 mb-8">

          {/* Bar Chart */}
          <div className="bg-white p-6 rounded-3xl shadow-md">

            <h2 className="text-2xl font-bold mb-4">
              Monthly Jobs
            </h2>

            <ResponsiveContainer width="100%" height={300}>

              <BarChart data={barData}>
                <XAxis dataKey="month" />
                <YAxis />
                <Tooltip />

                <Bar
                  dataKey="jobs"
                  fill="#f97316"
                />

              </BarChart>

            </ResponsiveContainer>

          </div>

          {/* Line Chart */}
          <div className="bg-white p-6 rounded-3xl shadow-md">

            <h2 className="text-2xl font-bold mb-4">
              User Growth
            </h2>

            <ResponsiveContainer width="100%" height={300}>

              <LineChart data={lineData}>

                <CartesianGrid strokeDasharray="3 3" />

                <XAxis dataKey="day" />
                <YAxis />
                <Tooltip />
                <Legend />

                <Line
                  type="monotone"
                  dataKey="users"
                  stroke="#22c55e"
                  strokeWidth={3}
                />

              </LineChart>

            </ResponsiveContainer>

          </div>

        </div>

        {/* Pie Chart + Complaint Stats */}
        <div className="grid grid-cols-2 gap-6 mb-8">

          {/* Pie Chart */}
          <div className="bg-white p-6 rounded-3xl shadow-md">

            <h2 className="text-2xl font-bold mb-4">
              Worker Categories
            </h2>

            <ResponsiveContainer width="100%" height={300}>

              <PieChart>

                <Pie
                  data={pieData}
                  dataKey="value"
                  outerRadius={100}
                  fill="#f97316"
                  label
                >

                  <Cell fill="#f97316" />
                  <Cell fill="#22c55e" />
                  <Cell fill="#eab308" />

                </Pie>

                <Tooltip />

              </PieChart>

            </ResponsiveContainer>

          </div>

          {/* Complaint Analytics */}
          <div className="bg-white p-6 rounded-3xl shadow-md">

            <h2 className="text-2xl font-bold mb-6">
              Complaint Analytics
            </h2>

            <div className="space-y-6">

              <div>
                <p className="font-bold">
                  Resolved Complaints
                </p>

                <div className="w-full bg-gray-200 rounded-full h-4 mt-2">
                  <div className="bg-green-500 h-4 rounded-full w-3/4"></div>
                </div>

                <p className="text-sm text-gray-500 mt-1">
                  75%
                </p>
              </div>

              <div>
                <p className="font-bold">
                  Pending Complaints
                </p>

                <div className="w-full bg-gray-200 rounded-full h-4 mt-2">
                  <div className="bg-yellow-400 h-4 rounded-full w-1/4"></div>
                </div>

                <p className="text-sm text-gray-500 mt-1">
                  25%
                </p>
              </div>

            </div>

          </div>

        </div>

        {/* Top Workers */}
        <div className="bg-white p-6 rounded-3xl shadow-md mb-8">

          <h2 className="text-2xl font-bold mb-6">
            Most Active Workers
          </h2>

          <div className="grid grid-cols-4 bg-gray-100 p-4 rounded-2xl font-bold mb-4">

            <p>Worker</p>
            <p>Category</p>
            <p>Jobs</p>
            <p>Rating</p>

          </div>

          <div className="grid grid-cols-4 p-4 border-b">

            <p>Sunil Perera</p>
            <p>Plumbing</p>
            <p>128</p>
            <p>⭐ 4.8</p>

          </div>

          <div className="grid grid-cols-4 p-4 border-b">

            <p>Kamal Fernando</p>
            <p>Electrical</p>
            <p>96</p>
            <p>⭐ 4.6</p>

          </div>

        </div>

        {/* Recent Activity */}
        <div className="bg-white p-6 rounded-3xl shadow-md">

          <h2 className="text-2xl font-bold mb-6">
            Recent Platform Activity
          </h2>

          <div className="space-y-4">

            <div className="bg-gray-100 p-4 rounded-2xl">
              New worker registered in Plumbing category.
            </div>

            <div className="bg-gray-100 p-4 rounded-2xl">
              Complaint resolved for Job #5678.
            </div>

            <div className="bg-gray-100 p-4 rounded-2xl">
              Revenue increased by 12% this week.
            </div>

          </div>

        </div>

      </div>

    </div>

  );
}

// ================= REPORTS & COMPLAINTS PAGE =================
if (activePage === "disputes") {
  return (

    <div className="flex min-h-screen bg-gray-100">

      {/* Sidebar */}
      <div className="w-64 bg-gray-900 text-white p-5">

        <h1 className="text-4xl font-bold text-orange-500 mb-12">
          SevaLink
        </h1>

        <div className="space-y-4">

          <button
            onClick={() => setActivePage("dashboard")}
            className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
          >
            Main Dashboard
          </button>

          <button
            onClick={() => setActivePage("workers")}
            className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
          >
            Worker Verification
          </button>

          <button
            onClick={() => setActivePage("users")}
            className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
          >
            User Management
          </button>

          <button
            onClick={() => setActivePage("jobs")}
            className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
          >
            Job Management
          </button>

          <button
            onClick={() => setActivePage("chat")}
            className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
          >
            Chat Monitoring
          </button>

          <button
            onClick={() => setActivePage("analytics")}
            className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
          >
            Analytics
          </button>

          <button
            onClick={() => setActivePage("disputes")}
            className="w-full text-left bg-orange-500 py-2 px-4 rounded-xl text-sm"
          >
            Reports & Complaints
          </button>

         <button
  onClick={() => setActivePage("settings")}
  className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
>
  Settings
</button>

          <button onClick={handleLogout} className="w-full text-left hover:bg-red-500 py-2 px-4 rounded-xl text-sm">
            Logout
          </button>

        </div>

      </div>

      {/* Main Content */}
      <div className="flex-1 p-8 overflow-y-auto">

        <h1 className="text-4xl font-bold mb-8">
          Reports & Complaints
        </h1>

        {/* Statistics */}
        <div className="grid grid-cols-4 gap-6 mb-8">

          <div className="bg-white p-6 rounded-3xl shadow-md border-l-4 border-red-500">
            <p className="text-gray-500">
              Total Reports
            </p>

            <h1 className="text-5xl font-bold mt-3">
              84
            </h1>

            <p className="text-red-500 mt-2">
              +12 New Today
            </p>
          </div>

          <div className="bg-white p-6 rounded-3xl shadow-md border-l-4 border-yellow-400">
            <p className="text-gray-500">
              Pending Complaints
            </p>

            <h1 className="text-5xl font-bold mt-3">
              22
            </h1>

            <p className="text-yellow-500 mt-2">
              Under Review
            </p>
          </div>

          <div className="bg-white p-6 rounded-3xl shadow-md border-l-4 border-green-500">
            <p className="text-gray-500">
              Resolved Cases
            </p>

            <h1 className="text-5xl font-bold mt-3">
              62
            </h1>

            <p className="text-green-500 mt-2">
              Successfully Solved
            </p>
          </div>

          <div className="bg-white p-6 rounded-3xl shadow-md border-l-4 border-orange-500">
            <p className="text-gray-500">
              Fraud Reports
            </p>

            <h1 className="text-5xl font-bold mt-3">
              11
            </h1>

            <p className="text-red-500 mt-2">
              High Risk
            </p>
          </div>

        </div>

        {/* Search */}
        <div className="flex gap-4 mb-6">

          <input
            type="text"
            placeholder="Search reports..."
            className="flex-1 border border-gray-300 px-5 py-4 rounded-2xl"
          />

          <select className="border border-gray-300 px-5 py-4 rounded-2xl bg-white">

            <option>All Categories</option>
            <option>Fraud</option>
            <option>Payment Issues</option>
            <option>Fake Jobs</option>
            <option>Harassment</option>
            <option>Abusive Messages</option>

          </select>

        </div>

        {/* Filter Buttons */}
        <div className="flex gap-4 mb-8 flex-wrap">

          <button className="bg-orange-500 text-white px-5 py-3 rounded-2xl">
            All Reports
          </button>

          <button className="bg-red-500 text-white px-5 py-3 rounded-2xl">
            Fraud
          </button>

          <button className="bg-yellow-400 px-5 py-3 rounded-2xl">
            Payment
          </button>

          <button className="bg-blue-500 text-white px-5 py-3 rounded-2xl">
            Fake Jobs
          </button>

          <button className="bg-green-500 text-white px-5 py-3 rounded-2xl">
            Harassment
          </button>

        </div>

        {/* Complaint Table */}
        <div className="bg-white rounded-3xl shadow-md p-6 mb-8">

          <h2 className="text-2xl font-bold mb-6">
            Active Complaints
          </h2>

          <div className="grid grid-cols-7 bg-gray-100 p-4 rounded-2xl font-bold mb-4">

            <p>ID</p>
            <p>Client</p>
            <p>Worker</p>
            <p>Issue</p>
            <p>Priority</p>
            <p>Status</p>
            <p>Actions</p>

          </div>

          <div className="grid grid-cols-7 items-center p-4 border-b">

            <p>#R1023</p>
            <p>Nimal</p>
            <p>Sunil</p>
            <p>Payment Issue</p>

            <span className="text-red-500 font-bold">
              High
            </span>

            <span className="text-yellow-500 font-bold">
              Investigating
            </span>

            <div className="flex gap-2">

              <button className="bg-blue-500 text-white px-3 py-1 rounded-lg">
                View
              </button>

              <button className="bg-green-500 text-white px-3 py-1 rounded-lg">
                Resolve
              </button>

              <button className="bg-red-500 text-white px-3 py-1 rounded-lg">
                Suspend
              </button>

            </div>

          </div>

        </div>

        {/* Fraud Alerts */}
        <div className="bg-white rounded-3xl shadow-md p-6 mb-8">

          <h2 className="text-2xl font-bold mb-6">
            Fraud Detection Alerts
          </h2>

          <div className="space-y-4">

            <div className="bg-red-100 border-l-4 border-red-500 p-4 rounded-2xl">
              ⚠ Worker received 8 complaints this week.
            </div>

            <div className="bg-yellow-100 border-l-4 border-yellow-500 p-4 rounded-2xl">
              ⚠ Fake payment screenshot detected.
            </div>

            <div className="bg-orange-100 border-l-4 border-orange-500 p-4 rounded-2xl">
              ⚠ Multiple spam jobs reported.
            </div>

          </div>

        </div>

        {/* Chat Evidence */}
        <div className="bg-white rounded-3xl shadow-md p-6 mb-8">

          <h2 className="text-2xl font-bold mb-6">
            Chat Evidence Review
          </h2>

          <div className="space-y-4">

            <div className="bg-gray-100 p-4 rounded-2xl">
              <p className="font-bold">
                Client:
              </p>

              <p>
                "The worker did not complete the job."
              </p>
            </div>

            <div className="bg-orange-100 p-4 rounded-2xl">
              <p className="font-bold">
                Worker:
              </p>

              <p>
                "I completed it yesterday."
              </p>
            </div>

          </div>

        </div>

      </div>

    </div>

  );
}

// ================= SETTINGS PAGE =================
if (activePage === "settings") {
  return (

    <div className="flex min-h-screen bg-gray-100">

      {/* Sidebar */}
      <div className="w-64 bg-gray-900 text-white p-5">

        <h1 className="text-4xl font-bold text-orange-500 mb-12">
          SevaLink
        </h1>

        <div className="space-y-4">

          <button
            onClick={() => setActivePage("dashboard")}
            className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
          >
            Main Dashboard
          </button>

          <button
            onClick={() => setActivePage("workers")}
            className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
          >
            Worker Verification
          </button>

          <button
            onClick={() => setActivePage("users")}
            className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
          >
            User Management
          </button>

          <button
            onClick={() => setActivePage("jobs")}
            className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
          >
            Job Management
          </button>

          <button
            onClick={() => setActivePage("chat")}
            className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
          >
            Chat Monitoring
          </button>

          <button
            onClick={() => setActivePage("analytics")}
            className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
          >
            Analytics
          </button>

          <button
            onClick={() => setActivePage("disputes")}
            className="w-full text-left hover:bg-gray-800 py-2 px-4 rounded-xl text-sm"
          >
            Reports & Complaints
          </button>

          <button
            onClick={() => setActivePage("settings")}
            className="w-full text-left bg-orange-500 py-2 px-4 rounded-xl text-sm"
          >
            Settings
          </button>

          <button onClick={handleLogout} className="w-full text-left hover:bg-red-500 py-2 px-4 rounded-xl text-sm">
            Logout
          </button>

        </div>

      </div>

      {/* Main Content */}
      <div className="flex-1 p-8 overflow-y-auto">

        <h1 className="text-4xl font-bold mb-8">
          Settings
        </h1>

        {/* Admin Profile */}
        <div className="bg-white rounded-3xl shadow-md p-6 mb-8">

          <h2 className="text-2xl font-bold mb-6">
            Admin Profile
          </h2>

          <div className="grid grid-cols-2 gap-6">

            <input
              value={adminName}
              onChange={e => setAdminName(e.target.value)}
              type="text"
              placeholder="Admin Name"
              className="border border-gray-300 px-5 py-4 rounded-2xl"
            />

            <input
              value={adminEmail}
              onChange={e => setAdminEmail(e.target.value)}
              type="email"
              placeholder="Admin Email"
              className="border border-gray-300 px-5 py-4 rounded-2xl"
            />

            <input
              value={newPassword}
              onChange={e => setNewPassword(e.target.value)}
              type="password"
              placeholder="New Password"
              className="border border-gray-300 px-5 py-4 rounded-2xl"
            />

            <input
              value={profileImageUrl}
              onChange={e => setProfileImageUrl(e.target.value)}
              type="text"
              placeholder="Profile Image URL (optional)"
              className="border border-gray-300 px-5 py-4 rounded-2xl"
            />

          </div>

          <div className="mt-4 flex items-center gap-3">
            <button
              onClick={async () => {
                setSaving(true);
                setMsg(null);
                try {
                  const payload = {
                    fullName: adminName,
                    email: adminEmail,
                    profileImageUrl: profileImageUrl,
                  };
                  if (newPassword && newPassword.length > 0) payload.newPassword = newPassword;
                  const updated = await api.updateProfile(payload);
                  setMsg('Profile saved');
                  setNewPassword('');
                } catch (e) {
                  setMsg(e.message || 'Save failed');
                } finally {
                  setSaving(false);
                }
              }}
              className="bg-blue-500 text-white px-6 py-3 rounded-2xl"
              disabled={saving}
            >
              {saving ? 'Saving...' : 'Save Profile'}
            </button>
            {msg && <p className="text-sm text-gray-600">{msg}</p>}
          </div>

        </div>

        {/* System Settings */}
        <div className="bg-white rounded-3xl shadow-md p-6 mb-8">

          <h2 className="text-2xl font-bold mb-6">
            System Settings
          </h2>

          <div className="space-y-5">

            <div className="flex justify-between items-center">
              <p>Enable User Registrations</p>
              <input type="checkbox" defaultChecked />
            </div>

            <div className="flex justify-between items-center">
              <p>Enable Worker Verification</p>
              <input type="checkbox" defaultChecked />
            </div>

            <div className="flex justify-between items-center">
              <p>Enable Chat Monitoring</p>
              <input type="checkbox" defaultChecked />
            </div>

            <div className="flex justify-between items-center">
              <p>Enable Fraud Detection</p>
              <input type="checkbox" defaultChecked />
            </div>

          </div>

        </div>

        {/* Security Settings */}
        <div className="bg-white rounded-3xl shadow-md p-6 mb-8">

          <h2 className="text-2xl font-bold mb-6">
            Security Settings
          </h2>

          <div className="space-y-5">

            <div className="flex justify-between items-center">
              <p>Two-Factor Authentication</p>
              <input type="checkbox" />
            </div>

            <div className="flex justify-between items-center">
              <p>Login Alerts</p>
              <input type="checkbox" defaultChecked />
            </div>

            <div className="flex justify-between items-center">
              <p>Session Timeout</p>
              <input type="checkbox" />
            </div>

            <div className="flex justify-between items-center">
              <p>Password Expiry</p>
              <input type="checkbox" />
            </div>

          </div>

        </div>

        {/* Notifications */}
        <div className="bg-white rounded-3xl shadow-md p-6 mb-8">

          <h2 className="text-2xl font-bold mb-6">
            Notification Settings
          </h2>

          <div className="space-y-5">

            <div className="flex justify-between items-center">
              <p>Complaint Alerts</p>
              <input type="checkbox" defaultChecked />
            </div>

            <div className="flex justify-between items-center">
              <p>Fraud Alerts</p>
              <input type="checkbox" defaultChecked />
            </div>

            <div className="flex justify-between items-center">
              <p>Worker Registration Alerts</p>
              <input type="checkbox" />
            </div>

            <div className="flex justify-between items-center">
              <p>Payment Issue Alerts</p>
              <input type="checkbox" defaultChecked />
            </div>

          </div>

        </div>

        {/* Appearance */}
        <div className="bg-white rounded-3xl shadow-md p-6 mb-8">

          <h2 className="text-2xl font-bold mb-6">
            Appearance Settings
          </h2>

          <div className="space-y-5">

            <div className="flex justify-between items-center">
              <p>Dark Mode</p>
              <input type="checkbox" />
            </div>

            <div className="flex justify-between items-center">
              <p>Compact Sidebar</p>
              <input type="checkbox" />
            </div>

            <div className="flex justify-between items-center">
              <p>Enable Animations</p>
              <input type="checkbox" defaultChecked />
            </div>

          </div>

        </div>

        {/* Platform Controls */}
        <div className="bg-white rounded-3xl shadow-md p-6 mb-8">

          <h2 className="text-2xl font-bold mb-6">
            Platform Controls
          </h2>

          <div className="grid grid-cols-2 gap-4">

            <button className="bg-orange-500 text-white py-4 rounded-2xl">
              Manage Categories
            </button>

            <button className="bg-blue-500 text-white py-4 rounded-2xl">
              Manage Service Fees
            </button>

            <button className="bg-green-500 text-white py-4 rounded-2xl">
              Export Reports
            </button>

            <button className="bg-red-500 text-white py-4 rounded-2xl">
              Backup Database
            </button>

          </div>

        </div>

        {/* Danger Zone */}
        <div className="bg-white rounded-3xl shadow-md p-6 border border-red-500">

          <h2 className="text-2xl font-bold text-red-500 mb-6">
            Danger Zone
          </h2>

          <div className="flex gap-4">

            <button className="bg-red-500 text-white px-6 py-4 rounded-2xl">
              Reset System
            </button>

            <button className="bg-black text-white px-6 py-4 rounded-2xl">
              Delete Admin Account
            </button>

          </div>

        </div>

      </div>

    </div>

  );
}
return null;
}

export default App;
