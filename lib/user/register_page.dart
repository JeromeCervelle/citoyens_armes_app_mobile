import 'package:flutter/material.dart';
import 'auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  Future<void> _handleRegister() async {
    // 1. Vérifications de base (Frontend)
    if (_passwordController.text.length < 8) {
      _showError("Le mot de passe doit faire au moins 8 caractères.");
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError("Les mots de passe ne correspondent pas.");
      return;
    }

    setState(() => _isLoading = true);
    
    // 2. Appel à l'API
    bool success = await _authService.register(
      _emailController.text,
      _passwordController.text,
      _nameController.text,
    );

    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Compte créé avec succès !"), backgroundColor: Colors.green),
      );
      // On ferme la page d'inscription pour revenir au Login
      Navigator.pop(context); 
    } else {
      _showError("❌ Échec de l'inscription. Email déjà utilisé ?");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inscription')),
      body: SingleChildScrollView( // Permet de scroller si le clavier cache des champs
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.person_add_alt_1, size: 80, color: Colors.blue),
            const SizedBox(height: 30),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nom complet', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Mot de passe (8 car. min)', border: OutlineInputBorder()),
              obscureText: true,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(labelText: 'Confirmer le mot de passe', border: OutlineInputBorder()),
              obscureText: true,
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _handleRegister,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                    child: const Text("S'inscrire", style: TextStyle(fontSize: 16)),
                  ),
          ],
        ),
      ),
    );
  }
}