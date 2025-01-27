# new_generic needs fun or dispatch_args

    Must call `new_generic()` with at least one of `dispatch_args` or `fun`

# check_dispatch_args() produces informative errors

    Code
      check_dispatch_args(1)
    Error <simpleError>
      `dispatch_args` must be a character vector
    Code
      check_dispatch_args(character())
    Error <simpleError>
      `dispatch_args` must have at least one component
    Code
      check_dispatch_args("")
    Error <simpleError>
      `dispatch_args` must not be missing or the empty string
    Code
      check_dispatch_args(NA_character_)
    Error <simpleError>
      `dispatch_args` must not be missing or the empty string
    Code
      check_dispatch_args(c("x", "x"))
    Error <simpleError>
      `dispatch_args` must be unique
    Code
      check_dispatch_args("...")
    Error <simpleError>
      Can't dispatch on `...`
    Code
      check_dispatch_args("x", function(x, y, ...) { })
    Error <simpleError>
      If present, ... must immediately follow the `dispatch_args`
    Code
      check_dispatch_args("y", function(x, ..., y) { })
    Error <simpleError>
      `dispatch_args` must be a prefix of the generic arguments

# R7_generic printing

    Code
      foo
    Output
      <R7_generic> function (x, y, z, ...)  with 3 methods:
      1: method(foo, list("character", "integer", "character"))
      2: method(foo, list("character", "integer", "logical"))
      3: method(foo, list("character", text, "character"))

# R7_generic printing with long / many arguments

    Code
      foo
    Output
      <R7_generic> function (a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, 
          r, s, t, u, v, w, x, y, z, ...)  with 0 methods:

# check_generic produces informative errors

    Code
      check_generic("x")
    Error <simpleError>
      `fun` must be a function
    Code
      check_generic(function() { })
    Error <simpleError>
      `fun` must contain a call to `method_call()`

