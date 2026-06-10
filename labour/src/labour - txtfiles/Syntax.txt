module labour::Syntax

/*
 * Concrete grammar for LaBouR (bouldering routes). This grammar aims to
 * reflect the language described in the assignment. It intentionally keeps
 * some checks (counts, numeric ranges, cross-references) to the external
 * checker (`Check.rsc`) so the grammar stays readable and extensible.
 */

start syntax BoulderingWall
  = "bouldering_wall" StringLiteral "{" WallElements "}"
  ;

syntax WallElements = [WallElement ("," WallElement)*];
syntax WallElement = RoutesClause | VolumesClause;

syntax RoutesClause = "routes" "[" RouteList "]";
syntax RouteList = [BoulderingRoute ("," BoulderingRoute)*];

syntax BoulderingRoute = "bouldering_route" StringLiteral "{" RouteFields "}";
syntax RouteFields = [RouteField ("," RouteField)*];
syntax RouteField = GradeField | GridBasePointField | HoldsField | IdField;
syntax GradeField = "grade" ":" StringLiteral;
syntax GridBasePointField = "grid_base_point" Position2D;
syntax HoldsField = "holds" "[" HoldRefList "]";
syntax IdField = /* placeholder to allow flexible ordering */ StringLiteral;

syntax HoldRefList = [HoldRef ("," HoldRef)*];
syntax HoldRef = StringLiteral | "{" StringLiteral ("," StringLiteral)* "}";

// Volumes
syntax VolumesClause = "volumes" "[" VolumeList "]";
syntax VolumeList = [Volume ("," Volume)*];
syntax Volume = CircleVolume | TriangleVolume;

syntax CircleVolume = "circle" "{" CircleFields "}";
syntax CircleFields = [CircleField ("," CircleField)*];
syntax CircleField = PosField | DepthField | RadiusField | FrontHoldsField | SideHoldsField;
syntax PosField = "pos" ":" Position2D;
syntax DepthField = "depth" ":" IntLiteral;
syntax RadiusField = "radius" ":" IntLiteral;
syntax FrontHoldsField = "front_holds" "[" HoldList "]";
syntax SideHoldsField = "side_holds" "[" HoldList "]";

syntax TriangleVolume = "triangle" "{" TriangleFields "}";
syntax TriangleFields = [TriangleField ("," TriangleField)*];
syntax TriangleField = PosField | ExtrusionField | DepthField | CornersField | LeftHoldsField | RightHoldsField | BottomHoldsField;
syntax ExtrusionField = "extrusion" ":" Position2D;
syntax CornersField = "corners" "[" CornerList "]";
syntax CornerList = Position2D ("," Position2D)*;
syntax LeftHoldsField = "left_holds" "[" HoldList "]";
syntax RightHoldsField = "right_holds" "[" HoldList "]";
syntax BottomHoldsField = "bottom_holds" "[" HoldList "]";

syntax HoldList = [Hold ("," Hold)*];
syntax Hold = "hold" StringLiteral "{" HoldFields "}";
syntax HoldFields = [HoldField ("," HoldField)*];
syntax HoldField = PosOrAngleField | ShapeField | ColoursField | RotationField | StartLabelField | EndLabelField;
syntax PosOrAngleField = "pos" ":" (Position2D | AnglePos);
syntax AnglePos = "{" "angle" ":" IntLiteral "}";
syntax ShapeField = "shape" ":" StringLiteral;
syntax ColoursField = "colours" "[" ColourList "]";
syntax ColourList = Id ("," Id)*;
syntax RotationField = "rotation" ":" IntLiteral;
syntax StartLabelField = "start_hold" ":" IntLiteral;
syntax EndLabelField = "end_hold";

// Positions
syntax Position2D = "{" "x" ":" IntLiteral "," "y" ":" IntLiteral "}";

// Tokens
lexical StringLiteral = '"' (~'"')* '"';
lexical IntLiteral = [0-9]+;
lexical Id = [a-zA-Z_][a-zA-Z0-9_]*;

// Whitespace/comments
layout WhiteSpace = [ \t\n\r]+ | "//" (~['\n'])* "\n";
