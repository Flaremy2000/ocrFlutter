import 'package:flutter/material.dart';
import 'package:ocr/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class UserGesture extends StatefulWidget {
  const UserGesture({super.key});

  @override
  _UserGestureState createState() => _UserGestureState();
}

class _UserGestureState extends State<UserGesture> {
  bool _isLoading = false;
  AuthProvider? authProvider;
  List<dynamic>? users;

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<AuthProvider>(context, listen: false);_fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    await authProvider?.getAllUsers();
    users = authProvider!.users;

    checkTokenExpiration(authProvider!);

    setState(() => _isLoading = false);
  }

void _showUserForm({Map<String, dynamic>? userData}) {
  if (userData == null) {
    showDialog(context: context, builder: (context) => UserCreateForm(onSave: _fetchUsers));
  } else {
    showDialog(context: context, builder: (context) => UserEditForm(userData: userData, onSave: _fetchUsers));
  }
}


void _confirmDeleteUser(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFF3F8),
        title: const Text("Confirmar eliminación", style: TextStyle(color: Color(0xC3000022)),),
        content: const Text("¿Está seguro que desea eliminar este usuario?", style: TextStyle(color: Color(0xC3000022)),),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancelar", style: TextStyle(color: Color(0xC3000022)),),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _deleteUser(id);
            },
            child: const Text("Eliminar", style: TextStyle(color: Color(0xC3000022)),),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(int id) async {
    if (id != 0) {
      final success = await authProvider?.deleteUser(id);
      if (success!) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Color(0xFFFFF3F8), content: Text('Usuario eliminado con éxito', style: TextStyle(color: Color(0xC3000022)),)));
        _fetchUsers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Color(0xFFFFF3F8), content: Text('Error al eliminar el usuario', style: TextStyle(color: Color(0xC3000022)),)));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Color(0xFFFFF3F8), content: Text('ID de usuario inválido', style: TextStyle(color: Color(0xC3000022)),)));
    }
  }

  void checkTokenExpiration(AuthProvider provider) {
    if (provider.expiredToken) {
      provider.handleTokenExpiration();
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  String isAdminOrManager(String value){
    return value == 'Admin' ? 'Administrador' : 'Gestor';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(backgroundColor: Color(0xC3000022),))
          : ListView(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () => _showUserForm(),
                      child: const Text('Agregar Usuario', style: TextStyle(color: Color(0xC3000022)),),
                    ),
                  ),
                ),
                ...authProvider!.users.map((user) => ListTile(
                      title: Text(user['name'] + ' ' + user['last_name'] + ' : ' + isAdminOrManager(user['user_type']), style: const TextStyle(color: Color(0xC3000022)),),
                      subtitle: Text(user['email'], style: const TextStyle(color: Color(0xC3000022)),),
                      trailing: PopupMenuButton<String>(
                        color: const Color(0xFFFFF3F8),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showUserForm(userData: user);
                          } else if (value == 'delete') {
                            _confirmDeleteUser(user['id']);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: Text('Editar', style: TextStyle(color: Color(0xC3000022)),)),
                          const PopupMenuItem(value: 'delete', child: Text('Eliminar', style: TextStyle(color: Color(0xC3000022)),)),
                        ],
                      ),
                    )),
              ],
            ),
    );
  }
}


class UserCreateForm extends StatefulWidget {
  final Function onSave;

  const UserCreateForm({super.key, required this.onSave});

  @override
  _UserCreateFormState createState() => _UserCreateFormState();
}

class _UserCreateFormState extends State<UserCreateForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _lastnameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmationController = TextEditingController();
  String _userType = 'Admin';
  
  String isAdminOrManager(String value){
    return value == 'Admin' ? 'Administrador' : 'Gestor';
  }

  void _handleSubmit() async {
    bool? success;
    if (_formKey.currentState!.validate()) {
      Map<String, String> userData = {
        'name': _nameController.text,
        'lastname': _lastnameController.text,
        'email': _emailController.text,
        'password': _passwordController.text,
        'password_confirmation': _passwordConfirmationController.text,
        'user_type': _userType,
      };

      success = await Provider.of<AuthProvider>(context, listen: false).registerUser(userData);
      if(success){
        Navigator.of(context).pop();
        widget.onSave();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Color(0xFFFFF3F8), content: Text('Usuario guardado exitosamente', style: TextStyle(color: Color(0xC3000022)),)));
      }else{
        Navigator.of(context).pop();
        widget.onSave();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Color(0xFFFFF3F8), content: Text('Hubo un error al guardar el usuario', style: TextStyle(color: Color(0xC3000022)),)));        
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nombre')),
            TextFormField(controller: _lastnameController, decoration: const InputDecoration(labelText: 'Apellido')),
            TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'Correo Electrónico')),
            TextFormField(controller: _passwordController, decoration: const InputDecoration(labelText: 'Contraseña'), obscureText: true),
            TextFormField(controller: _passwordConfirmationController, decoration: const InputDecoration(labelText: 'Confirmar Contraseña'), obscureText: true),
            DropdownButtonFormField<String>(
              dropdownColor: const Color(0xFFFFF3F8),
              value: _userType,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _userType = value;
                  });
                }
              },
              items: <String>['Admin', 'Manager'].map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(isAdminOrManager(value), style: const TextStyle(color: Color(0xC3000022)),),
                );
              }).toList(),
            ),
            const SizedBox(height: 16,),
            ElevatedButton(onPressed: _handleSubmit, child: const Text('Crear Usuario', style: TextStyle(color: Color(0xC3000022)),)),
          ],
        ),
      ),
    );
  }
}


class UserEditForm extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Function onSave;

  const UserEditForm({super.key, required this.userData, required this.onSave});

  @override
  _UserEditFormState createState() => _UserEditFormState();
}

class _UserEditFormState extends State<UserEditForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _lastnameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _userType = 'Admin';

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.userData['name'] ?? '';
    _lastnameController.text = widget.userData['last_name'] ?? '';
    _emailController.text = widget.userData['email'] ?? '';
    _userType = widget.userData['user_type'] ?? 'Admin';
  }
  
  String isAdminOrManager(String value){
    return value == 'Admin' ? 'Administrador' : 'Gestor';
  }

  void _handleUpdate() async {
    if (_formKey.currentState!.validate()) {
      Map<String, String> userData = {
        'name': _nameController.text,
        'last_name': _lastnameController.text,
        'email': _emailController.text,
        'password': _passwordController.text,
        'user_type': _userType,
      };

      final bool update = await Provider.of<AuthProvider>(context, listen: false).updateUser(widget.userData['id'], userData);

      if(update){
        Navigator.of(context).pop();
        widget.onSave();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Color(0xFFFFF3F8), content: Text('Perfil actualizado correctamente', style: TextStyle(color: Color(0xC3000022))),));
      }else{
        Navigator.of(context).pop();
        widget.onSave();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Color(0xFFFFF3F8), content: Text('Error actualizando el perfil', style: TextStyle(color: Color(0xC3000022))),));
      }



    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nombre')),
            TextFormField(controller: _lastnameController, decoration: const InputDecoration(labelText: 'Apellido')),
            TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'Correo Electrónico')),
            TextFormField(controller: _passwordController, decoration: const InputDecoration(labelText: 'Nueva Contraseña (opcional)'), obscureText: true),
            DropdownButtonFormField<String>(
              dropdownColor: const Color(0xFFFFF3F8),
              value: _userType,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _userType = value;
                  });
                }
              },
              items: <String>['Admin', 'Manager'].map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(isAdminOrManager(value), style: const TextStyle(color: Color(0xC3000022)),),
                );
              }).toList(),
            ),
            const SizedBox(height: 16,),
            ElevatedButton(onPressed: _handleUpdate, child: const Text('Actualizar Usuario', style: TextStyle(color: Color(0xC3000022)),)),
          ],
        ),
      ),
    );
  }
}
