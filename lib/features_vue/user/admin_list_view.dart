import 'dart:ui';
import 'package:flutter/material.dart';
import '../../user/auth_service.dart';
import '../../user/user_service.dart';
import '../../user/user_model.dart';
import '../theme/neon_components.dart';
import '../../log/log_service.dart';
import '../../log/log_model.dart';

class AdminListView extends StatefulWidget {
  const AdminListView({super.key});

  @override
  State<AdminListView> createState() => _AdminListViewState();
}

class _AdminListViewState extends State<AdminListView> {
  final UserService _userService = UserService();
  final LogService _logService = LogService();
  List<User> _users = [];
  bool _isLoading = true;
  bool _showInactive = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final me = await _userService.getCurrentUser();
    _currentUserId = me?.id;
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    try {
      final me = await _userService.getCurrentUser();
      List<User> users;
      if (me?.isSuperAdmin == true) {
        users = await _userService.getAllUsers(includeInactive: _showInactive);
      } else {
        // Un Admin simple ne voit que son propre profil
        users = me != null ? [me] : [];
      }
      setState(() {
        _users = users;
        _isLoading = false;
        _currentUserId = me?.id;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Erreur chargement utilisateurs: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showGlobalLogsDialog() async {
    showDialog(
      context: context,
      builder: (context) => _LogsDialog(
        title: 'LOGS GLOBAUX (7 JOURS)',
        fetchLogs: () => _logService.getRecentLogs(),
        users: _users,
      ),
    );
  }

  Future<void> _showUserLogsDialog(User u) async {
    showDialog(
      context: context,
      builder: (context) => _LogsDialog(
        title: 'LOGS DE ${u.name.toUpperCase()}',
        fetchLogs: () => _logService.getLogsByUser(u.id),
        users: _users,
      ),
    );
  }

  bool _isSelf(User u) => u.id == _currentUserId;

  Future<void> _showCreateUserDialog() async {
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    final passwordController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D1526),
        title: const Text(
          'CRÉER UN ADMIN',
          style: TextStyle(
            color: Color(0xFF00FF85),
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1.2,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildNeonField(nameController, 'Nom'),
              _buildNeonField(emailController, 'Email'),
              _buildNeonField(
                passwordController,
                'Mot de passe',
                obscure: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'ANNULER',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              final ok = await AuthService().registerByAdmin(
                emailController.text.trim(),
                passwordController.text,
                nameController.text.trim(),
              );
              if (!mounted) return;
              Navigator.pop(context);
              if (ok) {
                _refresh();
              } else {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('❌ Erreur lors de la création'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              'CRÉER',
              style: TextStyle(
                color: Color(0xFF00FF85),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditUserDialog(User user) async {
    final isSelf = _isSelf(user);
    final nameController = TextEditingController(text: user.name);
    final emailController = TextEditingController(text: user.email);
    String selectedRole = user.role ?? 'ADMIN';

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0D1526),
          title: Text(
            'MODIFIER : ${user.name.toUpperCase()}',
            style: const TextStyle(
              color: Color(0xFF00FF85),
              fontWeight: FontWeight.bold,
              fontSize: 15,
              letterSpacing: 1.1,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildNeonField(nameController, 'Nom'),
                _buildNeonField(emailController, 'Email'),
                if (!isSelf) ...[
                  const Divider(color: Colors.white24, height: 24),
                  const Text(
                    'RÔLE',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _buildRoleRadio(
                    setDialogState,
                    'ADMIN',
                    selectedRole,
                    (v) => selectedRole = v,
                  ),
                  _buildRoleRadio(
                    setDialogState,
                    'SUPERADMIN',
                    selectedRole,
                    (v) => selectedRole = v,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'ANNULER',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                final result = await _userService.updateUser(
                  user.id,
                  name: nameController.text.trim(),
                  email: emailController.text.trim(),
                  role: selectedRole,
                );
                if (result != null) {
                  _refresh();
                } else {
                  if (mounted)
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('❌ Erreur lors de la modification'),
                        backgroundColor: Colors.red,
                      ),
                    );
                }
              },
              child: const Text(
                'ENREGISTRER',
                style: TextStyle(
                  color: Color(0xFF00FF85),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showChangePasswordDialog(User user) async {
    final passwordController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D1526),
        title: Text(
          'NOUVEAU MOT DE PASSE : ${user.name.toUpperCase()}',
          style: const TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        content: _buildNeonField(
          passwordController,
          'Nouveau mot de passe',
          obscure: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'ANNULER',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (passwordController.text.length < 8) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Min. 8 caractères')),
                );
                return;
              }
              Navigator.pop(context);
              final ok = await _userService.updatePassword(
                user.id,
                passwordController.text,
              );
              if (ok) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('✅ Mot de passe mis à jour'),
                    backgroundColor: Color(0xFF00FF85),
                  ),
                );
              } else {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('❌ Erreur de mise à jour'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              'METTRE À JOUR',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleRadio(
    StateSetter setDialogState,
    String value,
    String groupValue,
    Function(String) onChanged,
  ) {
    return RadioListTile<String>(
      title: Text(
        value == 'SUPERADMIN' ? 'SUPER ADMIN' : 'ADMIN',
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      value: value,
      groupValue: groupValue,
      activeColor: const Color(0xFF00FF85),
      onChanged: (val) {
        if (val != null) setDialogState(() => onChanged(val));
      },
    );
  }

  void _confirmDelete(User u) {
    if (_isSelf(u)) {
      _showError('Vous ne pouvez pas vous supprimer vous-même.');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1526),
        title: const Text(
          'DÉSACTIVER',
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: Text(
          'Désactiver "${u.name}" ?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'ANNULER',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await _userService.deleteUser(u.id);
              if (ok) {
                _refresh();
              } else {
                if (mounted)
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('❌ Erreur suppression'),
                      backgroundColor: Colors.red,
                    ),
                  );
              }
            },
            child: const Text(
              'DÉSACTIVER',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reactivateUser(User u) async {
    final result = await _userService.updateUserStatus(u.id, 'ACTIVE');
    if (result != null) {
      _refresh();
    } else {
      if (mounted) _showError('Erreur lors de la réactivation');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const NeonBackground(),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: Text(
                _users.any((u) => _isSelf(u) && u.isSuperAdmin)
                    ? 'GESTION DES ADMINS'
                    : 'MON PROFIL',
                style: const TextStyle(
                  color: Color(0xFF00FF85),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              actions: [
                if (_users.any((u) => _isSelf(u) && u.isSuperAdmin))
                  IconButton(
                    icon: const Icon(Icons.history, color: Colors.white70),
                    onPressed: _showGlobalLogsDialog,
                    tooltip: 'Historique des connexions (7 jours)',
                  ),
                if (_users.any((u) => _isSelf(u) && u.isSuperAdmin))
                  IconButton(
                    icon: Icon(
                      _showInactive ? Icons.visibility : Icons.visibility_off,
                      color: _showInactive
                          ? const Color(0xFF00FF85)
                          : Colors.white54,
                    ),
                    onPressed: () {
                      setState(() => _showInactive = !_showInactive);
                      _refresh();
                    },
                    tooltip: _showInactive
                        ? 'Masquer inactifs'
                        : 'Afficher inactifs',
                  ),
                const SizedBox(width: 8),
              ],
            ),
            floatingActionButton:
                (_users.any((u) => _isSelf(u) && u.isSuperAdmin))
                ? FloatingActionButton(
                    onPressed: _showCreateUserDialog,
                    backgroundColor: const Color(0xFF00FF85),
                    child: const Icon(Icons.person_add, color: Colors.black),
                  )
                : null,
            body: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00FF85)),
                  )
                : _users.isEmpty
                ? const Center(
                    child: Text(
                      'Aucun utilisateur trouvé',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _refresh,
                    color: const Color(0xFF00FF85),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _users.length,
                      itemBuilder: (context, index) =>
                          _buildUserCard(_users[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(User u) {
    final isSelf = _isSelf(u);
    final isSuperAdmin = (u.role ?? '').toUpperCase() == 'SUPERADMIN';
    final color = isSuperAdmin ? const Color(0xFF00FF85) : Colors.white70;

    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          color: Colors.white.withOpacity(0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(
              color: isSelf
                  ? const Color(0xFF00FF85).withOpacity(0.5)
                  : u.status == 'INACTIVE'
                  ? Colors.redAccent.withOpacity(0.3)
                  : Colors.white.withOpacity(0.1),
            ),
          ),
          child: Opacity(
            opacity: u.status == 'INACTIVE' ? 0.6 : 1.0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withOpacity(0.1),
                    child: Text(
                      u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              u.name.toUpperCase(),
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                letterSpacing: 0.8,
                              ),
                            ),
                            if (isSelf) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF00FF85,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFF00FF85),
                                    width: 0.5,
                                  ),
                                ),
                                child: const Text(
                                  'MOI',
                                  style: TextStyle(
                                    color: Color(0xFF00FF85),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          u.email,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          u.roleLabel,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (u.status == 'INACTIVE')
                    IconButton(
                      icon: const Icon(
                        Icons.person_add_alt_1,
                        color: Color(0xFF00FF85),
                        size: 20,
                      ),
                      onPressed: () => _reactivateUser(u),
                      tooltip: 'Réactiver',
                    )
                  else ...[
                    if (_users.any((user) => _isSelf(user) && user.isSuperAdmin))
                      IconButton(
                        icon: const Icon(
                          Icons.history,
                          color: Colors.white54,
                          size: 20,
                        ),
                        onPressed: () => _showUserLogsDialog(u),
                        tooltip: 'Historique de connexion',
                      ),
                    IconButton(
                      icon: const Icon(
                        Icons.lock_reset,
                        color: Colors.white38,
                        size: 20,
                      ),
                      onPressed: () => _showChangePasswordDialog(u),
                      tooltip: 'Changer le mot de passe',
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.manage_accounts,
                        color: Colors.white54,
                        size: 20,
                      ),
                      onPressed: () => _showEditUserDialog(u),
                      tooltip: 'Modifier',
                    ),
                    if (!isSelf)
                      IconButton(
                        icon: const Icon(
                          Icons.person_off_outlined,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        onPressed: () => _confirmDelete(u),
                        tooltip: 'Désactiver',
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNeonField(
    TextEditingController controller,
    String label, {
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white24),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF00FF85)),
          ),
        ),
      ),
    );
  }
}

class _LogsDialog extends StatefulWidget {
  final String title;
  final Future<List<ConnectionLog>> Function() fetchLogs;
  final List<User> users;

  const _LogsDialog({required this.title, required this.fetchLogs, required this.users});

  @override
  State<_LogsDialog> createState() => _LogsDialogState();
}

class _LogsDialogState extends State<_LogsDialog> {
  List<ConnectionLog>? _logs;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      final logs = await widget.fetchLogs();
      logs.sort((a, b) => b.connectionDateTime.compareTo(a.connectionDateTime));
      setState(() => _logs = logs);
    } catch (e) {
      setState(() => _logs = []);
    }
  }

  String _getUserName(String userId) {
    try {
      return widget.users.firstWhere((u) => u.id == userId).name;
    } catch (_) {
      return 'Utilisateur inconnu';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0D1526),
      title: Text(
        widget.title,
        style: const TextStyle(
          color: Color(0xFF00FF85),
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 350,
        child: _logs == null
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FF85)))
            : _logs!.isEmpty
                ? const Center(child: Text('Aucun log trouvé', style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    itemCount: _logs!.length,
                    itemBuilder: (context, index) {
                      final log = _logs![index];
                      final d = log.connectionDateTime.toLocal();
                      final dateStr = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
                      final ipStr = log.ipAddress != null && log.ipAddress!.isNotEmpty ? ' - IP: ${log.ipAddress}' : '';
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 2),
                        leading: const Icon(Icons.login, color: Color(0xFF00FF85), size: 16),
                        title: Text(_getUserName(log.userId), style: const TextStyle(color: Colors.white, fontSize: 13)),
                        subtitle: Text('$dateStr$ipStr', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('FERMER', style: TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }
}
