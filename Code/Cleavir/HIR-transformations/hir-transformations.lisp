(cl:in-package #:cleavir-hir-transformations)

(defun hir-transformations (initial-instruction)
  (type-inference initial-instruction)
  (eliminate-typeq initial-instruction)
  (segregate-lexicals initial-instruction))