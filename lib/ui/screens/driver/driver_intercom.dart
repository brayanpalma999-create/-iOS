import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../providers/intercom_provider.dart";
import "../../../utils/app_text.dart";
import "../../widgets/ptt_button.dart";

class DriverIntercom extends StatelessWidget {
  const DriverIntercom({super.key});

  @override
  Widget build(BuildContext context) {
    String t({required String es, required String en}) =>
        context.txt(es: es, en: en);
    final intercom = context.watch<IntercomProvider>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t(es: "Intercom", en: "Intercom"),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                _ChannelLight(
                  color: intercom.channelLightColor,
                  blinking: intercom.shouldBlinkRed,
                  label: intercom.isPublic
                      ? t(
                          es: "Canal 1 publico: todos escuchan y todos pueden hablar",
                          en: "Public channel 1: everyone listens and everyone can talk",
                        )
                      : t(
                          es: "Canal 2 privado: enlace directo entre driver y admin",
                          en: "Private channel 2: direct link between driver and admin",
                        ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton.filledTonal(
                      onPressed: () =>
                          context.read<IntercomProvider>().toggleMuted(),
                      icon: Icon(
                        intercom.isMuted
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                      ),
                      tooltip: intercom.isMuted
                          ? t(es: "Audio silenciado", en: "Audio muted")
                          : t(es: "Silenciar audio", en: "Mute audio"),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      selected: intercom.isPublic,
                      onSelected: (_) => context
                          .read<IntercomProvider>()
                          .setMode(private: false),
                      label: Text(
                        t(es: "Canal 1 publico", en: "Public channel 1"),
                      ),
                    ),
                    ChoiceChip(
                      selected: intercom.isPrivate,
                      onSelected: (_) => context
                          .read<IntercomProvider>()
                          .setMode(private: true, targetId: "admin"),
                      label: Text(
                        t(es: "Canal 2 con admin", en: "Channel 2 with admin"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  intercom.isTransmitting
                      ? (context.isEnglish
                            ? "Transmitting: ${intercom.transmitSeconds}s"
                            : "Transmitiendo: ${intercom.transmitSeconds}s")
                      : (context.isEnglish
                            ? "Last transmission: ${intercom.lastTransmissionSeconds}s"
                            : "Ultima transmision: ${intercom.lastTransmissionSeconds}s"),
                ),
                const SizedBox(height: 4),
                Text(
                  intercom.channelBusy
                      ? t(es: "Canal ocupado", en: "Busy channel")
                      : t(es: "Canal libre", en: "Channel free"),
                ),
                const SizedBox(height: 4),
                Text(
                  intercom.isMuted
                      ? t(es: "Silencio: activado", en: "Mute: enabled")
                      : t(es: "Silencio: desactivado", en: "Mute: disabled"),
                ),
                if (intercom.lastErrorMessage != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    "Intercom: ${intercom.lastErrorMessage}",
                    style: const TextStyle(color: Colors.orangeAccent),
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
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: intercom.channelLightColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: intercom.channelLightColor.withValues(alpha: 0.55),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                context.isEnglish
                    ? (intercom.isTransmitting
                          ? "You are speaking"
                          : intercom.activeSpeakerLabel == null
                          ? "Nobody speaking"
                          : "${intercom.activeSpeakerLabel} is speaking")
                    : (intercom.isTransmitting
                          ? "Tu estas hablando"
                          : intercom.activeSpeakerLabel == null
                          ? "Nadie hablando"
                          : "${intercom.activeSpeakerLabel} esta hablando"),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: intercom.channelLightColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          intercom.activeSpeakerLabel == null
              ? t(es: "Hablando ahora: nadie", en: "Speaking now: nobody")
              : context.isEnglish
              ? "Speaking now: ${intercom.activeSpeakerLabel}"
              : "Hablando ahora: ${intercom.activeSpeakerLabel}",
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          t(es: "Mantener presionado para hablar.", en: "Hold to talk."),
          textAlign: TextAlign.center,
        ),
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
    if (widget.blinking) {
      _blinkController.repeat(reverse: true);
    }
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
