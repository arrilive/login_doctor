import 'package:cloud_firestore/cloud_firestore.dart';

class Appointment {
  final String? id;
  final String pacienteId;
  final String pacienteNombre;
  final String medicoNombre;
  final String especialidad;
  final DateTime fecha;
  final String horaInicio;
  final String horaFin;
  final String motivo;
  final String estado; // programada, completada, cancelada

  Appointment({
    this.id,
    required this.pacienteId,
    required this.pacienteNombre,
    required this.medicoNombre,
    required this.especialidad,
    required this.fecha,
    required this.horaInicio,
    required this.horaFin,
    required this.motivo,
    this.estado = 'programada',
  });

  // Convertir de Firestore a objeto Appointment
  factory Appointment.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Appointment(
      id: doc.id,
      pacienteId: data['pacienteId'] ?? '',
      pacienteNombre: data['pacienteNombre'] ?? '',
      medicoNombre: data['medicoNombre'] ?? '',
      especialidad: data['especialidad'] ?? '',
      fecha: (data['fecha'] as Timestamp).toDate(),
      horaInicio: data['horaInicio'] ?? '',
      horaFin: data['horaFin'] ?? '',
      motivo: data['motivo'] ?? '',
      estado: data['estado'] ?? 'programada',
    );
  }

  // Convertir objeto a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'pacienteId': pacienteId,
      'pacienteNombre': pacienteNombre,
      'medicoNombre': medicoNombre,
      'especialidad': especialidad,
      'fecha': Timestamp.fromDate(fecha),
      'horaInicio': horaInicio,
      'horaFin': horaFin,
      'motivo': motivo,
      'estado': estado,
    };
  }

  // Crear copia del objeto con cambios
  Appointment copyWith({
    String? id,
    String? pacienteId,
    String? pacienteNombre,
    String? medicoNombre,
    String? especialidad,
    DateTime? fecha,
    String? horaInicio,
    String? horaFin,
    String? motivo,
    String? estado,
  }) {
    return Appointment(
      id: id ?? this.id,
      pacienteId: pacienteId ?? this.pacienteId,
      pacienteNombre: pacienteNombre ?? this.pacienteNombre,
      medicoNombre: medicoNombre ?? this.medicoNombre,
      especialidad: especialidad ?? this.especialidad,
      fecha: fecha ?? this.fecha,
      horaInicio: horaInicio ?? this.horaInicio,
      horaFin: horaFin ?? this.horaFin,
      motivo: motivo ?? this.motivo,
      estado: estado ?? this.estado,
    );
  }
}