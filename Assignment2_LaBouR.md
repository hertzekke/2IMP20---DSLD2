# 2IMP20 DSL Design — Assignment 2: LaBouR in Rascal

**Deadline:** Friday, June 12th, 23:59 via Canvas (group submission of two students)

---

## Introduction

The goal of this assignment is to design and implement a Domain-Specific Language (DSL) for specifying bouldering gym routes. This assignment must be implemented using the **Rascal language workbench**.

Setup steps:
- Get the assignment's project skeleton from the template repository.
- Open the assignment folder in VSCode (`Ctrl/Cmd+K, Ctrl/Cmd+O` or `File → Open Folder`).
- If using a git repository: create your own repo and update the remote origin:
  ```
  git remote set-url origin <NEW_GIT_URL_HERE>
  ```

The DSL is called **LaBouR** (Language for Bouldering Routes). You already implemented it with Ecore in Assignment 1. Now you will re-implement it using Rascal's grammar formalism, parser, AST, CST-to-AST transformation, and well-formedness checker.

---

## Main Concepts

A **bouldering wall** has a unique ID and is composed of **volumes** and **routes**. Volumes define which holds are available in a wall; routes are defined based on those holds.

### Holds

Each hold provides:
- A **unique hold identifier** defined by a four-character string (e.g., `"0001"`)
- Its **(x, y) coordinates** in cm (integer values), or an **angle** if inside a cylindrical volume's side
- A **hold shape identifier** (e.g., `"52"`)
- A **list of colours** (supports multicoloured holds)
- An **optional rotation** — any integer between 0 and 359
- Optional labels: `start_hold:1` or `start_hold:2`, or `end_hold`

```
hold "0001" {
  pos { x: 30, y: 70 },
  shape: "107",
  colours [red, green],
  start_hold: 1,
  rotation: 30
}
```

### Volumes

There are two types of volumes:

#### Circle
Defined by: `(x,y)` position, `radius`, `depth` (can be negative).
- `front_holds`: holds with `(x,y)` relative to the cylinder's front face centre
- `side_holds`: holds with `angle` (degrees around the cylinder side surface)

```
circle {
  pos: { x: 50, y: 200 },
  depth: -10,
  radius: 50,
  front_holds [
    hold "0001" { pos: { x: 15, y: 30 }, shape: "52", colours [blue, white] }
  ],
  side_holds [
    hold "0002" { pos: { angle: 30 }, shape: "42", colours [blue] }
  ]
}
```

#### Triangle
Defined by: `(x,y)` position, `extrusion` point (relative to triangle centre), `depth`, and `corners` array (exactly 3 corners, relative to centre).
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

Each bouldering route must have:
- A **grade** (string, e.g., `"5A"`)
- A **grid_base_point** with `(x,y)` coordinates (relative to lower-left corner of the wall)
- A **unique route identifier** (string, e.g., `"myroute"`)
- An **array of hold identifiers**, where a split is expressed as `{"0003","0004"}`

```
routes [
  bouldering_route "Split route" {
    grade: "5A",
    grid_base_point { x: 0, y: 0 },
    holds ["0001", "0002", {"0003","0004"}, {"0005","0006"}, "0007"]
  }
]
```

A split at `{"0003","0004"}` means two sub-routes: `0001→0002→0003→0005→0007` and `0001→0002→0004→0006→0007`.

---

## Well-formedness Rules

All of the following must be validated in `Check.rsc`. Some may be embedded in the concrete syntax directly; others must be checked externally.

| # | Rule |
|---|------|
| 1 | Every wall must have at least one volume and one route |
| 2 | Every route must have two or more holds |
| 3 | Every route must have between zero and two hand start holds |
| 4 | Every route must have at most one splitting hold (i.e., no more than two sub-routes) |
| 5 | Every route must have a grade, a `grid_base_point`, and an identifier |
| 6 | The `grid_base_point` must have both `x` and `y` components |
| 7 | A route has at most two `end_hold`s if it splits, and at most one if it does not split |
| 8 | After a merge, there must be no new split — `split → merge → split` is **invalid** |
| 9 | Hold IDs are always exactly four digits (e.g., `"0025"`) |
| 10 | Wall and route IDs may contain any alphanumeric character |
| 11 | All holds in a route must share at least one colour (for multicoloured holds, the intersection of colour lists must be non-empty; order of colours is irrelevant) |
| 12 | Every hold must have a position, a shape, and a colour |
| 13 | If a hold position is defined by an angle, the angle must be between 0 and 359 |
| 14 | If a hold has a rotation, its value must be between 0 and 359 |
| 15 | Valid colours: `white`, `yellow`, `green`, `blue`, `red`, `purple`, `pink`, `black`, `orange` |
| 16 | Only two volume types: `circle` and `triangle` |
| 17 | A circular volume must have a `radius`, `depth`, and `position` |
| 18 | A circular volume may only contain holds in `front_holds` or `side_holds` |
| 19 | A triangular volume must have a `position`, `depth`, an extrusion point, and a `corners` array with exactly three items |
| 20 | A triangular volume may only contain holds in `left_holds`, `right_holds`, or `bottom_holds` |

**Invalid route example (rule 8 — split after merge):**
```
holds ["0001", "0002", {"0003","0004"}, "0007", {"0005","0006"}]
// > Split > Merge > Split  ← INVALID
```

---

## Deliverables — Five Rascal Modules

### `Syntax.rsc` — Concrete Grammar
Define the grammar for LaBouR using Rascal's grammar formalism. Decide carefully which well-formedness rules to embed directly in the syntax vs. which to handle in `Check.rsc`. Document this decision in comments.

### `Parser.rsc` — Parse Function
Implement `parseLaBouR(loc l)` that takes a file location and returns the parse tree for the LaBouR program at that location.

### `AST.rsc` — Abstract Syntax
Define Rascal `data` types that represent the abstract syntax of LaBouR. The AST should strip away concrete syntax noise (keywords, punctuation) and retain only semantically meaningful structure.

### `CST2AST.rsc` — CST to AST Transformation
Implement `cst2ast(...)` that takes a parse tree and returns the corresponding AST.

> ⚠️ **Do NOT use Rascal's built-in `implode` function.** You must write every mapping manually — this is one of the core learning objectives of the assignment.

### `Check.rsc` — Well-formedness Checker
Implement `checkBoulderRouteConfiguration(...)` that takes an AST and validates all well-formedness rules, returning a list of errors/messages for any violations.

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
- All modified `.rsc` files
- Test `.labour` programs demonstrating correct validation of non-trivial valid specifications
- Test `.labour` programs with invalid descriptions demonstrating correctness of the checker

**Add comments to your files explaining all design decisions.**

---

## Grading Rubric

| Category | Item | Points |
|---|---|---|
| **Concrete Syntax** | Well-thought separation of syntax validation vs. external validation | 1.0 |
| | Decoupled syntax, easy to modify and extend | 1.0 |
| **Abstract Syntax** | Matches the concrete syntax | 1.0 |
| **CST → AST** | Clean transformation, one mapping per language construct | 2.0 |
| **Constraints** | Route has two or more holds | 0.5 |
| | All route properties are present | 0.5 |
| | Correct number of start and end holds | 0.5 |
| | All required hold properties are present and correct | 0.5 |
| | All route holds have the same colour | 0.5 |
| | All required volume properties are present and correct | 0.5 |
| | Sub-route constraints are validated | 0.5 |
| **Other** | All constraints validated with test programs | 0.5 |
| | Test programs validate individual constraints | 0.5 |
| | Reasoning behind language design decisions present (as comments) | 0.5 |
| **Total** | | **10.0** |
