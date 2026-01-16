
import { defineStore } from "pinia";
import { ref, computed } from "vue";
import { useRouter } from "vue-router";
import { supabase } from "../lib/supabase";

export const useAuthStore = defineStore("auth", () => {
    const user = ref(JSON.parse(localStorage.getItem('user')) || null)

    // Normalize role to array helper
    const getRoles = (u) => {
        if (!u || !u.role) return []
        return Array.isArray(u.role) ? u.role : [u.role]
    }

    // Initialize currentRole: Default to first role or 'USER' if available
    const initialRoles = getRoles(user.value)
    const currentRole = ref(initialRoles.includes('ADMIN') ? 'ADMIN' : (initialRoles[0] || null))

    const router = useRouter()

    const isAuthenticated = computed(() => !!user.value)
    const isAdmin = computed(() => currentRole.value === 'ADMIN')
    // Check if user has ADMIN in their roles list (database)
    const isRealAdmin = computed(() => getRoles(user.value).includes('ADMIN'));

  async function login(username, password) {
    const { data, error } = await supabase
      .from("users")
      .select("*")
      .eq("username", username)
      .eq("password", password)
      .single();

    if (error || !data) {
      throw new Error("帳號或密碼錯誤");
    }

        user.value = data

        // Set default current role
        const roles = Array.isArray(data.role) ? data.role : [data.role]
        currentRole.value = roles.includes('ADMIN') ? 'ADMIN' : roles[0]

        localStorage.setItem('user', JSON.stringify(data));

    // Redirect logic handled by component
    return data;
  }

  function logout() {
    user.value = null;
    currentRole.value = null;
    localStorage.removeItem("user");
    localStorage.removeItem("admin_token"); // Clear legacy token
    router.push("/");
  }

    function switchRole(targetRole) {
        // Validation: Can only switch to roles they possess
        // But for "Switch View" feature, we usually just want to toggle between Admin/User views if they are an Admin.
        // If they are Real Admin, they can be 'ADMIN' or 'USER' view.

        if (!isRealAdmin.value) return

        currentRole.value = targetRole
        if (targetRole === 'USER' && router.currentRoute.value.path.startsWith('/admin')) {
             router.push('/equipment')
        } else if (targetRole === 'ADMIN') {
             router.push('/admin/dashboard')
        }
    }
  return {
    user,
    isAuthenticated,
    isAdmin,
    isRealAdmin,
    currentRole,
    login,
    logout,
    switchRole,
  };
});
