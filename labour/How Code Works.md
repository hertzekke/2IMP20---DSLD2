

To understand how the code flows through the files, let's walk through the pipeline step-by-step in your preferred order: **Syntax $\to$ CST2AST $\to$ AST $\to$ Check**.

We will follow a specific language construct—**a Route with its holds**—to see exactly how it is represented, transformed, and validated at each stage.

---

### Step 1: Syntax.rsc (Concrete Grammar)
This is where the user's raw text is parsed. The grammar defines how a route and its holds are syntactically structured.

```rascal
// Syntax.rsc (Concrete Rules)
syntax Route
  = route: "bouldering_route" RouteId "{"
      "grade:" ShapeId ","
      "grid_base_point" Pos ","
      "holds" "[" HoldRefList "]"
      "}"
  ;

syntax HoldRefList = {HoldRef ","}+;

syntax HoldRef
  = single:    HoldId
  | subRoute: "{" HoldIdList "}"
  ;
```

* **How the flow works here**:
  1. The user writes raw text in a `.labour` file (e.g., `bouldering_route "Route A" { grade: "5A", grid_base_point {x:0, y:0}, holds ["0001", {"0002", "0003"}] }`).
  2. The parser matches the text against the `Route` syntax rule, generating a **Concrete Syntax Tree (CST)** node labeled `route`.

---

### Step 2: CST2AST.rsc (The Mapping Bridge)
This is the bridge that takes the CST node produced by `Syntax.rsc` and maps it to a corresponding AST node defined in `AST.rsc`.

```rascal
// CST2AST.rsc (Translating CST to AST)
RouteAST cst2ast((Route)`bouldering_route <RouteId rid> { grade: <ShapeId gr> , grid_base_point <Pos gp> , holds [ <{HoldRef ","}+ hrs> ] }`) =
  route(unquote("<rid>"), unquote("<gr>"), cst2ast(gp), [cst2ast(hr) | hr <- hrs]);

HoldRefAST cst2ast((HoldRef)`<HoldId hid>`) = single(unquote("<hid>"));
HoldRefAST cst2ast((HoldRef)`{ <{HoldId ","}+ ids> }`) = subRoute([unquote("<id>") | id <- ids]);
```

* **How the flow works here**:
  1. The function matches the exact concrete shape of a parsed route (`bouldering_route <RouteId rid> ...`).
  2. It strips syntactic noise (like matching quotes with `unquote`) and maps the child elements.
  3. It calls `cst2ast(gp)` to convert coordinates and loops over the holds `[cst2ast(hr) | hr <- hrs]`.
  4. Finally, it constructs and returns a clean `route(...)` AST constructor.

---

### Step 3: AST.rsc (The Domain Model)
This defines the structural representation of the mapped data, completely free of grammar formatting.

```rascal
// AST.rsc (Data Constructors)
data RouteAST
  = route(str routeId, str grade, PosAST gridBase, list[HoldRefAST] holds);

data HoldRefAST
  = single(str holdId)
  | subRoute(list[str] holdIds);
```

* **How the flow works here**:
  1. Once `CST2AST.rsc` finishes running, we now have a standard Rascal algebraic data term representing the route.
  2. For our example, the resulting AST term looks like this:
     ```rascal
     route("Route A", "5A", pos(0,0), [single("0001"), subRoute(["0002", "0003"])])
     ```
  3. This clean tree structure makes it extremely easy to query, traverse, and validate in the next phase.

---

### Step 4: Check.rsc (Semantic Invalidation)
This takes the AST node and evaluates it against our well-formedness checks.

```rascal
// Check.rsc (Validation Functions)
bool checkNumberOfHolds(BoulderWallAST wall) {
  for (route(rid, g, gbp, holds) <- wall.routes) {
    if (size(holds) < 2) {
      println("Route has fewer than two holds: " + rid);
      return false;
    }
  }
  return true;
}
```

* **How the flow works here**:
  1. Pattern-matches on the AST elements directly using destructuring (`for (route(rid, g, gbp, holds) <- wall.routes)`).
  2. For example, `checkNumberOfHolds` gets the list of `holds` from the AST node and checks if `size(holds) < 2`.
  3. Because all punctuation has been stripped away in the AST, the checker does not need to care about commas or braces; it checks the semantic properties directly.

---

### Summary of File Dependencies
When you open a `.labour` file or run `runTests()`, the files import each other to build the chain:
1. **`Plugin.rsc`** imports `Parser.rsc`, `CST2AST.rsc`, and `Check.rsc`.
2. **`Parser.rsc`** imports `Syntax.rsc` to run the parsing engine.
3. **`CST2AST.rsc`** imports `Syntax.rsc` (for CST patterns) and `AST.rsc` (for target AST constructors).
4. **`Check.rsc`** imports `AST.rsc` to perform type matching and validations.