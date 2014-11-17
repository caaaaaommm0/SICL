(cl:in-package #:cleavir-ast-to-hir)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Compilation context.
;;;
;;; Each AST is compiled in a particular COMPILATION CONTEXT or
;;; CONTEXT for short.  A context object has three components:
;;;
;;; 1. SUCCESSORS, which is a proper list containing zero, one or two
;;; elements.  These elements are instructions resulting from the
;;; generation of the code that should be executed AFTER the code
;;; generated from this AST.  If the list contains two elements, then
;;; this AST is compiled in a context where a Boolean result is
;;; required.  In this case, the first element of the list is the
;;; successor to use when the value generated by the AST is NIL, and
;;; the second element is the successor to use when the value
;;; generated by the AST is something other than NIL.  If there are no
;;; successors, as indicated by SUCCESSORS being the empty list, then
;;; either a TAILCALL-INSTRUCTION (if the AST is a CALL-AST) or a
;;; RETURN-INSTRUCTION (for other ASTs) that returns all the values of
;;; the AST should be generated.
;;;
;;; 2. RESULTS, indicating how many values are required from the
;;; compilation of this AST.  It can be either a list or T.  If it is
;;; a list, it contains zero or more lexical locations into which the
;;; generated code must put the values of this AST.  If it is T, it
;;; means that ALL values are required.  If the list contains more
;;; elements than the number of values generated by this AST, then the
;;; remaining lexical locations in the list must be filled with NIL by
;;; the code generated from this AST.
;;;
;;; 3. INVOCATION, an ENTER-INSTRUCTION or NIL.  When it is an
;;; ENTER-INSTRUCTION, it indicates the function to which the code to
;;; be compiled belongs. When it is NIL, it means that the initial
;;; instruction was not an ENTER-INSTRUCTION and the code belongs to
;;; the top-level evaluation context.
;;;
;;; The following combinations of SUCCESSORS and RESULTS can occur:
;;;
;;;   SUCCESSORS is the empty list.  Then RESULTS is T, which means
;;;   that ALL the values are required.  Forms that are in TAIL
;;;   POSITION are compiled in a context like this.
;;;
;;;   SUCCESSORS has one element.  then RESULTS can be a list or T.
;;;
;;;      If RESULTS is the empty list, this means that no values are
;;;      required.  Forms inside a PROGN other than the last are
;;;      compiled in a context like this.
;;;
;;;      If RESULTS has a single element, then a single value is
;;;      required.  Arguments to function calls are examples of ASTs
;;;      that are compiled in a context like this.
;;;
;;;      If RESULTS has more than one element, then that many values
;;;      are required.  The VALUES-FORM-AST of MULTIPLE-VALUE-BIND-AST
;;;      is compiled in a context like this.
;;;
;;;      If RESULTS is T, then all values are required.  An example of
;;;      the use of this context is for compiling the FIRST-FORM of a
;;;      MULTIPLE-VALUE-PROG1 special form.
;;;
;;;   SUCCESSOR has two elements.  Then RESULTS is the empty list,
;;;   meaning that no values are required.  The TEST-AST of an IF-AST
;;;   is compiled in a context like this.
;;;
;;;   SUCCESSORS has more than two elements.  This possibility is
;;;   currently not used.  It is mean to be used for forms like CASE,
;;;   TYPECASE, etc.  Again, the RESULTS would be the empty list.

(defclass context ()
  ((%results :initarg :results :reader results)
   (%successors :initarg :successors :accessor successors)
   (%invocation :initarg :invocation :reader invocation)))

(defun context (results successors invocation)
  (unless (or (and (listp results)
		   (every (lambda (result)
			    (typep result 'cleavir-ir:lexical-location))
			  results))
	      (eq results t))
    (error "illegal results: ~s" results))
  (unless (and (listp successors)
	       (every (lambda (successor)
			(typep successor 'cleavir-ir:instruction))
		      successors))
    (error "illegal successors: ~s" results))
  (when (and (null successors) (not (null results)))
    (error "Illegal combination of results and successors"))
  (unless (or (null invocation)
	      (typep invocation 'cleavir-ir:enter-instruction))
    (error "Illegal invocation"))
  (make-instance 'context
    :results results
    :successors successors
    :invocation invocation))

(defmethod print-object ((obj context) stream)
  (print-unreadable-object (obj stream)
    (format stream " results: ~s" (results obj))
    (format stream " successors: ~s" (successors obj))))