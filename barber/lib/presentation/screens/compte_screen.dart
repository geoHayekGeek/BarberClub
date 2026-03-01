import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/country_picker_dialog.dart';
import '../providers/auth_providers.dart';
import '../widgets/bottom_nav_bar.dart';

class CompteScreen extends ConsumerWidget {
  const CompteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;
    final theme = Theme.of(context);

    // Initial logic for avatar
    final initials = user?.fullName?.isNotEmpty == true
        ? user!.fullName![0].toUpperCase()
        : 'U';

    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Explicit dark background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Text(
          'MON PROFIL',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 16,
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: user == null
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    // 1. Avatar Section
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1A1A1A),
                        border: Border.all(
                            color: Colors.white24, 
                            width: 2),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    Text(
                      user.fullName ?? 'Utilisateur',
                      style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Membre Barber Club',
                      style: theme.textTheme.labelLarge?.copyWith(
                          color: Colors.white70,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 40),

                    // 2. Info Card
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Mes Informations',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(color: Colors.white)),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      color: Colors.white70),
                                  onPressed: () => _showEditProfileSheet(context, ref, user),
                                ),
                              ],
                            ),
                          ),
                          const Divider(color: Colors.white10),
                          _buildInfoTile(context,
                              icon: Icons.person_outline,
                              title: 'Nom complet',
                              value: user.fullName ?? '-'),
                          _buildInfoTile(context,
                              icon: Icons.email_outlined,
                              title: 'Email',
                              value: user.email),
                          _buildInfoTile(context,
                              icon: Icons.phone_outlined,
                              title: 'Téléphone',
                              value: user.phoneNumber ?? '-'),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 3. Security Card
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.lock_outline, color: Colors.white70),
                        ),
                        title: const Text('Mot de passe',
                            style: TextStyle(color: Colors.white)),
                        trailing: const Icon(Icons.arrow_forward_ios,
                            size: 16, color: Colors.white54),
                        onTap: () => _showChangePasswordSheet(context, ref),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // 4. Logout Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await ref.read(authStateProvider.notifier).logout();
                          if (context.mounted) context.go('/login');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.05),
                          foregroundColor: Colors.redAccent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                                color: Colors.white.withOpacity(0.1)),
                          ),
                        ),
                        icon: const Icon(Icons.logout),
                        label: const Text('Se déconnecter',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }

  Widget _buildInfoTile(BuildContext context,
      {required IconData icon, required String title, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.white38)),
                const SizedBox(height: 2),
                Text(value,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: Colors.white, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- EDIT PROFILE SHEET ---
  void _showEditProfileSheet(BuildContext context, WidgetRef ref, dynamic user) {
    final nameCtrl = TextEditingController(text: user.fullName);
    final emailCtrl = TextEditingController(text: user.email);
    final formKey = GlobalKey<FormState>();

    String completePhoneNumber = user.phoneNumber ?? '';
    
    // Check if the user already has a properly formatted international number
    bool hasInternationalNumber = completePhoneNumber.startsWith('+');

    InputDecoration buildInputDecoration(String labelText) {
      return InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.white54),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white), 
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Modifier le profil',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextFormField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white, 
                decoration: buildInputDecoration('Nom complet'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailCtrl,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                decoration: buildInputDecoration('Email'),
                validator: (v) => v!.contains('@') ? null : 'Email invalide',
              ),
              const SizedBox(height: 16),
              
              // --- INTL PHONE FIELD ---
              IntlPhoneField(
                initialValue: hasInternationalNumber ? completePhoneNumber : null, 
                // Only default to FR if they don't have a valid international number saved
                initialCountryCode: hasInternationalNumber ? null : 'FR',
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                dropdownTextStyle: const TextStyle(color: Colors.white),
                dropdownIcon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                
                // Pushes the flag and country code down to align with the text
                flagsButtonPadding: const EdgeInsets.only(top: 18),
                
                decoration: buildInputDecoration('Téléphone'),
                onChanged: (phone) {
                  completePhoneNumber = phone.completeNumber;
                },
                pickerDialogStyle: PickerDialogStyle(
                  backgroundColor: const Color(0xFF1A1A1A),
                  countryCodeStyle: const TextStyle(color: Colors.white),
                  countryNameStyle: const TextStyle(color: Colors.white),
                  searchFieldInputDecoration: InputDecoration(
                    hintText: 'Rechercher un pays',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white10),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: Consumer(
                  builder: (context, ref, _) {
                    return ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        try {
                          Navigator.pop(ctx); 
                          await ref.read(authStateProvider.notifier).updateProfile(
                                fullName: nameCtrl.text,
                                email: emailCtrl.text,
                                phoneNumber: completePhoneNumber, 
                              );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Profil mis à jour')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white12,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Enregistrer'),
                    );
                  }
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- CHANGE PASSWORD SHEET ---
  void _showChangePasswordSheet(BuildContext context, WidgetRef ref) {
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    bool isLoading = false;
    String? localError;

    InputDecoration buildInputDecoration(String labelText) {
      return InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.white54),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white), 
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Changer le mot de passe',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),

                  TextFormField(
                    controller: oldPassCtrl,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white, 
                    decoration: buildInputDecoration('Ancien mot de passe'),
                    validator: (v) => v!.isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: newPassCtrl,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: buildInputDecoration('Nouveau mot de passe'),
                    validator: (v) =>
                        v!.length < 8 ? 'Min 8 caractères' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: confirmPassCtrl,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: buildInputDecoration('Confirmer le mot de passe'),
                    validator: (v) => v != newPassCtrl.text
                        ? 'Les mots de passe ne correspondent pas'
                        : null,
                  ),
                  const SizedBox(height: 24),

                  if (localError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        localError!,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;

                              setModalState(() {
                                isLoading = true;
                                localError = null;
                              });

                              try {
                                await ref
                                    .read(authStateProvider.notifier)
                                    .changePassword(
                                      oldPassword: oldPassCtrl.text,
                                      newPassword: newPassCtrl.text,
                                    );

                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Mot de passe modifié avec succès'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (ctx.mounted) {
                                  String cleanMessage = e.toString().replaceAll('Exception:', '').trim();
                                  setModalState(() {
                                    isLoading = false;
                                    localError = cleanMessage;
                                  });
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white12, 
                        foregroundColor: Colors.white,
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Confirmer'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}