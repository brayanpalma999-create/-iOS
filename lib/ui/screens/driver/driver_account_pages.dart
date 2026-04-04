import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";
import "package:provider/provider.dart";

import "../../../providers/auth_provider.dart";
import "../../../providers/chat_provider.dart";
import "../../../providers/driver_provider.dart";
import "../../../providers/map_ui_provider.dart";
import "../../../providers/trip_provider.dart";
import "../../../routes.dart";
import "../../../utils/app_text.dart";
import "../../widgets/account_avatar.dart";
import "../../widgets/custom_button.dart";
import "../../widgets/custom_input.dart";
import "../../widgets/group_inbox_thread.dart";

const String _vehicleOtherKey = "Other";

const Map<String, List<String>> _vehicleModelsByMake = {
  "Toyota": ["Corolla", "Camry", "Prius", "RAV4", "Highlander", "Sienna"],
  "Honda": ["Civic", "Accord", "CR-V", "Pilot", "Odyssey", "Fit"],
  "Nissan": ["Versa", "Sentra", "Altima", "Rogue", "Murano", "Pathfinder"],
  "Hyundai": ["Accent", "Elantra", "Sonata", "Tucson", "Santa Fe", "Palisade"],
  "Kia": ["Rio", "Forte", "K5", "Soul", "Sportage", "Telluride"],
  "Chevrolet": ["Spark", "Malibu", "Cruze", "Trax", "Equinox", "Tahoe"],
  "Ford": ["Focus", "Fusion", "Escape", "Explorer", "Edge", "Maverick"],
  "Tesla": ["Model 3", "Model Y", "Model S", "Model X"],
  "Mazda": ["Mazda3", "Mazda6", "CX-3", "CX-5", "CX-9"],
  "Volkswagen": ["Jetta", "Passat", "Taos", "Tiguan", "Atlas"],
  _vehicleOtherKey: [],
};

const List<String> _vehicleColors = [
  "Negro",
  "Blanco",
  "Gris",
  "Plata",
  "Azul",
  "Rojo",
  "Verde",
  "Cafe",
  "Beige",
  "Dorado",
];

class DriverProfileSettingsPage extends StatefulWidget {
  const DriverProfileSettingsPage({super.key});

  @override
  State<DriverProfileSettingsPage> createState() =>
      _DriverProfileSettingsPageState();
}

class _DriverProfileSettingsPageState extends State<DriverProfileSettingsPage> {
  final _displayNameCtrl = TextEditingController();
  final _legalNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _governmentIdCtrl = TextEditingController();
  final _vehiclePlateCtrl = TextEditingController();
  final _vehicleOtherMakeCtrl = TextEditingController();
  final _vehicleOtherModelCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _seeded = false;
  bool _updatingAvatar = false;
  String? _vehicleMake;
  String? _vehicleModel;
  String? _vehicleColor;
  String? _vehicleYear;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    final user = context.read<AuthProvider>().user;
    _displayNameCtrl.text = user?.name ?? "";
    _legalNameCtrl.text = user?.legalName ?? "";
    _emailCtrl.text = user?.email ?? "";
    _phoneCtrl.text = user?.phoneNumber ?? "";
    _addressCtrl.text = user?.address ?? "";
    _governmentIdCtrl.text = user?.governmentId ?? "";
    _vehiclePlateCtrl.text = user?.vehiclePlate ?? "";
    _vehicleMake = _safeVehicleMake(user?.vehicleMake);
    _vehicleOtherMakeCtrl.text =
        _vehicleMake == _vehicleOtherKey ? (user?.vehicleMake ?? "") : "";
    _vehicleModel = _safeVehicleModel(_vehicleMake, user?.vehicleModel);
    _vehicleOtherModelCtrl.text =
        _vehicleModel == _vehicleOtherKey ? (user?.vehicleModel ?? "") : "";
    _vehicleColor = _safeVehicleColor(user?.vehicleColor);
    _vehicleYear = _safeVehicleYear(user?.vehicleYear);
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _legalNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _governmentIdCtrl.dispose();
    _vehiclePlateCtrl.dispose();
    _vehicleOtherMakeCtrl.dispose();
    _vehicleOtherModelCtrl.dispose();
    super.dispose();
  }

  List<String> get _vehicleYears {
    final currentYear = DateTime.now().year + 1;
    return List<String>.generate(
      currentYear - 1999,
      (index) => (currentYear - index).toString(),
    );
  }

  String? _safeVehicleMake(String? value) {
    final clean = value?.trim();
    if (clean == null || clean.isEmpty) return null;
    if (clean == "Otro") return _vehicleOtherKey;
    return _vehicleModelsByMake.containsKey(clean) ? clean : _vehicleOtherKey;
  }

  String? _safeVehicleModel(String? make, String? value) {
    final clean = value?.trim();
    if (make == null || clean == null || clean.isEmpty) return null;
    if (clean == "Otro") return _vehicleOtherKey;
    if (make == _vehicleOtherKey) return _vehicleOtherKey;
    final models = _vehicleModelsByMake[make] ?? const <String>[];
    return models.contains(clean) ? clean : _vehicleOtherKey;
  }

  String? _safeVehicleColor(String? value) {
    final clean = value?.trim();
    if (clean == null || clean.isEmpty) return null;
    return _vehicleColors.contains(clean) ? clean : null;
  }

  String? _safeVehicleYear(String? value) {
    final clean = value?.trim();
    if (clean == null || clean.isEmpty) return null;
    return _vehicleYears.contains(clean) ? clean : null;
  }

  List<String> _vehicleModelOptionsFor(String? make) {
    if (make == null) return const <String>[];
    if (make == _vehicleOtherKey) return const <String>[_vehicleOtherKey];
    final models = List<String>.from(_vehicleModelsByMake[make] ?? const <String>[]);
    if (!models.contains(_vehicleOtherKey)) {
      models.add(_vehicleOtherKey);
    }
    return models;
  }

  String? get _resolvedVehicleMake {
    if (_vehicleMake == null) return null;
    if (_vehicleMake == _vehicleOtherKey) {
      return _vehicleOtherMakeCtrl.text.trim().isEmpty
          ? null
          : _vehicleOtherMakeCtrl.text.trim();
    }
    return _vehicleMake;
  }

  String? get _resolvedVehicleModel {
    if (_vehicleModel == null) return null;
    if (_vehicleModel == _vehicleOtherKey) {
      return _vehicleOtherModelCtrl.text.trim().isEmpty
          ? null
          : _vehicleOtherModelCtrl.text.trim();
    }
    return _vehicleModel;
  }

  Future<void> _pickAvatar() async {
    if (_updatingAvatar) return;
    setState(() => _updatingAvatar = true);
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 74,
        maxWidth: 1200,
      );
      if (file == null || !mounted) return;
      context.read<AuthProvider>().updateAvatarPath(file.path);
    } finally {
      if (mounted) {
        setState(() => _updatingAvatar = false);
      }
    }
  }

  void _save() {
    String t({required String es, required String en}) =>
        context.txt(es: es, en: en);
    context.read<AuthProvider>().updateProfile(
      displayName: _displayNameCtrl.text,
      legalName: _legalNameCtrl.text,
      email: _emailCtrl.text,
      phoneNumber: _phoneCtrl.text,
      address: _addressCtrl.text,
      governmentId: _governmentIdCtrl.text,
      vehicleMake: _resolvedVehicleMake,
      vehicleModel: _resolvedVehicleModel,
      vehicleColor: _vehicleColor,
      vehiclePlate: _vehiclePlateCtrl.text,
      vehicleYear: _vehicleYear,
    );
    final auth = context.read<AuthProvider>();
    final updatedUser = auth.user;
    if (updatedUser != null) {
      context.read<DriverProvider>().syncProfileFromUser(updatedUser);
    } else {
      context.read<DriverProvider>().updateDisplayName(_displayNameCtrl.text);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t(es: "Perfil actualizado", en: "Profile updated")),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String t({required String es, required String en}) =>
        context.txt(es: es, en: en);
    final user = context.watch<AuthProvider>().user;

    return _PageFrame(
      title: t(es: "Perfil", en: "Profile"),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          EditableAvatarCard(
            title: t(es: "Foto de perfil", en: "Profile photo"),
            subtitle: t(
              es: "Actualiza la imagen principal del driver.",
              en: "Update the main image of the driver account.",
            ),
            name: user?.name ?? t(es: "Driver", en: "Driver"),
            avatarPath: user?.avatarPath,
            busy: _updatingAvatar,
            onPick: _pickAvatar,
            onRemove: () => context.read<AuthProvider>().updateAvatarPath(null),
          ),
          const SizedBox(height: 12),
          CustomInput(
            controller: _displayNameCtrl,
            hint: t(es: "Nombre visible", en: "Display name"),
            prefixIcon: Icons.badge_outlined,
          ),
          const SizedBox(height: 10),
          CustomInput(
            controller: _legalNameCtrl,
            hint: t(es: "Nombre legal completo", en: "Full legal name"),
            prefixIcon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 10),
          CustomInput(
            controller: _emailCtrl,
            hint: t(es: "Correo electronico", en: "Email"),
            prefixIcon: Icons.alternate_email_rounded,
          ),
          const SizedBox(height: 10),
          CustomInput(
            controller: _phoneCtrl,
            hint: t(es: "Telefono", en: "Phone"),
            prefixIcon: Icons.phone_outlined,
          ),
          const SizedBox(height: 10),
          CustomInput(
            controller: _addressCtrl,
            hint: t(es: "Direccion", en: "Address"),
            prefixIcon: Icons.place_outlined,
          ),
          const SizedBox(height: 10),
          CustomInput(
            controller: _governmentIdCtrl,
            hint: t(es: "Identificacion", en: "ID"),
            prefixIcon: Icons.credit_card_outlined,
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF101214),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x22FFFFFF)),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
              ),
              child: ExpansionTile(
                initiallyExpanded: true,
                leading: const Icon(Icons.directions_car_filled_rounded),
                title: Text(
                  t(es: "Datos del vehiculo", en: "Vehicle details"),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  t(
                    es: "Marca, modelo, color, placas y ano del vehiculo",
                    en: "Make, model, color, plate, and vehicle year",
                  ),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                children: [
                  DropdownButtonFormField<String>(
                    key: ValueKey<String?>("vehicle-make-$_vehicleMake"),
                    initialValue: _vehicleMake,
                    dropdownColor: const Color(0xFF111315),
                    decoration: InputDecoration(
                      labelText: t(es: "Marca", en: "Make"),
                      prefixIcon: const Icon(Icons.factory_outlined),
                    ),
                    items: _vehicleModelsByMake.keys
                        .map(
                          (make) => DropdownMenuItem<String>(
                            value: make,
                            child: Text(
                              make == _vehicleOtherKey
                                  ? t(es: "Other", en: "Other")
                                  : make,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _vehicleMake = value;
                        if (value == _vehicleOtherKey) {
                          _vehicleModel = _vehicleOtherKey;
                        } else {
                          final models = _vehicleModelOptionsFor(value);
                          if (!models.contains(_vehicleModel)) {
                            _vehicleModel = null;
                          }
                        }
                        if (value != _vehicleOtherKey) {
                          _vehicleOtherMakeCtrl.clear();
                        }
                        if (_vehicleModel != _vehicleOtherKey) {
                          _vehicleOtherModelCtrl.clear();
                        }
                      });
                    },
                  ),
                  if (_vehicleMake == _vehicleOtherKey) ...[
                    const SizedBox(height: 10),
                    CustomInput(
                      controller: _vehicleOtherMakeCtrl,
                      hint: t(es: "Escribe la marca", en: "Enter make"),
                      prefixIcon: Icons.edit_rounded,
                    ),
                  ],
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String?>("vehicle-model-$_vehicleMake-$_vehicleModel"),
                    initialValue: _vehicleModel,
                    dropdownColor: const Color(0xFF111315),
                    decoration: InputDecoration(
                      labelText: t(es: "Modelo", en: "Model"),
                      prefixIcon: const Icon(Icons.local_taxi_outlined),
                    ),
                    items: _vehicleModelOptionsFor(_vehicleMake)
                        .map(
                          (model) => DropdownMenuItem<String>(
                            value: model,
                            child: Text(
                              model == _vehicleOtherKey
                                  ? t(es: "Other", en: "Other")
                                  : model,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _vehicleMake == null
                        ? null
                        : (value) => setState(() {
                            _vehicleModel = value;
                            if (value != _vehicleOtherKey) {
                              _vehicleOtherModelCtrl.clear();
                            }
                          }),
                  ),
                  if (_vehicleModel == _vehicleOtherKey) ...[
                    const SizedBox(height: 10),
                    CustomInput(
                      controller: _vehicleOtherModelCtrl,
                      hint: t(es: "Escribe el modelo", en: "Enter model"),
                      prefixIcon: Icons.edit_rounded,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey<String?>("vehicle-color-$_vehicleColor"),
                          initialValue: _vehicleColor,
                          dropdownColor: const Color(0xFF111315),
                          decoration: InputDecoration(
                            labelText: t(es: "Color", en: "Color"),
                            prefixIcon: const Icon(Icons.palette_outlined),
                          ),
                          items: _vehicleColors
                              .map(
                                (color) => DropdownMenuItem<String>(
                                  value: color,
                                  child: Text(color),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _vehicleColor = value),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey<String?>("vehicle-year-$_vehicleYear"),
                          initialValue: _vehicleYear,
                          dropdownColor: const Color(0xFF111315),
                          decoration: InputDecoration(
                            labelText: t(es: "Ano", en: "Year"),
                            prefixIcon: const Icon(Icons.event_outlined),
                          ),
                          items: _vehicleYears
                              .map(
                                (year) => DropdownMenuItem<String>(
                                  value: year,
                                  child: Text(year),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _vehicleYear = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  CustomInput(
                    controller: _vehiclePlateCtrl,
                    hint: t(es: "Placas", en: "Plate number"),
                    prefixIcon: Icons.pin_outlined,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          CustomButton(
            label: t(es: "Guardar cambios", en: "Save changes"),
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

class DriverPreferencesSettingsPage extends StatefulWidget {
  const DriverPreferencesSettingsPage({super.key});

  @override
  State<DriverPreferencesSettingsPage> createState() =>
      _DriverPreferencesSettingsPageState();
}

class _DriverPreferencesSettingsPageState
    extends State<DriverPreferencesSettingsPage> {
  bool _seeded = false;
  late MapThemeMode _draftTheme;
  late String _draftLanguage;
  late bool _draftVisible;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    final driver = context.read<DriverProvider>().self;
    final storedTheme = context.read<AuthProvider>().user?.mapThemeMode ?? "";
    _draftTheme = switch (storedTheme) {
      "dark" => MapThemeMode.dark,
      "satellite" => MapThemeMode.satellite,
      _ => context.read<MapUiProvider>().themeMode,
    };
    _draftLanguage = context.read<AuthProvider>().user?.languageCode ?? "es";
    _draftVisible = (driver?.status ?? "").toLowerCase().startsWith(
      "disponible",
    );
  }

  @override
  Widget build(BuildContext context) {
    String t({required String es, required String en}) =>
        context.txt(es: es, en: en);
    final liveTheme = context.watch<MapUiProvider>().themeMode;
    final liveLanguage =
        context.watch<AuthProvider>().user?.languageCode ?? "es";
    final liveDriver = context.watch<DriverProvider>().self;
    final liveVisible = (liveDriver?.status ?? "").toLowerCase().startsWith(
      "disponible",
    );
    final hasChanges =
        _draftTheme != liveTheme ||
        _draftLanguage != liveLanguage ||
        _draftVisible != liveVisible;

    return _PageFrame(
      title: t(es: "Preferencias", en: "Preferences"),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle(t(es: "Tema del mapa", en: "Map theme")),
          const SizedBox(height: 10),
          SegmentedButton<MapThemeMode>(
            segments: [
              ButtonSegment<MapThemeMode>(
                value: MapThemeMode.flow,
                icon: const Icon(Icons.map_rounded),
                label: const Text("AtoB Flow"),
              ),
              ButtonSegment<MapThemeMode>(
                value: MapThemeMode.dark,
                icon: const Icon(Icons.dark_mode_rounded),
                label: Text(t(es: "Oscuro", en: "Dark")),
              ),
              ButtonSegment<MapThemeMode>(
                value: MapThemeMode.satellite,
                icon: const Icon(Icons.satellite_alt_rounded),
                label: Text(t(es: "Satelital", en: "Satellite")),
              ),
            ],
            selected: {_draftTheme},
            onSelectionChanged: (selection) =>
                setState(() => _draftTheme = selection.first),
          ),
          const SizedBox(height: 18),
          _SectionTitle(t(es: "Idioma", en: "Language")),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(value: "es", label: Text("Espanol")),
              ButtonSegment<String>(value: "en", label: Text("English")),
            ],
            selected: {_draftLanguage},
            onSelectionChanged: (selection) =>
                setState(() => _draftLanguage = selection.first),
          ),
          const SizedBox(height: 18),
          _SectionTitle(t(es: "Visibilidad", en: "Visibility")),
          SwitchListTile.adaptive(
            value: _draftVisible,
            contentPadding: EdgeInsets.zero,
            title: Text(
              t(es: "Mostrarme en el mapa", en: "Show me on the map"),
            ),
            subtitle: Text(
              t(
                es: "Controla nuevas asignaciones y disponibilidad",
                en: "Controls new assignments and availability",
              ),
            ),
            onChanged: (value) => setState(() => _draftVisible = value),
          ),
          const SizedBox(height: 12),
          _HintCard(
            text: t(
              es: "El tema del mapa, el idioma y la visibilidad se guardan juntos cuando aplicas los cambios.",
              en: "Map theme, language, and visibility are saved together when you apply the changes.",
            ),
          ),
          const SizedBox(height: 18),
          CustomButton(
            label: t(es: "Aplicar cambios", en: "Apply changes"),
            onPressed: () {
              if (!hasChanges) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      t(
                        es: "No hay cambios pendientes",
                        en: "There are no pending changes",
                      ),
                    ),
                  ),
                );
                return;
              }
              context.read<MapUiProvider>().setThemeMode(_draftTheme);
              context.read<AuthProvider>().setMapThemeMode(
                switch (_draftTheme) {
                  MapThemeMode.dark => "dark",
                  MapThemeMode.satellite => "satellite",
                  MapThemeMode.flow => "flow",
                },
              );
              context.read<AuthProvider>().setLanguageCode(_draftLanguage);
              context.read<DriverProvider>().setOperationalStatus(
                _draftVisible
                    ? "Disponible (Visible)"
                    : "No disponible (Invisible)",
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    t(es: "Preferencias aplicadas", en: "Preferences applied"),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class DriverInboxSettingsPage extends StatelessWidget {
  const DriverInboxSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    String t({required String es, required String en}) =>
        context.txt(es: es, en: en);
    final driver = context.watch<DriverProvider>().self;
    final tripProvider = context.watch<TripProvider>();
    final chat = context.watch<ChatProvider>();
    final driverId = driver?.id;

    return _PageFrame(
      title: t(es: "Inbox", en: "Inbox"),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF101214),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x22FFFFFF)),
                ),
                child: TabBar(
                  tabs: [
                    Tab(
                      text: t(es: "Resumen", en: "Overview"),
                    ),
                    Tab(
                      text: t(es: "Chat", en: "Chat"),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: t(es: "Estado", en: "Status"),
                              value:
                                  driver?.status ??
                                  t(es: "Sin estado", en: "No status"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatCard(
                              label: t(
                                es: "Viajes activos",
                                en: "Active trips",
                              ),
                              value: tripProvider
                                  .totalActiveTrips(driverId: driverId)
                                  .toString(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatCard(
                              label: t(es: "Mensajes", en: "Messages"),
                              value: chat.groupMessageCount.toString(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _HintCard(
                        text: t(
                          es: "Inbox conserva el resumen operativo y ademas agrega mensajeria grupal con fotos entre admin y drivers.",
                          en: "Inbox keeps the operational summary and also adds group photo messaging between admin and drivers.",
                        ),
                      ),
                      const SizedBox(height: 12),
                      _HintCard(
                        text: t(
                          es: "Estado, viajes activos y mensajes siguen visibles porque son utiles para operar sin salir del flujo.",
                          en: "Status, active trips, and messages remain visible because they are useful to operate without leaving the flow.",
                        ),
                      ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      GroupInboxThread(
                        emptyLabel: t(
                          es: "Todavia no hay mensajes en el grupo",
                          en: "There are no group messages yet",
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DriverSecuritySettingsPage extends StatefulWidget {
  const DriverSecuritySettingsPage({super.key});

  @override
  State<DriverSecuritySettingsPage> createState() =>
      _DriverSecuritySettingsPageState();
}

class _DriverSecuritySettingsPageState
    extends State<DriverSecuritySettingsPage> {
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _savePassword() {
    String t({required String es, required String en}) =>
        context.txt(es: es, en: en);
    if (_newPasswordCtrl.text.trim() != _confirmPasswordCtrl.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              es: "La confirmacion no coincide",
              en: "The confirmation does not match",
            ),
          ),
        ),
      );
      return;
    }
    final error = context.read<AuthProvider>().changePassword(
      currentPassword: _currentPasswordCtrl.text,
      newPassword: _newPasswordCtrl.text,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(switch (error) {
          "current_password_mismatch" => t(
            es: "La contrasena actual no coincide",
            en: "The current password does not match",
          ),
          "password_too_short" => t(
            es: "Usa minimo 6 caracteres",
            en: "Use at least 6 characters",
          ),
          _ => t(es: "Contrasena actualizada", en: "Password updated"),
        }),
      ),
    );
    if (error == null) {
      _currentPasswordCtrl.clear();
      _newPasswordCtrl.clear();
      _confirmPasswordCtrl.clear();
    }
  }

  void _deleteLocalAccount() {
    context.read<ChatProvider>().clearSession();
    context.read<AuthProvider>().logout();
    context.read<TripProvider>().clearAll();
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    String t({required String es, required String en}) =>
        context.txt(es: es, en: en);
    final updatedAt = context.watch<AuthProvider>().passwordUpdatedAt;
    final stamp = updatedAt == null
        ? t(
            es: "Aun no hay una actualizacion de contrasena registrada.",
            en: "There is no recorded password update yet.",
          )
        : t(
            es: "Ultima actualizacion: ${updatedAt.day.toString().padLeft(2, "0")}/${updatedAt.month.toString().padLeft(2, "0")}/${updatedAt.year} ${updatedAt.hour.toString().padLeft(2, "0")}:${updatedAt.minute.toString().padLeft(2, "0")}",
            en: "Last update: ${updatedAt.month.toString().padLeft(2, "0")}/${updatedAt.day.toString().padLeft(2, "0")}/${updatedAt.year} ${updatedAt.hour.toString().padLeft(2, "0")}:${updatedAt.minute.toString().padLeft(2, "0")}",
          );

    return _PageFrame(
      title: t(es: "Seguridad", en: "Security"),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HintCard(
            text: t(
              es: "Para cambiar la contrasena se valida primero la actual. Si nunca definiste una, el campo actual puede quedar vacio.",
              en: "To change the password, the current one is checked first. If you have never set one, the current field can stay empty.",
            ),
          ),
          const SizedBox(height: 12),
          CustomInput(
            controller: _currentPasswordCtrl,
            hint: t(es: "Contrasena actual", en: "Current password"),
            obscureText: true,
            prefixIcon: Icons.lock_clock_outlined,
          ),
          const SizedBox(height: 10),
          CustomInput(
            controller: _newPasswordCtrl,
            hint: t(es: "Nueva contrasena", en: "New password"),
            obscureText: true,
            prefixIcon: Icons.lock_outline_rounded,
          ),
          const SizedBox(height: 10),
          CustomInput(
            controller: _confirmPasswordCtrl,
            hint: t(
              es: "Confirmar nueva contrasena",
              en: "Confirm new password",
            ),
            obscureText: true,
            prefixIcon: Icons.verified_user_outlined,
          ),
          const SizedBox(height: 14),
          CustomButton(
            label: t(es: "Guardar contrasena", en: "Save password"),
            onPressed: _savePassword,
          ),
          const SizedBox(height: 12),
          _HintCard(text: stamp),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1012),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x46FF667A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t(es: "Eliminar acceso local", en: "Remove local access"),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFFA6B3),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  t(
                    es: "Esto limpia la sesion local del dispositivo y elimina el acceso actual.",
                    en: "This clears the local device session and removes the current access.",
                  ),
                  style: const TextStyle(color: Colors.white70, height: 1.35),
                ),
                const SizedBox(height: 14),
                CustomButton(
                  label: t(
                    es: "Eliminar cuenta local",
                    en: "Remove local account",
                  ),
                  onPressed: _deleteLocalAccount,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101214),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white70)),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101214),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
