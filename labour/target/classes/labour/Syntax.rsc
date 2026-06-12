/* 
Concrete Grammar class. .labour tests are parsed here, checked against 
the Route syntax rules, and thus the Concrete Syntax Tree (CST) is generated.

[!] Most rules are checked in Check.rsc, but we specify them in this .rsc to show that the 
grammar finds its roots in them. Besides the well-formedness rules we also motivate our decisions as 
"From assignment:... ", which means it's from the assignment description, not a rule.
*/

module labour::Syntax

layout Standard = WhitespaceOrComment* !>> [\ \t\n\r\f] !>> "//";
// Allow comments to be treated as whitespace. Allows for whitespace and new lines in tests.
// For example, @missing_hold_property.labour has a comment
lexical WhitespaceOrComment = [\ \t\n\r\f] | "//" ![\n]* [\n]; 

/* **************************************************
 *                   Bouldering Wall                *
 ************************************************** */
// Rule 1: A bouldering wall must have at least one volume and one route

start syntax BoulderingWall
  = boulderWall: "bouldering_wall" WallId "{"
      "routes" "[" {Route ","}* "]" ","?
      "volumes" "[" {Volume ","}* "]"
      "}"
  ;

/* **************************************************
 *                     Route                        *
 ************************************************** */

// Rule 2: Every route must have two or more holds (checker verifies if size >= 2, grammar enforces 1 or more)
syntax HoldRefList = {HoldRef ","}+;

// Rule 5: Every route must have a grade, a grid_base_point, and an identifier
syntax Route
  = route: "bouldering_route" RouteId "{" // RouteId maps to "identifier" in Rule 5
      "grade:" ShapeId "," // grade maps to "grade" in Rule 5
      "grid_base_point" Pos "," // Pos maps to "grid_base_point" in Rule 5, which has x and y under Rule 6
      "holds" "[" HoldRefList "]" // From assignment: "an array of hold identifiers that indicate which holds are part of this route..."
      "}"
  ;

/* HoldIdList represents the branches inside a split/sub-route (e.g. {"0003", "0004"}).
 It uses "+" (one or more) because an empty block ("") makes no sense. Also, under rule 4, a split
 requires branching holds.
 */
syntax HoldIdList = {HoldId ","}+;

syntax HoldRef
  = single:    HoldId // From assignment: default hold references are written as standard string tokens (e.g. "0001")
  | subRoute: "{" HoldIdList "}" // From assignment: "Moreover, a route can split... e.g. {"0003", "0004"}"
  ;

/* **************************************************
 *                      Hold                        *
 ************************************************** */

/* HoldId is outside the list of properties because it's also defined outside in the assignment description.
Example:

hold "0001" {
  pos { x: 30, y: 70 },
  shape: "107",
  [...] // Any of the other properties
}
*/

// Even though we used a lenient check here (*), we check for mandatory properties (esp rule 12 here) in Check.rsc
syntax Hold
  = hold: "hold" HoldId "{" {HoldProperty ","}* "}"
  ;

// Rule 12 (hold must have position (x/y or angle), shape, colour) 
// Rule 13 (if hold position defined by angle. if so, 0 <= angle <= 359)
// Rule 14 (hold might have rotation. if so, 0 <= rotation <= 359)
syntax HoldProperty
  = posProperty: "pos:" HoldPosition
  | shapeProperty: "shape:" ShapeId
  | coloursProperty: "colours" "[" ColourList "]"
  | rotationProperty: "rotation:" Integer
  | startHoldProperty: "start_hold:" StartHold // From assignment: "A hold can be labelled as a start_hold, which takes either 1 or 2 as an argument"
  | endHoldProperty: "end_hold" // From assignment: "A hold can be labelled as a start_hold [...] or end_hold"
  ;

// Rule 12: Every hold must have a position, defined by x and y or by an angle value [...]
syntax HoldPosition
  = xyPos:    Pos
  | anglePos: "{" "angle:" Integer "}"
  ;
  
// Rule 12: Every hold must have [...] and colour
syntax ColourList = {Colour ","}+; // "+" because it must have at least 1 colour

// From assignment: "A hold can be labelled as a start_hold, which takes either 1 or 2 as an argument"
lexical StartHold
  = "1"
  | "2"
  ;

/* **************************************************
 *                      Volume                      *
 ************************************************** */
/* 
 Design Decision: a volume must have at least 1 hold. We chose "*" which means ZERO or more holds, but
 what we really meant is that there can be zero or more TYPES of holds. for example, a triangle volume
 can have just a left hold, and not a right or bottom hold.
*/
// Rule 16: Only 2 types of volumes: Circle and Triangle.
syntax Volume
  = circle: "circle" "{" // Rule 17: Circular volume has position, depth, radius
      "pos:" Pos ","
      "depth:" Integer ","
      "radius:" Integer ","?
      {CircleHolds ","}* // Zero or more holds
      "}"
  | triangle: "triangle" "{" // Rule 19: Triangular volume has position, depth, an extrude point, corner with 3 points
      "pos:" Pos ","
      "extrusion:" Pos ","
      "depth:" Integer ","
      "corners" "[" Pos "," Pos "," Pos "]" ","?
      {TriangleHolds ","}* // Zero or more holds
      "}"
  ;

// Rule 18: Circular Volume must only contain front-holds and side-holds
syntax CircleHolds
  = frontHolds: "front_holds" "[" {Hold ","}* "]"
  | sideHolds:  "side_holds"  "[" {Hold ","}* "]"
  ;

// Rule 20: Triangular Volume must only contain left-holds, right-holds, and bottom-holds
syntax TriangleHolds
  = leftHolds:   "left_holds"   "[" {Hold ","}* "]"
  | rightHolds:  "right_holds"  "[" {Hold ","}* "]"
  | bottomHolds: "bottom_holds" "[" {Hold ","}* "]"
  ;

/* **************************************************
 *                     Colours                      *
 ************************************************** */

lexical Colour // Rule 15. 9 available for now.
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

/* **************************************************
 *                    Positions                     *
 ************************************************** */
syntax Pos = pos: "{" "x:" Integer "," "y:" Integer "}";

/* **************************************************
 *                     Lexicals                     *
 ************************************************** */

// Rule 9. HoldId: 4 digits, inside quotes
// Quotes are important because hold IDs are strings, as the leading 0s matter
lexical HoldId = "\"" [0-9][0-9][0-9][0-9] "\"";

// String lexicals
lexical Char = ![\"\\]; // Defines what is allowed to represent a char (everything but backslash and double quote)
lexical String = "\"" Char* "\""; // a string can be made up of any alphanumerical, inside double quotes; e.g. "abc", "Alex's 8th Wall"

// Rule 10: wall and shape ID can have any alphanumeric character
lexical RouteId = String; // From assignment: "a unique route identifier defined by a string" e.g. "my route"
lexical WallId  = String; // From assignment: "A bouldering wall has a unique ID" e.g. "Example Wall"

lexical ShapeId = String; // From assignment: "a hold shape identifier defined by a string" e.g. "52"


// Integer: optional negative sign followed by one or more digits.
/* The negative lookahead (!>> [0-9]) is not needed per-se but we included to tell the parser
to match the digits until there are no more. So "1234" doesn't become "12" and "34", but just "1234".
Again, not needed, but this resolves possible ambiguity, just safe to have it.
*/
lexical Integer = [\-]?[0-9]+ !>> [0-9];


