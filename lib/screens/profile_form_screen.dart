import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_exception.dart';
import '../api/models/customer.dart';
import '../state/auth_provider.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import '../widgets/profile_photo.dart';

/// Edad mínima que exige el backend.
const _minimumAge = 13;

/// Formulario de datos personales.
///
/// Se usa en dos modos:
/// - **Obligatorio** (`mandatory: true`): el perfil está incompleto y la app
///   no deja pasar hasta llenarlo. Sin botón de regreso.
/// - **Edición**: el socio entra desde el menú a cambiar sus datos.
class ProfileFormScreen extends ConsumerStatefulWidget {
  final bool mandatory;

  const ProfileFormScreen({super.key, this.mandatory = false});

  @override
  ConsumerState<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends ConsumerState<ProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();

  DateTime? _dateOfBirth;
  bool _submitting = false;
  bool _uploadingPhoto = false;
  String? _error;
  bool _prefilled = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Rellena una sola vez con lo que ya tiene el socio. Si nunca completó el
  /// perfil, `name` del POS suele traer el nombre entero: lo partimos como
  /// punto de partida para que no escriba todo de cero.
  void _prefill(Customer customer) {
    if (_prefilled) return;
    _prefilled = true;

    final parts = customer.name.trim().split(RegExp(r'\s+'));
    _firstNameController.text = customer.firstName ??
        (parts.isNotEmpty ? parts.first : '');
    _lastNameController.text = customer.lastName ??
        (parts.length > 1 ? parts.sublist(1).join(' ') : '');
    _emailController.text = customer.email ?? '';
    _dateOfBirth = customer.dateOfBirth;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final latest = DateTime(now.year - _minimumAge, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: latest,
      helpText: 'Fecha de nacimiento',
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      // Reduce el peso antes de subir: el backend rechaza arriba de 5 MB.
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final bytes = await picked.readAsBytes();
      await ref.read(customerApiProvider).uploadPhoto(
            bytes: bytes,
            filename: picked.name,
          );
      await ref.read(authProvider.notifier).refreshProfile();
      ref.invalidate(profileProvider);
    } on ApiException catch (error) {
      if (mounted) _toast(error.message);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _uploadingPhoto = true);
    try {
      await ref.read(customerApiProvider).deletePhoto();
      await ref.read(authProvider.notifier).refreshProfile();
      ref.invalidate(profileProvider);
    } on ApiException catch (error) {
      if (mounted) _toast(error.message);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _photoOptions(Customer customer) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar una foto'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickPhoto(ImageSource.camera);
              },
            ),
            if (customer.photoUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: CelfixColors.danger),
                title: const Text('Quitar foto',
                    style: TextStyle(color: CelfixColors.danger)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _removePhoto();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _toast(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dateOfBirth == null) {
      setState(() => _error = 'La fecha de nacimiento es obligatoria.');
      return;
    }
    FocusScope.of(context).unfocus();

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final email = _emailController.text.trim();
      final customer = await ref.read(customerApiProvider).updateProfile(
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            dateOfBirth: _dateOfBirth!,
            email: email.isEmpty ? null : email,
          );
      ref.read(authProvider.notifier).setCustomer(customer);
      ref.invalidate(profileProvider);

      if (!mounted) return;
      _toast('Datos actualizados.');
      // En modo obligatorio no hay a dónde regresar: el guard del router
      // deja pasar solo cuando profile_complete pasa a true.
      if (!widget.mandatory && context.canPop()) context.pop();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = ref.watch(authProvider).customer;
    if (customer == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _prefill(customer);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.mandatory,
        title: Text(widget.mandatory ? 'Completa tu perfil' : 'Mis datos'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.mandatory)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 20),
                        child: Text(
                          'Necesitamos estos datos para activar tu membresía. '
                          'Solo se piden una vez.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: CelfixColors.inkSoft),
                        ),
                      ),
                    Center(
                      child: _uploadingPhoto
                          ? const SizedBox(
                              height: 96,
                              width: 96,
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : ProfilePhoto(
                              customer: customer,
                              onEdit: () => _photoOptions(customer),
                            ),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _firstNameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Nombre(s)',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'El nombre es obligatorio.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastNameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Apellidos',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Los apellidos son obligatorios.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius:
                          BorderRadius.circular(CelfixShape.buttonRadius),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Fecha de nacimiento',
                          prefixIcon: Icon(Icons.cake_outlined),
                        ),
                        child: Text(
                          _dateOfBirth == null
                              ? 'Selecciona una fecha'
                              : Fmt.longDate(_dateOfBirth),
                          style: TextStyle(
                            color: _dateOfBirth == null
                                ? CelfixColors.inkSoft
                                : CelfixColors.ink,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Correo (opcional)',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (value) {
                        final email = (value ?? '').trim();
                        if (email.isEmpty) return null;
                        final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(email);
                        return valid
                            ? null
                            : 'El correo electrónico no es válido.';
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDECEC),
                          borderRadius:
                              BorderRadius.circular(CelfixShape.cardRadius),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: CelfixColors.danger),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(widget.mandatory ? 'CONTINUAR' : 'GUARDAR'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
