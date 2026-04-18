# Refactoring Guide

Reference material for the incremental-refactoring skill. Based on "Refactoring" (Fowler) and "Working Effectively with Legacy Code" (Feathers).

## Core Philosophy

**Change code structure without changing behavior.** Every step must be small enough to verify correctness before proceeding.

### Edit and Pray vs Cover and Modify

- **With tests:** Make changes confidently, run tests after each step
- **Without tests:** Use only transformations verifiable through visual inspection, compiler/type checker, or mechanical transformation (no judgment calls)

**If you cannot verify a step, make it smaller.**

## The Golden Rule: One Thing at a Time

Never mix:
- Refactoring with behavior changes
- Multiple refactoring operations in one commit
- Cleanup with feature work

Each commit = single, reversible transformation.

---

## Safe Refactoring Catalog

These transformations are safe because they can be verified without tests.

### Extract Method/Function

**When:** Code is too long, has comments explaining sections, or you need to reuse a portion.

**Why safe:** Extracted code is literally copy-pasted. Compiler catches missing variables.

```python
# Before
def process_order(order):
    # validate
    if order.total < 0:
        raise ValueError("Invalid total")
    if not order.items:
        raise ValueError("No items")
    # calculate discount
    discount = 0
    if order.total > 100:
        discount = order.total * 0.1
    return order.total - discount

# After
def process_order(order):
    validate_order(order)
    discount = calculate_discount(order.total)
    return order.total - discount

def validate_order(order):
    if order.total < 0:
        raise ValueError("Invalid total")
    if not order.items:
        raise ValueError("No items")

def calculate_discount(total):
    if total > 100:
        return total * 0.1
    return 0
```

### Inline Method/Function

**When:** A function's body is as clear as its name, or you need the full picture before re-extracting differently.

**Why safe:** Mechanical replacement, compiler catches type mismatches.

```python
# Before
def is_adult(age):
    return age >= 18

def can_vote(person):
    return is_adult(person.age) and person.registered

# After (if is_adult adds no clarity)
def can_vote(person):
    return person.age >= 18 and person.registered
```

### Rename (Variable, Function, Class, File)

**When:** Name does not reflect purpose, or purpose has changed.

**Why safe:** Compiler/linter catches all references.

**Caution:** Watch for string references (API endpoints, serialization), dynamic access, cross-file public APIs.

### Move Method/Function

**When:** Function is more closely related to another module/class.

**Why safe:** Import errors catch missing references.

### Extract Variable

**When:** Expression is complex or used multiple times.

**Why safe:** Pure mechanical extraction.

```python
# Before
if user.subscription.plan.price > 100 and user.subscription.plan.price < 500:
    apply_mid_tier_discount(user.subscription.plan.price)

# After
price = user.subscription.plan.price
if price > 100 and price < 500:
    apply_mid_tier_discount(price)
```

### Inline Variable

**When:** Variable adds no explanatory value.

**Why safe:** Direct substitution.

### Split Loop

**When:** Loop does multiple unrelated things.

**Why safe:** Same iterations, same operations, just separated.

```python
# Before
total = 0
product = 1
for v in values:
    total += v
    product *= v

# After
total = 0
for v in values:
    total += v

product = 1
for v in values:
    product *= v
```

**Note:** Yes, two loops is "slower." Optimize later if profiling shows it matters. Clarity enables further refactoring.

### Replace Nested Conditional with Guard Clauses

**When:** Deep nesting obscures main logic.

**Why safe:** Same conditions, same outcomes, different structure.

```python
# Before
def get_payment(employee):
    if employee.is_separated:
        result = separated_amount(employee)
    else:
        if employee.is_retired:
            result = retired_amount(employee)
        else:
            result = normal_amount(employee)
    return result

# After
def get_payment(employee):
    if employee.is_separated:
        return separated_amount(employee)
    if employee.is_retired:
        return retired_amount(employee)
    return normal_amount(employee)
```

---

## Intermediate Techniques

### Duplicate Before Unifying

To extract common code from two similar functions:
1. First, make both functions structurally identical (even if that means temporary duplication)
2. Then extract the common code

This intentionally makes code worse before making it better. That is expected.

```python
# Two similar functions
def process_user_order(order):
    validate_user(order.user_id)
    tax = order.total * 0.08
    shipping = 5.99
    return order.total + tax + shipping

def process_guest_order(order):
    tax = order.total * 0.08
    shipping = 0 if order.item_count > 2 else 5.99  # different!
    return order.total + tax + shipping

# Step 1: Make shipping explicit in both (worse but parallel)
def process_user_order(order):
    validate_user(order.user_id)
    tax = order.total * 0.08
    shipping = calculate_shipping(order, is_guest=False)
    return order.total + tax + shipping

def process_guest_order(order):
    tax = order.total * 0.08
    shipping = calculate_shipping(order, is_guest=True)
    return order.total + tax + shipping

# Step 2: Now extract the common part
def calculate_order_total(order, is_guest=False):
    tax = order.total * 0.08
    shipping = calculate_shipping(order, is_guest)
    return order.total + tax + shipping
```

### Expand Before Contracting

To simplify complex conditionals:
1. First, expand to explicit cases (more verbose)
2. Then identify patterns and simplify

### Seams: Places to Change Behavior Without Editing

A "seam" is where you can alter behavior without modifying code at that location.

```python
# Before: hard to test
def send_notification(user, message):
    client = SMTPClient("mail.server.com")
    client.send(user.email, message)

# After: seam at the client parameter
def send_notification(user, message, client=None):
    if client is None:
        client = SMTPClient("mail.server.com")
    client.send(user.email, message)
```

This is not about creating interfaces for everything. It is about having one place to inject different behavior when needed.

---

## LLM-Specific Guidance

### Why Smaller Functions Help LLMs

- Search/replace tools struggle with deep indentation -- extracting methods reduces nesting
- Smaller functions = smaller context needed for reasoning
- Flat structure = fewer edit conflicts with tool-based editing

### Calibrating Step Size

- **More tests** = larger safe steps
- **Stronger type system** = larger safe steps
- **When uncertain** = smaller steps. Verify the approach works before going faster

### Observation-Driven Next Steps

Do NOT plan all refactoring steps upfront. After each transformation:
1. Look at what the code looks like now
2. The right next step becomes clear only after the previous step is complete
3. Decide: continue, re-analyze, or stop

---

## Verification Methods

- **Compiler/type checker** -- catches missing references, type mismatches
- **Unit tests** -- fast feedback on behavior preservation
- **Manual inspection** -- for simple transformations, before/after should be obviously equivalent

---

## What NOT to Do

- **Mix refactoring with features:** "While extracting this method, I also fixed the edge case..." -- NO. Separate commits.
- **Create speculative abstractions:** Extract interface only when you have two implementations NOW.
- **Refactor without purpose:** Finish what you start, or do not start.
- **Skip verification:** Make 1 change, verify, repeat. Not 10 changes then verify.

---

## Additional Fowler Catalogue Entries

*Source for this section: Fowler, "Refactoring: Improving the Design of Existing Code", 2nd ed. (2018). Canonical names verified against https://refactoring.com/catalog/.*

### Change Function Declaration
*Source: Fowler 2nd ed., Ch. 6*
**When:** A function's name, parameter list, or parameter order no longer fits its role.
**Why safe:** Compiler/type-checker plus call-site search finds every usage; for gradual rollout keep the old signature as a thin adapter until all callers migrate.

```js
// before
function circum(radius) { return 2 * Math.PI * radius; }
// after
function circumference(radius) { return 2 * Math.PI * radius; }
```

### Replace Conditional with Polymorphism
*Source: Fowler 2nd ed., Ch. 10*
**When:** A `switch`/`if-else` chain dispatches on a type tag and the same chain recurs in multiple places.
**Why safe:** Each branch becomes one subclass method; exhaustiveness is preserved by constructing the right subclass at the single creation site, and existing tests for each branch pin behaviour.

```js
// before
switch (bird.type) {
  case 'european': return 35;
  case 'african':  return 40 - 2 * bird.numberOfCoconuts;
  case 'norwegian': return bird.isNailed ? 0 : 10 + bird.voltage / 10;
}
// after: each subclass overrides airSpeedVelocity()
```

### Replace Magic Literal
*Source: Fowler 2nd ed., Ch. 9*
**When:** A literal (number, string, regex) whose meaning is not obvious appears inline, often more than once.
**Why safe:** Introduce a named constant; the compiler/linker guarantees each occurrence resolves to the same value, and a single rename eliminates drift.

### Extract Class
*Source: Fowler 2nd ed., Ch. 7*
**When:** A class holds two clusters of fields/methods that change for different reasons (low cohesion).
**Why safe:** Move one cluster to a new class, delegate from the old; each move is a Move Method/Move Field with pass-through, and tests keep the public surface intact.

### Inline Class
*Source: Fowler 2nd ed., Ch. 7*
**When:** A class no longer earns its keep — few members, used by only one caller, adds indirection without abstraction.
**Why safe:** Fold members back into the single user; the reverse of Extract Class, done one member at a time with the class kept alive until empty.

### Combine Functions into Class
*Source: Fowler 2nd ed., Ch. 6*
**When:** A clump of free functions always takes the same data and always runs in sequence.
**Why safe:** Convert shared parameters into fields; each function becomes a method with the same body, so behaviour is unchanged — only the calling form moves.

### Split Phase
*Source: Fowler 2nd ed., Ch. 6*
**When:** A function mixes two temporally distinct jobs (e.g. parse then calculate; load then render).
**Why safe:** Introduce an intermediate data structure, move phase-1 output into it, rewrite phase-2 to consume it; each phase is testable in isolation with a fixed contract at the seam.

### Remove Dead Code
*Source: Fowler 2nd ed., Ch. 8*
**When:** Static analysis or reachability shows a function/branch is never called, or a feature flag is permanently off.
**Why safe:** Version control retains the history; tests for non-dead code continue to pass, and removal reduces surface area for bugs.

### Substitute Algorithm
*Source: Fowler 2nd ed., Ch. 7*
**When:** A function's algorithm is needlessly complex and a clearer one computes the same result.
**Why safe:** Keep the signature; characterization tests around inputs/outputs pin behaviour, swap the body, rerun tests. Precondition: comprehensive tests before swapping.

### Introduce Parameter Object
*Source: Fowler 2nd ed., Ch. 6*
**When:** The same group of parameters travels together through several functions.
**Why safe:** Bundle them into a struct/record; each call-site change is mechanical, and the compiler catches unbundled survivors.

### Preserve Whole Object
*Source: Fowler 2nd ed., Ch. 11*
**When:** A caller extracts several values from an object only to pass them individually to a function that could take the object itself.
**Why safe:** Callee pulls fields it needs; removes parameter duplication without changing semantics. Watch: may increase coupling to the object type — acceptable when caller and callee already share that type.

### Replace Parameter with Query
*Source: Fowler 2nd ed., Ch. 11*
**When:** A parameter value is derivable from another parameter or from the receiver.
**Why safe:** Remove the parameter, compute it inside; works only if the query is referentially transparent at the call site.

### Replace Query with Parameter
*Source: Fowler 2nd ed., Ch. 11*
**When:** A function reads global/mutable state or hits an external dependency to get a value, making it impure and hard to test.
**Why safe:** Lift the query to a parameter at the boundary; the function becomes deterministic given its arguments.

### Parameterize Function
*Source: Fowler 2nd ed., Ch. 11*
**When:** Two or more functions differ only by a literal value in their body.
**Why safe:** Add the varying value as a parameter and delete the duplicates; call sites pass their specific values — a pure generalization.

### Remove Flag Argument
*Source: Fowler 2nd ed., Ch. 11*
**When:** A boolean/enum parameter toggles between two behaviours that are meaningfully distinct at the call site.
**Why safe:** Split into two explicitly named functions; call sites become self-documenting and dead branches disappear.

### Split Variable
*Source: Fowler 2nd ed., Ch. 9*
**When:** A single local variable is reassigned for two unrelated purposes (non-accumulator, non-loop-counter reuse).
**Why safe:** Introduce a second variable; each use-site references only one role. Compiler catches accidental cross-use.

### Replace Temp with Query
*Source: Fowler 2nd ed., Ch. 7*
**When:** A temp holds the result of a reusable expression and other methods in the class might want it.
**Why safe:** Extract the expression as a method; replace the temp with the call. Requires the expression to be pure (same inputs → same output).

### Collapse Hierarchy
*Source: Fowler 2nd ed., Ch. 12*
**When:** A subclass and its superclass are no longer different enough to justify separation.
**Why safe:** Merge fields/methods into one class; callers that used either type still compile because the surviving class has the full union.

### Pull Up Method / Push Down Method
*Source: Fowler 2nd ed., Ch. 12*
**When:** Pull Up — identical methods exist in sibling subclasses. Push Down — a superclass method is only used by one subclass.
**Why safe:** Move method to the correct level in the hierarchy; the overriding structure guarantees behaviour for each subclass, and a compile pass finds broken references.

### Encapsulate Variable
*Source: Fowler 2nd ed., Ch. 6*
**When:** A piece of mutable data is accessed directly from many sites and you need to intercept reads/writes (logging, validation, future data-structure change).
**Why safe:** Introduce getter/setter, replace direct accesses; a bulk search+replace plus compile confirms every access is routed.

### Encapsulate Record
*Source: Fowler 2nd ed., Ch. 7*
**When:** A raw record/dict is used widely and you want to add computed fields or rename fields without breaking callers.
**Why safe:** Wrap in a class with accessors; each field access becomes `rec.field()`, and the compiler flags every call-site that needs migrating.

### Replace Primitive with Object
*Source: Fowler 2nd ed., Ch. 7*
**When:** A primitive (string, int) carries domain meaning and repeatedly needs the same helper operations.
**Why safe:** Introduce a wrapper class with a single field; constructor validation catches bad values at boundaries; equality semantics must be explicitly defined (value object).

### Replace Type Code with Subclasses
*Source: Fowler 2nd ed., Ch. 12*
**When:** An enum/type-code field drives many conditionals that differ per code.
**Why safe:** Create a subclass per code; instantiation at construction sites encodes the type once, and dispatch replaces conditionals. Related: Replace Conditional with Polymorphism.

### Replace Loop with Pipeline
*Source: Fowler 2nd ed., Ch. 8*
**When:** A loop accumulates by filtering, mapping, and reducing — the shape matches a collection pipeline.
**Why safe:** Rewrite as `.filter().map().reduce()`; step-by-step refactor keeps the original loop until each stage is validated by tests.

```js
// before
const names = [];
for (const o of offices) {
  if (o.country === 'India') names.push(o.manager);
}
// after
const names = offices.filter(o => o.country === 'India').map(o => o.manager);
```

### Slide Statements
*Source: Fowler 2nd ed., Ch. 8*
**When:** Statements that belong together are scattered across unrelated code.
**Why safe:** Move them adjacent, respecting data dependencies; the compiler/tests confirm no interleaving side effects were disturbed.

### Decompose Conditional
*Source: Fowler 2nd ed., Ch. 10*
**When:** An `if/else if/else` has long, hard-to-name condition and body expressions.
**Why safe:** Extract each condition and each branch body as a named function; structure is unchanged, readability improves, and each extracted piece can be tested alone.

### Consolidate Conditional Expression
*Source: Fowler 2nd ed., Ch. 10*
**When:** Several sequential conditionals yield the same result.
**Why safe:** Combine with `&&`/`||` into one expression (or extract to a predicate function); truth table is unchanged.

### Replace Error Code with Exception (and its converse)
*Source: Fowler 2nd ed., Ch. 11*
**When:** Callers repeatedly check a sentinel return value; OR exceptions are thrown for conditions the caller could cheaply check first.
**Why safe:** Exceptions: every call-site that checked the code now propagates automatically — use only for genuinely exceptional paths. Precheck: swap try/catch for an `if` guard when the check is cheaper than the throw.

### Separate Query from Modifier
*Source: Fowler 2nd ed., Ch. 11*
**When:** A function both returns a value and mutates state.
**Why safe:** Split into a pure query and a void-returning command; call sites invoke both. Precondition: side effects must be idempotent or reorderable relative to the query.

### Hide Delegate / Remove Middle Man
*Source: Fowler 2nd ed., Ch. 7*
**When:** Hide — callers chain `a.getB().getC().foo()` exposing structure. Remove — a class is nothing but pass-throughs.
**Why safe:** Hide adds a delegating method; Remove deletes it. Each is the inverse, applied when the ratio of useful methods to pass-throughs tips.

---

## Functional Programming Refactorings

### Replace Imperative Loop with map/filter/fold
**When:** A `for`/`while` loop transforms, selects from, or reduces a collection without early exit or side effects.
**Why safe:** `map` preserves length and order, `filter` preserves order, `fold` specifies the accumulator precisely — each is total and equationally reasoned.
**Language-agnostic** (any FP language with higher-order collection functions).

```haskell
-- before
go [] acc = acc
go (x:xs) acc = go xs (if x > 0 then acc + x else acc)
-- after
sum (filter (> 0) xs)
```

### Extract Pure Function (separate I/O from logic)
*Source: Bird, "Pearls of Functional Algorithm Design"; also "Functional Core, Imperative Shell" (Bernhardt)*
**When:** A function mixes effectful code (I/O, DB, logging) with a pure transformation.
**Why safe:** Move the transformation to a new pure function; the shell calls it with loaded data. Pure function is deterministic and property-testable; the shell shrinks to glue.

### Introduce Monadic Effect
**When:** A function signals failure via exceptions, sentinels, or nulls; or implicitly depends on an ambient resource.
**Why safe:** Wrap the return type in `Maybe`/`Either`/`IO`/`Reader`; the monad's `>>=` sequences the effect, and the type system forces callers to handle the effect explicitly.
**Language-specific:** Haskell/PureScript native; Scala via `cats.effect.IO` or `ZIO`; F# via computation expressions.

### Replace Mutable State with State Monad (or Reader for read-only context)
**When:** A function threads a mutable accumulator or environment through many calls manually.
**Why safe:** `State s a` / `Reader r a` encapsulates the threading; referential transparency is preserved because the state is a pure value, not a ref cell.

### Lift to Point-Free (η-reduction)
**When:** A lambda trivially applies its argument to another function: `\x -> f x`.
**Why safe:** η-equivalence: `\x -> f x` ≡ `f` for pure functions. Do NOT apply blindly — point-free can obscure intent and in strict languages changes evaluation of `seq`/bottom. Applicability rule: apply when it removes noise, not when it removes names readers need.

### β-reduction (Inline Lambda Application)
**When:** `(\x -> body) arg` appears where `body[arg/x]` is clearer.
**Why safe:** β-equivalence guaranteed by the language's operational semantics for pure terms; in call-by-value watch for side-effect ordering.

### Replace Record Update with Lens / Optics
*Source: van Laarhoven, "Lenses: compositional data access and manipulation"*
**When:** Nested immutable record updates become a pyramid of copy-with-change.
**Why safe:** A lens `Lens s a` is a pair (get, set) satisfying the lens laws; composition is associative, so `outer . inner . leaf` behaves like nested field access.
**Language-specific:** Haskell (`lens`, `optics`); Scala (`Monocle`); PureScript (`profunctor-lenses`).

```haskell
-- before
updateCity u c = u { address = (address u) { city = c } }
-- after (lens)
updateCity u c = u & address . city .~ c
```

### Curry / Uncurry
**When:** Curry: you need partial application or want to compose. Uncurry: you need to pass a function that consumes a tuple (e.g., to `map` over `zip xs ys`).
**Why safe:** `curry` and `uncurry` are inverse isomorphisms `(a,b) -> c  ≅  a -> b -> c`. Same extension/behaviour, different shape.

### Replace Conditional with Pattern Match
**When:** `if` / nested `if` dispatches on the shape of a sum type.
**Why safe:** The compiler checks exhaustiveness on sum types (with `-Wincomplete-patterns` / equivalent) — drift is caught statically; default cases are opted into explicitly.
**Language-agnostic** (Haskell/OCaml/Scala/Rust/F#/Elm).

### Replace Exception with Either / Result
**When:** A function throws for a predictable domain failure, forcing callers into try/catch.
**Why safe:** The error becomes part of the type; compiler enforces handling at every call-site. Thrown exceptions are invisible in signatures; `Either e a` is visible.

```scala
// before
def parseAge(s: String): Int = s.toInt
// after
def parseAge(s: String): Either[ParseError, Int] =
  s.toIntOption.toRight(ParseError(s))
```

### Replace Null with Option / Maybe
**When:** A function returns `null` to mean "missing".
**Why safe:** `Option`/`Maybe` distinguishes presence at the type level; callers can't forget to check because projection requires `map`/`flatMap`/pattern match.

### Introduce Type Alias
**When:** A structural type (`Map String [User]`, `Int -> Int -> Bool`) is referenced widely and carries a domain name.
**Why safe:** `type` aliases are transparent — no runtime cost, no subtype confusion; swap is mechanical.

### Replace Type Alias with Newtype
*Source: Wadler, "Theorems for Free"; Haskell `newtype` idiom*
**When:** A type alias like `type UserId = Int` is accidentally interchangeable with other `Int`-aliases (`OrderId`, `Age`).
**Why safe:** `newtype` is nominally distinct at compile time but zero-cost at runtime; typos between `UserId` and `OrderId` become compile errors.

```haskell
-- before
type UserId = Int
type OrderId = Int
-- after
newtype UserId = UserId Int
newtype OrderId = OrderId Int
```

### Applicative Lifting (`liftA2` / `<*>`)
**When:** Independent effectful computations must be combined; `do`-notation suggests sequencing that doesn't reflect real dependency.
**Why safe:** `Applicative` laws (identity, composition, homomorphism, interchange) preserve meaning; exposes parallelism opportunities that monadic bind hides.

### Replace Sequence-of-Effects with `traverse`
*Source: McBride & Paterson, "Applicative Programming with Effects" (2008)*
**When:** Code does `mapM f xs` / explicit fold that collects effectful results into a list.
**Why safe:** `traverse :: (Traversable t, Applicative f) => (a -> f b) -> t a -> f (t b)` — the `Traversable` laws guarantee the structure is preserved and effects run in declared order.
**FP nuance:** `traverse` generalizes over any `Applicative`, so the same code works for `IO`, `Either e`, `Validation e`, `Parser`, etc.

### Foldable / Traversable Generalization
**When:** A function is written for `[a]` but logically requires only "things that can be folded/traversed".
**Why safe:** Weakening `[a]` to `Foldable f => f a` broadens callers without changing internals — the `Foldable` laws restrict operations to those `[]` already supports.

### Replace Custom Recursion with Catamorphism (Fold)
*Source: Meijer, Fokkinga, Paterson, "Functional Programming with Bananas, Lenses, Envelopes and Barbed Wire" (1991)*
**When:** Hand-written structural recursion over a data type repeats a pattern.
**Why safe:** A catamorphism is the unique homomorphism from the initial algebra — any structurally-recursive function on an ADT can be expressed as one `cata`/`fold`, and termination is guaranteed by structural decrease.

### Introduce Typeclass / Replace Dispatch with Typeclass
**When:** Functions take a record of operations (dictionary-passing by hand), or pattern-match on a tag to pick behaviour.
**Why safe:** A typeclass makes dispatch implicit; instance resolution is compile-time, and instances must satisfy the class laws. Watch: coherence (one instance per type) must hold.

### Replace Boolean Blindness with Sum Type
*Source: Harper, "Boolean Blindness" (existentialtype.wordpress.com, 2011)*
**When:** A function returns `Bool` or takes a `Bool` parameter where the meaning of `True`/`False` is not obvious from the type.
**Why safe:** A two-constructor sum type (`data Access = Granted | Denied`) carries its meaning in the type; pattern matches document intent and exhaustiveness is checked.

### Parse, Don't Validate
*Source: Alexis King, "Parse, Don't Validate" (2019), https://lexi-lambda.github.io/blog/2019/11/05/parse-don-t-validate/*
**When:** A function checks invariants and returns `()` / `Bool`, forcing downstream code to re-check or trust.
**Why safe:** Strengthen the return type to a refined type (`NonEmpty a`, `ValidatedEmail`) — once parsed, invariants are witnessed by the type, and callers cannot forget them.

```haskell
-- before
validateNonEmpty :: [a] -> Either Error ()
-- after
parseNonEmpty :: [a] -> Either Error (NonEmpty a)
```

### Make Illegal States Unrepresentable
*Source: Yaron Minsky, "Effective ML"; Scott Wlaschin, "Domain Modeling Made Functional"*
**When:** A record carries combinations of fields that are only valid in specific combinations (e.g. `{ isLoading, data, error }` where only one should be set).
**Why safe:** Replace the product type with a sum type encoding the valid shapes (`data State = Loading | Loaded Data | Failed Error`); invalid combinations become uninhabited — they cannot be constructed.

### Phantom Types for Units / State Tracking
*Source: Leijen & Meijer, "Domain-Specific Embedded Compilers"; common in Haskell/OCaml*
**When:** A type like `Double` or `Handle` is used in contexts with incompatible semantics (meters vs feet; open vs closed).
**Why safe:** Add a phantom parameter (`newtype Quantity u = Quantity Double`); the parameter enforces distinctions at compile time with zero runtime cost.

```haskell
newtype Quantity u = Quantity Double
data Meters; data Feet
-- addQuantity :: Quantity u -> Quantity u -> Quantity u  -- same unit only
```

---

## Lean / Theorem-Prover Refactorings

*Source: Lean 4 docs (https://lean-lang.org/theorem_proving_in_lean4/), Mathlib4 tactic reference, and de Moura & Ullrich, "The Lean 4 Theorem Prover and Programming Language" (CADE 2021).*

### Replace `sorry` with Proof
**When:** A `sorry` placeholder marks an unfinished proof obligation.
**Why safe:** `#print axioms` or the `sorryAx` warning identifies every remaining `sorry`; replacing one with a complete term/tactic script removes `sorryAx` from the axiom set of that theorem.

### Extract Lemma
**When:** A sub-goal proved inline within a larger proof is reusable or clutters the parent script.
**Why safe:** Pull the sub-proof to a top-level `theorem`/`lemma` with the exact goal; the parent invokes it via `exact sublemma …` or `apply sublemma`. Type-check confirms no context was implicitly captured.

### Generalize Hypothesis (`generalize` / `revert`)
**When:** A hypothesis mentions a specific term that prevents induction or rewriting.
**Why safe:** `generalize h : expr = x` replaces `expr` with a fresh variable `x` and records `h : expr = x`; the goal remains provably equivalent because the equation is in context.

### Introduce `have`
**When:** A proof step is used multiple times or needs a name to make the structure readable.
**Why safe:** `have h : P := proof` elaborates `proof : P` and adds `h` to the context — type-checked at introduction, so subsequent steps can rely on `h` without re-proof.

### Introduce `let`
**When:** A term recurs in the goal or in later proofs and deserves a name with its definition preserved.
**Why safe:** Unlike `have`, `let x := e` keeps `x` definitionally equal to `e`, so `rfl`-style reasoning still unfolds it; useful when you need both a name and transparency.

### Refactor `rw` Chain into `simp only [..]`
**When:** A sequence `rw [h1]; rw [h2]; rw [h3]` applies orientation-free rewrites that don't depend on order.
**Why safe:** `simp only [h1, h2, h3]` confines simp to the listed lemmas — it's more robust to term shape (handles under-binders, congruence), and unlike full `simp` it won't pull in unexpected simp-set lemmas.

### Replace Manual Proof with `decide` / `omega` / `linarith` / `nlinarith`
**When:** The goal is decidable (`decide`), linear over ℕ/ℤ (`omega`), linear over ordered fields (`linarith`), or nonlinear arithmetic (`nlinarith`).
**Why safe:** Each tactic is a verified decision procedure (or complete for its fragment); success produces a kernel-checked proof term — the decision procedure is not trusted, only its output.

```lean
-- before
example (a b : Nat) (h : a ≤ b) : a + 1 ≤ b + 1 := Nat.succ_le_succ h
-- after
example (a b : Nat) (h : a ≤ b) : a + 1 ≤ b + 1 := by omega
```

### Move Assumption into Premise (`revert`) / out of Premise (`intro`)
**When:** Induction or a tactic requires the hypothesis to be part of the goal (or vice-versa).
**Why safe:** `revert h` and `intro h` are inverses; together they preserve the proposition being proved — only its tactic-level shape changes.

### Strengthen / Weaken Induction Hypothesis
**When:** `induction` yields an IH too weak to close the step case, because a parameter was fixed before induction.
**Why safe:** `revert` the blocking parameter (or use `induction … generalizing x`) before `induction`; the resulting IH is universally quantified over `x`, strictly stronger, and the original goal is recovered by re-`intro`.

### Replace `exact` with `apply` (and vice versa)
**When:** `exact` fails because arguments need unification holes (prefer `apply`); or `apply` creates redundant metavariables when a full term is known (prefer `exact`).
**Why safe:** Both produce the same proof term when the given term unifies with the goal; `apply` leaves subgoals for unresolved arguments, `exact` demands full resolution. Choice is stylistic when both succeed.

### Use `classical` Tactic / `open Classical`
**When:** A proof needs excluded middle or choice and is not naturally constructive.
**Why safe:** `classical` locally assumes `Classical.em`/`Classical.choice`; these are standard Lean axioms already trusted in Mathlib, so no new soundness cost is incurred — but the theorem's `#print axioms` will list them.

### Convert Tactic-Mode Proof to Term-Mode (and vice versa)
**When:** Term-mode: proof is short, mechanical, and clearer as one expression. Tactic-mode: proof is long, exploratory, or benefits from interactive feedback.
**Why safe:** The term elaborated from a tactic block and the hand-written term are both checked by the same kernel; equivalence is verified by successful re-elaboration. Signature stays fixed.

```lean
-- tactic mode
theorem and_comm' : p ∧ q → q ∧ p := by
  intro ⟨hp, hq⟩; exact ⟨hq, hp⟩
-- term mode
theorem and_comm' : p ∧ q → q ∧ p :=
  fun ⟨hp, hq⟩ => ⟨hq, hp⟩
```

### Replace `simp` with `simp only [..]` (Tighten Simp Set)
**When:** A `simp` call succeeds but becomes brittle when the default simp set evolves.
**Why safe:** Switching to `simp only [lemma1, lemma2, …]` pins the rewrite set; the proof no longer depends on global simp attributes, making it reproducible across Mathlib updates.

### Refactor `calc` Block / Introduce `calc`
**When:** A chain of `trans`/`Eq.trans` steps is hard to read, or a chain of rewrites is obscuring a transitive argument.
**Why safe:** `calc` is syntactic sugar for chained transitivity using the same underlying lemmas; each step is type-checked independently against the declared relation, so structural rearrangement cannot produce a false proof.
