import 'package:flutter/material.dart';

import '../../../shared/widgets/app_scaffold.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Perfil',
      child: Center(child: Text('Vander Borges')),
    );
  }
}
