(in-package #:sicl-configuration)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; The size of a machine word.

(defconstant +word-size-in-bytes+ 4)
(defconstant +word-size-in-bits+ (* +word-size-in-bytes+ 8))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Tags
;;;
;;; We define only four main tags.  Two of the tags represent
;;; immediate data (fixnum, immediate) and two represent
;;; heap-allocated data (cons, other).  
;;;
;;; Fixnums are represented with two zero tag bits.  A machine number
;;; is simply shifted two positions to the left to obtain a fixnum.
;;; In other words, a fixnum is just represented as a machine number
;;; with 4 times the magnitude.  Thus, a negative fixnum has the most
;;; significant bit set to `1'.  This representation is well known to
;;; have some good properties, in particular that addition and
;;; subtraction can be performed on fixnums using existing machine
;;; instructions, and multiplcation only reuquires a shift operation
;;; to turn the result into the right representation (unless, of
;;; course, the operations cause overflow and we have to create a
;;; bignum instead.
;;;
;;; Immediate data other than fixnums is typically characters, but
;;; floating-point numbers that require no more than the available
;;; bits can also be represented like this.  We also represent UNBOUND
;;; (i.e. a distinguished object used to fill unbound slots and
;;; variable values) as an immediate quantity.  
;;;
;;; Usually, when we refer to "heap object" or "heap-allocated
;;; object", we exclude CONS cells, even thogh technically, CONS cells
;;; are also heap allocated.  The reson we treat CONS cells
;;; differently from other heap-allocated data is simply to save
;;; space.  Since we require heap-allocated objects with the "other"
;;; tag to have a header word pointing to the class metaobject of the
;;; object, this would add 50% more space to each CONS cell.  Since we
;;; assume that Lisp programs still use a significant number of CONS
;;; cells, this decision seems worth it. 

(defconstant +tag-fixnum+    #b00)
(defconstant +tag-cons+      #b01)
(defconstant +tag-immediate+ #b10)
(defconstant +tag-other+     #b11)

(defconstant +tag-mask+      #b11)

(defconstant +tag-width+ (integer-length +tag-mask+))

(defconstant +immediate-tag-mask+ #b1111)

(defconstant +tag-character+ #b0010)

(defconstant +immediate-tag-width+ (integer-length +immediate-tag-mask+))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Fixnum range and conversion.

(defconstant +most-positive-fixnum+
  (1- (ash 1 (- +word-size-in-bits+ +tag-width+ 1))))

(defconstant +most-negative-fixnum+
  (- (ash 1 (- +word-size-in-bits+ +tag-width+ 1))))

;;; We allow negative words. 
(defun host-integer-to-word (host-integer)
  (assert (<= +most-negative-fixnum+ host-integer +most-positive-fixnum+))
  (+ (ash host-integer +tag-width+) +tag-fixnum+))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Character conversion.

;;; Assume for now that the host is using Unicode encoding. 
(defun host-char-to-word (host-char)
  (let ((code (char-code host-char)))
    (assert (<= 0 code (1- (ash 2 24))))
    (+ (ash code +immediate-tag-width+) +tag-character+)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Unbound.
;;;
;;; We define the unbound value to be a machine word with immediate
;;; tag, and all the other bits equal to 1. 

(defconstant +unbound+
  (logior (logandc2 (1- (ash 1 +word-size-in-bits+)) +tag-mask+)
	  +tag-immediate+))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; CONS cell utilities.

(defconstant +car-offset+
  (- +tag-cons+))

(defconstant +cdr-offset+
  (- +word-size-in-bytes+ +tag-cons+))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Heap object utilities.

(defconstant +class-offset+
  (- +tag-other+))

(defconstant +contents-offset+
  (- +word-size-in-bytes+ +tag-other+))
