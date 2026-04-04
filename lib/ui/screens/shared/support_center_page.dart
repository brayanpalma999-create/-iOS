import "dart:async";

import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../models/support_ticket_model.dart";
import "../../../providers/auth_provider.dart";
import "../../../providers/support_provider.dart";
import "../../../utils/app_text.dart";
import "../../widgets/custom_button.dart";
import "../../widgets/custom_input.dart";

class SupportCenterPage extends StatefulWidget {
  const SupportCenterPage({super.key, required this.adminMode});

  final bool adminMode;

  @override
  State<SupportCenterPage> createState() => _SupportCenterPageState();
}

class _SupportCenterPageState extends State<SupportCenterPage> {
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  Timer? _refreshTimer;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) => _refresh());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final accountKey = auth.currentAccountKey ?? "";
    final role = auth.user?.role.name ?? "driver";
    await context.read<SupportProvider>().refresh(
      accountKey: widget.adminMode ? "" : accountKey,
      role: widget.adminMode ? "admin" : role,
      silent: true,
    );
  }

  Future<void> _submitTicket() async {
    if (_submitting) return;
    final auth = context.read<AuthProvider>();
    final accountKey = auth.currentAccountKey ?? "";
    final user = auth.user;
    if (user == null || accountKey.trim().isEmpty) return;
    if (_titleCtrl.text.trim().isEmpty || _descriptionCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.txt(
              es: "Titulo y descripcion son obligatorios",
              en: "Title and description are required",
            ),
          ),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final ticket = await context.read<SupportProvider>().createTicket(
        accountKey: accountKey,
        role: user.role.name,
        userName: user.legalName,
        userEmail: user.email,
        title: _titleCtrl.text,
        description: _descriptionCtrl.text,
        category: "operations",
        priority: user.role.name == "admin" ? "high" : "normal",
      );
      if (!mounted) return;
      if (ticket != null) {
        _titleCtrl.clear();
        _descriptionCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.txt(
                es: "Caso enviado a soporte",
                en: "Support case sent",
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _updateStatus(SupportTicketModel ticket, String status) async {
    final auth = context.read<AuthProvider>();
    await context.read<SupportProvider>().updateTicketStatus(
      ticketId: ticket.id,
      status: status,
      authorRole: auth.user?.role.name ?? "admin",
      authorName: auth.user?.name ?? "AtoB",
      note: context.txt(
        es: "Estado actualizado desde panel admin",
        en: "Status updated from admin panel",
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.txt(
            es: "Estado actualizado",
            en: "Status updated",
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String t({required String es, required String en}) =>
        context.txt(es: es, en: en);
    final support = context.watch<SupportProvider>();
    final tickets = support.tickets;

    return Scaffold(
      appBar: AppBar(
        title: Text(t(es: "Soporte e historial", en: "Support and history")),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!widget.adminMode) ...[
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t(es: "Nuevo caso", en: "New case"),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    CustomInput(
                      controller: _titleCtrl,
                      hint: t(es: "Titulo del problema", en: "Issue title"),
                      prefixIcon: Icons.support_agent_rounded,
                    ),
                    const SizedBox(height: 10),
                    CustomInput(
                      controller: _descriptionCtrl,
                      hint: t(
                        es: "Describe lo que paso, cuando y que estabas haciendo",
                        en: "Describe what happened, when, and what you were doing",
                      ),
                      prefixIcon: Icons.description_outlined,
                      maxLines: 5,
                    ),
                    const SizedBox(height: 12),
                    CustomButton(
                      label: _submitting
                          ? t(es: "Enviando...", en: "Sending...")
                          : t(es: "Enviar a soporte", en: "Send to support"),
                      onPressed: _submitTicket,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            _Panel(
              child: Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      label: t(es: "Casos", en: "Cases"),
                      value: tickets.length.toString(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      label: t(es: "Abiertos", en: "Open"),
                      value: tickets.where((item) => item.isOpen).length.toString(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      label: t(es: "Resueltos", en: "Resolved"),
                      value: tickets
                          .where((item) => item.status == "resolved")
                          .length
                          .toString(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              t(es: "Historial", en: "History"),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            if (support.loading && tickets.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (tickets.isEmpty)
              _Panel(
                child: Text(
                  t(
                    es: "Todavia no hay casos registrados.",
                    en: "There are no support cases yet.",
                  ),
                  style: const TextStyle(color: Colors.white70),
                ),
              )
            else
              ...tickets.map(
                (ticket) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TicketTile(
                    ticket: ticket,
                    adminMode: widget.adminMode,
                    onSetStatus: widget.adminMode
                        ? (status) => _updateStatus(ticket, status)
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({
    required this.ticket,
    required this.adminMode,
    this.onSetStatus,
  });

  final SupportTicketModel ticket;
  final bool adminMode;
  final ValueChanged<String>? onSetStatus;

  @override
  Widget build(BuildContext context) {
    String t({required String es, required String en}) =>
        context.txt(es: es, en: en);
    final color = switch (ticket.status) {
      "resolved" => const Color(0xFF41D891),
      "investigating" => const Color(0xFF72BBFF),
      _ => const Color(0xFFFFC857),
    };

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ticket.title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: color.withValues(alpha: 0.45)),
                ),
                child: Text(
                  ticket.status,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [
              ticket.userName,
              ticket.userEmail,
              ticket.priority,
            ].where((item) => item.trim().isNotEmpty).join(" • "),
            style: const TextStyle(color: Colors.white70, fontSize: 12.4),
          ),
          const SizedBox(height: 10),
          Text(
            ticket.description,
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
          if (ticket.messages.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...ticket.messages.take(3).map(
              (message) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  "${message.authorName}: ${message.message}",
                  style: const TextStyle(color: Colors.white60, fontSize: 12.4),
                ),
              ),
            ),
          ],
          if (adminMode && onSetStatus != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    inverted: true,
                    label: t(es: "Investigar", en: "Investigate"),
                    onPressed: () => onSetStatus!("investigating"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CustomButton(
                    label: t(es: "Resolver", en: "Resolve"),
                    onPressed: () => onSetStatus!("resolved"),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101214),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: child,
    );
  }
}
