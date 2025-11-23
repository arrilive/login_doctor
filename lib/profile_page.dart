import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController nombreController = TextEditingController();
  final TextEditingController edadController = TextEditingController();
  final TextEditingController lugarNacimientoController = TextEditingController();
  final TextEditingController padecimientosController = TextEditingController();

  bool _loading = false;
  bool _hasChanges = false;
  String _selectedRol = 'paciente';
  String _selectedEspecialidad = 'Medicina General'; // 🔥 NUEVO

  final List<Map<String, dynamic>> _roles = [
    {'value': 'paciente', 'label': 'Paciente', 'icon': Icons.person},
    {'value': 'medico', 'label': 'Médico', 'icon': Icons.medical_services},
  ];

  // 🔥 NUEVO: Lista de especialidades
  final List<String> _especialidades = [
    'Cardiología',
    'Pediatría',
    'Dermatología',
    'Neurología',
    'Traumatología',
    'Medicina General',
    'Oftalmología',
    'Ginecología',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    
    nombreController.addListener(() => setState(() => _hasChanges = true));
    edadController.addListener(() => setState(() => _hasChanges = true));
    lugarNacimientoController.addListener(() => setState(() => _hasChanges = true));
    padecimientosController.addListener(() => setState(() => _hasChanges = true));
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _loading = true);

    final doc = await _firestore.collection('usuarios').doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      nombreController.text = data['nombre'] ?? '';
      edadController.text = data['edad'] ?? '';
      lugarNacimientoController.text = data['lugar_nacimiento'] ?? '';
      padecimientosController.text = data['padecimientos'] ?? '';
      _selectedRol = data['rol'] ?? 'paciente';
      _selectedEspecialidad = data['especialidad'] ?? 'Medicina General'; // 🔥 NUEVO
    }

    setState(() {
      _loading = false;
      _hasChanges = false;
    });
  }

  Future<void> _saveUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _loading = true);

    await _firestore.collection('usuarios').doc(user.uid).set({
      'nombre': nombreController.text.trim(),
      'edad': edadController.text.trim(),
      'lugar_nacimiento': lugarNacimientoController.text.trim(),
      'padecimientos': padecimientosController.text.trim(),
      'email': user.email,
      'uid': user.uid,
      'rol': _selectedRol,
      'especialidad': _selectedEspecialidad, // 🔥 NUEVO
    });

    setState(() {
      _loading = false;
      _hasChanges = false;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Información guardada exitosamente'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return WillPopScope(
      onWillPop: () async {
        if (_hasChanges) {
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Cambios sin guardar'),
              content: const Text('¿Deseas salir sin guardar los cambios?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Salir'),
                ),
              ],
            ),
          );
          return shouldPop ?? false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mi Perfil'),
          actions: [
            if (_hasChanges)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadUserData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GestureDetector(
                        onDoubleTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cambio de foto próximamente'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Center(
                          child: Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _selectedRol == 'medico' 
                                      ? Icons.medical_services 
                                      : Icons.person,
                                  size: 60,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Toca dos veces para cambiar foto',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.email_outlined,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                user?.email ?? 'No disponible',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Selector de Rol
                      Text(
                        'Rol en la Aplicación',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: _roles.map((rol) {
                            final isSelected = _selectedRol == rol['value'];
                            return Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedRol = rol['value'];
                                    _hasChanges = true;
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Theme.of(context).primaryColor
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? Theme.of(context).primaryColor
                                          : Colors.grey[300]!,
                                      width: 2,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        rol['icon'],
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey[700],
                                        size: 28,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        rol['label'],
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 🔥 NUEVO: Especialidad (solo para médicos)
                      if (_selectedRol == 'medico') ...[
                        Text(
                          'Especialidad Médica',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedEspecialidad,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.medical_services),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: _especialidades.map((especialidad) {
                            return DropdownMenuItem(
                              value: especialidad,
                              child: Text(especialidad),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedEspecialidad = value!;
                              _hasChanges = true;
                            });
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                      
                      Text(
                        'Información Personal',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nombreController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre completo',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: edadController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Edad',
                          prefixIcon: Icon(Icons.cake_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: lugarNacimientoController,
                        decoration: const InputDecoration(
                          labelText: 'Lugar de nacimiento',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Padecimientos (solo para pacientes)
                      if (_selectedRol == 'paciente')
                        TextField(
                          controller: padecimientosController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Padecimientos',
                            prefixIcon: Icon(Icons.medical_information_outlined),
                            alignLabelWithHint: true,
                          ),
                        ),
                      const SizedBox(height: 32),
                      
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _hasChanges ? _saveUserData : null,
                          icon: Icon(
                            _hasChanges ? Icons.save_outlined : Icons.check_circle_outline,
                          ),
                          label: Text(
                            _hasChanges ? 'Guardar cambios' : 'Todo actualizado',
                            style: const TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _hasChanges 
                                ? const Color(0xFF2196F3) 
                                : Colors.grey[400],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      if (_hasChanges)
                        TextButton.icon(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Descartar cambios'),
                                content: const Text(
                                  '¿Estás seguro de que deseas descartar los cambios?'
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text('Descartar'),
                                  ),
                                ],
                              ),
                            );
                            
                            if (confirm == true) {
                              await _loadUserData();
                            }
                          },
                          icon: const Icon(Icons.undo),
                          label: const Text('Descartar cambios'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    nombreController.dispose();
    edadController.dispose();
    lugarNacimientoController.dispose();
    padecimientosController.dispose();
    super.dispose();
  }
}