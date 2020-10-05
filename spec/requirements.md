This page is for brainstorming on the technical requirements for solving our [problem](https://github.com/RConsortium/OOP-WG/wiki/Problem-Statement). Once we align on the requirements, we can start the design process.

## List of requirements
1. The system should be as compatible as possible with existing systems, particularly S3
1. Classes should be first class objects, extrinsic from instances
1. The system should support formal construction, casting, and coercion to create new instances of classes.
1. It should be convenient to systematically validate an instance
1. Double dispatch, and possibly general multiple dispatch, should be supported
1. Inheritance should be as simple as possible, ideally single (other features might compensate for the lack of multiple inheritance)
1. Syntax should be intuitive and idiomatic, and should not rely on side effects nor loose conventions
1. Namespace management should not be any more complicated than S3 currently
1. Performance should be competitive with existing solutions
1. The design should be simple to implement
1. The system should support reflection
1. The system should support lazy and dynamic registration of classes and methods.

## Compatibility

Ideally the new system will be an extension of S3, because S3 is already at the bottom of the stack and many of the other systems have some compatibility with S3.

## Classes as first class objects

It is important for classes to be defined extrinsically from instances, because it makes the data contract more obvious to both developers (reading the code) and users (interacting with objects). S4 represents classes as proper objects; however, typically developers will only refer to the classes by name (string literal) when interacting with the S4 API. Interacting directly with objects instead would likely simplify the API (syntax) and its implementation.

## Generics as extended function objects

Generic functions should be represented by a special class of function object that tracks its own method table. This puts generic functions at the same level as classes, which is the essence of functional OOP, and will likely enable more natural syntax in method registration.

## Formal instantiation and type conversion

Class instantiation should happen through a formal constructor. Once created, an object should keep its original class unless subjected to formal casting or formal coercion. The class of an object should be robust and predictable, and direct class assignment (e.g. `class<-()`) should generally be avoided.

## Systematic validation

Class contracts are often more complicated than a simple list of typed fields. Having a formally supported convention around validating objects is important so that code can make the necessary assumptions about data structures and their content. Otherwise, developers trying to be defensive will resort to ad hoc checks scattered throughout the code.
 
## Multiple dispatch

The system will at least need to support double dispatch, so that code can be polymorphic on the interaction of two arguments. There are many obvious examples: arithmetic, serialization (object, target), coercion, etc. It is less likely that we will require dispatch beyond two arguments, and any advantages are probably outweighed by the increase in complexity. In many cases of triple dispatch or higher in the wild, developers are abusing dispatch to implement type checks, instead of polymorphism. Almost always, we can deconstruct multiple dispatch into a series of double dispatch calls. General multiple dispatch makes software harder to understand and is more difficult to implement.

## Inheritance

Inheritance lets us define a data taxonomy, and it is often natural to organize a set of data structures into multiple, orthogonal taxonomies. Multiple inheritance enables that; however, it also adds a lot of complexity, both to the software relying on it and the underlying system. It is often possible and beneficial (in the long term) to rely on techniques like composition and delegation instead. We should consider how single inheritance languages like Java have been so successful, although they are not directly comparable to our functional system. 

## Syntax

Ideally the entire API could be free of side effects and odd conventions, like making the `.` character significant in method names. Direct manipulation of class and generic objects should enable this.

## Namespaces

The system should support exporting generics and classes. If classes are objects, they can be treated like any other object when exporting and importing symbols. If generics are objects, then it should be simple to export all methods on a generic.  It is not clear whether selective method export is important. One use case would be to hide a method with an internal class in its signature to avoid unnecessary documentation. Perhaps `R CMD check` could ignore methods for unexported classes. There should be no need for explicit method registration.  

## Reflection and dynamism

Given a class and a generic, you should be able to find the appropriate method without calling it. This is important for building tooling around the system.

## Lazy and dynamic registration

On the flip side, you should also be able to register a method lazily/dynamically at run-time. This is important for:

* Generics and classes in suggested packages, so that method registration can 
  occur when the dependency is loaded.

* Testing, since you may want to define a method only within a test. This is
  particularly useful whne used to eliminate the need for mocking.

* Interface evolution, so you can provide a method for a generic or class that 
  does not yet exist, anticipating a future release of a dependency.
