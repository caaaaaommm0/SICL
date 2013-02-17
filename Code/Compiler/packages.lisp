(defpackage #:sicl-compiler-environment
  (:nicknames #:sicl-env)
  (:use #:common-lisp)
  (:shadow #:type
	   #:proclaim
	   #:macroexpand-1
	   #:macroexpand
	   #:macro-function
	   #:*macroexpand-hook*
	   )
  (:export
   #:definition
   #:location #:lexical-location #:global-location #:special-location
   #:storage
   #:name
   #:type
   #:*global-environment*
   #:add-to-global-environment
   #:make-entry-from-declaration
   #:find-variable
   #:find-function
   #:find-block
   #:find-go-tag
   #:macroexpand-1
   #:macroexpand
   #:find-type
   #:find-ftype
   #:augment-environment
   #:augment-environment-with-declarations
   #:add-constant-variable-entry
   #:add-special-variable-entry
   #:add-lexical-variable-entry
   #:add-symbol-macro-entry
   #:add-global-function-entry
   #:add-local-function-entry
   #:add-macro-entry
   #:add-block-entry
   #:add-go-tag-entry
   #:constant-variable-info
   #:macro-info
   #:symbol-macro-info
   #:block-info
   #:tag-info
   #:special-location-info
   #:lexical-location-info
   #:global-location-info
   #:function-info
   #:variable-info
   ))

(defpackage #:sicl-ast
  (:use #:common-lisp)
  (:export
   #:ast
   #:constant-ast #:make-constant-ast #:value
   #:call-ast #:make-call-ast #:callee #:arguments
   #:block-ast #:make-block-ast #:body
   #:catch-ast #:make-catch-ast #:tag 
   #:eval-when-ast #:make-eval-when-ast #:situations
   #:function-ast #:make-function-ast #:body-ast
   #:go-ast #:make-go-ast #:tag-ast
   #:if-ast #:make-if-ast #:test-ast #:then-ast #:else-ast
   #:load-time-value-ast #:make-load-time-value-ast #:read-only-p
   #:multiple-value-call-ast
   #:make-multiple-value-call-ast #:function-ast #:argument-asts
   #:lambda-list #:required
   #:multiple-value-prog1-ast
   #:make-multiple-value-prog1-ast #:first-ast #:body-asts
   #:progn-ast #:make-progn-ast #:form-asts
   #:progv-ast #:make-progv-ast #:symbols-ast #:vals-ast
   #:return-from-ast #:make-return-from-ast #:form-ast
   #:setq-ast #:make-setq-ast #:location-ast #:value-ast
   #:tagbody-ast #:make-tagbody-ast #:items
   #:tag-ast #:make-tag-ast #:name
   #:the-ast #:make-the-ast #:value-type
   #:throw-ast #:make-throw-ast
   #:unwind-protect-ast
   #:make-unwind-protect-ast #:protected-ast #:cleanup-form-asts
   #:draw-ast
   #:children
   #:memalloc-ast #:make-memalloc-ast
   #:memref-ast #:make-memref-ast
   #:memset-ast #:make-memset-ast
   #:u+-ast #:make-u+-ast
   #:u--ast #:make-u--ast
   #:s+-ast #:make-s+-ast
   #:s--ast #:make-s--ast
   #:neg-ast #:make-neg-ast
   #:u*-ast #:make-u*-ast
   #:s*-ast #:make-s*-ast
   #:lshift-ast #:make-lshift-ast
   #:ashift-ast #:make-ashift-ast
   #:&-ast #:make-&-ast
   #:ior-ast #:make-ior-ast
   #:xor-ast #:make-xor-ast
   #:~-ast #:make-~-ast
   #:==-ast #:make-==-ast
   #:s<-ast #:make-s<-ast
   #:s<=-ast #:make-s<=-ast
   #:u<-ast #:make-u<-ast
   #:u<=-ast #:make-u<=-ast))

(defpackage #:sicl-compiler-phase-1
  (:nicknames #:p1)
  (:use #:common-lisp)
  (:shadow #:type
   )
  (:export
   #:ast
   #:constant-ast #:value
   #:call-ast #:callee #:arguments
   #:block-ast #:body
   #:catch-ast #:tag 
   #:eval-when-ast #:situations
   #:function-ast #:body-ast
   #:go-ast #:tag-ast
   #:if-ast #:test #:then #:else
   #:load-time-value-ast #:read-only-p
   #:multiple-value-call-ast #:function-ast #:argument-asts
   #:multiple-value-prog1-ast #:first-ast #:body-asts
   #:progn-ast #:form-asts
   #:progv-ast #:symbols-ast #:vals-ast
   #:return-from-ast #:form-ast
   #:setq-ast #:location-ast #:value-ast
   #:tagbody-ast #:items
   #:tag-ast #:name
   #:the-ast #:value-type
   #:throw-ast
   #:unwind-protect-ast #:protected-ast #:cleanup-form-asts
   #:lambda-list #:required #:optional #:rest-body
   #:keys #:allow-other-keys #:aux
   #:convert #:convert-compound
   #:draw-ast #:id
   ))

(defpackage #:sicl-mir
  (:use #:common-lisp)
  (:export
   #:instruction #:successors #:inputs #:outputs
   #:end-instruction #:make-end-instruction
   #:nop-instruction #:make-nop-instruction
   #:constant-assignment-instruction #:make-constant-assignment-instruction
   #:constant
   #:variable-assignment-instruction #:make-variable-assignment-instruction
   #:test-instruction #:make-test-instruction #:test
   #:funcall-instruction #:make-funcall-instruction #:fun
   #:get-arguments-instruction #:make-get-arguments-instruction #:lambda-list
   #:get-values-instruction #:make-get-values-instruction
   #:put-arguments-instruction #:make-put-arguments-instruction
   #:put-values-instruction #:make-put-values-instruction
   #:enter-instruction #:make-enter-instruction
   #:leave-instruction #:make-leave-instruction
   #:return-instruction #:make-return-instruction
   #:enclose-instruction #:make-enclose-instruction #:code
   #:go-instruction #:make-go-instruction
   #:memalloc-instruction #:make-memalloc-instruction
   #:memref-instruction #:make-memref-instruction
   #:memset-instruction #:make-memset-instruction
   #:u+-instruction #:make-u+-instruction
   #:u--instruction #:make-u--instruction
   #:s+-instruction #:make-s+-instruction
   #:s--instruction #:make-s--instruction
   #:neg-instruction #:make-neg-instruction
   #:&-instruction #:make-&-instruction
   #:ior-instruction #:make-ior-instruction
   #:xor-instruction #:make-xor-instruction
   #:~-instruction #:make-~-instruction
   #:==-instruction #:make-==-instruction
   #:s<-instruction #:make-s<-instruction
   #:s<=-instruction #:make-s<=-instruction
   #:u<-instruction #:make-u<-instruction
   #:u<=-instruction #:make-u<=-instruction
   #:draw-flowchart))

(defpackage #:sicl-compiler-phase-2
  (:nicknames #:p2)
  (:use #:common-lisp)
  (:export
   #:context #:results #:false-required-p
   #:nil-fill
   #:compile-ast
   #:compile-toplevel
   #:new-temporary
   ))

(defpackage #:sicl-word
  (:use #:common-lisp)
  (:export
   #:word
   #:memalloc #:memref #:memset
   #:u+ #:u- #:s+ #:s- #:neg
   #:u* #:s*
   #:lshift #:ashift
   #:& #:ior #:xor #:~
   #:== #:s< #:s<= #:u< #:u<=
   ))

(defpackage #:sicl-optimize
  (:use #:common-lisp)
  (:export
   ))

