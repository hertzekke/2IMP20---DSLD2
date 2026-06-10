module labour::Syntax

/*
 * Concrete syntax for LaBouR (Language for Bouldering Routes).
 * Updated to match the example.labour formatting perfectly.
 */

layout Standard = WhitespaceOrComment* !>> [\ \t\n\r\f] !>> "//";
lexical WhitespaceOrComment = [\ \t\n\r\f] | "//" ![\n]* [\n];

// ─── Start ────────────────────────────────────────────────────────────────────

start syntax BoulderingWall
  = boulderWall: "bouldering_wall" WallId "{"
      "routes" "[" {Route ","}* "]" ","?
      "volumes" "[" {Volume ","}* "]"
      "}"
  ;

// ─── Route ────────────────────────────────────────────────────────────────────

syntax HoldRefList = {HoldRef ","}+;

syntax Route
  = route: "bouldering_route" RouteId "{"
      "grade:" ShapeId ","
      "grid_base_point" Pos ","
      "holds" "[" HoldRefList "]"
      "}"
  ;

syntax HoldIdList = {HoldId ","}+;

syntax HoldRef
  = single:    HoldId
  | subRoute: "{" HoldIdList "}"
  ;

// ─── Hold (standalone, inside volumes) ───────────────────────────────────────

syntax ColourList = {Colour ","}+;

syntax Hold
  = hold: "hold" HoldId "{" {HoldProperty ","}* "}"
  ;

syntax HoldProperty
  = posProperty: "pos:" HoldPosition
  | shapeProperty: "shape:" ShapeId
  | coloursProperty: "colours" "[" ColourList "]"
  | rotationProperty: "rotation:" Integer
  | startHoldProperty: "start_hold:" StartNum
  | endHoldProperty: "end_hold"
  ;

/*
 * HoldPosition is either an x,y coordinate pair or a single angle value.
 */
syntax HoldPosition
  = xyPos:    Pos
  | anglePos: "{" "angle:" Integer "}"
  ;

lexical StartNum
  = "1"
  | "2"
  ;

// ─── Volume ───────────────────────────────────────────────────────────────────

syntax Volume
  = circle: "circle" "{"
      "pos:" Pos ","
      "depth:" Integer ","
      "radius:" Integer ","?
      {CircleHoldSection ","}*
      "}"
  | triangle: "triangle" "{"
      "pos:" Pos ","
      "extrusion:" Pos ","
      "depth:" Integer ","
      "corners" "[" Pos "," Pos "," Pos "]" ","?
      {TriangleHoldSection ","}*
      "}"
  ;

syntax CircleHoldSection
  = frontHolds: "front_holds" "[" {Hold ","}* "]"
  | sideHolds:  "side_holds"  "[" {Hold ","}* "]"
  ;

syntax TriangleHoldSection
  = leftHolds:   "left_holds"   "[" {Hold ","}* "]"
  | rightHolds:  "right_holds"  "[" {Hold ","}* "]"
  | bottomHolds: "bottom_holds" "[" {Hold ","}* "]"
  ;

// ─── Colours (rule 15: only these nine are valid) ─────────────────────────────

lexical Colour
  = "white"
  | "yellow"
  | "green"
  | "blue"
  | "red"
  | "purple"
  | "pink"
  | "black"
  | "orange"
  ;

// ---- Positions ---────────────────────────────────────────────────────────────

syntax Pos = pos: "{" "x:" Integer "," "y:" Integer "}";

// ─── Lexicals ─────────────────────────────────────────────────────────────────

/*
 * HoldId: exactly 4 digits inside quotes.
 */
lexical HoldId = "\"" [0-9][0-9][0-9][0-9] "\"";

/*
 * String lexicals
 */
lexical String = "\"" Char* "\"";
lexical Char = ![\"\\] | "\\" [\"\\/bfnrt];

lexical WallId  = String;
lexical RouteId = String;
lexical ShapeId = String;

/*
 * Integer: an optional minus sign followed by one or more digits.
 */
lexical Integer = [\-]?[0-9]+ !>> [0-9];


