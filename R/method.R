#' Retrieve or register an R7 method for a generic
#'
#' @description
#' Generics partition a function into interface (a generic) and implementation
#' (many methods). `method<-` allows you to register a method, an
#' implementation for a specified class signature, with a generic.
#'
#' `method()` retrieves a method for a given signature. You typically shouldn't
#' need this function while programming, because calling the generic will
#' automatically dispatch to the correct method, but it's often useful
#' interactively in order to see the implementation of a specific method.
#'
#' @param generic A generic function.
#' @param signature A method signature, a list of R7 class constructors
#'   (produced by [new_class()]) or names of S3 or S4 classes.
#' @param value A function that implements the generic specification for the
#'   given `signature`. The arguments must be compatible with the generic.
#' @importFrom utils getS3method
#' @export
#' @examples
#' # Create a generic
#' bizarro <- new_generic("bizarro", dispatch_args = "x")
#' # Register some methods
#' method(bizarro, "numeric") <- function(x, ...) rev(x)
#' method(bizarro, "factor") <- function(x, ...) {
#'   levels(x) <- rev(levels(x))
#'   x
#' }
#' method(bizarro, "data.frame") <- function(x, ...) {
#'   x[] <- lapply(x, bizarro)
#'   rev(x)
#' }
#'
#' # Using a generic calls the methods automatically
#' bizarro(1)
#'
#' # But it can be useful to explicitly retrieve a method in order to
#' # inspect its implementation
#' method(bizarro, list("numeric"))
#' method(bizarro, list("factor"))
method <- function(generic, signature) {
  signature <- as_signature(signature)

  method_impl(generic, signature, ignore = NULL)
}

methods <- function(generic) {
  get_all_methods(generic@methods, character())
}

get_all_methods <- function(x, signature) {
  if(!is.environment(x)) {
    return(x)
  }

  unlist(lapply(names(x), function(class) get_all_methods(x[[class]], c(signature, class))), recursive = FALSE)
}

as_signature <- function(signature) {
  if (!is.list(signature)) {
    signature <- list(signature)
  }
  is_valid_signature <- vlapply(signature, function(x) inherits(x, "R7_class") | inherits(x, "character"))
  if (all(is_valid_signature)) {
    return(signature)
  }

  invalid_indexes <- which(!is_valid_signature)
  invalid_classes <- vcapply(signature[!is_valid_signature], function(x) fmt_classes(class(x)))

  stop(
    "`signature` must be a list of <R7_class> or a <character>:\n",
    paste0(collapse = "\n",
      sprintf("- `signature[%s]`: is %s", invalid_indexes, invalid_classes)
    ),
  call. = FALSE)
}

method_impl <- function(generic, signature, ignore) {
  out <- .Call(method_, generic, signature, ignore)
  if (is.null(out)) {
    # If no R7 method is found, see if there are any S3 methods registered
    if (inherits(generic, "R7_generic")) {
      args <- generic@dispatch_args
      generic <- generic@name
    } else {
      generic <- find_function_name(generic, topenv(environment(generic)))
      args <- names(formals(generic))
    }
    args <- setdiff(args, "...")

    out <- getS3method(generic, signature[[1]][[1]], optional = TRUE)

    # If no method found check if the generic has a default method
    out <- getS3method(generic, "default", optional = TRUE)
  }

  if (is.null(out)) {
    method_lookup_error(generic, args, signature)
  }

  out
}

find_function_name <- function(x, env) {
  nms <- ls(env, all.names = TRUE, sorted = FALSE)
  for (name in nms) {
    if (identical(get0(name, envir = env, mode = "function", inherits = FALSE), x)) {
      return(name)
    }
  }
  NULL
}

#' Retrieve the next applicable method after the current one
#'
#' @export
next_method <- function() {
  current_method <- sys.function(sys.parent(1))

  methods <- list()
  i <- 1
  while (!inherits(current_method, "R7_generic")) {
    methods <- c(methods, current_method)
    i <- i + 1
    current_method <- sys.function(sys.parent(i))
  }

  generic <- current_method

  # Find signature
  dispatch_on <- setdiff(generic@dispatch_args, "...")
  vals <- mget(dispatch_on, envir = parent.frame())
  signature <- lapply(vals, object_class)

  method_impl(generic, signature, ignore = methods)
}

method_compatible <- function(method, generic) {
  generic_formals <- suppressWarnings(formals(args(generic)))
  # This can happen for some primitive functions such as `[`
  if (length(generic_formals) == 0) {
    return()
  }

  method_formals <- formals(method)
  generic_args <- names(generic_formals)
  method_args <- names(method_formals)

  n_dispatch <- length(generic@dispatch_args)
  has_dispatch <- length(method_formals) >= n_dispatch &&
    identical(method_args[1:n_dispatch], generic@dispatch_args)
  if (!has_dispatch) {
    stop("`method` doesn't match generic dispatch arg", call. = FALSE)
  }
  if ("..." %in% method_args && method_args[[n_dispatch + 1]] != "...") {
    stop("... must immediately follow dispatch args", call. = FALSE)
  }
  empty_dispatch <- vlapply(method_formals[generic@dispatch_args], identical, quote(expr = ))
  if (any(!empty_dispatch)) {
    stop("Dispatch arguments must not have default values", call. = FALSE)
  }

  extra_args <- setdiff(names(generic_formals), c(generic@dispatch_args, "..."))
  for (arg in extra_args) {
    if (!arg %in% method_args) {
      warning(sprintf("Argument `%s` is missing from method", arg), call. = FALSE)
    } else if (!identical(generic_formals[[arg]], method_formals[[arg]])) {
      warning(sprintf("Default value is not the same as the generic\n- Generic: %s = %s\n- Method:  %s = %s", arg, deparse1(generic_formals[[arg]]), arg, deparse1(method_formals[[arg]])), call. = FALSE)
    }
  }

  TRUE
}

new_method <- function(generic, signature, method, package = NULL) {
  if (inherits(generic, "R7_external_generic")) {
    # Get current package, if any
    if (!is.null(package)) {
      tbl <- asNamespace(package)[[".__S3MethodsTable__."]]
      if (is.null(tbl[[".R7_methods"]])) {
        tbl[[".R7_methods"]] <- list()
      }
      tbl[[".R7_methods"]] <- append(tbl[[".R7_methods"]], list(list(generic = generic$generic, package = generic$package, signature = signature, method = method, version = generic$version)))

      return(invisible())
    }
    generic <- getFromNamespace(generic$generic, asNamespace(generic$package))
  }

  if (!is.character(signature) && !inherits(signature, "list")) {
    signature <- list(signature)
  }

  generic <- as_generic(generic)

  method_compatible(method, generic)

  if (!inherits(method, "R7_method")) {
    method <- R7_method(generic, signature, method)
  }

  if (inherits(generic, "S3_generic")) {
    if (inherits(signature[[1]], "R7_class")) {
      signature[[1]] <- signature[[1]]@name
    }
    registerS3method(attr(generic, "name"), signature[[1]], method, envir = parent.frame())
    return(invisible(generic))
  }

  generic_name <- generic@name

  p_tbl <- generic@methods


  for (i in seq_along(signature)) {
    if (inherits(signature[[i]], "R7_union")) {
      for (class in signature[[i]]@classes) {
        new_method(generic, c(signature[seq_len(i - 1)], class@name), method)
      }
      return(invisible(generic))
    } else if (inherits(signature[[i]], "R7_class")) {
      signature[[i]] <- signature[[i]]@name
    }
    if (i == length(signature)) {
      p_tbl[[signature[[i]]]] <- method
    } else {
      tbl <- p_tbl[[signature[[i]]]]
      if (is.null(tbl)) {
        tbl <- new.env(hash = TRUE, parent = emptyenv())
        p_tbl[[signature[[i]]]] <- tbl
      }
      p_tbl <- tbl
    }
  }

  invisible(generic)
}


#' @rdname method
#'
#' @export
`method<-` <- function(generic, signature, value) {
  new_method(generic, signature, value, package = packageName(parent.frame()))
}

find_generic_name <- function(generic) {
  env <- environment(generic) %||% baseenv()
  for (nme in names(env)) {
    if (identical(generic, env[[nme]])) {
      return(nme)
    }
  }
}

as_generic <- function(generic) {
  if (length(generic) == 1 && is.character(generic)) {
    fun <- match.fun(generic)
    generic <- fun
  }
  if (!inherits(generic, "R7_generic")) {
    attr(generic, "name") <- find_generic_name(generic)
    class(generic) <- "S3_generic"
  }

  generic
}

#' @export
print.R7_method <- function(x, ...) {
  method_signature <- method_signature(x@signature)

  msg <- sprintf("method(%s, list(%s))", x@generic@name, method_signature)

  attributes(x) <- NULL

  cat("<R7_method> ", msg, "\n", sep = "")
  print(x)
}
