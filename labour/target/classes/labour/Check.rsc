/* 
This fil verifies all semantic constraints from the assignment description
 that were not checked/enforced at the grammar level (Syntax.rsc).
 
 Syntax.rsc already handles:
 - Rule 5: Route must have grade, grid_base_point, identifier
 - Rule 6: grid_base_point has x and y components
 - Rule 9: Hold IDs are made up of 4 digits
 - Rule 10: Wall/route IDs are made up of any alphanumeric characters
 - Rule 15: Colour values only from a set of 9 colours
 - Rule 16: Only circle and triangle volumes are allowed
 - Rule 17: Circular volume has position, depth, radius
 - Rule 18: Circle only has front/side holds
 - Rule 19: Triangle has position, depth, extrusion, 3 corners
 - Rule 20: Triangle only has left/right/bottom holds
*/

module labour::Check

import labour::AST;
import labour::Parser;
import labour::CST2AST;

import IO;
import List;
import Set;
import Prelude;
import String;

/* **************************************************
 *      Main Well-formedness Check Function         *
 ************************************************** */
// From assignment: "checkBoulderRouteConfiguration(...) takes the AST of a bouldering route
// as parameter and verifies that all well-formedness checks succeed"
bool checkBoulderRouteConfiguration(BoulderWallAST wall){
  // Rule 1: Every wall must have at least one volume and one route
  bool hasVolumesAndRoutes = (size(wall.routes) >= 1 && size(wall.volumes) >= 1);

  // Rule 2: Every route must have two or more holds
  bool routesHaveEnoughHolds = checkNumberOfHolds(wall);

  // Rule 3: Every route must have between zero and two hand start holds
  bool startingLabelLimit = checkStartingHoldsTotalLimit(wall);

  // Rule 4: At most one split per route, with exactly two sub-routes per split
  bool splitLimit = checkMaxOneSplit(wall);

  // Rule 7: At most two end_holds if split, at most one if not
  bool unique_end_hold = checkUniqueEndHold(wall);

  // Rule 8: No re-split after a merge (split-merge-split is invalid)
  bool noReSplit = checkNoSplitAfterMerge(wall);

  // Rule 11: All holds in a route share at least one common colour
  bool colours = checkRoutesColoursIntersection(wall);

  // Rule 12, 13, 14: Hold property presence and range validation
  bool holdProperties = checkHoldProperties(wall);

  return (hasVolumesAndRoutes && routesHaveEnoughHolds && startingLabelLimit
          && splitLimit && unique_end_hold && noReSplit
          && colours && holdProperties);
}

/* **************************************************
 *         Rule 2: Route Hold Count                 *
 ************************************************** */
// Rule 2: "Every route must have two or more holds."
bool checkNumberOfHolds(BoulderWallAST wall) {
  for (route(rid, g, gbp, holds) <- wall.routes) {
    if (size(holds) < 2) {
      println("Route has fewer than two holds: " + rid);
      return false;
    }
  }
  return true;
}

/* **************************************************
 *         Rule 3: Start Hold Limit                 *
 ************************************************** */
// Rule 3: "Every route must have between zero and two hand start holds."
// From assignment: "A hold can be labelled as a start_hold, which takes either 1 or 2 as an argument"
// From assignment: "There can be a maximum of two starting holds [...] per route"
bool checkStartingHoldsTotalLimit(BoulderWallAST wall) {
  for (route(rid, g, gbp, holds) <- wall.routes) {
    int totalStarts = 0;
    for (hr <- holds) {
      switch(hr) {
        case single(id): {
          list[HoldAST] hs = findHoldById(wall, id);
          for (h <- hs) {
            for (lbl <- h.labels) {
              if (startHold(_) := lbl) totalStarts += 1;
            }
          }
        }
        case subRoute(ids): {
          for (id <- ids) {
            list[HoldAST] hs = findHoldById(wall, id);
            for (h <- hs) {
              for (lbl <- h.labels) {
                if (startHold(_) := lbl) totalStarts += 1;
              }
            }
          }
        }
      }
    }
    // From assignment: maximum of two starting holds per route
    if (totalStarts > 2) {
      println("Route " + rid + " has invalid number of start holds: " + toString(totalStarts));
      return false;
    }
  }
  return true;
}

/* **************************************************
 *      Rule 4: Max One Split Per Route             *
 ************************************************** */
// Split must branch into exactly 2 sub-routes; less or more is invalid.
bool checkMaxOneSplit(BoulderWallAST wall) {
  for (route(rid, g, gbp, holds) <- wall.routes) {
    for (hr <- holds) {
      if (subRoute(ids) := hr) {
        // From assignment: "no more than two sub-routes" — each sub-route group must have exactly 2 branches
        if (size(ids) != 2) {
          println("Route " + rid + " has a sub-route group with " + toString(size(ids)) + " branches (expected exactly 2)");
          return false;
        }
      }
    }
  }
  return true;
}

/* **************************************************
 *      Rule 7: End Hold Limit                      *
 ************************************************** */
// Rule 7: "Every route has at most two holds indicated as end_hold if it splits into sub-routes,
//          and at most one end_hold if it does not split."
// From assignment: "If there are sub-routes, then each sub-route may have an end hold."
bool checkUniqueEndHold(BoulderWallAST wall){
  for (route(rid, g, gbp, holds) <- wall.routes) {
    int endCount = 0;
    bool hasSplit = false;
    for (hr <- holds) {
      switch(hr) {
        case single(id): {
          list[HoldAST] hs = findHoldById(wall, id);
          for (h <- hs) {
            for (lbl <- h.labels) {
              if (endHold() := lbl) endCount += 1;
            }
          }
        }
        case subRoute(ids): {
          hasSplit = true;
          for (id <- ids) {
            list[HoldAST] hs = findHoldById(wall, id);
            for (h <- hs) {
              for (lbl <- h.labels) {
                if (endHold() := lbl) endCount += 1;
              }
            }
          }
        }
      }
    }
    if (hasSplit) {
      if (endCount > 2) {
        println("Route " + rid + " has too many end holds for a split route");
        return false;
      }
    }
    else {
      if (endCount > 1) {
        println("Route " + rid + " has more than one end hold");
        return false;
      }
    }
  }
  return true;
}

/* **************************************************
 *      Rule 8: No Split After Merge                *
 ************************************************** */
// Rule 8: "In a route, after a split, there should be no new split if there was a merge before."
// From assignment listing 5: holds ["0001", "0002", {"0003", "0004"}, "0007", {"0005", "0006"}]
//                                                   > Split           > Merge   > Split (INVALID)
// Design Decision: we track state using a simple state machine:
//   0 (BEFORE_SPLIT) -> 1 (IN_SPLIT) -> 2 (MERGED) -> seeing subRoute in state 2 = error
bool checkNoSplitAfterMerge(BoulderWallAST wall) {
  for (route(rid, g, gbp, holds) <- wall.routes) {
    int state = 0;
    for (hr <- holds) {
      switch(hr) {
        case subRoute(_): {
          if (state == 0) {
            state = 1; // First split encountered
          } else if (state == 2) {
            // Re-split after merge: invalid per Rule 8
            println("Route " + rid + " has a split after a merge (split-merge-split is not allowed, see Rule 8)");
            return false;
          }
          // state == 1: still within the same split region, OK
        }
        case single(_): {
          if (state == 1) {
            state = 2; // Transition from split to single = merge
          }
          // state == 0: still before any split, OK
          // state == 2: after merge, still on single holds, OK
        }
      }
    }
  }
  return true;
}

/* **************************************************
 *    Rules 12, 13, 14: Hold Properties             *
 ************************************************** */
// Rule 12: "Every hold must have a position (defined by x and y, or by an angle), a shape, and colour."
// Rule 13: "If a hold position is defined by an angle, the angle must be between 0 and 359."
// Rule 14: "Holds may have a rotation property. If a hold has a rotation, its value must be between 0 and 359."
bool checkHoldProperties(BoulderWallAST wall) {
  for (v <- wall.volumes) {
    for (h <- volumeHolds(v)) {
      // Rule 12: position must have been explicitly provided
      // Design Decision: CST2AST tracks whether pos: was present via a boolean flag (posProvided).
      // Without this, a missing position would silently default to (0,0).
      if (!h.posProvided) { println("Hold " + h.holdId + " missing position"); return false; }
      // Rule 12: shape must be present
      if (h.shape == "") { println("Hold " + h.holdId + " missing shape"); return false; }
      // Rule 12: at least one colour must be present
      if (size(h.colours) == 0) { println("Hold " + h.holdId + " missing colours"); return false; }
      // Rule 13: if position is an angle, it must be in [0, 359]
      switch(h.pos) {
        case xyPos(_): ; // OK — x/y positions have no range constraint from the assignment
        case anglePos(a): if (a < 0 || a > 359) { println("Hold " + h.holdId + " angle out of range"); return false; }
      }
      // Rule 14: if rotation is present, it must be in [0, 359]
      switch(h.rotation) {
        case just(rot): if (rot < 0 || rot > 359) { println("Hold " + h.holdId + " rotation out of range"); return false; }
        case nothing(): ; // OK — rotation is optional per Rule 14
      }
      // Rule 15: each colour must be valid
      // [!] Also enforced by grammar (Colour lexical), but checked here for robustness.
      for (c <- h.colours) { if (!isValidColour(c)) { println("Hold " + h.holdId + " has invalid colour " + c); return false; } }
    }
  }
  return true;
}

// Rule 15: "The colour values used must be valid. For now, we assume valid colours to be
//           white, yellow, green, blue, red, purple, pink, black, and orange."
bool isValidColour(str c) {
  set[str] valid = {"white","yellow","green","blue","red","purple","pink","black","orange"};
  return c in valid;
}

/* **************************************************
 *      Volume Hold Extraction Helper               *
 ************************************************** */
// Helper: extracts all holds from a volume (circle or triangle) regardless of hold section type.
// This is used by multiple check functions to iterate over all physical holds defined in the wall.
list[HoldAST] volumeHolds(VolumeAST v) {
  switch(v) {
    case circle(_, _, _, sections): {
      list[HoldAST] res = [];
      for (s <- sections) {
        switch(s) {
          case frontHolds(hs): res += hs;
          case sideHolds(hs): res += hs;
        }
      }
      return res;
    }
    case triangle(_, _, _, _, sections): {
      list[HoldAST] res = [];
      for (s <- sections) {
        switch(s) {
          case leftHolds(hs): res += hs;
          case rightHolds(hs): res += hs;
          case bottomHolds(hs): res += hs;
        }
      }
      return res;
    }
  }
  return [];
}

/* **************************************************
 *    Rule 11: Common Colour Across Route Holds     *
 ************************************************** */
// Rule 11: "The holds in a bouldering route must all have the same colour.
//           In multicoloured holds, the intersection of the colour lists must be non-empty.
//           The order of the colours in a multicoloured hold is not relevant."
// Design Decision: we compute the running intersection of all hold colour lists in the route.
// For each subsequent hold, we filter the running intersection to keep only colours present in both.
bool checkRoutesColoursIntersection(BoulderWallAST wall) {
  for (route(rid, g, gbp, holds) <- wall.routes) {
    list[list[str]] allColours = [];
    for (hr <- holds) {
      switch(hr) {
        case single(id): {
          list[HoldAST] hs = findHoldById(wall,id);
          for (h <- hs) allColours += [h.colours];
        }
        case subRoute(ids): {
          for (id <- ids) {
            list[HoldAST] hs = findHoldById(wall,id);
            for (h <- hs) allColours += [h.colours];
          }
        }
      }
    }
    if (size(allColours) == 0) { println("Route " + rid + " references unknown holds"); return false; }
    // Compute running intersection: start with the first hold's colours, then intersect with each subsequent hold
    list[str] interList = allColours[0];
    for (i <- [1..size(allColours)]) {
      list[str] next = allColours[i];
      interList = [c | c <- interList, c in next];
    }
    if (size(interList) == 0) { println("Route " + rid + " has no common colour across its holds"); return false; }
  }
  return true;
}

/* **************************************************
 *      Hold Lookup Helper                          *
 ************************************************** */
// Helper: finds a hold by its ID across all volumes in the wall.
// Returns a list with the matching hold, or an empty list if not found.
// From assignment: holds are defined inside volumes and referenced by ID in routes.
list[HoldAST] findHoldById(BoulderWallAST wall, str id) {
  for (v <- wall.volumes) {
    for (h <- volumeHolds(v)) {
      if (h.holdId == id) return [h];
    }
  }
  return [];
}
