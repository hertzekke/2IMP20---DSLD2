module labour::CST2AST

import labour::Syntax;
import labour::AST;

// This provides println which can be handy during debugging.
import IO;

// These provide useful functions such as toInt, keep those in mind.
import Prelude;	
import String;
import ParseTree;

/*
 * Entry point. The parser in Parser.rsc produces a
 * Tree rooted at (start BoulderWallConfiguration); we unwrap the start
 * node and dispatch into the main mapping.
 */
BoulderWallConfigurationAST cst2ast(Tree tree) {
  return cst2ast(tree.top);
}

// ─── BoulderWallConfiguration ────────────────────────────────────────────────

BoulderWallConfigurationAST cst2ast((BoulderWallConfiguration) `boulderingwall <WallId wid>
                                                               routes <Route+ routes>
                                                               volumes <Volume+ volumes>`) =
  boulderWall(
    "<wid>",
    [cst2ast(r) | r <- routes],
    [cst2ast(v) | v <- volumes]
  );

// ─── Route ────────────────────────────────────────────────────────────────────

RouteAST cst2ast((Route) `boulderingroute <RouteId rid>
                        grade <ShapeId grade> ,
                        gridbasepoint <Pos gp> ,
                        holds <HoldRef first> <("," HoldRef rest)*  tail> <","?>`) =
  route(
    "<rid>",
    "<grade>",
    cst2ast(gp),
    [cst2ast(first)] + [cst2ast(hr) | hr <- tail]
  );

// ─── HoldRef ─────────────────────────────────────────────────────────────────

HoldRefAST cst2ast((HoldRef) `<HoldId hid>`) =
  single("<hid>");

HoldRefAST cst2ast((HoldRef) `( <HoldId first> <("," HoldId rest)*  tail> )`) =
  subRoute(["<first>"] + ["<h>" | h <- tail]);

// ─── Hold ────────────────────────────────────────────────────────────────────

HoldAST cst2ast((Hold) `hold <HoldId hid>
                     <HoldPosition hp> ,
                     shape <ShapeId shape> ,
                     colours <{Colour ","}+ colours> ,
                     <Rotation? rot>
                     <HoldLabel* labels>`) =
  hold(
    "<hid>",
    cst2ast(hp),
    "<shape>",
    ["<c>" | c <- colours],     // sep list: iterate directly
    cst2astRotation(rot),
    [cst2ast(l) | l <- labels]
  );

// ─── Rotation (Maybe) ────────────────────────────────────────────────────────

/*
 * Rotation? produces an optional node. We pattern-match on the two possible
 * shapes: a present Rotation node, or an empty optional.
 */
MaybeInt cst2astRotation((Rotation?) `rotation <Integer n> ,`) =
  just(toInt("<n>"));

MaybeInt cst2astRotation((Rotation?) ``) =
  nothing();

// ─── HoldPosition ─────────────────────────────────────────────────────────────

HoldPositionAST cst2ast((HoldPosition) `pos <Pos p>`) =
  xyPos(cst2ast(p));

HoldPositionAST cst2ast((HoldPosition) `pos angle <Integer n>`) =
  anglePos(toInt("<n>"));

// ─── Pos ─────────────────────────────────────────────────────────────────────

PosAST cst2ast((Pos) `x <Integer x> , y <Integer y>`) =
  pos(toInt("<x>"), toInt("<y>"));

// ─── HoldLabel ────────────────────────────────────────────────────────────────

HoldLabelAST cst2ast((HoldLabel) `starthold <StartNum n> ,`) =
  startHold(cst2astStartNum(n));

HoldLabelAST cst2ast((HoldLabel) `endhold`) =
  endHold();

int cst2astStartNum((StartNum) `1`) = 1;
int cst2astStartNum((StartNum) `2`) = 2;

// ─── Volume ───────────────────────────────────────────────────────────────────

VolumeAST cst2ast((Volume) `circle
                          pos <Pos p> ,
                          depth <Integer d> ,
                          radius <Integer r> ,
                          <CircleHoldSection* circleSections>`) =
  circle(
    cst2ast(p),
    toInt("<d>"),
    toInt("<r>"),
    [cst2ast(s) | s <- circleSections]
  );

VolumeAST cst2ast((Volume) `triangle
                          pos <Pos p> ,
                          extrusion <Pos ext> ,
                          depth <Integer d> ,
                          corners <Pos c1> , <Pos c2> , <Pos c3> ,
                          <TriangleHoldSection* triangleSections>`) =
  triangle(
    cst2ast(p),
    cst2ast(ext),
    toInt("<d>"),
    [cst2ast(c1), cst2ast(c2), cst2ast(c3)],
    [cst2ast(s) | s <- triangleSections]
  );

// ─── CircleHoldSection ────────────────────────────────────────────────────────

CircleHoldSectionAST cst2ast((CircleHoldSection) `frontholds <Hold+ hs> <","?>`) =
  frontHolds([cst2ast(h) | h <- hs]);

CircleHoldSectionAST cst2ast((CircleHoldSection) `sideholds <Hold+ hs> <","?>`) =
  sideHolds([cst2ast(h) | h <- hs]);

// ─── TriangleHoldSection ──────────────────────────────────────────────────────

TriangleHoldSectionAST cst2ast((TriangleHoldSection) `leftholds <Hold+ hs> <","?>`) =
  leftHolds([cst2ast(h) | h <- hs]);

TriangleHoldSectionAST cst2ast((TriangleHoldSection) `rightholds <Hold+ hs> <","?>`) =
  rightHolds([cst2ast(h) | h <- hs]);

TriangleHoldSectionAST cst2ast((TriangleHoldSection) `bottomholds <Hold+ hs> <","?>`) =
  bottomHolds([cst2ast(h) | h <- hs]);