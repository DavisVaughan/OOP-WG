#' @importFrom utils modifyList
R7_class <- function(name, parent = R7_object, constructor = NULL, validator = function(x) NULL, properties = list()) {

  parent_obj <- class_get(parent)
  if (!is.null(parent_obj) && inherits(parent_obj, "R7_class")) {
    parent <- parent_obj
  }

  # Combine properties from parent, overriding as needed
  properties <- modifyList(
    attr(parent, "properties", exact = TRUE) %||% list(),
    as_properties(properties)
  )

  if (is.null(constructor)) {
    constructor <- new_constructor(parent, properties)
  }

  object <- constructor
  attr(object, "name") <- name
  attr(object, "parent") <- parent
  attr(object, "properties") <- properties
  attr(object, "constructor") <- constructor
  attr(object, "validator") <- validator
  class(object) <- c("R7_class", "R7_object")

  global_variables(names(properties))
  object
}

#' Create a new R7 class
#'
#' A class specifies the properties (data) that each of its objects will
#' possess. The class, and its parent, determines which method will be used
#' when an object is passed to a generic.
#'
#' @param name The name of the class, as a string.
#' @param parent The parent class.
#'
#'   * To inherit behaviour from an R7 class, pass the class object.
#'   * To inherit behaviour from a base type, pass the function you'd use
#'     to construct the object, e.g. `character`, `integer`.
#'
#' @param constructor The constructor function. This is optional, unless
#'   you want to control which properties can be set on constructor.
#' @param validator A function used to determine whether or not an object
#'   is valid. This is called automatically after construction, and
#'   whenever any property is set. It should return `NULL` if the object is
#'   valid, and otherwise return a character vector of problems.
#' @param properties A list specifying the properties (data) that
#'   every object of the class will possess. Each property can either be
#'   a named string (specifying the class), or a call to [new_property()],
#'   allowing greater flexibility.
#' @return A object constructor, a function that can be used to create objects
#'   of the given class.
#' @export
#' @examples
#' # Create an class that represents a range using a numeric start and end
#' range <- new_class("range",
#'   properties = list(
#'     start = "numeric",
#'     end = "numeric"
#'   )
#' )
#' r <- range(start = 10, end = 20)
#' r
#' # get and set properties with @
#' r@start
#' r@end <- 40
#' r@end
#'
#' # Use a validator to ensure that start and end are both length 1,
#' # and that start is < end
#' range <- new_class("range",
#'   properties = list(
#'     start = "numeric",
#'     end = "numeric"
#'   ),
#'   validator = function(x) {
#'     if (length(x@start) != 1) {
#'       "@start must be a single number"
#'     } else if (length(x@end) != 1) {
#'       "@end must be a single number"
#'     } else if (x@end < x@start) {
#'       "@end must be great than or equal to @start"
#'     }
#'   }
#' )
#' try(range(start = c(10, 15), end = 20))
#' try(range(start = 20, end = 10))
#' # Type validation is performed automatically in R7
#' try(range(start = "hello", end = 20))
new_class <- function(
    name,
    parent = R7_object,
    properties = list(),
    constructor = NULL,
    validator = function(x) NULL) {

  R7_class(
    name = name,
    parent = parent,
    constructor = constructor,
    validator = validator,
    properties = properties
  )
}

#' Retrieve all of the class names for a class
#'
#' @param object The R7 object to query
#' @return A character vector of all the class names for a given R7 class.
#' @export
class_names <- function(object) {
  parent <- object
  classes <- character()
  while(!is.null(parent)) {
    if (inherits(parent, "R7_union")) {
      for (class in parent@classes) {
        classes <- c(classes, class_names(class))
      }
    } else if (inherits(parent, "R7_class")) {
      classes <- c(classes, parent@name, "R7_object")
    } else {
      classes <- c(classes, parent)
    }
    parent <- prop_safely(parent, "parent")
  }
  unique(classes, fromLast = TRUE)
}

#' Retrieve the R7 class from a class specification
#'
#' @param x The name of the R7 class
#' @param envir The environment to look for the name
#' @param unions Include unions?
#' @export
class_get <- function(x, unions = FALSE, envir = parent.frame()) {
  if (inherits(x, "R7_class")) {
    x
  } else if (unions && is_union(x)) {
    x
  } else if (is.function(x)) {
    candidate <- Filter(function(y) identical(x, y), base_constructors)
    if (length(candidate) != 1) {
      stop("Could not find class for constructor function", call. = FALSE)
    }
    base_classes[[names(candidate)]]
  } else if (is.character(x)) {
    if (length(x) == 1) {
      if (x %in% names(base_classes)) {
        return(base_classes[[x]])
      }

      obj <- get(x, envir = envir)
      if (inherits(obj, "R7_class")) {
        return(obj)
      }
    }

    # TODO: What do we do about existing S3 / S4 classes?
    NULL
  } else if (is.null(x)) {
    x
  } else {
    stop(
      "Must specify class as a <R7_class>, a base constructor function, or a string",
      call. = FALSE
    )
  }
}


#' @export
print.R7_class <- function(x, ...) {
  props <- x@properties
  if (length(props) > 0) {
    prop_names <- format(names(props))
    prop_types <- format(paste0("<", vcapply(props, function(xx) xx[["class"]][[1]] %||% ""), ">"), justify = "right")
    prop_fmt <- paste0(paste0(" $", prop_names, " ", prop_types, collapse = "\n"), "\n")
  } else {
    prop_fmt <- ""
  }
  parent <- prop_safely(x, "parent")
  parent <- prop_safely(parent, "name") %||% parent %||% ""

  cat(sprintf("<R7_class>\n@name %s\n@parent <%s>\n@properties\n%s", x@name, parent, prop_fmt), sep = "")
}

#' @export
str.R7_class <- function(object, ..., nest.lev = 0) {
  cat(if (nest.lev > 0) " ")
  cat("<", paste0(class_names(object), collapse = "/"), "> constructor", sep = "")
  cat("\n")

  if (nest.lev == 0) {
    props <- props(object)
    props$srcref <- NULL
    str_list(props, ..., prefix = "@", nest.lev = nest.lev)
  }
}
