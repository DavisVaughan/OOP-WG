#' Define a new property
#'
#' @description
#' A property defines a named component of an object. Properties are
#' typically used to store (meta) data about an object, and are often
#' limited to a data of a specific `class`.
#'
#' By specifying a `getter` and/or `setter`, you can make the property
#' "dynamic" so that it's computed when accessed or has some non-standard
#' behaviour when modified.
#'
#' @param name Property name, primarily used for error messages.
#' @param class If specified, any values must be one of these classes
#'   (or [class union][new_union]).
#' @param getter An optional function used to get the value. The function
#'   should take the object as its sole argument and return the value. If the
#'   property has a `class` the class of the value is validated.
#' @param setter An optional function used to set the value. The function
#'   should take the object and new value as its two parameters and return the
#'   modified object. The value is _not_ automatically checked.
#' @export
#' @examples
#' # Simple properties store data inside an object
#' pizza <- new_class("pizza", properties = list(
#'   new_property("slices", "numeric")
#' ))
#' my_pizza <- pizza(slices = 6)
#' my_pizza@slices
#' my_pizza@slices <- 5
#' my_pizza@slices
#'
#' # Dynamic properties can compute on demand
#' clock <- new_class("clock", properties = list(
#'   new_property("now", getter = function(x) Sys.time())
#' ))
#' my_clock <- clock()
#' my_clock@now; Sys.sleep(1)
#' my_clock@now
#'
#' # These can be useful if you want to deprecate a property
#' person <- new_class("person", properties = list(
#'   first_name = "character",
#'   new_property(
#'      "firstName",
#'      getter = function(x) {
#'        warning("@firstName is deprecated; please use @first_name instead")
#'        x@first_name
#'      },
#'      setter = function(x, value) {
#'        warning("@firstName is deprecated; please use @first_name instead")
#'        x@first_name <- value
#'      }
#'    )
#' ))
#' hadley <- person(first_name = "Hadley")
#' hadley@firstName
#' hadley@first_name
new_property <- function(name, class = NULL, getter = NULL, setter = NULL) {
  out <- list(name = name, class = class, getter = getter, setter = setter)
  class(out) <- "R7_property"

  out
}

#' @export
str.R7_property <- function(object, ..., nest.lev = 0) {
  cat(if (nest.lev > 0) " ")
  cat("<R7_property> \n")
  str_list(object, nest.lev = nest.lev)
}

#' Get or set value of a property
#'
#' - `prop()` and `@`, gets the value of the given property, throwing an
#'   error if the property doesn't exist for that object.
#' - `prop_safely()` returns `NULL` if a property doesn't exist,
#'   rather than throwing an error.
#' - `prop<-` and `@<-` set a new value for the given property.
#' - `props()` returns a list of all properties
#' - `prop_names()` returns the names of the properties
#' - `prop_exists(x, "prop")` returns `TRUE` iif `x` has property `prop`.
#'
#' @param object An object from a R7 class
#' @param name The name of the parameter as a character. Partial matching
#'   is not performed.
#' @param value A replacement value for the parameter. The object is
#'   automatically checked for validity after the replacement is done.
#' @export
#' @examples
#' horse <- new_class("horse", properties = list(
#'   name = "character",
#'   colour = "character",
#'   height = "numeric"
#' ))
#' lexington <- horse(colour = "bay", height = 15, name = "Lex")
#' lexington@colour
#' prop(lexington, "colour")
#'
#' lexington@height <- 14
#' prop(lexington, "height") <- 15
#'
#' try(prop(lexington, "age"))
#' prop_safely(lexington, "age")
prop <- function(object, name) {
  if (!inherits(object, "R7_object")) {
    stop("`object` is not an <R7_object>")
  } else if (!prop_exists(object, name)) {
    class <- object_class(object)
    stop(sprintf("Can't find property %s@%s", fmt_classes(attr(class, "name")), name))
  } else {
    prop_val(object, name)
  }
}

#' @rdname prop
#' @export
prop_safely <- function(object, name) {
  if (!inherits(object, "R7_object")) {
    NULL
  } else if (!prop_exists(object, name)) {
    NULL
  } else {
    prop_val(object, name)
  }
}

# Internal helper that assumes the property exists
prop_val <- function(object, name) {
  val <- attr(object, name, exact = TRUE)
  if (is.null(val)) {
    prop <- prop_obj(object, name)
    if (!is.null(prop$getter)) {
      val <- prop$getter(object)
    }
  }
  val
}

# Get underlying property object from class
prop_obj <- function(object, name) {
  class <- object_class(object)
  attr(class, "properties")[[name]]
}

#' @rdname prop
#' @export
prop_names <- function(object) {
  if (inherits(object, "R7_class")) {
    names(attributes(object))
  } else {
    class <- object_class(object)
    props <- attr(class, "properties", exact = TRUE)
    if (length(props) == 0) {
      character()
    } else {
      names(props)
    }
  }
}

#' @importFrom stats setNames
#' @rdname prop
#' @export
props <- function(object) {
  prop_names <- prop_names(object)
  if (length(prop_names) == 0) {
    list()
  } else {
    setNames(lapply(prop_names, prop_safely, object = object), prop_names)
  }
}

#' @rdname prop
#' @export
prop_exists <- function(object, name) {
  name %in% prop_names(object)
}

#' @rdname prop
#' @param check If `TRUE`, check that `value` is of the correct type and run
#'   [validate()] on the object before returning.
#' @export
`prop<-` <- local({
  # This flag is used to avoid infinate loops if you are assigning a property from a setter function
  setter_property <- NULL

  function(object, name, check = TRUE, value) {
    prop <- prop_obj(object, name)
    if (!is.null(prop$setter) && !identical(setter_property, name)) {
      setter_property <<- name
      on.exit(setter_property <<- NULL, add = TRUE)
      object <- prop$setter(object, value)
    } else {
      if (isTRUE(check) && length(prop[["class"]]) > 0) {
        classes <- setdiff(class_names(prop[["class"]]), "R7_object")
        if (!inherits(value, classes)) {
          obj_cls <- object_class(object)
          stop(sprintf("%s@%s must be of class %s:\n- `value` is of class <%s>", fmt_classes(obj_cls@name), name, fmt_classes(classes), class(value)[[1]]), call. = FALSE)
        }
      }
      attr(object, name) <- value
    }

    if (isTRUE(check)) {
      validate(object)
    }

    invisible(object)
  }
})

#' @rdname prop
#' @usage object@name
#' @export
`@` <- function(object, name) {
  if (inherits(object, "R7_object")) {
    name <- as.character(substitute(name))
    prop(object, name)
  } else {
    name <- substitute(name)
    do.call(base::`@`, list(object, name))
  }
}

#' @rawNamespace S3method("@<-",R7_object)
`@<-.R7_object` <- function(object, name, value) {
  nme <- as.character(substitute(name))
  prop(object, nme) <- value

  invisible(object)
}

as_properties <- function(x) {
  if (length(x) == 0) {
    return(list())
  }

  named_chars <- vlapply(x, is.character) & has_names(x)
  R7_properties <- vlapply(x, inherits, "R7_property")

  if (!all(named_chars | R7_properties)) {
    stop("`x` must be a list of 'R7_property' objects or named characters", call. = FALSE)
  }

  x[named_chars] <- mapply(new_property, name = names(x)[named_chars], class = x[named_chars], USE.NAMES = TRUE, SIMPLIFY = FALSE)

  names(x)[!named_chars] <- vcapply(x[!named_chars], function(x) x[["name"]])

  x
}
