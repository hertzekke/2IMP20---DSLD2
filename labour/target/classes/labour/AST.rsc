module labour::AST

/*
 * Design Decisions for AST (Abstract Syntax Tree)
 * 
 * - Domain Model: Defines the structural representation of the mapped data, completely
 *   free of grammar formatting (e.g., syntactic noise like braces and commas are removed).
 * - Simplicity for Validation: This clean tree structure makes it extremely easy to query, 
 *   traverse, and validate in the subsequent checker phase.
 * - Comprehensive Constructors: Contains constructors for walls, routes, hold references, 
 *   volumes, holds, and position variants used by the checker and mapping.
 */

data BoulderWallAST
  = boulderWall(str wallId, list[RouteAST] routes, list[VolumeAST] volumes);

data RouteAST
  = route(str routeId, str grade, PosAST gridBase, list[HoldRefAST] holds);

data HoldRefAST
  = single(str holdId)
  | subRoute(list[str] holdIds);

data HoldAST
  = hold(str holdId, HoldPositionAST pos, str shape, list[str] colours,
         MaybeInt rotation, list[HoldLabelAST] labels, bool posProvided);

data HoldPositionAST
  = xyPos(PosAST p)
  | anglePos(int angle);

data PosAST
  = pos(int x, int y);


data HoldLabelAST
  = startHold(int StartHold)
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