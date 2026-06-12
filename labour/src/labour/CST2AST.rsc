module labour::CST2AST

import labour::Syntax;
import labour::AST;
import String;

/*
 * Design Decisions for CST2AST (The Mapping Bridge)
 *
 * - Manual Mapping Bridge: Takes the Concrete Syntax Tree (CST) node produced by 
 *   Syntax.rsc and manually maps it to the corresponding clean AST node in AST.rsc.
 * - Stripping Syntactic Noise: It strips syntactic elements like matching quotes 
 *   (using the `unquote` helper), braces, and commas, keeping only the underlying data.
 * - Extensibility: Constructs AST nodes by pattern-matching the CST. It currently 
 *   works well for the provided example inputs but may require hardening for every 
 *   edge case of the grammar (e.g., optional fields, alternate whitespace, reordering).
 */

BoulderWallAST cst2ast(start[BoulderingWall] pt) {
  return cst2ast(pt.top);
}

str unquote(str s) = substring(s, 1, size(s)-1);

// ─── BoulderingWall ─────────────────────────────────────────────────────────

BoulderWallAST cst2ast((BoulderingWall)`bouldering_wall <WallId wid> { routes [ <{Route ","}* rs> ] , volumes [ <{Volume ","}* vs> ] }`) =
  boulderWall(unquote("<wid>"), [cst2ast(r) | r <- rs], [cst2ast(v) | v <- vs]);

BoulderWallAST cst2ast((BoulderingWall)`bouldering_wall <WallId wid> { routes [ <{Route ","}* rs> ] volumes [ <{Volume ","}* vs> ] }`) =
  boulderWall(unquote("<wid>"), [cst2ast(r) | r <- rs], [cst2ast(v) | v <- vs]);

// ─── Route ───────────────────────────────────────────────────────────────────

RouteAST cst2ast((Route)`bouldering_route <RouteId rid> { grade: <ShapeId gr> , grid_base_point <Pos gp> , holds [ <{HoldRef ","}+ hrs> ] }`) =
  route(unquote("<rid>"), unquote("<gr>"), cst2ast(gp), [cst2ast(hr) | hr <- hrs]);

HoldRefAST cst2ast((HoldRef)`<HoldId hid>`) = single(unquote("<hid>"));
HoldRefAST cst2ast((HoldRef)`{ <{HoldId ","}+ ids> }`) = subRoute([unquote("<id>") | id <- ids]);

// ─── Hold ────────────────────────────────────────────────────────────────────

HoldAST cst2ast((Hold)`hold <HoldId hid> { <{HoldProperty ","}* props> }`) {
  HoldPositionAST pos = xyPos(pos(0,0)); 
  str shape = "";
  list[str] colours = [];
  MaybeInt rot = nothing();
  list[HoldLabelAST] labels = [];
  bool posProvided = false;

  for (HoldProperty prop <- props) {
    if ((HoldProperty)`pos: <HoldPosition hp>` := prop) { pos = cst2ast(hp); posProvided = true; }
    else if ((HoldProperty)`shape: <ShapeId sh>` := prop) shape = unquote("<sh>");
    else if ((HoldProperty)`colours [ <{Colour ","}+ cols> ]` := prop) colours = ["<c>" | c <- cols];
    else if ((HoldProperty)`rotation: <Integer n>` := prop) rot = just(toInt("<n>"));
    else if ((HoldProperty)`start_hold: <StartHold n>` := prop) labels += startHold(toInt("<n>"));
    else if ((HoldProperty)`end_hold` := prop) labels += endHold();
  }

  return hold(unquote("<hid>"), pos, shape, colours, rot, labels, posProvided);
}

// ─── HoldPosition ─────────────────────────────────────────────────────────────

HoldPositionAST cst2ast((HoldPosition)`<Pos p>`) = xyPos(cst2ast(p));
HoldPositionAST cst2ast((HoldPosition)`{ angle: <Integer n> }`) = anglePos(toInt("<n>"));

// ─── Pos ─────────────────────────────────────────────────────────────────────

PosAST cst2ast((Pos)`{ x: <Integer x> , y: <Integer y> }`) = pos(toInt("<x>"), toInt("<y>"));

// ─── Volume ───────────────────────────────────────────────────────────────────

VolumeAST cst2ast((Volume)`circle { pos: <Pos p> , depth: <Integer d> , radius: <Integer r> , <{CircleHolds ","}* circleSections> }`) =
  circle(cst2ast(p), toInt("<d>"), toInt("<r>"), [cst2ast(s) | s <- circleSections]);

VolumeAST cst2ast((Volume)`triangle { pos: <Pos p> , extrusion: <Pos ext> , depth: <Integer d> , corners [ <Pos c1> , <Pos c2> , <Pos c3> ] , <{TriangleHolds ","}* triangleSections> }`) =
  triangle(cst2ast(p), cst2ast(ext), toInt("<d>"), [cst2ast(c1), cst2ast(c2), cst2ast(c3)], [cst2ast(s) | s <- triangleSections]);

// ─── CircleHoldSection ────────────────────────────────────────────────────────

CircleHoldSectionAST cst2ast((CircleHolds)`front_holds [ <{Hold ","}* hs> ]`) = frontHolds([cst2ast(h) | h <- hs]);
CircleHoldSectionAST cst2ast((CircleHolds)`side_holds [ <{Hold ","}* hs> ]`)  = sideHolds([cst2ast(h) | h <- hs]);

// ─── TriangleHolds ──────────────────────────────────────────────────────

TriangleHoldSectionAST cst2ast((TriangleHolds)`left_holds [ <{Hold ","}* hs> ]`)   = leftHolds([cst2ast(h) | h <- hs]);
TriangleHoldSectionAST cst2ast((TriangleHolds)`right_holds [ <{Hold ","}* hs> ]`)  = rightHolds([cst2ast(h) | h <- hs]);
TriangleHoldSectionAST cst2ast((TriangleHolds)`bottom_holds [ <{Hold ","}* hs> ]`) = bottomHolds([cst2ast(h) | h <- hs]);