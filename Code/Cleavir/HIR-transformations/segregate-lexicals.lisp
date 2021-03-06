(cl:in-package #:cleavir-hir-transformations)

;;;; Recall that an ENTER-INSTRUCTION is the successor of no other
;;;; instruction.
;;;;
;;;; The ENTER-INSTRUCTIONs of a program constitute a directed tree.
;;;; An ENTER-INSTRUCTION I closer to the root of the tree than some
;;;; other ENTER-INSTRUCTION J is said to be located FURTHER OUT than
;;;; J.
;;;;
;;;; We introduce the concept of OWNERSHIP.  This concept is defined
;;;; for lexical variables and for instructions.  The OWNER of an
;;;; instruction or a lexical variable is an ENTER-INSTRUCTION.
;;;;
;;;; Ownership for instructions is defined as follows:
;;;;
;;;;   * The owner of an ENTER-INSTRUCTION is itself.
;;;;
;;;;   * For all instruction types, EXCEPT the UNWIND-INSTRUCTION, the
;;;;     owner of the successors of an instruction I is the same as
;;;;     the owner of I.
;;;;
;;;;   * The owner of the successor of an UNWIND-INSTRUCTION I is the
;;;;     value returned by calling (INVOCATION I).
;;;;
;;;; The owner of a datum D is the outermost ENTER-INSTRUCTION of all
;;;; the owners of all the instructions using D.
;;;;
;;;; Each ENTER-INSTRUCTION A defines a PROCEDURE which is a the set
;;;; of all the instructions owned by A.  We extend the definition of
;;;; ownership so that a procedure P is the owner of some instruction
;;;; or datum X if an only if the unique ENTER-INSTRUCTION of P is the
;;;; owner of X.
;;;;
;;;; A procedure P is said to DEPEND on a different procedure Q if and
;;;; only if P or any of its descendants owns an instruction I (which
;;;; must then be an UNWIND-INSTRUCTION) with a successor owned by Q,
;;;; or if some instruction I owned by P or any of its descendants
;;;; refers to a datum owned by Q.
;;;;
;;;; The DROP of a procedure P is defined recursively as follows:
;;;;
;;;;   * If P depends on no other procedure then its drop is 0.
;;;;
;;;;   * Otherwise, the drop of P is d+1, where d is the
;;;;     maximum drop of any of the procedures it depends on.
;;;;
;;;; The drop is important for the following reason.  The runtime
;;;; environment could be organized as a list of LEVELS, where each
;;;; level is a vector.  A procedure P then has a runtime environment
;;;; with N = d+1 levels in it where d is the drop of P.  When some
;;;; procedure P with drop d executes an ENCLOSE-INSTRUCTION with some
;;;; procedure Q with drop e as an argument, then the top d-e+1 levels
;;;; of the static runtime environment of P should be discarded in
;;;; order to obtain the enclosed runtime environment.  Furthermore if
;;;; some procedure P with drop d accesses a variable owned by a
;;;; procedure Q with drop e, then level d-e of the static runtime
;;;; should be consulted.

(defun data (instruction)
  (append (cleavir-ir:inputs instruction)
	  (cleavir-ir:outputs instruction)))

(defvar *ownerships*)

(defun owner (item)
  (gethash item *ownerships*))

(defun (setf owner) (new-owner item)
  (setf (gethash item *ownerships*) new-owner))

(defun has-owner-p (item)
  (nth-value 1 (gethash item *ownerships*)))

;;; Compute the owner of each instruction and each datum.  The return
;;; value is an EQ hash table mapping an instruction or a datum to its
;;; owner.
(defun compute-ownerships (initial-instruction)
  (let ((*ownerships* (make-hash-table :test #'eq)))
    (cleavir-ir:map-instructions-by/with-owner
     (lambda (instruction owner)
       (setf (owner instruction) owner)
       (loop for datum in (data instruction)
	     do (unless (has-owner-p datum)
		  (setf (owner datum) owner))))
     initial-instruction)
    *ownerships*))

;;; By SEGREGATING lexical locations, we mean taking each lexical
;;; location and turning it into either a dynamic lexical location
;;; (which can be allocated in a register or on the stack) or an
;;; static lexical location (which may or may not be possible to
;;; allocate on the stack, and might have to be allocated in some
;;; other place, possibly on the heap).
;;;
;;; The method used here is very simple, and not particularly
;;; sophisticated.  It assumes that every nested function can escape
;;; in arbitrary ways, so that every lexical location that is shared
;;; by some function F and some other function G nested inside F must
;;; be an static lexical location.

(defun segregate-lexicals (initial-instruction)
  ;; Make sure everything is up to date.
  (cleavir-ir:reinitialize-data initial-instruction)
  (let ((owners (make-hash-table :test #'eq)))
    (cleavir-ir:map-instructions-with-owner
     (lambda (instruction owner)
       (loop for datum in (append (cleavir-ir:inputs instruction)
				  (cleavir-ir:outputs instruction))
	     do (when (eq (class-of datum)
				    (find-class 'cleavir-ir:lexical-location))
		  (cond ((null (gethash datum owners))
			 (setf (gethash datum owners) owner))
			((eq owner (gethash datum owners))
			 nil)
			(t
			 (change-class
			  datum
			  'cleavir-ir:static-lexical-location))))))
     initial-instruction))
  (cleavir-ir:map-instructions
   (lambda (instruction)
     (loop for datum in (append (cleavir-ir:inputs instruction)
				(cleavir-ir:outputs instruction))
	   do (when (eq (class-of datum)
			(find-class 'cleavir-ir:lexical-location))
		(change-class
		 datum
		 'cleavir-ir:dynamic-lexical-location))))
   initial-instruction))

;;; Given an instruction I that writes to a captured variable CV, and
;;; a dynamic lexical variable L holding the location of the cell that
;;; will store the value of CV, we do the following: We allocate a new
;;; temporary dynamic lexical variable V.  We return V from this
;;; function so that the caller can replace CV by V in I.  We add a
;;; WRITE-CELL-INSTRUCTION after I that writes the contents of V to
;;; the cell in L.
(defun new-output (instruction cell-location)
  (let ((temp (cleavir-ir:new-dynamic-temporary)))
    (cleavir-ir:insert-instruction-after
     (cleavir-ir:make-write-cell-instruction
      cell-location temp)
     instruction)
    ;; Return the new output to this instruction.
    temp))

;;; Given an instruction I that reads a captured variable CV, and a
;;; dynamic lexical variable L holding the location of the cell that
;;; will store the value of CV, we do the following: We allocate a new
;;; temporary dynamic lexical variable V.  We return V from this
;;; function so that the caller can replace CV by V in I.  We add a
;;; READ-CELL-INSTRUCTION before I that reads the contents of the cell
;;; in L and writes it into V.
(defun new-input (instruction cell-location)
  (let ((temp (cleavir-ir:new-dynamic-temporary)))
    (cleavir-ir:insert-instruction-before
     (cleavir-ir:make-read-cell-instruction
      cell-location temp)
     instruction)
    ;; Return the new input to this instruction.
    temp))

;;; This function adds a FETCH instruction before INSTRUCTION.  OWNER
;;; is the owner of INSTRUCTION, and it is known that OWNER is NOT the
;;; owner of LOCATION.  In other words, LOCATION is one of the
;;; locations imported to OWNER.  We allocate a new temporary dynamic
;;; lexical variable to hold the cell that the FETCH instruction
;;; fetches, so that the new temporary is the output of the FETCH
;;; instruction.  We return that new temporary variable.
(defun fetch-cell (instruction owner location imports)
  (let ((pos (position location (gethash owner imports))))
    (when (null pos)
      ;; We haven't seen this location before.  Add it to the imports
      ;; of OWNER.  We add it to the end so that the position of each
      ;; of the ones we have already seen remains the same.
      (setf (gethash owner imports)
	    (append (gethash owner imports) (list location)))
      (setf pos (1- (length (gethash owner imports)))))
    ;; We must now generate a FETCH instruction to load the cell from
    ;; the static environment
    (let* ((temp (cleavir-ir:new-dynamic-temporary))
	   (env-location (first (cleavir-ir:outputs owner)))
	   (index (cleavir-ir:make-immediate-input pos))
	   (fetch (cleavir-ir:make-fetch-instruction
		   env-location index temp)))
      (cleavir-ir:insert-instruction-before fetch instruction)
      ;; Return the temporary holding the cell.
      temp)))

;;; Compute and return a list of new outputs for INSTRUCTION.  OWNER
;;; is the owner of INSTRUCTION.  OWNERS
(defun new-outputs (instruction owner owners imports cell-locations)
  (loop for output in (cleavir-ir:outputs instruction)
	collect
	(if (typep output 'cleavir-ir:static-lexical-location)
	    (let ((output-owner (gethash output owners)))
	      (when (null output-owner)
		(setf output-owner owner)
		(setf (gethash output owners) output-owner))
	      (if (eq output-owner owner)
		  ;; The owner of this instruction is also the owner
		  ;; of the captured variable.  Check whether we have
		  ;; written to it before.  If we have, then we have
		  ;; allocated a location for the corresponding cell.
		  (let ((location (gethash (cons owner output)
					   cell-locations)))
		    (if (null location)
			;; This write is the defining write to the
			;; variable, so we must allocate a location
			;; for its cell.
			(progn
			  (setf location (cleavir-ir:new-dynamic-temporary))
			  (setf (gethash (cons owner output)
					 cell-locations)
				location)
			  ;; Our mission now is to add two new
			  ;; instructions.  The first of the two new
			  ;; instructions (I1) is an instruction to
			  ;; create the cell.  The second (I2) is the
			  ;; one writing to the cell.  Since it is
			  ;; possible that there is an
			  ;; ENCLOSE-INSTRUCTION before INSTRUCTION
			  ;; that will have the cell as input, we must
			  ;; create the cell early.  We do it
			  ;; conservatively by adding I1 right after
			  ;; the OWNER of INSTRUCTION.  But I1 must
			  ;; absolutely come before I2, so in case
			  ;; INSTRUCTION is its own owner, we first
			  ;; add I2 after INSTRUCTION, and then I1
			  ;; after the owner of INSTRUCTION.  Recall
			  ;; that the function NEW-OUTPUT does the job
			  ;; of adding I2.
			  (let ((new-output (new-output instruction location)))
			    ;; We must now add I1 to create the cell.
			    (cleavir-ir:insert-instruction-after
			     (cleavir-ir:make-create-cell-instruction
			      location)
			     owner)
			    ;; Return the new output to replace the old
			    ;; one in INSTRUCTION.
			    new-output))
			;; This write is not the defining write, so we
			;; just change the current output to a
			;; temporary dynamic lexical location, and
			;; then add a WRITE-CELL instruction after
			;; this one to write the contents of that
			;; temporary location to the cell.
			(new-output instruction location)))
		  ;; The owner if this instruction is not the owner of
		  ;; the captured variable.  We need to fetch the cell
		  ;; from our static environment.
		  (let ((cell-location (fetch-cell instruction
						   owner
						   output
						   imports)))
		    ;; We must now change the current output to a
		    ;; temporary dynamic lexical location, and then
		    ;; add a WRITE-CELL instruction after this one to
		    ;; write the contents of that temporary location
		    ;; to the cell.
		    (new-output instruction cell-location))))
	    ;; This input is not a captured variable, return it
	    ;; unchanged.
	    output)))

;;; Compute and return a list of new inputs for INSTRUCTION.  OWNER is
;;; the owner of INSTRUCTION.
(defun new-inputs (instruction owner owners imports cell-locations)
  (loop for input in (cleavir-ir:inputs instruction)
	do (when (null (gethash input owners))
	     (setf (gethash input owners) owner))
	collect
	(if (typep input 'cleavir-ir:static-lexical-location)
	    (let ((input-owner (gethash input owners)))
	      (when (null input-owner)
		(setf input-owner owner)
		(setf (gethash input owners) input-owner))
	      (if (eq input-owner owner)
		  ;; The owner of this instruction is also the owner
		  ;; of the captured variable.  This means that we
		  ;; already allocated a dynamic lexical location for
		  ;; it.
		  (let ((location (gethash (cons owner input)
					   cell-locations)))
		    ;; We must now generate a READ-CELL instruction to
		    ;; read the value into a temporary location.
		    (new-input instruction location))
		  ;; The owner of this instruction is not the owner of
		  ;; the captured variable.  We need to fetch the cell
		  ;; from our static environment.
		  (let ((cell-location (fetch-cell instruction
						   owner
						   input
						   imports)))
		    ;; We must now generate a READ-CELL instruction to
		    ;; read the value into a temporary location.
		    (new-input instruction cell-location))))
	    ;; This input is not a captured variable, return it
	    ;; unchanged.
	    input)))

(defun handle-enclose-instruction (enclose owner owners imports cell-locations)
  (setf (cleavir-ir:inputs enclose)
	(loop with enter = (cleavir-ir:code enclose)
	      for import in (gethash enter imports)
	      collect
	      (if (eq (gethash import owners) owner)
		  (gethash (cons owner import) cell-locations)
		  (fetch-cell enclose owner import imports)))))

;;; For each ENCLOSE-INSTRUCTION of the program, add inputs
;;; corresponding to the cells of the captured variables that the
;;; corresponding ENTER-INSTRUCTION imports.
(defun handle-enclose-instructions
    (initial-instruction owners imports cell-locations)
  (let ((enclose-instructions-to-handle '()))
    (cleavir-ir:map-instructions-with-owner
     (lambda (instruction owner)
       (when (typep instruction 'cleavir-ir:enclose-instruction)
	 (push (cons instruction owner) enclose-instructions-to-handle)))
     initial-instruction)
    (loop until (null enclose-instructions-to-handle)
	    do (destructuring-bind (instruction . owner)
		   (pop enclose-instructions-to-handle)
		 (handle-enclose-instruction
		  instruction owner owners imports cell-locations)))))

(defun process-captured-variables (initial-instruction)
  (segregate-lexicals initial-instruction)
  (let ((owners (make-hash-table :test #'eq))
	;; This table maps each ENTER-INSTRUCTION to a list of
	;; imported static lexical locations that it needs.
	(imports (make-hash-table :test #'eq))
	;; This table maps pairs of the form (<enter-instruction>
	;; . <static-lexical-location>) to dynamic lexical locations
	;; holding the cell for the captured variable.
	(cell-locations (make-hash-table :test #'equal)))
    ;; Replace every reference to a static lexical location by a
    ;; combination of dynamic lexical locations and new instructions
    ;; for allocating the cell holding the value of the variable.
    (cleavir-ir:map-instructions-with-owner
     (lambda (instruction owner)
       (setf (cleavir-ir:inputs instruction)
	     (new-inputs instruction owner owners imports cell-locations))
       ;; Now process the outputs of this instruction
       (setf (cleavir-ir:outputs instruction)
	     (new-outputs instruction owner owners imports cell-locations)))
     initial-instruction)
    (handle-enclose-instructions
     initial-instruction owners imports cell-locations)))
