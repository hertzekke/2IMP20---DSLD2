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

 Some rules are implicitely checked, such as rule 16. We defined in Syntax.rsc only 2 types of volumes.
 Other rules (logic-centric) are checked here, as seen above.
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
  bool routesHaveEnoughHolds = all(route(_, _, _, holds) <- wall.routes, size(holds) >= 2);

  // Rule 3: Every route must have between zero and two hand start holds
  bool startingLabelLimit = checkStartingHoldsTotalLimit(wall);

  // Rule 4: At most one split per route, with exactly two sub-routes per split
  bool splitLimit = checkMaxOneSplitWithExactlyTwoBranches(wall);

  // Rule 7: At most two end_holds if split, at most one if not
  bool unique_end_hold = checkUniqueEndHold(wall);

  // Rule 8: No re-split after a merge (split-merge-split is invalid)
  bool noReSplit = checkNoSplitAfterMerge(wall);

  // Rule 11: All holds in a route share at least one common colour
  bool colours = checkRoutesColoursIntersection(wall);

  // Rule 12: "Every hold must have a position (defined by x and y, or by an angle), a shape, and colour."
  // Rule 13: "If a hold position is defined by an angle, the angle must be between 0 and 359."
  // Rule 14: "Holds may have a rotation property. If a hold has a rotation, its value must be between 0 and 359."
  bool holdProperties = checkHoldProperties(wall);

  return (hasVolumesAndRoutes && routesHaveEnoughHolds && startingLabelLimit
          && splitLimit && unique_end_hold && noReSplit
          && colours && holdProperties);
}

/* **************************************************
 *         Rule 3: Start Hold Limit                 *
 ************************************************** */
// Besides the rule, from the assignment says "A hold can be labelled as a start_hold, which takes either 1 or 2 as an argument"
bool checkStartingHoldsTotalLimit(BoulderWallAST wall) {
  for (route(_, _, _, holds) <- wall.routes) {
    int totalStarts = 0;
    for (holdRef <- holds) {
      // Design Decision: look up hold attributes directly for non-split hold references
      if (single(id) := holdRef) {
        for (h <- findHoldById(wall, id)) {
          for (label <- h.labels) {
            if (startHold(_) := label) totalStarts += 1;
          }
        }
      }
      // Design Decision: iterate over all sub-route hold IDs to look up holds for split route references
      else if (subRoute(branchHoldIds) := holdRef) {
        for (id <- branchHoldIds) {
          for (h <- findHoldById(wall, id)) {
            for (label <- h.labels) {
              if (startHold(_) := label) totalStarts += 1;
            }
          }
        }
      }
    }
    // From assignment: maximum of two starting holds per route
    if (totalStarts > 2) {
      println("Route does not have a maximum of 2 starting holds per route");
      return false;
    }
  }
  return true;
}

/* **************************************************
 *      Rule 4: Max One Split Per Route             *
 ************************************************** */
bool checkMaxOneSplitWithExactlyTwoBranches(BoulderWallAST wall) {
  for (route(_, _, _, holds) <- wall.routes) {
    for (holdRef <- holds) {
      if (subRoute(branchHoldIds) := holdRef) {
        if (size(branchHoldIds) != 2) {
          println("Route has a sub-route group with more or less than 2 branches (expected exactly 2)");
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
// Besides rule, from assignment: "If there are sub-routes, then each sub-route may have an end hold."
bool checkUniqueEndHold(BoulderWallAST wall){
  for (route(_, _, _, holds) <- wall.routes) {
    int endCount = 0;
    bool hasSplit = false;
    for (holdRef <- holds) {
      switch(holdRef) {
        // Look up hold attributes for non-split hold references
        case single(id): {
          for (h <- findHoldById(wall, id)) {
            for (label <- h.labels) {
              if (endHold() := label) endCount += 1;
            }
          }
        }
        // From assignment description
        case subRoute(branchHoldIds): {
          hasSplit = true;
          for (id <- branchHoldIds) {
            for (h <- findHoldById(wall, id)) {
              for (label <- h.labels) {
                if (endHold() := label) endCount += 1;
              }
            }
          }
        }
      }
    }
    // Rule 7 enforcment
    if (hasSplit) {
      if (endCount > 2) {
        println("Route has too many end holds for a split route");
        return false;
      }
    }
    else {
      if (endCount > 1) {
        println("Route has more than one end hold");
        return false;
      }
    }
  }
  return true;
}

/* **************************************************
 *      Rule 8: No Split After Merge                *
 ************************************************** */
// In short, we track state using a simple state machine: 0 (before split), 1 (in split), 2 (merged)
// if subRoute appears in state 2, there's a rule violation
bool checkNoSplitAfterMerge(BoulderWallAST wall) {
  for (route(_, _, _, holds) <- wall.routes) {
    int state = 0;
    for (holdRef <- holds) {
      if (subRoute(_) := holdRef) {
        if (state == 0) {
          state = 1;
        } else if (state == 2) {
          println("Route has a split after a merge, see Rule 8");
          return false;
        }
      } else {
        if (state == 1) {
          state = 2; // Transition from split to single = merge
        }
      }
    }
  }
  return true;
}

/* **************************************************
 *    Rules 12, 13, 14: Hold Properties             *
 ************************************************** */
bool checkHoldProperties(BoulderWallAST wall) {
  for (v <- wall.volumes) {
    for (h <- volumeHolds(v)) {
      // Design Decision: CST2AST tracks whether pos was present via a boolean flag (posProvided).
      // Without this, a missing position is defaulting to (0,0).
      if (!h.posProvided) { println("Hold " + h.holdId + " missing position"); return false; }
      // Rule 12: shape must be present
      if (h.shape == "") { println("Hold " + h.holdId + " missing shape"); return false; }
      // Rule 12: at least one colour must be present
      if (size(h.colours) == 0) { println("Hold " + h.holdId + " missing colours"); return false; }
      // Rule 13: if position is an angle, it must be in [0, 359]
      if (anglePos(a) := h.pos) {
        if (a < 0 || a > 359) { println("Hold " + h.holdId + " angle out of range"); return false; }
      }
      // Rule 14: if rotation is present, it must be in [0, 359]
      if (just(rot) := h.rotation) {
        if (rot < 0 || rot > 359) { println("Hold " + h.holdId + " rotation out of range"); return false; }
      }
    }
  }
  return true;
}

/* **************************************************
 *      Volume Hold Extraction Helper               *
 ************************************************** */
// Helper function to extract all holds from a volume (circle or triangle). Used by multiple check functions that go over all holds defined in a wall
list[HoldAST] volumeHolds(VolumeAST v) {
  if (circle(_, _, _, sections) := v) {
    list[HoldAST] extractedHolds = [];
    for (s <- sections) {
      if (frontHolds(sectionHolds) := s) {
        extractedHolds += sectionHolds;
      } else if (sideHolds(sectionHolds) := s) {
        extractedHolds += sectionHolds;
      }
    }
    return extractedHolds;
  }
  else if (triangle(_, _, _, _, sections) := v) {
    list[HoldAST] extractedHolds = [];
    for (s <- sections) {
      if (leftHolds(sectionHolds) := s) {
        extractedHolds += sectionHolds;
      } else if (rightHolds(sectionHolds) := s) {
        extractedHolds += sectionHolds;
      } else if (bottomHolds(sectionHolds) := s) {
        extractedHolds += sectionHolds;
      }
    }
    return extractedHolds;
  }
  return [];
}

/* **************************************************
 *    Rule 11: Common Colour Across Route Holds     *
 ************************************************** */
// In short, we collect all holds' colours and check if they share at least one common colour.
bool checkRoutesColoursIntersection(BoulderWallAST wall) {
  for (route(_, _, _, holds) <- wall.routes) {
    list[list[str]] allColours = [];
    for (holdRef <- holds) {
      // if hold is part of main route, take its colour
      if (single(id) := holdRef) {
        for (h <- findHoldById(wall, id)) allColours += [h.colours];
        // if hold is part of sub route, take its colour
      } else if (subRoute(branchHoldIds) := holdRef) {
        for (id <- branchHoldIds) {
          for (h <- findHoldById(wall, id)) allColours += [h.colours];
        }
      }
    }
    // prevents accessing an array list of size 0, throwing error
    if (size(allColours) == 0) { println("Route references unknown holds"); return false; }
    list[str] interList = allColours[0]; // first hold's colours
    // get the intersection of colors for all holds
    for (i <- [1..size(allColours)]) {
      list[str] next = allColours[i];
      interList = [c | c <- interList, c in next]; 
    }
    // invalid if they share no common color
    if (size(interList) == 0) { println("Route has no common colour across its holds"); return false; }
  }
  return true;
}

// Helper function to find a hold by its ID across all volumes in the wall. Returns list with matching hold if ID matches, empty list otherwise.
// Design decision: rascal has no null values (from Rascal's 0.42.2 docs: "Rascal is safe: there are no null values"). Thus, 
// if the list is empty, it means the hold was not found. If it has one element, then the hold has been found. It's easier
// to check after size().
list[HoldAST] findHoldById(BoulderWallAST wall, str id) {
  for (v <- wall.volumes) {
    for (h <- volumeHolds(v)) {
      if (h.holdId == id) return [h];
    }
  }
  return [];
}
