import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'home_page.dart';
import 'profile_page.dart';
import 'login_page.dart';
import 'appointments_page.dart';
import 'appointment_form_page.dart';
import 'dashboard_page.dart';
import 'dashboard_bloc.dart';

class Routes {
  static const String login = '/login';
  static const String home = '/home';
  static const String profile = '/profile';
  static const String appointments = '/appointments';
  static const String appointmentForm = '/appointment-form';
  static const String dashboard = '/dashboard'; // ✅ NUEVO

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      
      case home:
        return MaterialPageRoute(builder: (_) => const HomePage());
      
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfilePage());
      
      case appointments:
        return MaterialPageRoute(builder: (_) => const AppointmentsPage());
      
      case appointmentForm:
        return MaterialPageRoute(builder: (_) => const AppointmentFormPage());
      
      // ✅ NUEVO: Ruta del Dashboard con BlocProvider
      case dashboard:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => DashboardBloc(),
            child: const DashboardPage(),
          ),
        );
      
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}