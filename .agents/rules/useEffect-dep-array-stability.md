# Rule: useEffect Dependency Array Stability

## When This Applies
Any time you modify, add, or refactor a `useEffect` hook in a React component.

## The Rule
**NEVER change the size of a `useEffect` dependency array in a hot-reloadable component.** React enforces that the dependency array must remain constant in size and order across renders. Changing `[]` → `[user]` during a hot-reload triggers a fatal React error:

```
The final argument passed to useEffect changed size between renders.
The order and size of this array must remain constant.
```

## Correct Patterns

### Pattern 1: Guard Inside, Not in Deps
If you need to gate a `useEffect` on a value that wasn't in the original deps, **add the guard inside the effect body** while keeping the deps array stable:

```tsx
// ✅ CORRECT — deps array stays empty, guard is inside
useEffect(() => {
    if (!user) return;  // guard inside
    doSomething();
}, []);  // deps unchanged
```

BUT this means `doSomething()` only runs on mount IF user is already available. If user arrives later, it won't re-fire. For that case, use Pattern 2.

### Pattern 2: Stable Primitive Dep
If you need the effect to re-fire when auth state changes, use a **stable primitive** (like `user?.uid`) instead of the full object:

```tsx
// ✅ CORRECT — deps use a primitive, not an object reference
useEffect(() => {
    if (!user) return;
    doSomething();
}, [user?.uid]);
```

### Pattern 3: From Scratch (New Effects)
When writing a NEW `useEffect`, always plan the deps array correctly from the start. Include all reactive values that should trigger re-execution.

## Anti-Pattern
```tsx
// ❌ WRONG — changing deps from [] to [user] breaks hot-reload
// Before: }, []);
// After:  }, [user]);  // 💥 React error
```

## Why This Matters
- Hot Module Replacement (HMR) preserves component state between code edits
- React tracks dependency array length per hook call site
- Changing the array size violates React's Rules of Hooks invariant
- This crashes the app during development and requires a full page reload to recover
