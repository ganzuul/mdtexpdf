---
title: "Test LaTeX Error Diagnostics"
author: "mdtexpdf test"
date: "2025-01-01"
---

# Error Diagnostics Test

This document contains patterns that commonly break LaTeX output.

## Table with bare $ and ! characters

| Field | Value |
|-------|-------|
| query | $event_id \| !room_id \| server_name" |
| status | $active |

## Inline code with special characters

The variable `$foo!bar` is problematic.

So is `event_id | !room_id`.

## Unpaired dollar signs

This line has an unpaired $ sign which will break math mode.

## Normal content

This paragraph is fine and should not trigger any warnings.
