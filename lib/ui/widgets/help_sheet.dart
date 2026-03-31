import "package:flutter/material.dart";

import "../../utils/app_text.dart";

enum AtoBHelpTopic {
  general,
  adminMap,
  adminAssign,
  intercom,
  adminEarnings,
  account,
  driverMap,
  driverRoute,
  driverEarnings,
}

Future<void> showAtoBHelpSheet(
  BuildContext context, {
  AtoBHelpTopic topic = AtoBHelpTopic.general,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF101214),
    showDragHandle: true,
    builder: (sheetContext) {
      final data = _sheetData(sheetContext, topic);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                data.subtitle,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 18),
              ...data.lines.map(
                (line) => _HelpLine(title: line.title, body: line.body),
              ),
            ],
          ),
        ),
      );
    },
  );
}

_HelpSheetData _sheetData(BuildContext context, AtoBHelpTopic topic) {
  switch (topic) {
    case AtoBHelpTopic.adminMap:
      return _HelpSheetData(
        title: context.txt(es: "Ayuda del mapa", en: "Map help"),
        subtitle: context.txt(
          es: "Guia rapida para seguir drivers y centrar la operacion.",
          en: "Quick guide to track drivers and center operations.",
        ),
        lines: [
          _HelpLineData(
            title: context.txt(es: "Ubicacion real", en: "Live location"),
            body: context.txt(
              es: "El mapa prioriza ubicaciones reales de drivers conectados. Si no hay ubicacion util, se usa solo una vista amplia temporal.",
              en: "The map prioritizes real locations from connected drivers. If there is no usable location yet, it only falls back to a wide overview temporarily.",
            ),
          ),
          _HelpLineData(
            title: context.txt(es: "Hotspots", en: "Hotspots"),
            body: context.txt(
              es: "Los hotspots resumen zonas con mayor concentracion operativa para lectura rapida del despacho.",
              en: "Hotspots summarize areas with higher operational concentration for faster dispatch reading.",
            ),
          ),
          _HelpLineData(
            title: context.txt(es: "Acciones", en: "Actions"),
            body: context.txt(
              es: "Usa centrar mapa para volver al foco operativo y revisa la barra inferior para ver cuantos drivers reales hay conectados.",
              en: "Use center map to return to the operational focus and review the lower bar to see how many real drivers are connected.",
            ),
          ),
        ],
      );
    case AtoBHelpTopic.adminAssign:
      return _HelpSheetData(
        title: context.txt(es: "Ayuda de asignaciones", en: "Assignments help"),
        subtitle: context.txt(
          es: "Como asignar rutas manuales sin perder tiempo.",
          en: "How to assign routes manually without losing time.",
        ),
        lines: [
          _HelpLineData(
            title: context.txt(es: "Drivers elegibles", en: "Eligible drivers"),
            body: context.txt(
              es: "Solo aparecen como listos los drivers conectados, visibles y sin otro viaje activo.",
              en: "Only connected, visible drivers without another active trip appear as ready.",
            ),
          ),
          _HelpLineData(
            title: context.txt(
              es: "Direcciones sugeridas",
              en: "Suggested addresses",
            ),
            body: context.txt(
              es: "El buscador prioriza direcciones cercanas a la zona donde se encuentran los drivers y recuerda lugares usados antes.",
              en: "The search prioritizes addresses near the area where drivers are located and remembers places used before.",
            ),
          ),
          _HelpLineData(
            title: context.txt(es: "Despacho directo", en: "Direct dispatch"),
            body: context.txt(
              es: "Cuando envias la orden, el viaje queda asignado al driver elegido y en su lado solo aparece la ruta para iniciar.",
              en: "When you send the order, the trip is assigned to the selected driver and on the driver side only the route to start appears.",
            ),
          ),
        ],
      );
    case AtoBHelpTopic.intercom:
      return _HelpSheetData(
        title: context.txt(es: "Ayuda del intercom", en: "Intercom help"),
        subtitle: context.txt(
          es: "Referencia rapida del canal publico y privado.",
          en: "Quick reference for public and private channels.",
        ),
        lines: [
          _HelpLineData(
            title: context.txt(es: "Canal 1", en: "Channel 1"),
            body: context.txt(
              es: "Canal publico: admin y todos los drivers pueden escuchar y hablar.",
              en: "Public channel: admin and all drivers can listen and talk.",
            ),
          ),
          _HelpLineData(
            title: context.txt(es: "Canal 2", en: "Channel 2"),
            body: context.txt(
              es: "Canal privado: enlaza admin con un driver especifico y la luz cambia a rojo parpadeando.",
              en: "Private channel: links admin with a specific driver and the light switches to blinking red.",
            ),
          ),
          _HelpLineData(
            title: context.txt(es: "PTT", en: "PTT"),
            body: context.txt(
              es: "Mantener presionado transmite. Al soltar, la app corta la emision, conserva beeps y muestra quien esta hablando debajo del microfono.",
              en: "Holding the button transmits. Releasing stops the transmission, keeps the beeps, and shows who is speaking below the microphone.",
            ),
          ),
        ],
      );
    case AtoBHelpTopic.adminEarnings:
      return _HelpSheetData(
        title: context.txt(es: "Ayuda de ganancias", en: "Earnings help"),
        subtitle: context.txt(
          es: "Como leer ingresos, flota y tendencia semanal.",
          en: "How to read revenue, fleet status, and weekly trend.",
        ),
        lines: [
          _HelpLineData(
            title: context.txt(es: "Balance actual", en: "Current balance"),
            body: context.txt(
              es: "Suma viajes confirmados y completados para la operacion.",
              en: "Adds confirmed and completed trips for operations.",
            ),
          ),
          _HelpLineData(
            title: context.txt(es: "Semanas", en: "Weeks"),
            body: context.txt(
              es: "Esta semana y semana pasada ayudan a comparar ritmo operativo reciente.",
              en: "This week and last week help compare recent operational pace.",
            ),
          ),
          _HelpLineData(
            title: context.txt(es: "Flota", en: "Fleet"),
            body: context.txt(
              es: "La tarjeta de flota cruza drivers online con rutas activas para ver carga operativa.",
              en: "The fleet card combines online drivers with active routes to show operational load.",
            ),
          ),
        ],
      );
    case AtoBHelpTopic.account:
      return _HelpSheetData(
        title: context.txt(es: "Ayuda de cuenta", en: "Account help"),
        subtitle: context.txt(
          es: "Resumen rapido de perfil, preferencias, inbox y seguridad.",
          en: "Quick summary of profile, preferences, inbox, and security.",
        ),
        lines: [
          _HelpLineData(
            title: context.txt(es: "Perfil", en: "Profile"),
            body: context.txt(
              es: "Aqui editas foto, nombre legal, telefono, direccion y datos principales del usuario.",
              en: "Here you edit photo, legal name, phone, address, and the user's main details.",
            ),
          ),
          _HelpLineData(
            title: context.txt(es: "Preferencias", en: "Preferences"),
            body: context.txt(
              es: "Tema del mapa, idioma y visibilidad se aplican juntos al usar el boton de guardar.",
              en: "Map theme, language, and visibility apply together when you use the save button.",
            ),
          ),
          _HelpLineData(
            title: context.txt(es: "Inbox", en: "Inbox"),
            body: context.txt(
              es: "Mantiene el resumen operativo y agrega chat privado con fotos sin perder la vista rapida.",
              en: "It keeps the operational summary and adds private photo chat without losing the quick view.",
            ),
          ),
        ],
      );
    case AtoBHelpTopic.driverMap:
      return _HelpSheetData(
        title: context.txt(es: "Ayuda del mapa", en: "Map help"),
        subtitle: context.txt(
          es: "Referencia rapida para ubicacion del driver y visibilidad.",
          en: "Quick reference for driver location and visibility.",
        ),
        lines: [
          _HelpLineData(
            title: context.txt(es: "Centrado", en: "Centering"),
            body: context.txt(
              es: "Centrar mapa lleva la vista a tu ubicacion real cuando ya existe un fix util.",
              en: "Center map returns the view to your real location when a usable fix already exists.",
            ),
          ),
          _HelpLineData(
            title: context.txt(
              es: "Visible o invisible",
              en: "Visible or invisible",
            ),
            body: context.txt(
              es: "Ese control decide si puedes recibir nuevas asignaciones y si apareces en el mapa del admin.",
              en: "That control decides whether you can receive new assignments and whether you appear on the admin map.",
            ),
          ),
          _HelpLineData(
            title: context.txt(es: "Ruta activa", en: "Active route"),
            body: context.txt(
              es: "La ruta solo se dibuja cuando existe un viaje real asignado al driver.",
              en: "The route is only drawn when there is a real trip assigned to the driver.",
            ),
          ),
        ],
      );
    case AtoBHelpTopic.driverRoute:
      return _HelpSheetData(
        title: context.txt(es: "Ayuda de ruta", en: "Route help"),
        subtitle: context.txt(
          es: "Que aparece cuando el admin asigna un viaje.",
          en: "What appears when the admin assigns a trip.",
        ),
        lines: [
          _HelpLineData(
            title: context.txt(es: "Asignacion", en: "Assignment"),
            body: context.txt(
              es: "El driver no acepta ni rechaza. Solo recibe la ruta, el estimado y el boton para iniciar.",
              en: "The driver does not accept or reject. They only receive the route, estimate, and button to start.",
            ),
          ),
          _HelpLineData(
            title: context.txt(es: "Trazo", en: "Route line"),
            body: context.txt(
              es: "Si no hay viaje real, no debe mostrarse ningun trazo en esta pantalla.",
              en: "If there is no real trip, no route line should be shown on this screen.",
            ),
          ),
          _HelpLineData(
            title: context.txt(es: "Seguimiento", en: "Tracking"),
            body: context.txt(
              es: "Al iniciar ruta, la ubicacion del driver sigue actualizandose en tiempo real para admin.",
              en: "Once the route starts, the driver's location continues updating in real time for admin.",
            ),
          ),
        ],
      );
    case AtoBHelpTopic.driverEarnings:
      return _HelpSheetData(
        title: context.txt(es: "Ayuda de ganancias", en: "Earnings help"),
        subtitle: context.txt(
          es: "Lectura rapida de balance y rendimiento personal.",
          en: "Quick reading of balance and personal performance.",
        ),
        lines: [
          _HelpLineData(
            title: context.txt(es: "Balance", en: "Balance"),
            body: context.txt(
              es: "Solo muestra lo asociado a los viajes de este driver.",
              en: "It only shows values associated with this driver's trips.",
            ),
          ),
          _HelpLineData(
            title: context.txt(es: "Resumen semanal", en: "Weekly summary"),
            body: context.txt(
              es: "Compara semana actual y anterior para ver tendencia operativa.",
              en: "It compares the current and previous week to show operating trend.",
            ),
          ),
          _HelpLineData(
            title: context.txt(es: "Movimientos", en: "Recent activity"),
            body: context.txt(
              es: "Los ultimos movimientos muestran destino, estado y distancia de los viajes registrados.",
              en: "Recent activity shows destination, status, and distance for registered trips.",
            ),
          ),
        ],
      );
    case AtoBHelpTopic.general:
      return _HelpSheetData(
        title: context.txt(es: "Ayuda", en: "Help"),
        subtitle: context.txt(
          es: "Respuestas rapidas para operacion diaria en AtoB.",
          en: "Quick answers for day-to-day operations in AtoB.",
        ),
        lines: [
          _HelpLineData(
            title: context.txt(es: "Mapa", en: "Map"),
            body: context.txt(
              es: "Activa ubicacion precisa para mejorar mapa, rutas y seguimiento en tiempo real.",
              en: "Enable precise location to improve maps, routes, and real-time tracking.",
            ),
          ),
          _HelpLineData(
            title: context.txt(es: "Asignaciones", en: "Assignments"),
            body: context.txt(
              es: "Solo drivers visibles, conectados y sin viaje activo aparecen como elegibles.",
              en: "Only visible, connected drivers without an active trip appear as eligible.",
            ),
          ),
          _HelpLineData(
            title: context.txt(es: "Intercom", en: "Intercom"),
            body: context.txt(
              es: "Canal 1 es publico y canal 2 enlaza admin con un driver especifico.",
              en: "Channel 1 is public and channel 2 links admin with a specific driver.",
            ),
          ),
        ],
      );
  }
}

class _HelpSheetData {
  const _HelpSheetData({
    required this.title,
    required this.subtitle,
    required this.lines,
  });

  final String title;
  final String subtitle;
  final List<_HelpLineData> lines;
}

class _HelpLineData {
  const _HelpLineData({required this.title, required this.body});

  final String title;
  final String body;
}

class _HelpLine extends StatelessWidget {
  const _HelpLine({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: const TextStyle(color: Colors.white70, height: 1.3),
          ),
        ],
      ),
    );
  }
}
