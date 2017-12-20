---
title: Rails Refactoring - The Service Object Debate
category: programming
subtitle: What's the best way to keep keep your controllers and models skinny?
---

When you first start sinking your teeth into Rails, you'll start hearing the "skinny controllers, fat models" line a lot. The idea behind this is that controllers ought to do as little as possible. Their primary responsibility, as far as I understand it, is to (1) fetch data and (2) set variables. They should have the minimum number of dependencies to achieve these two tasks. Per the saying, most of the dirty work should be offloaded to models.

Just so we're all on the same page, some examples might do us some good. Suppose we have a blog app with `Article`, `User`, and `Comment` models. They each have their own respective 

## Callbacks, or, How to Write the Most Unmaintainable Code
