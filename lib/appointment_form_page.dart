import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'appointment_model.dart';
import 'appointment_service.dart';
import 'package:intl/intl.dart';

class AppointmentFormPage extends StatefulWidget {
  final Appointment? appointment;

  const AppointmentFormPage({super.key, this.appointment});

  @override
  State<AppointmentFormPage> createState() => _AppointmentFormPageState();
}

class _AppointmentFormPageState extends State<AppointmentFormPage> {
  final _formKey = GlobalKey<FormState>();
  final AppointmentService _appointmentService = AppointmentService();
  
  late TextEditingController _motivoController;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  
  String _selectedMedico = '';
  String _selectedEspecialidad = '';
  String _pacienteNombre = '';
  bool _isLoading = false;
  bool _loadingMedicos = true;

  // Lista de especialidades (estática)
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

  // 🔥 NUEVO: Médicos cargados dinámicamente desde Firestore
  List<Map<String, String>> _medicosDisponibles = [];
  List<Map<String, String>> get _medicosFiltrados {
    if (_selectedEspecialidad.isEmpty) return _medicosDisponibles;
    return _medicosDisponibles
        .where((medico) => medico['especialidad'] == _selectedEspecialidad)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _motivoController = TextEditingController();
    _loadUserData();
    _loadMedicosFromFirestore(); // 🔥 NUEVO
    
    if (widget.appointment != null) {
      _loadAppointmentData();
    }
  }

  // 🔥 NUEVO: Cargar médicos reales desde Firestore
  Future<void> _loadMedicosFromFirestore() async {
    setState(() => _loadingMedicos = true);
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('rol', isEqualTo: 'medico')
          .get();

      final medicos = <Map<String, String>>[];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final nombre = data['nombre'] ?? '';
        
        if (nombre.isNotEmpty) {
          // Intentar obtener especialidad del médico, o asignar una por defecto
          final especialidad = data['especialidad'] ?? 'Medicina General';
          
          medicos.add({
            'nombre': nombre,
            'especialidad': especialidad,
            'uid': doc.id,
          });
          
          print('👨‍⚕️ Médico cargado: $nombre - $especialidad');
        }
      }

      setState(() {
        _medicosDisponibles = medicos;
        _loadingMedicos = false;
      });

      print('✅ Total de médicos cargados: ${medicos.length}');

      // Si no hay médicos, mostrar advertencia
      if (medicos.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay médicos disponibles. Verifica tu perfil.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('❌ Error cargando médicos: $e');
      setState(() => _loadingMedicos = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar médicos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _loadAppointmentData() {
    final appointment = widget.appointment!;
    _motivoController.text = appointment.motivo;
    _selectedDate = appointment.fecha;
    _selectedEspecialidad = appointment.especialidad;
    _selectedMedico = appointment.medicoNombre;
    
    // Convertir strings de hora a TimeOfDay
    List<String> startParts = appointment.horaInicio.split(':');
    _startTime = TimeOfDay(
      hour: int.parse(startParts[0]),
      minute: int.parse(startParts[1]),
    );
    
    List<String> endParts = appointment.horaFin.split(':');
    _endTime = TimeOfDay(
      hour: int.parse(endParts[0]),
      minute: int.parse(endParts[1]),
    );
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();
      
      if (doc.exists && doc.data()?['nombre'] != null) {
        setState(() {
          _pacienteNombre = doc.data()!['nombre'];
        });
      }
    }
  }

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.appointment != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Cita' : 'Nueva Cita'),
      ),
      body: _isLoading || _loadingMedicos
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando médicos disponibles...'),
                ],
              ),
            )
          : _medicosDisponibles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning_amber, size: 64, color: Colors.orange[300]),
                      const SizedBox(height: 16),
                      const Text(
                        'No hay médicos disponibles',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Asegúrate de que existan usuarios con rol "médico" y que tengan un nombre configurado.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Volver'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Banner informativo
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue[700]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${_medicosDisponibles.length} médico(s) disponible(s)',
                                  style: TextStyle(
                                    color: Colors.blue[900],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Especialidad
                        DropdownButtonFormField<String>(
                          value: _selectedEspecialidad.isEmpty ? null : _selectedEspecialidad,
                          decoration: const InputDecoration(
                            labelText: 'Especialidad',
                            prefixIcon: Icon(Icons.medical_services),
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
                              _selectedMedico = '';
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor selecciona una especialidad';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Médico (cargado dinámicamente)
                        DropdownButtonFormField<String>(
                          value: _selectedMedico.isEmpty ? null : _selectedMedico,
                          decoration: InputDecoration(
                            labelText: 'Médico',
                            prefixIcon: const Icon(Icons.person),
                            helperText: _selectedEspecialidad.isEmpty
                                ? 'Selecciona una especialidad primero'
                                : '${_medicosFiltrados.length} médico(s) en esta especialidad',
                          ),
                          items: _medicosFiltrados.map((medico) {
                            return DropdownMenuItem(
                              value: medico['nombre'],
                              child: Text('Dr. ${medico['nombre']}'),
                            );
                          }).toList(),
                          onChanged: _medicosFiltrados.isEmpty
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedMedico = value!;
                                  });
                                },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor selecciona un médico';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Fecha
                        InkWell(
                          onTap: _selectDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Fecha',
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              DateFormat('dd/MM/yyyy').format(_selectedDate),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Horario
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectTime(true),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Hora Inicio',
                                    prefixIcon: Icon(Icons.access_time),
                                  ),
                                  child: Text(
                                    _startTime.format(context),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectTime(false),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Hora Fin',
                                    prefixIcon: Icon(Icons.access_time),
                                  ),
                                  child: Text(
                                    _endTime.format(context),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Motivo
                        TextFormField(
                          controller: _motivoController,
                          decoration: const InputDecoration(
                            labelText: 'Motivo de la consulta',
                            prefixIcon: Icon(Icons.notes),
                            hintText: 'Describe el motivo de tu consulta',
                          ),
                          maxLines: 3,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingresa el motivo de la consulta';
                            }
                            if (value.length < 10) {
                              return 'El motivo debe tener al menos 10 caracteres';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Información del paciente
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person, color: Color(0xFF2196F3)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Paciente',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      _pacienteNombre.isEmpty ? 'Cargando...' : _pacienteNombre,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Botón de guardar
                        ElevatedButton(
                          onPressed: _saveAppointment,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            isEditing ? 'Actualizar Cita' : 'Agendar Cita',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2196F3),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _startTime : _endTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2196F3),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
          // Ajustar hora fin automáticamente (1 hora después)
          final int newHour = (picked.hour + 1) % 24;
          _endTime = TimeOfDay(hour: newHour, minute: picked.minute);
        } else {
          _endTime = picked;
        }
      });

      // Validar que la hora de fin sea después de la hora de inicio
      if (_timeToMinutes(_endTime) <= _timeToMinutes(_startTime)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La hora de fin debe ser posterior a la hora de inicio'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  int _timeToMinutes(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  String _timeOfDayToString(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _saveAppointment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validar horarios
    if (_timeToMinutes(_endTime) <= _timeToMinutes(_startTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La hora de fin debe ser posterior a la hora de inicio'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      final appointment = Appointment(
        id: widget.appointment?.id,
        pacienteId: user.uid,
        pacienteNombre: _pacienteNombre,
        medicoNombre: _selectedMedico,
        especialidad: _selectedEspecialidad,
        fecha: _selectedDate,
        horaInicio: _timeOfDayToString(_startTime),
        horaFin: _timeOfDayToString(_endTime),
        motivo: _motivoController.text.trim(),
        estado: widget.appointment?.estado ?? 'programada',
      );

      print('💾 Guardando cita para médico: $_selectedMedico');

      if (widget.appointment == null) {
        // Crear nueva cita
        await _appointmentService.createAppointment(appointment);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cita agendada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        // Actualizar cita existente
        await _appointmentService.updateAppointment(
          widget.appointment!.id!,
          appointment,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cita actualizada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      print('❌ Error guardando cita: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}