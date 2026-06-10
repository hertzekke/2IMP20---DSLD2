module labour::AST

/*
 * Define the Abstract Syntax for LaBouR
 * - Hint: make sure there is an almost one-to-one correspondence with the grammar in Syntax.rsc
 */

data BoulderingWall(loc src=|unknown:///|)
  = bWall(str id, list[BoulderingRoute] routes, list[Volume] volumes)
  ;

data BoulderingRoute
  = bRoute(str id, str grade, Position gridBasePoint, list[HoldRef] holds)
  ;

// A hold reference inside a route: either a single hold id or a split (multiple hold ids)
data HoldRef
  = single(str id)
  | split(list[str] ids)
  ;

// Volumes: circle or triangle
data Volume
  = circle(Position pos, int depth, int radius, list[Hold] front_holds, list[Hold] side_holds)
  | triangle(Position pos, Position extrusion, int depth, list[Position] corners, list[Hold] left_holds, list[Hold] right_holds, list[Hold] bottom_holds)
  ;

// Hold in a volume
data Hold
  = hold(str id, PositionOrAngle pos, str shape, list[str] colours, int rotation, int startLabel, bool endHold)
  ;

// Position types
data Position = pos2D(int x, int y);

data PositionOrAngle = posXY(int x, int y) | posAngle(int angle);

