import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../providers/driver_provider.dart";
import "../../../providers/intercom_provider.dart";
import "../../widgets/ptt_button.dart";

class AdminIntercom extends StatelessWidget {
  const AdminIntercom({super.key});

  @override
  Widget build(BuildContext context) {
    final intercom = context.watch<IntercomProvider>();
    final fallbackDrivers = context.watch<DriverProvider>().drivers;
    final availableDrivers = intercom.availableDrivers;
    final useRemoteDrivers = availableDrivers.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Intercom",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                _ChannelLight(
                  color: intercom.channelLightColor,
                  blinking: intercom.shouldBlinkRed,
                  label: intercom.isPublic
                      ? "Canal 1 publico: todos escuchan y todos pueden hablar"
                      : "Canal 2 privado: enlace directo entre admin y driver",
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        intercom.activeSpeakerLabel == null
                            ? "Hablando ahora: nadie"
                            : "Hablando ahora: ${intercom.activeSpeakerLabel}",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: () =>
                          context.read<IntercomProvider>().toggleMuted(),
                      icon: Icon(
                        intercom.isMuted
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                      ),
                      tooltip: intercom.isMuted
                          ? "Audio silenciado"
                          : "Silenciar audio",
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      selected: intercom.isPublic,
                      onSelected: (_) => context
                          .read<IntercomProvider>()
                          .setMode(private: false),
                      label: const Text("Canal 1 publico"),
                    ),
                    if (useRemoteDrivers)
                      ...availableDrivers.map(
                        (d) => ChoiceChip(
                          selected:
                              intercom.isPrivate && intercom.targetId == d.id,
                          onSelected: (_) => context
                              .read<IntercomProvider>()
                              .setMode(private: true, targetId: d.id),
                          label: Text("Canal 2: ${d.name} #${d.id}"),
                        ),
                      )
                    else
                      ...fallbackDrivers.map(
                        (d) => ChoiceChip(
                          selected:
                              intercom.isPrivate && intercom.targetId == d.id,
                          onSelected: (_) => context
                              .read<IntercomProvider>()
                              .setMode(private: true, targetId: d.id),
                          label: Text("Canal 2: ${d.name} #${d.id}"),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFF121212),
                    border: Border.all(color: const Color(0x30FFFFFF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Admin ID: ${intercom.selfId ?? '-'}",
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Canal activo: ${intercom.isPublic ? '1 publico' : '2 privado'}",
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        intercom.isPrivate && intercom.targetId != null
                            ? "Driver enlazado: ${intercom.displayNameForTarget(intercom.targetId)}"
                            : "Driver enlazado: no seleccionado",
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                if (intercom.isPrivate && intercom.targetId != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    "Privado activo con: ${intercom.displayNameForTarget(intercom.targetId)}",
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: PttButton(
            onPress: () => context.read<IntercomProvider>().pressPtt(),
            onRelease: () => context.read<IntercomProvider>().releasePtt(),
            active: intercom.isTransmitting,
            busy: intercom.channelBusy,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          intercom.isTransmitting
              ? "Transmitiendo: ${intercom.transmitSeconds}s"
              : "Ultima transmision: ${intercom.lastTransmissionSeconds}s",
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          intercom.channelBusy ? "Canal ocupado" : "Canal libre",
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          intercom.isMuted ? "Silencio: activado" : "Silencio: desactivado",
          textAlign: TextAlign.center,
        ),
        if (intercom.lastErrorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            "Intercom: ${intercom.lastErrorMessage}",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.orangeAccent),
          ),
        ],
      ],
    );
  }
}

class _ChannelLight extends StatefulWidget {
  const _ChannelLight({
    required this.color,
    required this.blinking,
    required this.label,
  });

  final Color color;
  final bool blinking;
  final String label;

  @override
  State<_ChannelLight> createState() => _ChannelLightState();
}

class _ChannelLightState extends State<_ChannelLight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
      lowerBound: 0.2,
      upperBound: 1,
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant _ChannelLight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.blinking) {
      _blinkController.repeat(reverse: true);
    } else {
      _blinkController.stop();
      _blinkController.value = 1;
    }
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.blinking) {
      return Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.label)),
        ],
      );
    }

    return FadeTransition(
      opacity: _blinkController,
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.label)),
        ],
      ),
    );
  }
}
