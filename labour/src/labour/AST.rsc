module labour::AST

data BoulderWallAST
  = boulderWall(str wallId, list[RouteAST] routes, list[VolumeAST] volumes);

data RouteAST
  = route(str routeId, str grade, PosAST gridBase, list[HoldRefAST] holds);

data HoldRefAST
  = single(str holdId)
  | subRoute(list[str] holdIds);

data HoldAST
  = hold(str holdId, HoldPositionAST pos, str shape, list[str] colours,
         MaybeInt rotation, list[HoldLabelAST] labels);

data HoldPositionAST
  = xyPos(PosAST p)
  | anglePos(int angle);

data PosAST
  = pos(int x, int y);

data RotationAST
  = rotation(int angle);

data HoldLabelAST
  = startHold(int startNum)
  | endHold();

data VolumeAST
  = circle(PosAST p, int depth, int radius, list[CircleHoldSectionAST] circleSections)
  | triangle(PosAST p, PosAST extrusion, int depth, list[PosAST] corners,
             list[TriangleHoldSectionAST] triangleSections);

data CircleHoldSectionAST
  = frontHolds(list[HoldAST] holds)
  | sideHolds(list[HoldAST] holds);

data TriangleHoldSectionAST
  = leftHolds(list[HoldAST] holds)
  | rightHolds(list[HoldAST] holds)
  | bottomHolds(list[HoldAST] holds);

data MaybeInt
  = just(int val)
  | nothing();