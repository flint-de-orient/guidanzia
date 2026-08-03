import 'package:flutter/material.dart';

import '../theme/guidanzia_colors.dart';

/// A compact, collapsible "Rules" recap shown at the top of a Game-5 Task's
/// play screen — so a student who breezed past the intro can re-read the rules
/// mid-game without leaving the puzzle. Collapsed by default to keep the board
/// front-and-centre.
class RulesCard extends StatefulWidget {
  const RulesCard({super.key, required this.bullets});
  final List<String> bullets;

  @override
  State<RulesCard> createState() => _RulesCardState();
}

class _RulesCardState extends State<RulesCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return Container(
      decoration: BoxDecoration(
        color: g.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: g.outline),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.menu_book_outlined, size: 17, color: g.gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Rules',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color: g.onSurface)),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        size: 20, color: g.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.bullets
                    .map((b) => Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Container(
                                  width: 5,
                                  height: 5,
                                  decoration:
                                      BoxDecoration(color: g.gold, shape: BoxShape.circle),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(b,
                                    style: TextStyle(
                                        color: g.onSurfaceVariant,
                                        fontSize: 12.5,
                                        height: 1.4)),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
            crossFadeState:
                _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }
}
