import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class GraphicsPage extends StatefulWidget {
  const GraphicsPage({super.key});

  @override
  State<GraphicsPage> createState() => _GraphicsPageState();
}

class _GraphicsPageState extends State<GraphicsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  String medicoNombre = '';
  String userRole = 'paciente';
  
  // Datos para las gráficas
  Map<String, int> citasPorMes = {};
  Map<String, int> citasPorEstado = {};
  Map<String, int> pacientesPorMedico = {};
  int totalCitas = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      // Obtener datos del usuario
      final userDoc = await _firestore.collection('usuarios').doc(user.uid).get();
      
      if (!userDoc.exists) {
        throw Exception('Usuario no encontrado en Firestore');
      }

      final userData = userDoc.data()!;
      medicoNombre = userData['nombre'] ?? '';
      userRole = userData['rol'] ?? 'paciente';

      print('📊 Usuario: $medicoNombre, Rol: $userRole');

      // Obtener citas según el rol
      QuerySnapshot citasSnapshot;
      
      if (userRole == 'medico') {
        // Si es médico, obtener todas sus citas
        citasSnapshot = await _firestore
            .collection('citas')
            .where('medicoNombre', isEqualTo: medicoNombre)
            .get();
        
        print('📊 Citas del médico encontradas: ${citasSnapshot.docs.length}');
      } else {
        // Si es paciente, obtener solo sus citas
        citasSnapshot = await _firestore
            .collection('citas')
            .where('pacienteId', isEqualTo: user.uid)
            .get();
        
        print('📊 Citas del paciente encontradas: ${citasSnapshot.docs.length}');
      }

      totalCitas = citasSnapshot.docs.length;

      if (citasSnapshot.docs.isEmpty) {
        print('⚠️ No se encontraron citas');
        setState(() => _isLoading = false);
        return;
      }

      // Procesar datos para gráfica 1: Citas por mes
      citasPorMes = {};
      for (var doc in citasSnapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final fecha = (data['fecha'] as Timestamp).toDate();
          final mesAnio = DateFormat('MMM yyyy', 'es').format(fecha);
          citasPorMes[mesAnio] = (citasPorMes[mesAnio] ?? 0) + 1;
        } catch (e) {
          print('Error procesando fecha: $e');
        }
      }

      print('📊 Citas por mes: $citasPorMes');

      // Procesar datos para gráfica 2: Citas por estado
      citasPorEstado = {
        'Programada': 0,
        'Completada': 0,
        'Cancelada': 0,
      };
      
      for (var doc in citasSnapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final estado = data['estado'] ?? 'programada';
          final estadoCapitalizado = estado[0].toUpperCase() + estado.substring(1);
          citasPorEstado[estadoCapitalizado] = 
              (citasPorEstado[estadoCapitalizado] ?? 0) + 1;
        } catch (e) {
          print('Error procesando estado: $e');
        }
      }

      print('📊 Citas por estado: $citasPorEstado');

      // Procesar datos para gráfica 3: Pacientes por médico (solo si es médico)
      if (userRole == 'medico') {
        final allCitasSnapshot = await _firestore.collection('citas').get();
        Map<String, Set<String>> pacientesPorMedicoTemp = {};
        
        for (var doc in allCitasSnapshot.docs) {
          try {
            final data = doc.data();
            final medico = data['medicoNombre'] ?? 'Desconocido';
            final pacienteId = data['pacienteId'] ?? '';
            
            if (pacienteId.isNotEmpty) {
              if (!pacientesPorMedicoTemp.containsKey(medico)) {
                pacientesPorMedicoTemp[medico] = {};
              }
              pacientesPorMedicoTemp[medico]!.add(pacienteId);
            }
          } catch (e) {
            print('Error procesando médico: $e');
          }
        }

        // Convertir a Map<String, int> y ordenar
        pacientesPorMedico = {};
        pacientesPorMedicoTemp.forEach((medico, pacientes) {
          pacientesPorMedico[medico] = pacientes.length;
        });

        // Ordenar y tomar top 5
        var sortedEntries = pacientesPorMedico.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        
        pacientesPorMedico = Map.fromEntries(sortedEntries.take(5));
        
        print('📊 Top 5 médicos: $pacientesPorMedico');
      }

    } catch (e) {
      print('❌ Error cargando datos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas y Gráficas'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualizar datos',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: totalCitas == 0
                  ? _buildEmptyState()
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        children: [
                          _buildHeader(),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Gráfica 1: Citas por Mes
                                _buildGraphCard(
                                  title: 'Citas por Mes',
                                  icon: Icons.calendar_month,
                                  color: const Color(0xFF2196F3),
                                  child: _buildBarChart(),
                                ),
                                const SizedBox(height: 24),

                                // Gráfica 2: Citas por Estado
                                _buildGraphCard(
                                  title: 'Distribución por Estado',
                                  icon: Icons.pie_chart,
                                  color: const Color(0xFF4CAF50),
                                  child: _buildPieChart(),
                                ),
                                const SizedBox(height: 24),

                                // Gráfica 3: Solo para médicos
                                if (userRole == 'medico' && pacientesPorMedico.isNotEmpty)
                                  _buildGraphCard(
                                    title: 'Top 5 Médicos por Pacientes',
                                    icon: Icons.people,
                                    color: const Color(0xFFFF9800),
                                    child: _buildHorizontalBarChart(),
                                  ),
                                
                                if (userRole == 'medico' && pacientesPorMedico.isNotEmpty)
                                  const SizedBox(height: 24),

                                _buildInfoSection(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bar_chart_outlined,
                size: 100,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 24),
              Text(
                'No hay datos disponibles',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                userRole == 'medico'
                    ? 'Aún no tienes citas registradas.\nLas estadísticas aparecerán cuando los pacientes agenden citas contigo.'
                    : 'Aún no tienes citas registradas.\nAgenda tu primera cita para ver las estadísticas.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Volver'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
                      Icons.bar_chart,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Estadísticas',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          userRole == 'medico' 
                              ? 'Dr. $medicoNombre'
                              : medicoNombre,
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
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.analytics,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Total de Citas: $totalCitas',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGraphCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    if (citasPorMes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('No hay datos disponibles'),
        ),
      );
    }

    final sortedEntries = citasPorMes.entries.toList();
    final maxValue = sortedEntries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble();

    return SizedBox(
      height: 250,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxValue + (maxValue * 0.2),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${sortedEntries[group.x.toInt()].key}\n${rod.toY.toInt()} citas',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= sortedEntries.length) return const Text('');
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      sortedEntries[value.toInt()].key,
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 12),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxValue > 0 ? maxValue / 5 : 1,
          ),
          barGroups: List.generate(
            sortedEntries.length,
            (index) => BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: sortedEntries[index].value.toDouble(),
                  color: const Color(0xFF2196F3),
                  width: 20,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    if (citasPorEstado.isEmpty || citasPorEstado.values.every((v) => v == 0)) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('No hay datos disponibles'),
        ),
      );
    }

    final colors = {
      'Programada': const Color(0xFF2196F3),
      'Completada': const Color(0xFF4CAF50),
      'Cancelada': const Color(0xFFF44336),
    };

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: citasPorEstado.entries.where((e) => e.value > 0).map((entry) {
                final total = citasPorEstado.values.reduce((a, b) => a + b);
                final percentage = total > 0 ? (entry.value / total * 100).toStringAsFixed(1) : '0';
                
                return PieChartSectionData(
                  color: colors[entry.key] ?? Colors.grey,
                  value: entry.value.toDouble(),
                  title: '$percentage%',
                  radius: 50,
                  titleStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: citasPorEstado.entries.where((e) => e.value > 0).map((entry) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: colors[entry.key],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${entry.key}: ${entry.value}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildHorizontalBarChart() {
    if (pacientesPorMedico.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('No hay datos disponibles'),
        ),
      );
    }

    final maxValue = pacientesPorMedico.values.reduce((a, b) => a > b ? a : b).toDouble();
    final entries = pacientesPorMedico.entries.toList();

    return SizedBox(
      height: entries.length * 60.0 + 50,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxValue + (maxValue * 0.2),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${entries[group.x.toInt()].key}\n${rod.toY.toInt()} pacientes',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 12),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 100,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= entries.length) return const Text('');
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text(
                      'Dr. ${entries[value.toInt()].key}',
                      style: const TextStyle(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            drawHorizontalLine: false,
          ),
          barGroups: List.generate(
            entries.length,
            (index) => BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: entries[index].value.toDouble(),
                  color: const Color(0xFFFF9800),
                  width: 20,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
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
                'Información de las Gráficas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.bar_chart,
            'Citas por Mes',
            'Muestra la distribución temporal de tus citas',
          ),
          const Divider(height: 24),
          _buildInfoRow(
            Icons.pie_chart,
            'Estado de Citas',
            'Proporción de citas según su estado actual',
          ),
          if (userRole == 'medico' && pacientesPorMedico.isNotEmpty) ...[
            const Divider(height: 24),
            _buildInfoRow(
              Icons.trending_up,
              'Comparativa de Médicos',
              'Top 5 médicos con más pacientes únicos',
            ),
          ],
          const Divider(height: 24),
          _buildInfoRow(
            Icons.access_time,
            'Última actualización',
            DateFormat('HH:mm:ss - dd/MM/yyyy').format(DateTime.now()),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}