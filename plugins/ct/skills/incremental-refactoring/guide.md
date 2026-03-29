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
