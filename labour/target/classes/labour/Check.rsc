module labour::Check

import labour::AST;
import labour::Parser;
import labour::CST2AST;

import IO;
import List;
import Set;
import Prelude;
import String;


/*
 * Implement a well-formedness checker for the LaBouR language. For this you must use the AST.
 * - Hint: Map regular CST arguments (e.g., *, +, ?) to lists
 * - Hint: Map lexical nodes to Rascal primitive types (bool, int, str)
 * - Hint: Use switch to do case distinction with concrete patterns
 */

/*
 * Define a function per each verification defined in the PDF (Section 2.2.)
 * Some examples are provided below.
 */

bool checkBoulderWallConfiguration(BoulderingWall wall){
  bool hasVolumesAndRoutes = (size(wall.routes) > 0 && size(wall.volumes) > 0);

  bool routesHaveEnoughHolds = checkNumberOfHolds(wall);
  bool startingLabelLimit = checkStartingHoldsTotalLimit(wall);
  bool unique_end_hold = checkUniqueEndHold(wall);

  bool idFormat = checkHoldIdFormat(wall);
  bool holdProperties = checkHoldProperties(wall);
  bool colours = checkRoutesColoursIntersection(wall);

  return (hasVolumesAndRoutes && routesHaveEnoughHolds && startingLabelLimit && unique_end_hold && idFormat && holdProperties && colours);
}


// Check that there are at least two holds in the wall
bool checkNumberOfHolds(BoulderingWall wall) {
  // Check each route has two or more holds
  for (bRoute(rid, g, gbp, holds) <- wall.routes) {
    if (size(holds) < 2) {
      println("Route has fewer than two holds: " + rid);
      return false;
    }
  }
  return true;
}

// Check that routes have between zero and two hand start holds
bool checkStartingHoldsTotalLimit(BoulderingWall wall) {
  for (bRoute(rid, g, gbp, holds) <- wall.routes) {
    int totalStarts = 0;
    for (hr <- holds) {
      switch(hr) {
        case single(id): {
          Hold? h = findHoldById(wall, id);
          if (h != null) {
            switch(h) {
              case hold(_, _, _, _, _, sl, _): if (sl > 0) totalStarts += 1;
            }
          }
        }
        case split(ids): {
          for (id <- ids) {
            Hold? h = findHoldById(wall, id);
            if (h != null) {
              switch(h) {
                case hold(_, _, _, _, _, sl, _): if (sl > 0) totalStarts += 1;
              }
            }
          }
        }
      }
    }
    if (totalStarts < 0 || totalStarts > 2) {
      println("Route " + rid + " has invalid number of start holds: " + toString(totalStarts));
      return false;
    }
  }
  return true;
}

// This function will insure that there is only one hold assign to end hold
bool checkUniqueEndHold(BoulderingWall wall){
  for (bRoute(rid, g, gbp, holds) <- wall.routes) {
    int endCount = 0;
    bool hasSplit = false;
    for (hr <- holds) {
      switch(hr) {
        case single(id): {
          Hold? h = findHoldById(wall, id);
          if (h != null) {
            switch(h) { case hold(_, _, _, _, _, _, eh): { if (eh) endCount += 1; } }
          }
        }
        case split(ids): {
          hasSplit = true;
          for (id <- ids) {
            Hold? h = findHoldById(wall, id);
            if (h != null) { switch(h) { case hold(_, _, _, _, _, _, eh): { if (eh) endCount += 1; } } }
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

// Check hold id format: exactly four digits
bool checkHoldIdFormat(BoulderingWall wall) {
  for (v <- wall.volumes) {
    for (h <- volumeHolds(v)) {
      switch(h) {
        case hold(id, _, _, _, _, _, _): if (!matchHoldId(id)) { println("Hold id " + id + " is not four digits"); return false; }
      }
    }
  }
  return true;
}

bool matchHoldId(str id) {
  return regex("^[0-9]{4}$").match(id);
}

// Check that each hold has required properties (position, shape, colours)
bool checkHoldProperties(BoulderingWall wall) {
  for (v <- wall.volumes) {
    for (h <- volumeHolds(v)) {
      switch(h) {
        case hold(id, pos, shape, colours, rotation, startLabel, endHold): {
          if (shape == "") { println("Hold " + id + " missing shape"); return false; }
          if (size(colours) == 0) { println("Hold " + id + " missing colours"); return false; }
          switch(pos) {
            case posXY(x,y): break;
            case posAngle(a): if (a < 0 || a > 359) { println("Hold " + id + " angle out of range"); return false; }
          }
          if (rotation >= 0 && (rotation < 0 || rotation > 359)) { println("Hold " + id + " rotation out of range"); return false; }
          for (c <- colours) { if (!isValidColour(c)) { println("Hold " + id + " has invalid colour " + c); return false; } }
        }
      }
    }
  }
  return true;
}

bool isValidColour(str c) {
  set[str] valid = {"white","yellow","green","blue","red","purple","pink","black","orange"};
  return c in valid;
}

list[Hold] volumeHolds(Volume v) {
  switch(v) {
    case circle(p,d,r,front,side): return front + side;
    case triangle(p,e,d,corners,left,right,bottom): return left + right + bottom;
  }
}

// For each route, ensure all holds referenced share at least one colour
bool checkRoutesColoursIntersection(BoulderingWall wall) {
  for (bRoute(rid, g, gbp, holds) <- wall.routes) {
    list[list[str]] allColours = [];
    for (hr <- holds) {
      switch(hr) {
        case single(id): {
          Hold? h = findHoldById(wall,id);
          if (h != null) { switch(h) { case hold(_,_,_,cols,_,_,_): { allColours += [cols]; } } }
        }
        case split(ids): {
          for (id <- ids) {
            Hold? h = findHoldById(wall,id);
            if (h != null) { switch(h) { case hold(_,_,_,cols,_,_,_): { allColours += [cols]; } } }
          }
        }
      }
    }
    if (size(allColours) == 0) { println("Route " + rid + " references unknown holds"); return false; }
    list[str] interList = allColours[0];
    for (i <- [1..size(allColours)-1]) {
      list[str] next = allColours[i];
      interList = [c | c <- interList, c in next];
    }
    if (size(interList) == 0) { println("Route " + rid + " has no common colour across its holds"); return false; }
  }
  return true;
}

// Find a hold by id in the wall; returns null if not found
Hold? findHoldById(BoulderingWall wall, str id) {
  for (v <- wall.volumes) {
    for (h <- volumeHolds(v)) {
      switch(h) { case hold(hid, _, _, _, _, _, _): if (hid == id) return h; }
    }
  }
  return null;
}
