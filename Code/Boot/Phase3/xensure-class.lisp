(cl:in-package #:sicl-boot-phase3)

(defun *ensure-class (name
		      &rest arguments
		      &key
			direct-default-initargs
			direct-slots
			direct-superclasses
			(metaclass nil metaclass-p)
		      &allow-other-keys)
  ;; If the class already exists, then do nothing.
  (let ((class (find-ersatz-class name nil)))
    (if (null class)
	(let ((superclasses (loop for name in direct-superclasses
				  for class = (find-ersatz-class name)
				  collect class))
	      (remaining-keys (copy-list arguments)))
	  (loop while (remf remaining-keys :metaclass))
	  (loop while (remf remaining-keys :direct-superclasses))
	  (let* ((class (if metaclass-p
			    metaclass
			    'standard-class))
		 (result (apply #'make-instance class
				:direct-default-initargs direct-default-initargs
				:direct-slots direct-slots
				:name name
				:direct-superclasses superclasses
				remaining-keys)))
	    (add-ersatz-class name result)
	    result))
	class)))
