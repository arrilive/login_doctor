import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_bloc.dart';
import 'package:intl/intl.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String medicoNombre = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedicoData();
  }

  Future<void> _loadMedicoData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();
      
      if (doc.exists && doc.data()?['nombre'] != null) {
        setState(() {
          medicoNombre = doc.data()!['nombre'];
          _isLoading = false;
        });
        
        // Cargar datos del dashboard
        context.read<DashboardBloc>().add(LoadDashboardData(medicoNombre));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Médico'),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<DashboardBloc>().add(LoadDashboardData(medicoNombre));
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: BlocBuilder<DashboardBloc, DashboardState>(
          builder: (context, state) {
            if (state is DashboardLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is DashboardError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      state.message,
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        context
                            .read<DashboardBloc>()
                            .add(LoadDashboardData(medicoNombre));
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              );
            }

            if (state is DashboardLoaded) {
              return _buildDashboardContent(state.stats);
            }

            return const Center(child: Text('Iniciando...'));
          },
        ),
      ),
    );
  }

  Widget _buildDashboardContent(DashboardStats stats) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          // Header con gradiente
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2196F3),
                  Color(0xFF1976D2),
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.medical_services,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dr. $medicoNombre',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                DateFormat('EEEE, d \'de\' MMMM \'de\' yyyy').format(DateTime.now()),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título de estadísticas
                const Text(
                  'Resumen General',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Grid de estadísticas principales (3 cards)
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        title: 'Total Citas',
                        value: stats.totalCitas.toString(),
                        icon: Icons.event_note,
                        color: const Color(0xFF2196F3),
                        subtitle: 'Registradas',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        title: 'Pendientes',
                        value: stats.citasPendientes.toString(),
                        icon: Icons.pending_actions,
                        color: const Color(0xFFFFA726),
                        subtitle: 'Por atender',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        title: 'Pacientes',
                        value: stats.totalPacientes.toString(),
                        icon: Icons.people,
                        color: const Color(0xFF66BB6A),
                        subtitle: 'Únicos',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        title: 'Hoy',
                        value: stats.citasHoy.toString(),
                        icon: Icons.today,
                        color: const Color(0xFFEC407A),
                        subtitle: 'Citas',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Card adicional de completadas (ocupa toda la fila)
                _buildWideStatCard(
                  title: 'Citas Completadas',
                  value: stats.citasCompletadas.toString(),
                  icon: Icons.check_circle,
                  color: const Color(0xFF26A69A),
                  percentage: stats.totalCitas > 0
                      ? (stats.citasCompletadas / stats.totalCitas * 100)
                          .toStringAsFixed(1)
                      : '0',
                ),
                const SizedBox(height: 24),

                // Gráfico de barras simple
                const Text(
                  'Distribución de Citas',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSimpleBarChart(stats),
                const SizedBox(height: 24),

                // Información adicional
                _buildInfoSection(stats),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String percentage,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$percentage%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleBarChart(DashboardStats stats) {
    final maxValue = [
      stats.totalCitas,
      stats.citasPendientes,
      stats.citasCompletadas,
    ].reduce((a, b) => a > b ? a : b).toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildBar(
            'Total',
            stats.totalCitas,
            maxValue,
            const Color(0xFF2196F3),
          ),
          const SizedBox(height: 16),
          _buildBar(
            'Pendientes',
            stats.citasPendientes,
            maxValue,
            const Color(0xFFFFA726),
          ),
          const SizedBox(height: 16),
          _buildBar(
            'Completadas',
            stats.citasCompletadas,
            maxValue,
            const Color(0xFF26A69A),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(String label, int value, double maxValue, Color color) {
    final percentage = maxValue > 0 ? value / maxValue : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: 10,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(DashboardStats stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2196F3).withOpacity(0.1),
            const Color(0xFF1976D2).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Color(0xFF2196F3),
              ),
              SizedBox(width: 8),
              Text(
                'Información del Dashboard',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.access_time,
            'Última actualización',
            DateFormat('HH:mm:ss').format(DateTime.now()),
          ),
          const Divider(height: 24),
          _buildInfoRow(
            Icons.trending_up,
            'Tasa de completación',
            stats.totalCitas > 0
                ? '${(stats.citasCompletadas / stats.totalCitas * 100).toStringAsFixed(1)}%'
                : '0%',
          ),
          const Divider(height: 24),
          _buildInfoRow(
            Icons.calendar_month,
            'Promedio por paciente',
            stats.totalPacientes > 0
                ? '${(stats.totalCitas / stats.totalPacientes).toStringAsFixed(1)} citas'
                : '0 citas',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}