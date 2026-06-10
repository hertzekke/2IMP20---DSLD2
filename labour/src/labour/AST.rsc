module labour::AST

data BoulderWallConfiguration
  = boulderWall(str wallId, list[Route] routes, list[Volume] volumes);

data Route
  = route(str routeId, str grade, Pos gridBase, list[HoldRef] holds);

data HoldRef
  = single(str holdId)
  | subRoute(list[str] holdIds);

data Hold
  = hold(str holdId, HoldPosition pos, str shape, list[str] colours,
         Maybe[int] rotation, list[HoldLabel] labels);

data HoldPosition
  = xyPos(Pos p)
  | anglePos(int angle);

data Pos
  = pos(int x, int y);

data Rotation
  = rotation(int angle);

data HoldLabel
  = startHold(int num)
  | endHold();

data Volume
  = circle(Pos p, int depth, int radius, list[CircleHoldSection] sections)
  | triangle(Pos p, Pos extrusion, int depth, list[Pos] corners,
             list[TriangleHoldSection] sections);

data CircleHoldSection
  = frontHolds(list[Hold] holds)
  | sideHolds(list[Hold] holds);

data TriangleHoldSection
  = leftHolds(list[Hold] holds)
  | rightHolds(list[Hold] holds)
  | bottomHolds(list[Hold] holds);

data Maybe[&T]
  = just(&T val)
  | nothing();