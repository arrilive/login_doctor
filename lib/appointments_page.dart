import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'appointment_model.dart';
import 'appointment_service.dart';
import 'appointment_form_page.dart';

class AppointmentsPage extends StatefulWidget {
  const AppointmentsPage({super.key});

  @override
  State<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends State<AppointmentsPage> {
  final AppointmentService _appointmentService = AppointmentService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  String userRole = 'paciente';
  String medicoNombre = '';
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_currentUser == null) return;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(_currentUser!.uid)
          .get();
      
      if (doc.exists && mounted) {
        final data = doc.data();
        setState(() {
          userRole = data?['rol'] ?? 'paciente';
          medicoNombre = data?['nombre'] ?? '';
          _isLoadingUser = false;
        });
        print('👤 Usuario cargado: $medicoNombre (Rol: $userRole)');
      }
    } catch (e) {
      print('❌ Error cargando usuario: $e');
      if (mounted) {
        setState(() => _isLoadingUser = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Usuario no autenticado')),
      );
    }

    if (_isLoadingUser) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(userRole == 'medico' ? 'Mis Citas Médicas' : 'Mis Citas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: StreamBuilder<List<Appointment>>(
          stream: userRole == 'medico'
              ? _appointmentService.getAppointmentsByPatient(_currentUser!.uid)
              : _appointmentService.getAppointmentsByPatient(_currentUser!.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              print('❌ Error en stream: ${snapshot.error}');
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    const Text(
                      'Error al cargar citas',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              print('ℹ️ No hay citas para mostrar');
              return Center(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        userRole == 'medico' 
                            ? 'No tienes citas registradas'
                            : 'No tienes citas agendadas',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (userRole == 'paciente')
                        ElevatedButton.icon(
                          onPressed: () => _navigateToAddAppointment(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Agendar Primera Cita'),
                        ),
                    ],
                  ),
                ),
              );
            }

            List<Appointment> appointments = snapshot.data!;
            print('✅ Mostrando ${appointments.length} citas');

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: appointments.length,
              itemBuilder: (context, index) {
                return _buildAppointmentCard(appointments[index]);
              },
            );
          },
        ),
      ),
      floatingActionButton: userRole == 'paciente'
          ? FloatingActionButton(
              onPressed: () => _navigateToAddAppointment(context),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildAppointmentCard(Appointment appointment) {
    Color statusColor = _getStatusColor(appointment.estado);
    IconData statusIcon = _getStatusIcon(appointment.estado);
    bool canEdit = userRole == 'paciente' && appointment.estado == 'programada';

    return Dismissible(
      key: Key(appointment.id ?? ''),
      direction: canEdit
          ? DismissDirection.endToStart 
          : DismissDirection.none,
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete, color: Colors.white, size: 32),
            SizedBox(height: 4),
            Text(
              'Cancelar',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cancelar Cita'),
            content: const Text(
              '¿Estás seguro de que deseas cancelar esta cita?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text('Sí, Cancelar'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        await _deleteAppointment(appointment.id!);
      },
      child: GestureDetector(
        onTap: () => _showAppointmentDetails(appointment),
        onLongPress: () {
          if (canEdit) {
            _navigateToEditAppointment(context, appointment);
          }
        },
        child: Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          color: Color(0xFF2196F3),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd/MM/yyyy').format(appointment.fecha),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(statusIcon, size: 16, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            appointment.estado.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      '${appointment.horaInicio} - ${appointment.horaFin}',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                Row(
                  children: [
                    Icon(
                      userRole == 'medico' ? Icons.person : Icons.medical_services,
                      size: 18,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        userRole == 'medico' 
                            ? appointment.pacienteNombre
                            : 'Dr. ${appointment.medicoNombre}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                Row(
                  children: [
                    const Icon(Icons.medical_services, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      appointment.especialidad,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notes, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          appointment.motivo,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[800],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                
                if (canEdit)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.touch_app, size: 14, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                          'Mantén presionado para editar • Desliza para cancelar',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String estado) {
    switch (estado) {
      case 'programada':
        return Colors.blue;
      case 'completada':
        return Colors.green;
      case 'cancelada':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String estado) {
    switch (estado) {
      case 'programada':
        return Icons.schedule;
      case 'completada':
        return Icons.check_circle;
      case 'cancelada':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  void _showAppointmentDetails(Appointment appointment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detalles de la Cita'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Fecha', DateFormat('dd/MM/yyyy').format(appointment.fecha)),
              _buildDetailRow('Horario', '${appointment.horaInicio} - ${appointment.horaFin}'),
              _buildDetailRow('Médico', 'Dr. ${appointment.medicoNombre}'),
              _buildDetailRow('Especialidad', appointment.especialidad),
              _buildDetailRow('Paciente', appointment.pacienteNombre),
              _buildDetailRow('Motivo', appointment.motivo),
              _buildDetailRow('Estado', appointment.estado.toUpperCase()),
            ],
          ),
        ),
        actions: [
          if (userRole == 'paciente' && appointment.estado == 'programada')
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _navigateToEditAppointment(context, appointment);
              },
              icon: const Icon(Icons.edit),
              label: const Text('Editar'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToAddAppointment(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AppointmentFormPage(),
      ),
    );
  }

  void _navigateToEditAppointment(BuildContext context, Appointment appointment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppointmentFormPage(appointment: appointment),
      ),
    );
  }

  Future<void> _deleteAppointment(String appointmentId) async {
    try {
      await _appointmentService.deleteAppointment(appointmentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cita cancelada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error cancelando cita: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cancelar cita: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}