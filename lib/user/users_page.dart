import 'package:flutter/material.dart';
import 'user_model.dart';
import 'user_service.dart';
import 'auth_service.dart';
import 'login_page.dart';

class UsersPage extends StatefulWidget {
  final User currentUser;

  const UsersPage({super.key, required this.currentUser});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();

  List<User> _users = [];
  List<User> _filtered = [];
  bool _isLoading = true;
  String _searchQuery = '';

  static const List<String> _roles = ['ADMIN', 'SUPERADMIN'];

  @override
  void initState() {
    super.initState();
    if (widget.currentUser.isSuperAdmin) _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final users = await _userService.getAllUsers();
    setState(() {
      _users = users;
      _applySearch();
      _isLoading = false;
    });
  }

  void _applySearch() {
    final q = _searchQuery.toLowerCase();
    _filtered = _users.where((u) {
      return u.name.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q);
    }).toList();
  }

  Color _roleColor(String? role) {
    switch (role) {
      case 'SUPERADMIN': return Colors.deepPurple;
      case 'ADMIN': return Colors.blue.shade700;
      default: return Colors.grey;
    }
  }

  bool _isSelf(User user) => user.id == widget.currentUser.id;
  bool _isSuperAdmin(User user) => user.isSuperAdmin;

  // ─── Dialog : Ajouter ─────────────────────────────────────────────────────
  Future<void> _showAddUserDialog() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String selectedRole = 'ADMIN';
    bool obscure = true;
    bool loading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person_add, color: Colors.blue),
              SizedBox(width: 8),
              Text('Ajouter un utilisateur'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogField(nameCtrl, 'Nom complet', Icons.person),
                const SizedBox(height: 12),
                _buildDialogField(emailCtrl, 'Email', Icons.email_outlined,
                    type: TextInputType.emailAddress),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe (8 car. min)',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Rôle',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: _roles
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(r == 'SUPERADMIN' ? 'Super Admin' : 'Admin'),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedRole = v ?? 'ADMIN'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final email = emailCtrl.text.trim();
                      final pass = passCtrl.text;

                      if (name.isEmpty || email.isEmpty || pass.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Tous les champs sont requis.'),
                            backgroundColor: Colors.red));
                        return;
                      }
                      if (pass.length < 8) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Le mot de passe doit faire ≥ 8 caractères.'),
                            backgroundColor: Colors.red));
                        return;
                      }

                      setDialogState(() => loading = true);

                      final registered =
                          await _authService.register(email, pass, name);

                      if (!registered) {
                        setDialogState(() => loading = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('❌ Échec — email déjà utilisé ?'),
                              backgroundColor: Colors.red));
                        }
                        return;
                      }

                      if (selectedRole == 'SUPERADMIN') {
                        final allUsers = await _userService.getAllUsers();
                        final newUser = allUsers.firstWhere(
                          (u) => u.email == email,
                          orElse: () => User(id: '', email: '', name: ''),
                        );
                        if (newUser.id.isNotEmpty) {
                          await _userService.updateUser(newUser.id,
                              role: 'SUPERADMIN');
                        }
                      }

                      if (mounted) {
                        Navigator.pop(ctx);
                        await _loadUsers();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('✅ Utilisateur créé !'),
                            backgroundColor: Colors.green));
                      }
                    },
              child: loading
                  ? const SizedBox(
                      height: 18, width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Dialog : Modifier ────────────────────────────────────────────────────
  Future<void> _showEditUserDialog(User user) async {
    String selectedRole = user.role ?? 'ADMIN';
    bool loading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: _roleColor(user.role),
                radius: 18,
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name,
                        style: const TextStyle(fontSize: 16),
                        overflow: TextOverflow.ellipsis),
                    Text(user.email,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          content: DropdownButtonFormField<String>(
            value: selectedRole,
            decoration: const InputDecoration(
              labelText: 'Rôle',
              prefixIcon: Icon(Icons.badge_outlined),
              border: OutlineInputBorder(),
            ),
            items: _roles
                .map((r) => DropdownMenuItem(
                      value: r,
                      child: Row(
                        children: [
                          Icon(Icons.circle, size: 12, color: _roleColor(r)),
                          const SizedBox(width: 8),
                          Text(r == 'SUPERADMIN' ? 'Super Admin' : 'Admin'),
                        ],
                      ),
                    ))
                .toList(),
            onChanged: (v) =>
                setDialogState(() => selectedRole = v ?? 'ADMIN'),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      setDialogState(() => loading = true);
                      await _userService.updateUser(user.id, role: selectedRole);
                      if (mounted) {
                        Navigator.pop(ctx);
                        await _loadUsers();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('✅ Rôle mis à jour.'),
                            backgroundColor: Colors.green));
                      }
                    },
              child: loading
                  ? const SizedBox(
                      height: 18, width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Confirmer suppression ─────────────────────────────────────────────────
  Future<void> _confirmDelete(User user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'utilisateur'),
        content: Text('Confirmer la suppression de "${user.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _userService.deleteUser(user.id);
      if (mounted) {
        if (success) {
          await _loadUsers();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('✅ Utilisateur supprimé.'),
              backgroundColor: Colors.green));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('❌ Échec de la suppression.'),
              backgroundColor: Colors.red));
        }
      }
    }
  }

  // ─── Helpers UI ───────────────────────────────────────────────────────────
  Widget _buildDialogField(TextEditingController ctrl, String label, IconData icon,
      {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _roleChip(String? role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _roleColor(role).withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _roleColor(role).withOpacity(0.5)),
      ),
      child: Text(
        role == 'SUPERADMIN' ? 'Super Admin' : (role ?? '—'),
        style: TextStyle(
            color: _roleColor(role),
            fontSize: 11,
            fontWeight: FontWeight.w600),
      ),
    );
  }

  // ─── Vue bloquée (pas SUPERADMIN) ─────────────────────────────────────────
  Widget _buildBlockedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock, size: 64, color: Colors.red.shade300),
            ),
            const SizedBox(height: 24),
            const Text(
              'Accès refusé',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Cette page est réservée aux Super Admins.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Retour'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Deuxième vérification côté page
    if (!widget.currentUser.isSuperAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Gestion des utilisateurs'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
        ),
        body: _buildBlockedView(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des utilisateurs'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text(
                widget.currentUser.name,
                style: const TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() {
                _searchQuery = v;
                _applySearch();
              }),
              decoration: InputDecoration(
                hintText: 'Rechercher par nom ou email…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${_filtered.length} utilisateur${_filtered.length > 1 ? 's' : ''}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'Aucun utilisateur trouvé.'
                                  : 'Aucun résultat pour "$_searchQuery".',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadUsers,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final user = _filtered[i];
                            final isSelf = _isSelf(user);
                            final isSuperAdmin = _isSuperAdmin(user);
                            // Boutons désactivés si : soi-même OU superadmin cible
                            final canEdit = !isSelf && !isSuperAdmin;
                            final canDelete = !isSelf && !isSuperAdmin;

                            return Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: _roleColor(user.role),
                                  child: Text(
                                    user.name.isNotEmpty
                                        ? user.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Text(user.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    if (isSelf) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: Colors.blue.shade200),
                                        ),
                                        child: Text('Vous',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.blue.shade700)),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 2),
                                    Text(user.email,
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.grey)),
                                    const SizedBox(height: 6),
                                    _roleChip(user.role),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.edit_outlined,
                                          color: canEdit
                                              ? Colors.blue
                                              : Colors.grey.shade300),
                                      tooltip: canEdit ? 'Modifier' : null,
                                      onPressed: canEdit
                                          ? () => _showEditUserDialog(user)
                                          : null,
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline,
                                          color: canDelete
                                              ? Colors.red
                                              : Colors.grey.shade300),
                                      tooltip: canDelete ? 'Supprimer' : null,
                                      onPressed: canDelete
                                          ? () => _confirmDelete(user)
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddUserDialog,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Ajouter'),
      ),
    );
  }
}