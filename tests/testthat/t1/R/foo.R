#' @importFrom R7 method object_class
#' @export
foo <- R7::new_generic("foo", dispatch_args = c("x", "y"))
