module labour::Syntax

/*
 * Concrete syntax for LaBouR (Language for Bouldering Routes).
 *
 * Design decisions:
 * - HoldId is exactly 4 digits (rule 9), enforced lexically via [0-9][0-9][0-9][0-9].
 * - WallId and RouteId are alphanumeric strings (rule 10), no keywords reserved for them.
 * - Colour values are modelled as keywords (rule 15) — this keeps validation in the grammar
 *   itself and avoids needing a separate string-based colour check in Check.rsc.
 * - Integer values are signed (depth can be negative, rule 17/19). Rotation/angle range
 *   (0–359, rules 13/14) cannot be expressed in CFG and is deferred to Check.rsc.
 * - HoldPosition is a choice between xy-position (pos x,y) and angle-position (angle ...),
 *   enforcing rule 12 structurally.
 * - The holds list in a route uses a HoldGroup to allow sub-route branching via
 *   parenthesised sub-lists: holds A, B, (C, D), (E, F), G
 *   This encodes the split/merge structure of rule 4/7/8 at the syntactic level.
 * - Volume hold-placement (frontholds, sideholds, leftholds, rightholds, bottomholds)
 *   is typed per volume kind in syntax, enforcing rules 18 and 20.
 */

// ─── Start ────────────────────────────────────────────────────────────────────

start syntax BoulderWallConfiguration
  = boulderWall: "boulderingwall" WallId
      "routes" Route+
      "volumes" Volume+
  ;

// ─── Route ────────────────────────────────────────────────────────────────────

syntax Route
  = route: "boulderingroute" RouteId
      "grade" ShapeId ","
      "gridbasepoint" Pos ","
      "holds" HoldRef ("," HoldRef)* ","?
  ;

/*
 * HoldRef encodes the hold list structure including sub-route splits.
 * A plain HoldId is a normal hold in the route.
 * A parenthesised group (HoldId, ...) represents one branch of a split.
 * The parser will produce a flat list of HoldRefs; Check.rsc validates
 * the split/merge rules (at most one split, no new split after merge).
 */
syntax HoldRef
  = single:    HoldId
  | subRoute: "(" HoldId ("," HoldId)* ")"
  ;

// ─── Hold (standalone, inside volumes) ───────────────────────────────────────

syntax Hold
  = hold: "hold" HoldId
      HoldPosition ","
      "shape" ShapeId ","
      "colours" {Colour ","}+ ","
      Rotation?
      HoldLabel*
  ;

syntax Rotation
  = rotation: "rotation" Integer ","
  ;

/*
 * HoldPosition is either an x,y coordinate pair or a single angle value.
 * This structurally enforces rule 12 (position by x,y OR by angle).
 */
syntax HoldPosition
  = xyPos:    "pos" Pos
  | anglePos: "pos" "angle" Integer
  ;

/*
 * HoldLabel covers the optional fields: starthold (1 or 2), endhold, rotation.
 * Using a list of HoldLabel* makes all three individually optional and
 * order-independent, which matches the examples in the assignment.
 * Rules 3/7 (at most 2 startholds, at most 1 endhold per route) are
 * checked in Check.rsc since they require counting across holds.
 */
syntax HoldLabel
  = startHold: "starthold" StartNum ","
  | endHold:   "endhold"
  ;

syntax StartNum
  = one: "1"
  | two: "2"
  ;

// ─── Volume ───────────────────────────────────────────────────────────────────

/*
 * Two volume kinds, each with their own hold-list sections.
 * Circle  → frontholds and/or sideholds only   (rule 18)
 * Triangle → leftholds, rightholds, bottomholds only (rule 20)
 * This enforces rules 18 and 20 in the grammar itself.
 */
syntax Volume
  = circle: "circle"
      "pos" Pos ","
      "depth" Integer ","
      "radius" Integer ","
      CircleHoldSection*
  | triangle: "triangle"
      "pos" Pos ","
      "extrusion" Pos ","
      "depth" Integer ","
      "corners" Pos "," Pos "," Pos ","
      TriangleHoldSection*
  ;

syntax CircleHoldSection
  = frontHolds: "frontholds" Hold+ ","?
  | sideHolds:  "sideholds"  Hold+ ","?
  ;

syntax TriangleHoldSection
  = leftHolds:   "leftholds"   Hold+ ","?
  | rightHolds:  "rightholds"  Hold+ ","?
  | bottomHolds: "bottomholds" Hold+ ","?
  ;

// ─── Colours (rule 15: only these nine are valid) ─────────────────────────────

syntax Colour
  = white:  "white"
  | yellow: "yellow"
  | green:  "green"
  | blue:   "blue"
  | red:    "red"
  | purple: "purple"
  | pink:   "pink"
  | black:  "black"
  | orange: "orange"
  ;

// ---- Positions ---────────────────────────────────────────────────────────────────────────
syntax Pos = pos: "x" Integer "," "y" Integer;

// ─── Lexicals ─────────────────────────────────────────────────────────────────

/*
 * HoldId: exactly 4 digits (rule 9).
 */
lexical HoldId = [0-9][0-9][0-9][0-9];

/*
 * WallId and RouteId: one or more alphanumeric characters (rule 10).
 * The follow restriction (!>> [a-zA-Z0-9]) prevents partial matches
 * when an id is followed by more alphanumeric input.
 */
lexical WallId  = [a-zA-Z0-9]+ !>> [a-zA-Z0-9];
lexical RouteId = [a-zA-Z0-9]+ !>> [a-zA-Z0-9];

/*
 * ShapeId: used for hold shape identifiers and route grades.
 * Defined as a non-empty alphanumeric string (e.g., "52", "5A").
 */
lexical ShapeId = [a-zA-Z0-9]+ !>> [a-zA-Z0-9];

/*
 * Integer: an optional minus sign followed by one or more digits.
 * Covers negative depth values (rule 17) and negative corner coordinates.
 */
lexical Integer = [\-]?[0-9]+ !>> [0-9];

// ─── Layout ───────────────────────────────────────────────────────────────────

/*
 * Standard whitespace and single-line comment layout.
 * The !>> ensures the layout is maximal (longest match).
 */
layout Layout = WhitespaceOrComment* !>> [\ \t\n\r\/];

lexical WhitespaceOrComment
  = [\ \t\n\r]
  | "//" ![\n]* [\n]
  ;

// ─── Keyword reservation ──────────────────────────────────────────────────────

/*
 * Reserving all keywords prevents them from being parsed as WallId/RouteId/ShapeId.
 * Rascal's `prefer keywords` disambiguation applies automatically when keyword
 * alternatives are listed in a `keyword` declaration.
 */
keyword Keywords
  = "boulderingwall" | "boulderingroute" | "routes" | "volumes"
  | "grade" | "gridbasepoint" | "holds" | "pos" | "angle"
  | "shape" | "colours" | "starthold" | "endhold" | "rotation"
  | "circle" | "triangle" | "depth" | "radius" | "extrusion" | "corners"
  | "frontholds" | "sideholds" | "leftholds" | "rightholds" | "bottomholds"
  | "white" | "yellow" | "green" | "blue" | "red"
  | "purple" | "pink" | "black" | "orange"
  ;