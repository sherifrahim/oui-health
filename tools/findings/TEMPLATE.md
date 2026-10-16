# Finding NNNN — <short title>

- **Target:** <package name + version, e.g. com.samsung.android.app.watchmanager 2.x (base split)>
- **Category:** (A) on-device satisfiable | (B) missing channel | (C) server/signature limit
- **Feature affected:** <what the user loses on a non-Samsung phone>
- **Date / analyst:**

## Gate

Where and how the suite decides it is not on a Samsung phone.

- **Class / method:** `Lcom/...;->method()`
- **Mechanism:** (Build fingerprint | system-feature | Sem* API | signature/package | account | server)

## Evidence

Point at the real thing — never paraphrase from memory. One of:
- decompiled lines (REA `inspect-android-method` output, with the evidence id), or
- the exact string-table literals + class descriptors that locate it (from `scan-blockers.sh`).

```
<paste the evidence>
```

Note which parts are **confirmed** (seen in the binary) vs **inferred** (branch behaviour not yet
decompiled).

## Un-gating strategy

How the oui-health interop layer answers this gate. Be concrete and reviewable.

## Limits / risks

What this does not solve; what could break; whether it needs a real Samsung package present.
