import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

// ============== EVENTS ==============
abstract class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => [];
}

class LoadDashboardData extends DashboardEvent {
  final String medicoNombre;

  const LoadDashboardData(this.medicoNombre);

  @override
  List<Object?> get props => [medicoNombre];
}

class DashboardDataUpdated extends DashboardEvent {
  final DashboardStats stats;

  const DashboardDataUpdated(this.stats);

  @override
  List<Object?> get props => [stats];
}

// ============== STATES ==============
abstract class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object?> get props => [];
}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final DashboardStats stats;

  const DashboardLoaded(this.stats);

  @override
  List<Object?> get props => [stats];
}

class DashboardError extends DashboardState {
  final String message;

  const DashboardError(this.message);

  @override
  List<Object?> get props => [message];
}

// ============== MODELS ==============
class DashboardStats extends Equatable {
  final int totalCitas;
  final int citasPendientes;
  final int totalPacientes;
  final int citasHoy;
  final int citasCompletadas;

  const DashboardStats({
    required this.totalCitas,
    required this.citasPendientes,
    required this.totalPacientes,
    required this.citasHoy,
    required this.citasCompletadas,
  });

  @override
  List<Object?> get props => [
        totalCitas,
        citasPendientes,
        totalPacientes,
        citasHoy,
        citasCompletadas,
      ];
}

// ============== BLOC ==============
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DashboardBloc() : super(DashboardInitial()) {
    on<LoadDashboardData>(_onLoadDashboardData);
    on<DashboardDataUpdated>(_onDashboardDataUpdated);
  }

  Future<void> _onLoadDashboardData(
    LoadDashboardData event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoading());

    try {
      // Escuchar cambios en tiempo real
      _firestore
          .collection('citas')
          .where('medicoNombre', isEqualTo: event.medicoNombre)
          .snapshots()
          .listen((snapshot) async {
        final stats = await _calculateStats(event.medicoNombre, snapshot.docs);
        add(DashboardDataUpdated(stats));
      });
    } catch (e) {
      emit(DashboardError('Error al cargar datos: $e'));
    }
  }

  void _onDashboardDataUpdated(
    DashboardDataUpdated event,
    Emitter<DashboardState> emit,
  ) {
    emit(DashboardLoaded(event.stats));
  }

  Future<DashboardStats> _calculateStats(
    String medicoNombre,
    List<QueryDocumentSnapshot> docs,
  ) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    int totalCitas = docs.length;
    int citasPendientes = 0;
    int citasHoy = 0;
    int citasCompletadas = 0;
    Set<String> pacientesUnicos = {};

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final estado = data['estado'] ?? '';
      final fecha = (data['fecha'] as Timestamp).toDate();
      final pacienteId = data['pacienteId'] ?? '';

      // Contar estados
      if (estado == 'programada') citasPendientes++;
      if (estado == 'completada') citasCompletadas++;

      // Contar citas de hoy
      if (fecha.isAfter(startOfDay) && fecha.isBefore(endOfDay)) {
        citasHoy++;
      }

      // Contar pacientes únicos
      if (pacienteId.isNotEmpty) {
        pacientesUnicos.add(pacienteId);
      }
    }

    return DashboardStats(
      totalCitas: totalCitas,
      citasPendientes: citasPendientes,
      totalPacientes: pacientesUnicos.length,
      citasHoy: citasHoy,
      citasCompletadas: citasCompletadas,
    );
  }
}