import 'package:flutter/material.dart';
import 'package:ocr/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<Profile> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _lastname = '';
  String _email = '';
  String _password = '';
  bool _isLoading = false;
  Map<String, String>? user;
  AuthProvider? authProvider;

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<AuthProvider>(context, listen: false);

    _loadUserData();
  }

  Future<void> _loadUserData() async {
    authProvider?.getCurrentUser();
    user = authProvider!.currentUser;

    checkTokenExpiration(authProvider);

    if (user != null) {
      setState(() {
        _name = user!['name']!;
        _lastname = user!['last_name']!;
        _email = user!['email']!;
        _isLoading = false;
      });
    }
  }
  
  void checkTokenExpiration(dynamic provider) {
    if (provider.expiredToken) {
      provider.handleTokenExpiration();
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  void _saveProfile() async {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();
      setState(() => _isLoading = true);
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final bool updated = await authProvider.updateUser(int.parse(user!['id']!), {
        'name': _name,
        'last_name': _lastname,
        'email': _email,
        'password': _password,
      });
      
    if (updated) {
      await authProvider.getCurrentUser();
      _loadUserData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Color(0xFFFFF3F8), content: Text('Perfil actualizado correctamente', style: TextStyle(color: Color(0xC3000022))),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Color(0xFFFFF3F8), content: Text('Error actualizando el perfil', style: TextStyle(color: Color(0xC3000022))),
      ));
    }
    
    setState(() => _isLoading = false);
    
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading ? const Center(child: CircularProgressIndicator(backgroundColor: Color(0xC3000022),)) : _buildProfileForm(),
      ),
    );
  }

  Widget _buildProfileForm() {
    return Center(child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            style: const TextStyle(color: Color(0xC3000022)),
            initialValue: _name,
            decoration: const InputDecoration(labelText: 'Nombre'),
            validator: (value) => value!.isEmpty ? 'Por favor, ingrese su nombre' : null,
            onSaved: (value) => _name = value!,
          ),
          TextFormField(
            style: const TextStyle(color: Color(0xC3000022)),
            initialValue: _lastname,
            decoration: const InputDecoration(labelText: 'Apellido'),
            validator: (value) => value!.isEmpty ? 'Por favor, ingrese su apellido' : null,
            onSaved: (value) => _lastname = value!,
          ),
          TextFormField(
            style: const TextStyle(color: Color(0xC3000022)),
            initialValue: _email,
            decoration: const InputDecoration(labelText: 'Correo Electrónico'),
            validator: (value) => value!.isEmpty ? 'Por favor, ingrese su correo electrónico' : null,
            onSaved: (value) => _email = value!,
          ),
          TextFormField(
            style: const TextStyle(color: Color(0xC3000022)),
            initialValue: _password,
            decoration: const InputDecoration(labelText: 'Contraseña'),
            obscureText: true,
            validator: (value) {
              if (value!.isNotEmpty && value.length < 8) {
                return 'La contraseña debe tener al menos 8 caracteres';
              }
              return null;
            },
            onSaved: (value) => _password = value!,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saveProfile,
            child: const Text('Guardar', style: TextStyle(color: Color(0xC3000022)),),
          ),
        ],
      ),
    ));
  }
}
