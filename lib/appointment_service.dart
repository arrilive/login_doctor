import 'package:cloud_firestore/cloud_firestore.dart';
import 'appointment_model.dart';

class AppointmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'citas';

  // CREATE - Crear una nueva cita
  Future<String?> createAppointment(Appointment appointment) async {
    try {
      // Validar que no haya conflictos de horario
      bool hasConflict = await _checkTimeConflict(
        appointment.fecha,
        appointment.horaInicio,
        appointment.horaFin,
        appointment.medicoNombre,
      );

      if (hasConflict) {
        throw Exception('Ya existe una cita en ese horario para el médico seleccionado');
      }

      DocumentReference docRef = await _firestore
          .collection(_collection)
          .add(appointment.toMap());
      
      return docRef.id;
    } catch (e) {
      print('Error al crear cita: $e');
      rethrow;
    }
  }

  // READ - Obtener todas las citas de un paciente
  Stream<List<Appointment>> getAppointmentsByPatient(String pacienteId) {
    return _firestore
        .collection(_collection)
        .where('pacienteId', isEqualTo: pacienteId)
        .orderBy('fecha', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Appointment.fromFirestore(doc))
            .toList());
  }

  // READ - Obtener una cita específica por ID
  Future<Appointment?> getAppointmentById(String appointmentId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection(_collection)
          .doc(appointmentId)
          .get();
      
      if (doc.exists) {
        return Appointment.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error al obtener cita: $e');
      return null;
    }
  }

  // READ - Obtener todas las citas (para admin)
  Stream<List<Appointment>> getAllAppointments() {
    return _firestore
        .collection(_collection)
        .orderBy('fecha', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Appointment.fromFirestore(doc))
            .toList());
  }

  // UPDATE - Actualizar una cita existente
  Future<void> updateAppointment(String appointmentId, Appointment appointment) async {
    try {
      // Validar que no haya conflictos de horario (excluyendo la cita actual)
      bool hasConflict = await _checkTimeConflict(
        appointment.fecha,
        appointment.horaInicio,
        appointment.horaFin,
        appointment.medicoNombre,
        excludeAppointmentId: appointmentId,
      );

      if (hasConflict) {
        throw Exception('Ya existe una cita en ese horario para el médico seleccionado');
      }

      await _firestore
          .collection(_collection)
          .doc(appointmentId)
          .update(appointment.toMap());
    } catch (e) {
      print('Error al actualizar cita: $e');
      rethrow;
    }
  }

  // DELETE - Eliminar una cita
  Future<void> deleteAppointment(String appointmentId) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(appointmentId)
          .delete();
    } catch (e) {
      print('Error al eliminar cita: $e');
      rethrow;
    }
  }

  // MÉTODO AUXILIAR - Verificar conflictos de horario
  Future<bool> _checkTimeConflict(
    DateTime fecha,
    String horaInicio,
    String horaFin,
    String medicoNombre, {
    String? excludeAppointmentId,
  }) async {
    try {
      // Obtener el inicio y fin del día
      DateTime startOfDay = DateTime(fecha.year, fecha.month, fecha.day);
      DateTime endOfDay = DateTime(fecha.year, fecha.month, fecha.day, 23, 59, 59);

      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('medicoNombre', isEqualTo: medicoNombre)
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .where('estado', isEqualTo: 'programada')
          .get();

      for (var doc in snapshot.docs) {
        // Excluir la cita actual si estamos actualizando
        if (excludeAppointmentId != null && doc.id == excludeAppointmentId) {
          continue;
        }

        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String existingStart = data['horaInicio'];
        String existingEnd = data['horaFin'];

        // Verificar si hay solapamiento de horarios
        if (_timeOverlap(horaInicio, horaFin, existingStart, existingEnd)) {
          return true;
        }
      }

      return false;
    } catch (e) {
      print('Error al verificar conflictos: $e');
      return false;
    }
  }

  // MÉTODO AUXILIAR - Verificar si dos rangos de tiempo se solapan
  bool _timeOverlap(String start1, String end1, String start2, String end2) {
    int start1Minutes = _timeToMinutes(start1);
    int end1Minutes = _timeToMinutes(end1);
    int start2Minutes = _timeToMinutes(start2);
    int end2Minutes = _timeToMinutes(end2);

    return (start1Minutes < end2Minutes) && (end1Minutes > start2Minutes);
  }

  // MÉTODO AUXILIAR - Convertir hora (HH:mm) a minutos desde medianoche
  int _timeToMinutes(String time) {
    List<String> parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  // MÉTODO ADICIONAL - Actualizar solo el estado de una cita
  Future<void> updateAppointmentStatus(String appointmentId, String newStatus) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(appointmentId)
          .update({'estado': newStatus});
    } catch (e) {
      print('Error al actualizar estado: $e');
      rethrow;
    }
  }

  // MÉTODO ADICIONAL - Obtener citas por fecha
  Stream<List<Appointment>> getAppointmentsByDate(DateTime fecha) {
    DateTime startOfDay = DateTime(fecha.year, fecha.month, fecha.day);
    DateTime endOfDay = DateTime(fecha.year, fecha.month, fecha.day, 23, 59, 59);

    return _firestore
        .collection(_collection)
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('fecha')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Appointment.fromFirestore(doc))
            .toList());
  }
}