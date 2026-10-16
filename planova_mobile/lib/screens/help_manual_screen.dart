import 'package:flutter/material.dart';
import 'package:planova_mobile/theme/app_theme.dart';

/// In-app user manual. Open it from Settings → "Help & FAQ":
///
///   Navigator.push(context, MaterialPageRoute(
///     builder: (_) => HelpManualScreen(isAdmin: <your admin check>)));
///
/// Everyone sees "Using Planova" and "Troubleshooting". The "Admin guide" tab
/// only appears when [isAdmin] is true.
class HelpManualScreen extends StatelessWidget {
  final bool isAdmin;
  const HelpManualScreen({super.key, this.isAdmin = false});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);
    final tabs = <Tab>[
      const Tab(text: 'Using Planova'),
      if (isAdmin) const Tab(text: 'Admin guide'),
      const Tab(text: 'Troubleshooting'),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: c.background,
          elevation: 0,
          iconTheme: IconThemeData(color: c.onBackground),
          title: Text('Help & Manual',
              style: TextStyle(
                  color: c.onBackground, fontWeight: FontWeight.w700)),
          bottom: TabBar(
            tabs: tabs,
            labelColor: c.primary,
            unselectedLabelColor: c.onSurfaceSecondary,
            indicatorColor: c.primary,
            isScrollable: false,
          ),
        ),
        body: TabBarView(children: [
          _UserTab(c: c),
          if (isAdmin) _AdminTab(c: c),
          _TroubleTab(c: c, isAdmin: isAdmin),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Building blocks
// ─────────────────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final AppColors c;
  final IconData icon;
  final String title;
  final String? intro;
  final List<String> steps;
  final List<String> tips;
  final Widget? visual;
  const _Section({
    required this.c,
    required this.icon,
    required this.title,
    this.intro,
    this.steps = const [],
    this.tips = const [],
    this.visual,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          leading: Icon(icon, color: c.primary),
          title: Text(title,
              style: TextStyle(
                  color: c.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 15)),
          children: [
            if (intro != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(intro!,
                    style: TextStyle(
                        color: c.onSurfaceSecondary, height: 1.45)),
              ),
            if (visual != null)
              Padding(
                  padding: const EdgeInsets.only(bottom: 12), child: visual),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration:
                          BoxDecoration(color: c.primary, shape: BoxShape.circle),
                      child: Text('${i + 1}',
                          style: TextStyle(
                              color: c.onPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(steps[i],
                          style: TextStyle(color: c.onSurface, height: 1.45)),
                    ),
                  ],
                ),
              ),
            for (final t in tips)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: c.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline,
                        size: 16, color: c.onPrimaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(t,
                          style: TextStyle(
                              color: c.onPrimaryContainer,
                              fontSize: 13,
                              height: 1.4)),
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

class _Page extends StatelessWidget {
  final String heading;
  final String sub;
  final AppColors c;
  final List<Widget> children;
  const _Page(
      {required this.heading,
      required this.sub,
      required this.c,
      required this.children});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(heading,
            style: TextStyle(
                color: c.onBackground,
                fontSize: 22,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(sub,
            style: TextStyle(color: c.onSurfaceSecondary, height: 1.4)),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }
}

/// Row of boxes joined by arrows — a quick "how it flows" picture.
class _Flow extends StatelessWidget {
  final AppColors c;
  final List<String> labels;
  const _Flow({required this.c, required this.labels});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 6,
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: c.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(labels[i],
                style: TextStyle(
                    color: c.onPrimaryContainer,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          if (i != labels.length - 1)
            Icon(Icons.arrow_forward, size: 14, color: c.onSurfaceSecondary),
        ],
      ],
    );
  }
}

/// Mini floor map drawn with widgets: start, destination, route, wall, door.
class _MiniMap extends StatelessWidget {
  final AppColors c;
  const _MiniMap({required this.c});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.border),
        ),
        child: CustomPaint(painter: _MiniMapPainter(c)),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 14, runSpacing: 6, children: [
        _legend(c, Colors.green, 'Start'),
        _legend(c, Colors.red, 'Destination'),
        _legend(c, c.primary, 'Your route'),
        _legend(c, c.onSurfaceSecondary, 'Walls'),
      ]),
    ]);
  }

  static Widget _legend(AppColors c, Color color, String t) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(t, style: TextStyle(color: c.onSurfaceSecondary, fontSize: 12)),
        ],
      );
}

class _MiniMapPainter extends CustomPainter {
  final AppColors c;
  _MiniMapPainter(this.c);

  @override
  void paint(Canvas canvas, Size s) {
    final wall = Paint()
      ..color = c.onSurfaceSecondary
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final w = s.width, h = s.height;
    // outer box
    canvas.drawRect(Rect.fromLTWH(8, 8, w - 16, h - 16),
        wall..style = PaintingStyle.stroke);
    // inner wall with a doorway gap
    canvas.drawLine(Offset(w * .5, 8), Offset(w * .5, h * .38), wall);
    canvas.drawLine(Offset(w * .5, h * .62), Offset(w * .5, h - 8), wall);
    final route = Paint()
      ..color = c.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final p = Path()
      ..moveTo(w * .15, h * .5)
      ..lineTo(w * .5, h * .5)
      ..lineTo(w * .85, h * .5);
    canvas.drawPath(p, route);
    canvas.drawCircle(Offset(w * .15, h * .5), 6, Paint()..color = Colors.green);
    canvas.drawCircle(Offset(w * .85, h * .5), 6, Paint()..color = Colors.red);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — everyone
// ─────────────────────────────────────────────────────────────────────────────

class _UserTab extends StatelessWidget {
  final AppColors c;
  const _UserTab({required this.c});

  @override
  Widget build(BuildContext context) {
    return _Page(
      c: c,
      heading: 'Using Planova',
      sub: 'Find your way around a building in a few taps. Tap a topic to open it.',
      children: [
        _Section(
          c: c,
          icon: Icons.rocket_launch_outlined,
          title: 'Getting started',
          intro: 'The whole trip in one line:',
          visual: _Flow(c: c, labels: const [
            'Sign in',
            'Open building',
            'Pick floor',
            'Choose room',
            'Follow route',
          ]),
          steps: const [
            'Open Planova. On the sign-in screen choose Sign In (email and password), Continue with Google, or Continue as Guest.',
            'Guests can look around without an account. Create an account if you want your profile and saved access.',
            'Open a building by scanning its QR code, or pick it from your home screen.',
          ],
          tips: const [
            'Guests can use navigation, but some floors may need approval, which is easier with an account.',
          ],
        ),
        _Section(
          c: c,
          icon: Icons.qr_code_scanner,
          title: 'Open a building with a QR code',
          steps: const [
            'Tap the scan option on the home screen and allow camera access.',
            'Point the camera at the building\'s Planova QR code.',
            'Use Toggle Flash in dim lighting, or Flip Camera to switch cameras.',
            'The building opens and shows its floors and rooms.',
          ],
          tips: const [
            'A QR code may only unlock certain floors. Floors you cannot open will show as restricted.',
          ],
        ),
        _Section(
          c: c,
          icon: Icons.layers_outlined,
          title: 'Choose a floor and find a room',
          steps: const [
            'Pick the floor you are on from the floor list.',
            'If a floor shows "Floor access", you need approval first (see the next topic).',
            'Type a room name in Search rooms on <floor>… (for example, Conference Room).',
            'To look in every floor at once, tap Search All Floors.',
          ],
        ),
        _Section(
          c: c,
          icon: Icons.lock_open_outlined,
          title: 'Request access to a restricted floor',
          intro: 'Some floors are staff-only. You ask, an admin approves.',
          visual: _Flow(c: c, labels: const [
            'Tap restricted floor',
            'Send request',
            'Admin approves',
            'Floor unlocks',
          ]),
          steps: const [
            'Tap the restricted floor and send an access request.',
            'Wait for the admin. You get a notification when it is approved or rejected.',
            'Access can be time-limited. When it expires, request it again.',
          ],
        ),
        _Section(
          c: c,
          icon: Icons.navigation_outlined,
          title: 'Navigate to a room',
          visual: _MiniMap(c: c),
          steps: const [
            'Open the floor map. The app asks for Sensors if it needs them to follow your direction; tap Open Settings if you declined by mistake.',
            'Set your start point. A "Start set" message confirms it.',
            'Choose the room you want. A "Destination set" message confirms it.',
            'The route is drawn along open space and through doorways, never through walls.',
            'Tap Reset to clear the start and destination and begin again.',
          ],
          tips: const [
            'Pinch to zoom the map. Open Map Legend to see what each symbol means.',
          ],
        ),
        _Section(
          c: c,
          icon: Icons.map_outlined,
          title: 'Map legend',
          intro:
              'Tap Map Legend on a floor map. It explains doors, off-limits areas, safety markers and the route colors used on that map.',
        ),
        _Section(
          c: c,
          icon: Icons.person_outline,
          title: 'Your profile and settings',
          steps: const [
            'Open Profile to change your Full Name or photo (Take a Photo, or Choose from Gallery; you can Crop Photo).',
            'Your Email is shown but cannot be edited here.',
            'Open Settings for Dark mode & preferences.',
            'About Planova shows the app version.',
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 — admins
// ─────────────────────────────────────────────────────────────────────────────

class _AdminTab extends StatelessWidget {
  final AppColors c;
  const _AdminTab({required this.c});

  @override
  Widget build(BuildContext context) {
    return _Page(
      c: c,
      heading: 'Admin guide',
      sub: 'Set up buildings, check walls, control who can enter, and keep things running.',
      children: [
        _Section(
          c: c,
          icon: Icons.checklist,
          title: 'Setting up a building: the full path',
          visual: _Flow(c: c, labels: const [
            'Create building',
            'Add floors',
            'Upload floorplan',
            'Auto wall detection',
            'Review Walls',
            'Map rooms',
            'Share QR',
          ]),
          intro:
              'Do these in order. Navigation only works well once walls are checked and rooms are mapped.',
        ),
        _Section(
          c: c,
          icon: Icons.apartment,
          title: '1. Create a building',
          steps: const [
            'From home, tap Manage Buildings.',
            'Tap Create Building.',
            'Enter the Building name (for example, STI Pasay Campus) and the Address (for example, EDSA, Pasay City).',
            'Save. The building appears in your list.',
          ],
          tips: const [
            'Deleting a building asks for confirmation. It cannot be undone.',
          ],
        ),
        _Section(
          c: c,
          icon: Icons.upload_file,
          title: '2. Add floors and upload floorplans',
          steps: const [
            'Open the building and add a floor.',
            'Upload a floorplan image (PNG or JPG) for that floor.',
            'Wait while the floor shows "processing". Planova removes clutter and detects walls automatically. This usually takes under a minute.',
            'When the status shows ready, the floor is usable but still needs your review.',
          ],
          tips: const [
            'Best results: a clear, top-down plan with dark walls on a light background, no photos, tilted scans or heavy shading.',
          ],
        ),
        _Section(
          c: c,
          icon: Icons.edit_road,
          title: '3. Review Walls (important)',
          intro:
              'Automatic detection does most of the work, but it can mistake furniture outlines, door arcs or hatching for walls. Review every new floor once.',
          steps: const [
            'On the floor card tap Review Walls.',
            'Use Move to pan and pinch to zoom.',
            'Wall draws walls, Erase removes wrongly detected ones, and Line draws a straight wall between two taps.',
            'Use the brush slider (1 to 4) for thickness, Undo for mistakes, and show/hide walls to compare with the original plan.',
            'Reset restores the automatic result.',
            'Tap Confirm. If some rooms would be unreachable, Planova warns you before saving.',
          ],
          tips: const [
            'Make sure every room has an open doorway, or people cannot route into it.',
            'Re-uploading a floorplan replaces your manual edits and review starts again.',
          ],
        ),
        _Section(
          c: c,
          icon: Icons.meeting_room_outlined,
          title: '4. Map rooms, doors and off-limits areas',
          steps: const [
            'Open Room Mapping for the floor.',
            'Tap a room and enter its name (for example, Conference Room A).',
            'Mark Door positions so routes enter rooms through the right place.',
            'Mark an Off-Limits area with a short message (for example, Staff Only Beyond This Point). Routes will avoid it.',
            'If an off-limits area blocks other rooms, Planova warns: "This area blocks other rooms". Choose Go Back to adjust it, or Save Anyway if that is intended.',
            'Use Safety markers for things like exits. Tap Help for the map legend and Reset view to recenter.',
          ],
        ),
        _Section(
          c: c,
          icon: Icons.qr_code_2,
          title: '5. Create and share a QR code',
          steps: const [
            'Open the building\'s QR generator.',
            'Choose All Floors or Selected Floors. At least one floor must be selected.',
            'Save; you see "Floor access saved for this QR code".',
            'Save to Gallery, share it, or copy the QR value.',
            'If you change the floors later, you are asked "Update existing visitors too?". Update Everyone applies the change to people who already scanned it.',
          ],
        ),
        _Section(
          c: c,
          icon: Icons.how_to_reg_outlined,
          title: 'Access requests (approve, reject, revoke)',
          steps: const [
            'In Manage Buildings open the Requests tab.',
            'Open a request to see who asked and for which floor.',
            'Approve, optionally with a duration in days (for example, 90), or Reject.',
            'To remove access later, find the person and Revoke.',
            'The person is notified of the outcome.',
          ],
          tips: const [
            'Time-limited approvals expire on their own.',
          ],
        ),
        _Section(
          c: c,
          icon: Icons.groups_outlined,
          title: 'Users and History',
          steps: const [
            'The Users tab lists everyone with access and what they can open.',
            'The History tab is the audit log of approvals, rejections and revocations. Entries are never edited or removed.',
          ],
        ),
        _Section(
          c: c,
          icon: Icons.shield_outlined,
          title: 'Keeping the system safe',
          steps: const [
            'Treat admin accounts carefully. New accounts may be created as admins by default in your current setup, so check who has admin rights.',
            'Ask your developer to tighten Firebase Storage and Firestore rules so only admins can upload floorplans or change buildings.',
            'Review History regularly for unexpected approvals.',
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 3 — troubleshooting
// ─────────────────────────────────────────────────────────────────────────────

class _TroubleTab extends StatelessWidget {
  final AppColors c;
  final bool isAdmin;
  const _TroubleTab({required this.c, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return _Page(
      c: c,
      heading: 'Troubleshooting',
      sub: 'Find your symptom, try the fix.',
      children: [
        _Section(
          c: c,
          icon: Icons.person_outline,
          title: 'For everyone',
          steps: const [
            'Route looks wrong or won\'t appear: tap Reset, set the start and destination again. Make sure both are on the same floor.',
            'Cannot open a floor: it needs approval. Send an access request, or ask an admin. If it worked before, your access may have expired.',
            'QR code won\'t scan: allow camera access, turn on Toggle Flash, hold steady about 20 to 30 cm away. If the code is old, ask for a new one.',
            '"Building no longer available": an admin removed it. Ask them for the correct one.',
            'Direction arrow is off: allow Sensors via Open Settings, then move the phone in a figure-8 to recalibrate.',
            'Cannot sign in: check email and password, or use Continue with Google. As a fallback, Continue as Guest.',
          ],
        ),
        if (isAdmin)
          _Section(
            c: c,
            icon: Icons.admin_panel_settings_outlined,
            title: 'For admins',
            steps: const [
              'Walls are missing or too few after upload: open Review Walls and draw them with Wall or Line. Faint or low-contrast plans detect poorly; re-upload a darker, cleaner image.',
              'Furniture or door arcs appear as walls: use Erase in Review Walls.',
              'Routes go through where a wall should be: wall is too thin or has a gap. Close the gap in Review Walls with Line and Confirm.',
              'A room cannot be reached: it has no opening. Add a doorway by erasing a short wall piece, then Confirm.',
              'Floor stuck on "processing" or shows "failed": wait a minute, then re-upload. If it repeats, the image may be too large or unreadable; try a smaller PNG.',
              'Upload works but nothing is detected: check that the file is saved under the building and floor, and ask your developer to check the Cloud Function logs.',
              'Someone says they cannot enter a floor: check Requests and Users for their approval, expiry date and whether it was revoked.',
              'Changes to a QR code did not reach earlier visitors: edit it again and choose Update Everyone.',
            ],
            tips: const [
              'For developers: processing runs in a Cloud Function. Each floor records how it was processed (processingMethod, fallbackReason), and debug images are saved in Storage under debug/.',
            ],
          ),
      ],
    );
  }
}
