
<!-- README.md is generated from README.Rmd. Please edit that file -->

# Object-oriented Programming Working Group

  - [Initial proposal](proposal/proposal.org)
  - [Requirements brainstorming](spec/requirements.md)
  - [Minutes](minutes/)
  - [Code](R/) (this repository is an R package)

<!-- badges: start -->

[![R-CMD-check](https://github.com/jimhester/OOP-WG/workflows/R-CMD-check/badge.svg)](https://github.com/jimhester/OOP-WG/actions)
[![Codecov test
coverage](https://codecov.io/gh/jimhester/OOP-WG/branch/master/graph/badge.svg)](https://codecov.io/gh/jimhester/OOP-WG?branch=master)
<!-- badges: end -->

## Workflow

  - File an issue to discuss the topic and build consensus.
  - Once consensus has been reached, the issue author should create a
    pull request that summarises the discussion in the appropriate `.md`
    file, and request review from all folks who participated the issue
    discussion.
  - Once all participants have accepted the PR, the original author
    merges.

## Example

``` r
library(R7)
#> 
#> Attaching package: 'R7'
#> The following object is masked from 'package:base':
#> 
#>     @

range <- class_new("range",
  constructor = function(start, end) {
    object_new(start = start, end = end)
  },
  validator = function(x) {
    if (prop(x, "end") < prop(x, "start")) {
      "`end` must be greater than or equal to `start`"
    }
  },
  properties = c(start = "numeric", end = "numeric")
)

x <- range(start = 1, end = 10)

x@start
#> [1] 1

x@end
#> [1] 10

object_class(x)
#> r7: <range>
```

## Performance

The dispatch performance should be roughly on par with S3 and S4, though
as this is implemented in the package there is some overhead due to
`.Call` vs `.Primitive`.

``` r
text <- class_new("text", parent = "character", constructor = function(text) object_new(.data = text))
number <- class_new("number", parent = "numeric", constructor = function(x) object_new(.data = x))

x <- text("hi")
y <- number(1)

foo_r7 <- generic_new(name = "foo_r7", signature = alist(x=))
method(foo_r7, "text") <- function(x) paste0(x, "-foo")

foo_s3 <- function(x) {
  UseMethod("foo_s3")
}

foo_s3.text <- function(x) {
  paste0(x, "-foo")
}

library(methods)
setOldClass(c("number", "numeric", "r7_object"))
setOldClass(c("text", "character", "r7_object"))

setGeneric("foo_s4", function(x) standardGeneric("foo_s4"))
#> [1] "foo_s4"
setMethod("foo_s4", c("text"), function(x) paste0(x, "-foo"))

# Measure performance of single dispatch
bench::mark(foo_r7(x), foo_s3(x), foo_s4(x))
#> # A tibble: 3 x 6
#>   expression      min   median `itr/sec` mem_alloc `gc/sec`
#>   <bch:expr> <bch:tm> <bch:tm>     <dbl> <bch:byt>    <dbl>
#> 1 foo_r7(x)    4.22µs    5.2µs   186682.    3.99KB     74.7
#> 2 foo_s3(x)    3.87µs   5.03µs   169026.        0B      0  
#> 3 foo_s4(x)    4.01µs   4.45µs   174301.        0B     17.4


bar_r7 <- generic_new("bar_r7", alist(x=, y=))
method(bar_r7, list("text", "number")) <- function(x, y) paste0(x, "-", y, "-bar")

setGeneric("bar_s4", function(x, y) standardGeneric("bar_s4"))
#> [1] "bar_s4"
setMethod("bar_s4", c("text", "number"), function(x, y) paste0(x, "-", y, "-bar"))

# Measure performance of double dispatch
bench::mark(bar_r7(x, y), bar_s4(x, y))
#> # A tibble: 2 x 6
#>   expression        min   median `itr/sec` mem_alloc `gc/sec`
#>   <bch:expr>   <bch:tm> <bch:tm>     <dbl> <bch:byt>    <dbl>
#> 1 bar_r7(x, y)   9.71µs   10.5µs    89157.        0B    17.8 
#> 2 bar_s4(x, y)   9.29µs   10.3µs    92372.        0B     9.24
```

## TODO

  - Objects
      - [x] - A class object attribute, a reference to the class object,
        and retrieved with `object_class()`.
      - [x] - For S3 compatibility, a class attribute, a character
        vector of class names.
      - [ ] - Additional attributes storing properties defined by the
        class, accessible with @/prop().
  - Classes
      - [x] - R7 classes are first class objects with the following
          - [x] - `name`, a human-meaningful descriptor for the class.
              - [ ] - It does *not* identify the class.
          - [x] - `parent`, the class object of the parent class.
          - [x] - A constructor, an user-facing function used to create
            new objects of this class. It always ends with a call to
            `object_new()` to initialize the class.
          - [x] - A validator, a function that takes the object and
            returns NULL if the object is valid, otherwise a character
            vector of error messages.
          - [x] - properties, a list of property objects
  - Initialization
  - Shortcuts
  - Validation
      - [ ] - valid\_eventually
      - [ ] - valid\_implicitly
  - Unions
      - [ ] - Used in properties to allow a property to be one of a set
        of classes
      - [ ] - In method dispatch as a convenience for defining a method
        for multiple classes
  - Properties
      - [x] - Accessed using `prop()` / `prop<-`
      - [x] - Accessed using `@` / `@<-`
      - [x] - A name, used to label output
      - [ ] - A optional class or union
      - [ ] - An optional accessor function
      - [ ] - Properties are created with `prop_new()`
  - Generics
      - [x] - It knows its name and the names of the arguments in its
        signature
      - [x] - Calling `generic_new()` defines a new generic
      - [ ] - By convention, any argument that takes a generic function,
        can instead take the name of a generic function supplied as a
        string
  - Methods
      - [ ] -
