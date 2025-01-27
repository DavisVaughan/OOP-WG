#' Get/set underlying "base" data
#'
#' When an R7 class inherits from an existing base type, it can be useful
#' to work with the underlying object, i.e. the R7 object stripped of class
#' and all properties.
#'
#' @inheritParams prop
#' @export
#' @examples
#' text <- new_class("text", parent = "character")
#' y <- text(c(foo = "bar"))
#' str(r7_data(y))
r7_data <- function(object) {
  # Remove properties, return the rest
  for (name in prop_names(object)) {
    attr(object, name) <- NULL
  }

  obj_cls <- object_class(object)
  class(object) <- setdiff(class_names(obj_cls@parent), obj_cls@name)
  object_class(object) <- object_class(obj_cls@parent)

  object
}

#' @export
#' @rdname r7_data
`r7_data<-` <- function(object, check = TRUE, value) {
  attrs <- attributes(object)
  object <- value
  attributes(object) <- attrs
  if (isTRUE(check)) {
    validate(object)
  }
  return(invisible(object))
}
