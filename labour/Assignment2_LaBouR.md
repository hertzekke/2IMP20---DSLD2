# 2IMP20 DSL Design — Assignment 2: LaBouR in Rascal

---

## Introduction

The goal of this assignment is to design and implement a Domain-Specific Language (DSL) for specifying *bouldering* gym routes (see [https://en.wikipedia.org/wiki/Bouldering](https://en.wikipedia.org/wiki/Bouldering)). This assignment must be implemented using the [Rascal language workbench](https://www.rascal-mpl.org/).

## Assignment

This assignment is meant to familiarize you with the basics of defining languages using Rascal.

The assignment aims to build a DSL called LaBouR (Language for Bouldering Routes) for defining routes for a bouldering gym. You have already done so before but with Ecore. One of the tasks in this assignment is to develop a concrete syntax for LaBouR, which can then be used to parse LaBouR programs. In the template repository, you will find a [VS Code](https://code.visualstudio.com/) project with the skeleton of the assignment. Look at the `src` folder within [VS Code](https://code.visualstudio.com/). This folder contains all the necessary language modules. Each module contains the instructions for the exercises and hints to guide the development.

LaBouR allows users to define bouldering routes consisting of bouldering holds. Both the routes and the holds have properties that are described below. Furthermore, LaBouR allows the definition of “volumes” that represent the depth of the bouldering wall. Figure 1 shows a bouldering wall composed of coloured holds and polygonal volumes.

We will use LaBouR to demonstrate the various aspects of language design discussed in this course. As mentioned, we will do this with the [Rascal language workbench](https://www.rascal-mpl.org/). Hereafter, we introduce more details about the LaBouR language.

---

## Main Concepts

A bouldering wall has a unique ID, and it is composed of volumes and routes. **Volumes define which holds are available in a wall, and the routes are defined based on these holds.**

### Holds

A hold can be labelled as a `start_hold`, which takes either 1 or 2 as an argument, or `end_hold`. There can be a maximum of two starting holds and a maximum of one end hold per route. If there are sub-routes, then each sub-route may have an end hold. If no end hold is defined, the bouldering route is finished by climbing over the top of the wall (onto a landing area). Each hold provides information describing:

- a unique hold identifier defined by a four-character string.
- its (x, y) coordinates. These coordinates are in **cm** and defined with **integer** values. (more about this in Section 2.1.2).
- a hold shape identifier defined by a string, e.g., "52".
- a list of colours (to accommodate not just unicoloured holds, but also multicoloured ones—in practice, think transparent holds that have small coloured holds or stickers inside them corresponding to the multiple colours).
- an optional rotation that defines the angle of the hold. The angle can be any **integer** between 0 and 359.

An example of a hold described using the LaBouR language is provided in Listing 1

```
hold "0001" {
  pos { x: 30, y: 70 },
  shape: "107",
  colours [ red, green ],
  start_hold: 1,
  rotation: 30
}
```
Listing 1: Example definition of a Hold

### Volumes

There are two types of volumes:

#### Circle

A cylindrical volume is defined by its `(x, y)` position, `radius` and `depth`. The depth describes how extruded the volume is. This depth can also be negative if the shape "subtracts" from the wall. Listing 2 provides an example of a `circle` in LaBouR and Figure 2 provides a visual description of the different `circle` properties.

For holds in a cylindrical volume, their position is defined in relation to the volume position. For holds in the `side_holds`, instead of `(x, y)` coordinates, the holds are defined by their `angle` (in degrees) around the cylinder side surface. For `front_holds`, the `(x, y)` coordinates are defined relative to the centre of the front face of the cylinder.

```
circle {
  pos: { x: 50, y: 200 },
  depth: -10,
  radius: 50,
  front_holds [
    hold "0001" {
      pos: { x: 15, y: 30 },
      shape: "52",
      colours [ blue, white ]
    }
  ],
  side_holds [
    hold "0002" {
      pos: { angle: 30 },
      shape: "42",
      colours [ blue ]
    }
  ]
}
```
Listing 2: Example definition of a Circle volume

#### Triangle
A triangular volume is defined by its (x, y) position, an array of three corners,
an extrusion point and a depth. Listing 3 provides an example of a triangle in LaBouR
and Figure 3 provides a visual description of the different triangle properties.
- May contain holds in `left_holds`, `right_holds`, or `bottom_holds`

```
triangle {
  pos: { x: 0, y: 0 },
  extrusion: { x: 10, y: 5 },
  depth: 40,
  corners [
    { x: 2, y: 0 },
    { x: -2, y: 0 },
    { x: 0, y: 2 }
  ],
  left_holds [
    hold "0012" { pos: { x: 108, y: 50 }, shape: "5", rotation: 98, colours [white], end_hold }
  ]
}
```

### Routes

Besides the volumes, the wall can also contain multiple routes. A bouldering route must have a few properties:
- a grade defined by a string, e.g., “5A”.
- a grid_base_point defined by an (x, y) coordinate. These coordinates are relative to the left lower corner of the bouldering wall.
- a unique route identifier defined by a string, e.g., “my route”
- an array of hold identifiers that indicate which holds are part of this route and which sub-routes are present.

Moreover, a route can split at a certain hold into two sub-routes that can later merge or end up in two different end holds (if not merged). An example of such a route is given in Listing 4.

```
routes [
  bouldering_route "Split route" {
    grade: "5A",
    grid_base_point { x: 0, y: 0 },
    holds ["0001", "0002", {"0003", "0004"}, {"0005", "0006"}, "0007"]
  }
]
```
Listing 4: Example definition of a single route that splits into two sub-routes

For the route in Listing 4, it is possible to imagine the split as two separate routes:

1. "0001", "0002", "0003", "0005", "0007"
2. "0001", "0002", "0004", "0006", "0007"

---

## Well-formedness Rules

To have a valid LaBouR bouldering route definition, some requirements have to be satisfied. The following conditions ensure the  ell-formedness of a LaBouRbouldering route definition. Note that if a data type is not specified, you may choose something sensible yourself; do not forget to explain why.

1. Every wall must have at least one volume and one route.
2. Every route must have two or more holds.
3. Every route must have between zero and two hand start holds.
4. Every route must have at most one splitting hold where sub-routes start (i.e. no more than two sub-routes).
5. Every route must have a grade, a `grid_base_point`, and an `identifier`.
6. The `grid_base_point` must have an `x` and a `y` component.
7. Every route has at most two holds indicated as `end_hold` if it splits into sub-routes, and at most one `end_hold` if it does not split.
8. In a route, after a split, there should be no new split if there was a merge before.

```
holds ["0001", "0002", {"0003", "0004"}, "0007", {"0005", "0006"}]
                      > Split           > Merge   > Split
```
Listing 5: Example of an invalid route

9. Hold IDs are always defined with four digits, for example, "0025".
10. The wall and route IDs can take any alphanumeric character.
11. The holds in a bouldering route must all have the same colour. In multicoloured holds, the intersection of the colour lists must be non-empty. The order of the colours in a multicoloured hold is not relevant.
12. Every hold must have a position (defined by `x` and `y`, or by and angle), a shape, and colour.
13. If a hold position is defined by an angle, the angle must be between 0 and 359.
14. Holds may have a rotation property. If a hold has a rotation, its value must be between 0 and 359.
15. The colour values used must be valid. For now, we assume valid colours to be `white`, `yellow`, `green`, `blue`, `red`, `purple`, `pink`, `black`, and `orange`.
16. There are only two types of volumes: `circle` and `triangle`.
17. A circular volume must have a `radius`, a `depth` and a `position`.
18. A circular volume may only contain holds in the `front_holds` or `side_holds` lists.
19. A triangular volume must have a `position`, `depth`, an `extrude` point, and a `corner` array, with three items that defines the corners of the triangle.
20. A triangular volume may only contain holds in the `left_holds`, `right_holds`, or `bottom_holds` lists.

---

## Deliverables — Five Rascal Modules

### `Syntax.rsc` — Concrete Grammar
Define the grammar for LaBouR using Rascal's grammar formalism in `Syntax.rsc`.

### `Parser.rsc` — Parse Function
Define a parse function for LaBouR. The name of the function is `parseLaBouR(...)`. It gets a location (loc) as parameter and it returns the parse tree corresponding to the concrete LaBouR bouldering route in the file at loc (module `Parser.rsc`).

### `AST.rsc` — Abstract Syntax
Define Rascal `data` types that represent the abstract syntax of LaBouR.

### `CST2AST.rsc` — CST to AST Transformation
Define the function `cst2ast(...)`, which takes a parse tree of a LaBouR bouldering route as parameter and returns an abstract syntax tree as described in the AST (module `CST2AST.rsc`). Obviously, you are not allowed to use Rascal’s built in `implode` function—one of the goals of this assignment is to make you understand and implement the process to go from CST to AST.

### `Check.rsc` — Well-formedness Checker
Specify a well-formedness checker for LaBouR. To do this, it is necessary to define the function `checkBoulderRouteConfiguration(...)`, which takes the AST of a bouldering route as parameter and verifies that all well-formedness checks succeed (module `Check.rsc`).

---

## Testing in VSCode

- Import `labour::Plugin` in the Rascal REPL and call `main()` to register LaBouR with VSCode.
- `.labour` files will get syntax highlighting if your grammar is correct.
- Use `checkWellformedness(path)` from `Plugin.rsc` to test a `.labour` file — returns `true` if valid.
- Create test files covering:
  - **Valid** non-trivial LaBouR specifications
  - **Invalid** specifications, ideally one per well-formedness rule

> 💡 Rascal can be memory-hungry. If you encounter random issues, clean your project, restart VSCode, and check for trailing Rascal processes.

---

## Complete Valid Example

```
bouldering_wall "Example wall" {
  routes [
    bouldering_route "Split route" {
      grade: "5A",
      grid_base_point { x: 0, y: 0 },
      holds ["0001", "0002", {"0003","0004"}, {"0005","0006"}, "0007"]
    }
  ],
  volumes [
    circle {
      pos: { x: 50, y: 200 },
      depth: -10,
      radius: 50,
      front_holds [
        hold "0001" { pos: { x: 2, y: 20 }, shape: "5", rotation: 98, colours [white], start_hold: 1 },
        hold "0002" { pos: { x: 2, y: 20 }, shape: "5", rotation: 98, colours [white] },
        hold "0003" { pos: { x: 15, y: 30 }, shape: "52", colours [blue, white] }
      ],
      side_holds [
        hold "0004" { pos: { x: 30, y: 20 }, shape: "42", colours [white, orange, green] }
      ]
    },
    triangle {
      pos: { x: 0, y: 0 },
      extrusion: { x: 10, y: 2 },
      depth: 40,
      corners [
        { x: 20, y: 0 },
        { x: -20, y: 0 },
        { x: 0, y: 30 }
      ],
      left_holds [
        hold "0005" { pos: { x: 12, y: 25 }, shape: "5", rotation: 0, colours [white] },
        hold "0006" { pos: { x: 10, y: 14 }, shape: "53", rotation: 98, colours [white] },
        hold "0007" { pos: { x: 15, y: 19 }, shape: "53", rotation: 0, colours [white, red], end_hold }
      ]
    }
  ]
}
```

---

## Submission

Submit a **zip file** via Canvas (as a group of two) containing:
- Your LaBouR language solution, including all modified files.
- The test programs demonstrating the correct validation of non-trivial LaBouR specifications.
- Test programs containing invalid route descriptions to demonstrate the correctness of the checker.

**Add comments to your files explaining all design decisions.**

---

## Grading Rubric
- **Concrete Syntax**
  - Well-thought separation of syntax validation vs. external validation | 1.0 |
  - Decoupled syntax, easy to modify and extend | 1.0 |
- **Abstract Syntax**
  - Matches the concrete syntax | 1.0 |
- **CST -> AST**
  - Clean transformation, one mapping per language construct | 2.0 |
- **Constraints**
  - Route has two or more holds | 0.5 |
  - All route properties are present | 0.5 |
  - Correct number of start and end holds | 0.5 |
  - All required hold properties are present and correct | 0.5 |
  - All route holds have the same colour | 0.5 |
  - All required volume properties are present and correct | 0.5 |
  - Sub-route constraints are validated | 0.5 |
- **Other**
  - All constraints validated with test programs | 0.5 |
  - Test programs validate individual constraints | 0.5 |
  - Reasoning behind language design decisions present (as comments) | 0.5 |
- **Total** | **10.0** |
