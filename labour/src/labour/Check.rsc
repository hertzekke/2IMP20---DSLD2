module labour::Check

import labour::AST;
import labour::Parser;
import labour::CST2AST;

import IO;
import List;
import Set;
import Prelude;
import String;

bool checkBoulderingWall(BoulderWallAST wall){
  bool hasVolumesAndRoutes = (size(wall.routes) > 0 && size(wall.volumes) > 0);

  bool routesHaveEnoughHolds = checkNumberOfHolds(wall);
  bool startingLabelLimit = checkStartingHoldsTotalLimit(wall);
  bool unique_end_hold = checkUniqueEndHold(wall);

  bool idFormat = checkHoldIdFormat(wall);
  bool holdProperties = checkHoldProperties(wall);
  bool colours = checkRoutesColoursIntersection(wall);

  return (hasVolumesAndRoutes && routesHaveEnoughHolds && startingLabelLimit && unique_end_hold && idFormat && holdProperties && colours);
}

bool checkNumberOfHolds(BoulderWallAST wall) {
  for (route(rid, g, gbp, holds) <- wall.routes) {
    if (size(holds) < 2) {
      println("Route has fewer than two holds: " + rid);
      return false;
    }
  }
  return true;
}

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
    if (totalStarts < 0 || totalStarts > 2) {
      println("Route " + rid + " has invalid number of start holds: " + toString(totalStarts));
      return false;
    }
  }
  return true;
}

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

bool checkHoldIdFormat(BoulderWallAST wall) {
  for (v <- wall.volumes) {
    for (h <- volumeHolds(v)) {
      if (!matchHoldId(h.holdId)) { 
        println("Hold id " + h.holdId + " is not four digits"); 
        return false; 
      }
    }
  }
  return true;
}

bool matchHoldId(str id) {
  return /^[0-9]{4}$/ := id;
}

bool checkHoldProperties(BoulderWallAST wall) {
  for (v <- wall.volumes) {
    for (h <- volumeHolds(v)) {
      if (h.shape == "") { println("Hold " + h.holdId + " missing shape"); return false; }
      if (size(h.colours) == 0) { println("Hold " + h.holdId + " missing colours"); return false; }
      switch(h.pos) {
        case xyPos(_): ; // OK
        case anglePos(a): if (a < 0 || a > 359) { println("Hold " + h.holdId + " angle out of range"); return false; }
      }
      switch(h.rotation) {
        case just(rot): if (rot < 0 || rot > 359) { println("Hold " + h.holdId + " rotation out of range"); return false; }
        case nothing(): ; // OK
      }
      for (c <- h.colours) { if (!isValidColour(c)) { println("Hold " + h.holdId + " has invalid colour " + c); return false; } }
    }
  }
  return true;
}

bool isValidColour(str c) {
  set[str] valid = {"white","yellow","green","blue","red","purple","pink","black","orange"};
  return c in valid;
}

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
    list[str] interList = allColours[0];
    for (i <- [1..size(allColours)-1]) {
      if (i < size(allColours)) {
        list[str] next = allColours[i];
        interList = [c | c <- interList, c in next];
      }
    }
    if (size(interList) == 0) { println("Route " + rid + " has no common colour across its holds"); return false; }
  }
  return true;
}

list[HoldAST] findHoldById(BoulderWallAST wall, str id) {
  for (v <- wall.volumes) {
    for (h <- volumeHolds(v)) {
      if (h.holdId == id) return [h];
    }
  }
  return [];
}
