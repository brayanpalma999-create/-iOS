import "dart:async";

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

class AdminProfileSettingsPage extends StatefulWidget {
  const AdminProfileSettingsPage({super.key});

  @override
  State<AdminProfileSettingsPage> createState() =>
      _AdminProfileSettingsPageState();
}

class _AdminProfileSettingsPageState extends State<AdminProfileSettingsPage> {
  final _displayNameCtrl = TextEditingController();
  final _legalNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _governmentIdCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _seeded = false;
  bool _updatingAvatar = false;

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
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _legalNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _governmentIdCtrl.dispose();
    super.dispose();
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
    context.read<AuthProvider>().updateProfile(
      displayName: _displayNameCtrl.text,
      legalName: _legalNameCtrl.text,
      email: _emailCtrl.text,
      phoneNumber: _phoneCtrl.text,
      address: _addressCtrl.text,
      governmentId: _governmentIdCtrl.text,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.txt(es: "Perfil actualizado", en: "Profile updated"),
        ),
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
              es: "Actualiza la imagen principal de tu cuenta admin.",
              en: "Update the main image of your admin account.",
            ),
            name: user?.name ?? t(es: "Admin", en: "Admin"),
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

class AdminDriverAccessPage extends StatefulWidget {
  const AdminDriverAccessPage({super.key});

  @override
  State<AdminDriverAccessPage> createState() => _AdminDriverAccessPageState();
}

class _AdminDriverAccessPageState extends State<AdminDriverAccessPage> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _governmentIdCtrl = TextEditingController();
  final _accessCodeCtrl = TextEditingController();
  String? _editingId;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _governmentIdCtrl.dispose();
    _accessCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    String t({required String es, required String en}) =>
        context.txt(es: es, en: en);
    if (_nameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _accessCodeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              es: "Nombre, correo y codigo de acceso son obligatorios",
              en: "Name, email, and access code are required",
            ),
          ),
        ),
      );
      return;
    }

    await context.read<AuthProvider>().saveAuthorizedDriver(
      id: _editingId,
      displayName: _nameCtrl.text,
      email: _emailCtrl.text,
      phoneNumber: _phoneCtrl.text,
      governmentId: _governmentIdCtrl.text,
      accessCode: _accessCodeCtrl.text,
    );
    if (!mounted) return;
    _clearForm();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t(
            es: "Acceso del driver guardado",
            en: "Driver access saved",
          ),
        ),
      ),
    );
  }

  Future<void> _toggle(DriverAccessProfile profile, bool value) async {
    await context.read<AuthProvider>().setAuthorizedDriverActive(
      profile.id,
      value,
    );
  }

  Future<void> _remove(DriverAccessProfile profile) async {
    await context.read<AuthProvider>().removeAuthorizedDriver(profile.id);
    if (!mounted) return;
    if (_editingId == profile.id) {
      _clearForm();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.txt(
            es: "Acceso eliminado",
            en: "Access removed",
          ),
        ),
      ),
    );
  }

  void _edit(DriverAccessProfile profile) {
    setState(() {
      _editingId = profile.id;
      _nameCtrl.text = profile.displayName;
      _emailCtrl.text = profile.email;
      _phoneCtrl.text = profile.phoneNumber ?? "";
      _governmentIdCtrl.text = profile.governmentId ?? "";
      _accessCodeCtrl.text = profile.accessCode;
    });
  }

  void _clearForm() {
    setState(() {
      _editingId = null;
      _nameCtrl.clear();
      _emailCtrl.clear();
      _phoneCtrl.clear();
      _governmentIdCtrl.clear();
      _accessCodeCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    String t({required String es, required String en}) =>
        context.txt(es: es, en: en);
    final auth = context.watch<AuthProvider>();
    final drivers = auth.authorizedDrivers;

    return _PageFrame(
      title: t(es: "Acceso de drivers", en: "Driver access"),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HintCard(
            text: t(
              es: "Aqui autorizas nuevos drivers por invitacion privada con nombre legal, correo, telefono, identificacion y codigo de acceso.",
              en: "Here you authorize new drivers through private invitations with legal name, email, phone, ID, and access code.",
            ),
          ),
          const SizedBox(height: 14),
          _SectionTitle(
            _editingId == null
                ? t(es: "Nuevo acceso", en: "New access")
                : t(es: "Editar acceso", en: "Edit access"),
          ),
          const SizedBox(height: 10),
          CustomInput(
            controller: _nameCtrl,
            hint: t(es: "Nombre del driver", en: "Driver name"),
            prefixIcon: Icons.badge_outlined,
          ),
          const SizedBox(height: 10),
          CustomInput(
            controller: _emailCtrl,
            hint: t(es: "Correo opcional", en: "Optional email"),
            prefixIcon: Icons.alternate_email_rounded,
          ),
          const SizedBox(height: 10),
          CustomInput(
            controller: _phoneCtrl,
            hint: t(es: "Telefono opcional", en: "Optional phone"),
            prefixIcon: Icons.phone_outlined,
          ),
          const SizedBox(height: 10),
          CustomInput(
            controller: _governmentIdCtrl,
            hint: t(es: "Identificacion", en: "Government ID"),
            prefixIcon: Icons.credit_card_outlined,
          ),
          const SizedBox(height: 10),
          CustomInput(
            controller: _accessCodeCtrl,
            hint: t(es: "Codigo de acceso", en: "Access code"),
            obscureText: true,
            prefixIcon: Icons.lock_outline_rounded,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  label: _editingId == null
                      ? t(es: "Guardar acceso", en: "Save access")
                      : t(es: "Actualizar acceso", en: "Update access"),
                  onPressed: _save,
                ),
              ),
              if (_editingId != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: CustomButton(
                    inverted: true,
                    label: t(es: "Cancelar", en: "Cancel"),
                    onPressed: _clearForm,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          _SectionTitle(t(es: "Drivers autorizados", en: "Authorized drivers")),
          const SizedBox(height: 10),
          if (drivers.isEmpty)
            _HintCard(
            text: t(
                es: "Aun no hay drivers autorizados. El acceso de driver solo se habilita cuando el admin crea una invitacion activa.",
                en: "There are no authorized drivers yet. Driver access is only enabled when the admin creates an active invitation.",
              ),
            )
          else
            ...drivers.map(
              (profile) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF101214),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0x22FFFFFF)),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(
                          14,
                          10,
                          10,
                          0,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: profile.isActive
                              ? const Color(0x1F3DDC97)
                              : const Color(0x22FF667A),
                          child: Text(
                            profile.displayName.characters.first.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: profile.isActive
                                  ? const Color(0xFF8DF5C6)
                                  : const Color(0xFFFFA6B3),
                            ),
                          ),
                        ),
                        title: Text(
                          profile.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          [
                            profile.email,
                            if ((profile.phoneNumber ?? "").isNotEmpty)
                              profile.phoneNumber!,
                            if ((profile.governmentId ?? "").isNotEmpty)
                              profile.governmentId!,
                            "${t(es: "Codigo", en: "Code")}: ${profile.maskedAccessCode}",
                          ].join(" • "),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                          ),
                        ),
                        trailing: Switch(
                          value: profile.isActive,
                          onChanged: (value) => _toggle(profile, value),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: CustomButton(
                                inverted: true,
                                label: t(es: "Editar", en: "Edit"),
                                onPressed: () => _edit(profile),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CustomButton(
                                label: t(es: "Eliminar", en: "Remove"),
                                onPressed: () => _remove(profile),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AdminRecordsPage extends StatefulWidget {
  const AdminRecordsPage({super.key});

  @override
  State<AdminRecordsPage> createState() => _AdminRecordsPageState();
}

class _AdminRecordsPageState extends State<AdminRecordsPage> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthProvider>().refreshAuthorizedDrivers();
      context.read<AuthProvider>().warmAuthorizedDriverRecords();
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      context.read<AuthProvider>().refreshAuthorizedDrivers();
      context.read<AuthProvider>().warmAuthorizedDriverRecords();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String t({required String es, required String en}) =>
        context.txt(es: es, en: en);
    final auth = context.watch<AuthProvider>();
    final allDrivers = auth.driverRecords.toList()
      ..sort(
        (a, b) => a.user.legalName.toLowerCase().compareTo(
          b.user.legalName.toLowerCase(),
        ),
      );
    final validDrivers = allDrivers
        .where((record) => record.profile.isActive && record.profile.isActivated)
        .toList();
    final activeCount =
        allDrivers.where((record) => record.profile.isActive).length;
    final pendingCount =
        allDrivers.where((record) => record.profile.activationPending).length;

    return _PageFrame(
      title: t(es: "Records", en: "Records"),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HintCard(
            text: t(
              es: "Aqui se concentra el record operativo de drivers con credenciales vigentes. Los accesos se crean desde el panel Acceso y aqui queda el historial valido y activo.",
              en: "This is the operational record for drivers with valid credentials. Access is created from the Access panel and the valid active roster lives here.",
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: t(es: "Autorizados", en: "Authorized"),
                  value: "$activeCount",
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: t(es: "Vigentes", en: "Valid"),
                  value: "${validDrivers.length}",
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: t(es: "Pendientes", en: "Pending"),
                  value: "$pendingCount",
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionTitle(
            t(
              es: "Base completa de drivers",
              en: "Full driver database",
            ),
          ),
          const SizedBox(height: 10),
          if (allDrivers.isEmpty)
            _HintCard(
              text: t(
                es: "Todavia no hay drivers registrados para mostrar en records.",
                en: "There are no registered drivers to show in records yet.",
              ),
            )
          else
            ...allDrivers.map(
              (record) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AdminDriverRecordPage(record: record),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF101214),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0x22FFFFFF)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0x1F3DDC97),
                          child: Text(
                            record.user.legalName.isEmpty
                                ? "D"
                                : record.user.legalName.characters.first.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF8DF5C6),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                record.user.legalName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.6,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                [
                                  record.user.email,
                                  if ((record.user.vehicleMake ?? "").trim().isNotEmpty)
                                    "${record.user.vehicleMake} ${record.user.vehicleModel ?? ""}".trim(),
                                ].join(" • "),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _StatusBadge(record: record),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

}

class AdminDriverRecordPage extends StatelessWidget {
  const AdminDriverRecordPage({super.key, required this.record});

  final DriverRecordData record;

  @override
  Widget build(BuildContext context) {
    String t({required String es, required String en}) =>
        context.txt(es: es, en: en);
    final liveRecord = context
            .watch<AuthProvider>()
            .driverRecords
            .where((item) => item.profile.id == record.profile.id)
            .cast<DriverRecordData?>()
            .firstWhere((item) => item != null, orElse: () => null) ??
        record;
    final user = liveRecord.user;
    final profile = liveRecord.profile;

    return _PageFrame(
      title: t(es: "Ficha del driver", en: "Driver record"),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF101214),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x22FFFFFF)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0x1F3DDC97),
                  child: Text(
                    user.legalName.isEmpty
                        ? "D"
                        : user.legalName.characters.first.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF8DF5C6),
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.legalName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatusBadge(record: record, large: true)),
              const SizedBox(width: 10),
              Expanded(
                child: CustomButton(
                  label: t(es: "Editar record", en: "Edit record"),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AdminDriverRecordEditPage(record: liveRecord),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _HintCard(
            text: t(
              es: "Aqui esta la base de datos completa del conductor. Puedes revisar toda su informacion y editarla cuando sea necesario.",
              en: "This is the full driver database record. You can review all information and edit it whenever needed.",
            ),
          ),
          const SizedBox(height: 14),
          _SectionTitle(t(es: "Datos personales", en: "Personal data")),
          const SizedBox(height: 10),
          _RecordPanel(
            children: [
              _RecordLine(label: t(es: "Nombre visible", en: "Display name"), value: user.name),
              _RecordLine(label: t(es: "Nombre legal", en: "Legal name"), value: user.legalName),
              _RecordLine(label: t(es: "Correo", en: "Email"), value: user.email),
              _RecordLine(
                label: t(es: "Telefono", en: "Phone"),
                value: user.phoneNumber.trim().isEmpty
                    ? t(es: "No registrado", en: "Not set")
                    : user.phoneNumber,
              ),
              _RecordLine(
                label: t(es: "Direccion", en: "Address"),
                value: user.address.trim().isEmpty
                    ? t(es: "No registrada", en: "Not set")
                    : user.address,
              ),
              _RecordLine(
                label: t(es: "Identificacion", en: "Government ID"),
                value: user.governmentId.trim().isEmpty
                    ? t(es: "No registrada", en: "Not set")
                    : user.governmentId,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SectionTitle(t(es: "Vehiculo", en: "Vehicle")),
          const SizedBox(height: 10),
          _RecordPanel(
            children: [
              _RecordLine(
                label: t(es: "Marca", en: "Make"),
                value: (user.vehicleMake ?? "").trim().isEmpty
                    ? t(es: "No registrada", en: "Not set")
                    : user.vehicleMake!,
              ),
              _RecordLine(
                label: t(es: "Modelo", en: "Model"),
                value: (user.vehicleModel ?? "").trim().isEmpty
                    ? t(es: "No registrado", en: "Not set")
                    : user.vehicleModel!,
              ),
              _RecordLine(
                label: t(es: "Color", en: "Color"),
                value: (user.vehicleColor ?? "").trim().isEmpty
                    ? t(es: "No registrado", en: "Not set")
                    : user.vehicleColor!,
              ),
              _RecordLine(
                label: t(es: "Placas", en: "Plate"),
                value: (user.vehiclePlate ?? "").trim().isEmpty
                    ? t(es: "No registradas", en: "Not set")
                    : user.vehiclePlate!,
              ),
              _RecordLine(
                label: t(es: "Ano", en: "Year"),
                value: (user.vehicleYear ?? "").trim().isEmpty
                    ? t(es: "No registrado", en: "Not set")
                    : user.vehicleYear!,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SectionTitle(t(es: "Acceso", en: "Access")),
          const SizedBox(height: 10),
          _RecordPanel(
            children: [
              _RecordLine(
                label: t(es: "Clave cifrada", en: "Encrypted key"),
                value: profile.maskedAccessCode,
              ),
              _RecordLine(
                label: t(es: "Activacion", en: "Activation"),
                value: profile.isActivated
                    ? t(es: "Cuenta activa", en: "Active account")
                    : t(es: "Pendiente", en: "Pending"),
              ),
              _RecordLine(
                label: t(es: "Fecha de activacion", en: "Activation date"),
                value: profile.activatedAt == null
                    ? t(es: "Sin fecha", en: "No date")
                    : _formatStamp(profile.activatedAt!),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatStamp(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, "0");
    final day = local.day.toString().padLeft(2, "0");
    final hour = local.hour.toString().padLeft(2, "0");
    final minute = local.minute.toString().padLeft(2, "0");
    return "${local.year}-$month-$day  $hour:$minute";
  }
}

class AdminDriverRecordEditPage extends StatefulWidget {
  const AdminDriverRecordEditPage({super.key, required this.record});

  final DriverRecordData record;

  @override
  State<AdminDriverRecordEditPage> createState() =>
      _AdminDriverRecordEditPageState();
}

class _AdminDriverRecordEditPageState extends State<AdminDriverRecordEditPage> {
  final _displayNameCtrl = TextEditingController();
  final _legalNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _governmentIdCtrl = TextEditingController();
  final _vehicleMakeCtrl = TextEditingController();
  final _vehicleModelCtrl = TextEditingController();
  final _vehicleColorCtrl = TextEditingController();
  final _vehiclePlateCtrl = TextEditingController();
  final _vehicleYearCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = widget.record.user;
    _displayNameCtrl.text = user.name;
    _legalNameCtrl.text = user.legalName;
    _emailCtrl.text = user.email;
    _phoneCtrl.text = user.phoneNumber;
    _addressCtrl.text = user.address;
    _governmentIdCtrl.text = user.governmentId;
    _vehicleMakeCtrl.text = user.vehicleMake ?? "";
    _vehicleModelCtrl.text = user.vehicleModel ?? "";
    _vehicleColorCtrl.text = user.vehicleColor ?? "";
    _vehiclePlateCtrl.text = user.vehiclePlate ?? "";
    _vehicleYearCtrl.text = user.vehicleYear ?? "";
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _legalNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _governmentIdCtrl.dispose();
    _vehicleMakeCtrl.dispose();
    _vehicleModelCtrl.dispose();
    _vehicleColorCtrl.dispose();
    _vehiclePlateCtrl.dispose();
    _vehicleYearCtrl.dispose();
    _newPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    String t({required String es, required String en}) =>
        context.txt(es: es, en: en);
    setState(() => _saving = true);
    try {
      final ok = await context.read<AuthProvider>().updateAuthorizedDriverRecord(
        id: widget.record.profile.id,
        displayName: _displayNameCtrl.text,
        legalName: _legalNameCtrl.text,
        email: _emailCtrl.text,
        phoneNumber: _phoneCtrl.text,
        governmentId: _governmentIdCtrl.text,
        address: _addressCtrl.text,
        vehicleMake: _vehicleMakeCtrl.text,
        vehicleModel: _vehicleModelCtrl.text,
        vehicleColor: _vehicleColorCtrl.text,
        vehiclePlate: _vehiclePlateCtrl.text,
        vehicleYear: _vehicleYearCtrl.text,
        newPassword: _newPasswordCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? t(es: "Record actualizado", en: "Record updated")
                : t(es: "Faltan datos obligatorios", en: "Required data missing"),
          ),
        ),
      );
      if (ok) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String t({required String es, required String en}) =>
        context.txt(es: es, en: en);
    return _PageFrame(
      title: t(es: "Editar driver", en: "Edit driver"),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HintCard(
            text: t(
              es: "Desde aqui puedes editar cualquier dato del driver, incluida la clave, los datos personales y la informacion del vehiculo.",
              en: "From here you can edit any driver data, including password, personal details, and vehicle information.",
            ),
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
            hint: t(es: "Identificacion", en: "Government ID"),
            prefixIcon: Icons.credit_card_outlined,
          ),
          const SizedBox(height: 10),
          CustomInput(
            controller: _vehicleMakeCtrl,
            hint: t(es: "Marca", en: "Make"),
            prefixIcon: Icons.directions_car_outlined,
          ),
          const SizedBox(height: 10),
          CustomInput(
            controller: _vehicleModelCtrl,
            hint: t(es: "Modelo", en: "Model"),
            prefixIcon: Icons.commute_outlined,
          ),
          const SizedBox(height: 10),
          CustomInput(
            controller: _vehicleColorCtrl,
            hint: t(es: "Color", en: "Color"),
            prefixIcon: Icons.palette_outlined,
          ),
          const SizedBox(height: 10),
          CustomInput(
            controller: _vehiclePlateCtrl,
            hint: t(es: "Placas", en: "Plate"),
            prefixIcon: Icons.pin_outlined,
          ),
          const SizedBox(height: 10),
          CustomInput(
            controller: _vehicleYearCtrl,
            hint: t(es: "Ano", en: "Year"),
            prefixIcon: Icons.event_outlined,
          ),
          const SizedBox(height: 10),
          CustomInput(
            controller: _newPasswordCtrl,
            hint: t(
              es: "Nueva contrasena (opcional)",
              en: "New password (optional)",
            ),
            obscureText: true,
            prefixIcon: Icons.lock_outline_rounded,
          ),
          const SizedBox(height: 16),
          CustomButton(
            label: _saving
                ? t(es: "Guardando...", en: "Saving...")
                : t(es: "Guardar cambios", en: "Save changes"),
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.record, this.large = false});

  final DriverRecordData record;
  final bool large;

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    if (record.profile.isActive && record.profile.isActivated) {
      label = context.txt(es: "Activo y vigente", en: "Active and valid");
      color = const Color(0xFF41D891);
    } else if (record.profile.activationPending) {
      label = context.txt(es: "Pendiente", en: "Pending");
      color = const Color(0xFFFFC857);
    } else {
      label = context.txt(es: "Inactivo", en: "Inactive");
      color = const Color(0xFFFF8A9A);
    }
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 12 : 10,
        vertical: large ? 10 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: large ? 12.5 : 11.8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RecordPanel extends StatelessWidget {
  const _RecordPanel({required this.children});

  final List<Widget> children;

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
        children: children,
      ),
    );
  }
}

class AdminPreferencesSettingsPage extends StatefulWidget {
  const AdminPreferencesSettingsPage({super.key});

  @override
  State<AdminPreferencesSettingsPage> createState() =>
      _AdminPreferencesSettingsPageState();
}

class _AdminPreferencesSettingsPageState
    extends State<AdminPreferencesSettingsPage> {
  bool _seeded = false;
  late MapThemeMode _draftTheme;
  late String _draftLanguage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    final storedTheme = context.read<AuthProvider>().user?.mapThemeMode ?? "";
    _draftTheme = switch (storedTheme) {
      "dark" => MapThemeMode.dark,
      "satellite" => MapThemeMode.satellite,
      _ => context.read<MapUiProvider>().themeMode,
    };
    _draftLanguage = context.read<AuthProvider>().user?.languageCode ?? "es";
  }

  @override
  Widget build(BuildContext context) {
    String t({required String es, required String en}) =>
        context.txt(es: es, en: en);
    final liveTheme = context.watch<MapUiProvider>().themeMode;
    final liveLanguage =
        context.watch<AuthProvider>().user?.languageCode ?? "es";
    final hasChanges =
        _draftTheme != liveTheme || _draftLanguage != liveLanguage;

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
            segments: [
              ButtonSegment<String>(value: "es", label: Text("Espanol")),
              ButtonSegment<String>(value: "en", label: Text("English")),
            ],
            selected: {_draftLanguage},
            onSelectionChanged: (selection) =>
                setState(() => _draftLanguage = selection.first),
          ),
          const SizedBox(height: 12),
          _HintCard(
            text: t(
              es: "Los cambios quedan listos y solo se aplican cuando presionas el boton inferior.",
              en: "Changes stay pending until you press the button below.",
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

class AdminInboxSettingsPage extends StatefulWidget {
  const AdminInboxSettingsPage({super.key});

  @override
  State<AdminInboxSettingsPage> createState() => _AdminInboxSettingsPageState();
}

class _AdminInboxSettingsPageState extends State<AdminInboxSettingsPage> {
  @override
  Widget build(BuildContext context) {
    String t({required String es, required String en}) =>
        context.txt(es: es, en: en);
    final drivers = context
        .watch<DriverProvider>()
        .drivers
        .where((driver) => driver.isOnline)
        .toList();
    final tripProvider = context.watch<TripProvider>();
    final chat = context.watch<ChatProvider>();

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
                              label: t(
                                es: "Flota conectada",
                                en: "Connected fleet",
                              ),
                              value: context.isEnglish
                                  ? "${drivers.length} online"
                                  : "${drivers.length} en linea",
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatCard(
                              label: t(es: "Viaje activo", en: "Active trip"),
                              value: tripProvider.totalActiveTrips().toString(),
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
                          es: "Flota conectada, viaje activo y mensajes se mantienen visibles porque siguen siendo utiles para la operacion diaria.",
                          en: "Connected fleet, active trip, and messages remain visible because they are still useful for daily operations.",
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

class AdminSecuritySettingsPage extends StatefulWidget {
  const AdminSecuritySettingsPage({super.key});

  @override
  State<AdminSecuritySettingsPage> createState() =>
      _AdminSecuritySettingsPageState();
}

class _AdminSecuritySettingsPageState extends State<AdminSecuritySettingsPage> {
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
          "password_locked" => t(
            es: "El acceso admin fijo esta bloqueado y solo cambia cuando tu lo indiques",
            en: "The fixed admin access is locked and only changes when you say so",
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

class _RecordLine extends StatelessWidget {
  const _RecordLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.8,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
